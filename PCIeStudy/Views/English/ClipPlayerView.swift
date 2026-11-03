import AVKit
import UIKit
import UniformTypeIdentifiers
import SwiftUI

/// 動画を再生しながら、文字起こしした英文を1文ずつ練習する
struct ClipPlayerView: View {
    private enum Mode: String, CaseIterable, Identifiable {
        case normal, repeatLine, stopEachLine

        var id: String { rawValue }

        var label: String {
            switch self {
            case .normal: return "通常"
            case .repeatLine: return "1文くり返し"
            case .stopEachLine: return "1文ずつ止める"
            }
        }
    }

    let clipID: UUID
    private let startAt: Double?

    @Environment(EnglishStore.self) private var store
    @Environment(SpecRAGClient.self) private var pc
    @State private var player: AVPlayer
    @State private var fetchingVideo = false
    @State private var fetchVideoError: String?
    @State private var timeObserver: Any?
    @State private var currentTime = 0.0
    @State private var rate: Float = 1.0
    @State private var mode = Mode.normal
    /// 「1文くり返し」で再生している文
    @State private var loopLine: TranscriptLine?
    @State private var hidesText = false
    @State private var revealed: Set<UUID> = []
    @State private var transcribing = false
    @State private var transcribeProgress = 0.0
    @State private var transcribeError: String?
    @State private var savingLine: TranscriptLine?
    @State private var translatingText = ""
    @State private var showsTranslation = false
    /// 全文の日本語訳を表示する
    @State private var showsJapanese = false
    @State private var translateError: String?
    @State private var showsQA = false
    @State private var showsSongs = false
    @State private var showsSubtitleImporter = false

    init(clip: EnglishClip, startAt: Double? = nil) {
        clipID = clip.id
        self.startAt = startAt
        _player = State(initialValue: AVPlayer(url: EnglishStore.fileURL(for: clip)))
    }

    private var clip: EnglishClip? { store.clip(id: clipID) }
    private var lines: [TranscriptLine] { clip?.lines ?? [] }

    /// 共有・コピー用のスクリプト（1行に1文、先頭に時刻）
    private var scriptText: String {
        let body = lines.map { line in
            let english = "[\(TimeText.format(line.start))] \(line.text)"
            guard showsJapanese, let japanese = line.japanese else { return english }
            return english + "\n　\(japanese)"
        }.joined(separator: "\n")
        return "\(clip?.title ?? "")\n\n\(body)"
    }

    var body: some View {
        VStack(spacing: 0) {
            if clip?.hasVideo ?? false {
                VideoPlayer(player: player)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .background(Color.black)
            } else {
                missingVideo
                    .aspectRatio(16 / 9, contentMode: .fit)
            }

            controls
                .padding(.horizontal)
                .padding(.vertical, 10)

            if clip?.lines == nil || transcribing {
                transcribePrompt
            } else {
                transcript
            }
        }
        .screenBackground()
        .navigationTitle(clip?.title ?? "動画")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if clip?.lines != nil {
                if TranscriptTranslation.isSupported {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showsJapanese.toggle()
                        } label: {
                            Image(systemName: showsJapanese ? "character.bubble.fill" : "character.bubble")
                        }
                        .accessibilityLabel(showsJapanese ? "日本語訳を隠す" : "日本語訳を表示する")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        hidesText.toggle()
                        revealed = []
                    } label: {
                        Image(systemName: hidesText ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(hidesText ? "英文を表示する" : "英文を隠す")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ShareLink(item: scriptText) {
                            Label("スクリプトを共有", systemImage: "square.and.arrow.up")
                        }
                        Button {
                            UIPasteboard.general.string = scriptText
                        } label: {
                            Label("スクリプトをコピー", systemImage: "doc.on.doc")
                        }
                        Button {
                            showsSongs = true
                        } label: {
                            Label("流れている曲を調べる", systemImage: "music.note.list")
                        }
                        if #available(iOS 26.0, *) {
                            Button {
                                showsQA = true
                            } label: {
                                Label("動画で Q&A（要約・クイズ・質問）", systemImage: "sparkles")
                            }
                        }
                        Button {
                            showsSubtitleImporter = true
                        } label: {
                            Label("字幕ファイルを読み込む", systemImage: "captions.bubble")
                        }
                        Button(role: .destructive) {
                            loopLine = nil
                            Task { await transcribe() }
                        } label: {
                            Label("文字起こしをやり直す", systemImage: "arrow.clockwise")
                        }
                        .disabled(transcribing)
                    } label: {
                        Image(systemName: "doc.plaintext")
                    }
                    .accessibilityLabel("スクリプト")
                }
            }
        }
        .onAppear(perform: startObserving)
        .onDisappear {
            player.pause()
            if let timeObserver { player.removeTimeObserver(timeObserver) }
            timeObserver = nil
        }
        .sheet(item: $savingLine) { line in
            SavePhraseSheet(line: line, clipID: clipID)
        }
        .fileImporter(isPresented: $showsSubtitleImporter,
                      allowedContentTypes: ["srt", "vtt"].compactMap { UTType(filenameExtension: $0, conformingTo: .text) }) { result in
            importSubtitles(result)
        }
        .sheet(isPresented: $showsSongs) {
            SongListView(clipID: clipID) { seconds in
                seek(to: seconds, play: true)
            }
        }
        .sheet(isPresented: $showsQA) {
            if #available(iOS 26.0, *) {
                ClipQAView(title: clip?.title ?? "", lines: lines) { seconds in
                    seek(to: seconds, play: true)
                }
            }
        }
        .modifier(TranslationSheet(isPresented: $showsTranslation, text: translatingText))
        .modifier(TranscriptTranslation(isActive: showsJapanese && !transcribing, lines: lines,
                                        onTranslated: { store.setTranslations($0, for: clipID) },
                                        onError: { translateError = $0 }))
        .alert("翻訳できませんでした", isPresented: Binding(get: { translateError != nil },
                                                    set: { if !$0 { translateError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(translateError ?? "")
        }
        .alert("文字起こしできませんでした", isPresented: Binding(get: { transcribeError != nil },
                                                       set: { if !$0 { transcribeError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(transcribeError ?? "")
        }
    }

    // MARK: - 動画がこの iPhone にないとき

    /// ブラウザ版で取り込んだ動画は、スクリプトだけ同期される。PC で保存した動画なら受け取れる
    private var missingVideo: some View {
        VStack(spacing: 10) {
            Image(systemName: "film.stack").font(.largeTitle).foregroundStyle(.secondary)
            if clip?.youtubeID != nil {
                Text("動画は PC にあります").font(.subheadline)
                if fetchingVideo {
                    ProgressView("受け取り中…")
                } else {
                    Button {
                        Task { await fetchVideo() }
                    } label: {
                        Label("PC から動画を受け取る", systemImage: "square.and.arrow.down")
                    }
                    .buttonStyle(AppButtonStyle(.primary))
                    .controlSize(.small)
                }
                if let fetchVideoError {
                    Text(fetchVideoError).font(.caption).foregroundStyle(.red)
                }
            } else {
                Text("動画はほかの端末にあります。スクリプト・訳・フレーズは使えます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.secondarySystemBackground))
    }

    private func fetchVideo() async {
        guard let youtubeID = clip?.youtubeID else { return }
        fetchingVideo = true
        fetchVideoError = nil
        defer { fetchingVideo = false }
        do {
            let file = try await PCVideoFetcher.fetchLibraryVideo(youtubeID: youtubeID, base: pc.baseURL)
            store.attachVideo(copiedFile: file, to: clipID)
            player.replaceCurrentItem(with: AVPlayerItem(url: file))
        } catch {
            fetchVideoError = error.localizedDescription
        }
    }

    // MARK: - 操作ボタン

    private var controls: some View {
        VStack(spacing: 10) {
            HStack {
                Button {
                    seek(to: currentTime - 5, play: false)
                } label: {
                    Label("5秒戻る", systemImage: "gobackward.5")
                }
                .buttonStyle(AppButtonStyle(.secondary))
                .controlSize(.small)

                Spacer()

                Picker("速さ", selection: $rate) {
                    Text("0.5×").tag(Float(0.5))
                    Text("0.75×").tag(Float(0.75))
                    Text("1×").tag(Float(1.0))
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)
                .onChange(of: rate) { _, newRate in
                    player.defaultRate = newRate
                    if player.rate != 0 { player.rate = newRate }
                }
            }

            if clip?.lines != nil {
                Picker("練習のしかた", selection: $mode) {
                    ForEach(Mode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: mode) { _, newMode in
                    loopLine = newMode == .repeatLine ? lineAt(currentTime) : nil
                }
            }
        }
    }

    // MARK: - 文字起こし前

    private var transcribePrompt: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Label("英語を文字起こしする", systemImage: "waveform")
                    .font(.headline)
                Text("iPhone の音声認識で英語を書き起こし、1文ずつに分けます。英語の音声認識データが iPhone に入っていないときは、音声を Apple に送って認識します。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("長い動画は時間がかかります（10分の動画で数分ほど）。最初は1〜3分くらいの短い動画がおすすめです。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if transcribing {
                    ProgressView(value: transcribeProgress) {
                        Text("文字起こし中… \(Int(transcribeProgress * 100))%")
                            .font(.caption)
                    }
                } else {
                    Button {
                        Task { await transcribe() }
                    } label: {
                        Text("文字起こしを始める").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppButtonStyle(.primary))

                    Button {
                        showsSubtitleImporter = true
                    } label: {
                        Label("字幕ファイル（.srt / .vtt）を読み込む", systemImage: "captions.bubble").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppButtonStyle(.secondary))

                    Button {
                        showsSongs = true
                    } label: {
                        Label("流れている曲を調べる", systemImage: "music.note.list").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppButtonStyle(.secondary))
                }
            }
            .padding()
            .cardStyle()
            .padding()
        }
    }

    /// 字幕ファイルを、文字起こしの代わりに使う
    private func importSubtitles(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let lines = SubtitleParser.parse(try String(contentsOf: url, encoding: .utf8))
            guard !lines.isEmpty else {
                transcribeError = "字幕ファイルから文を読み取れませんでした。"
                return
            }
            loopLine = nil
            store.setLines(lines, for: clipID)
        } catch {
            transcribeError = error.localizedDescription
        }
    }

    private func transcribe() async {
        guard let clip else { return }
        transcribing = true
        transcribeProgress = 0
        defer { transcribing = false }
        do {
            let result = try await ClipTranscriber.transcribe(fileURL: EnglishStore.fileURL(for: clip)) { value in
                transcribeProgress = value
            }
            store.setLines(result, for: clip.id)
        } catch {
            transcribeError = error.localizedDescription
        }
    }

    // MARK: - 英文の一覧

    private var transcript: some View {
        let current = lineAt(currentTime)?.id
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(lines) { line in
                        lineRow(line, isCurrent: line.id == current)
                            .id(line.id)
                    }
                }
                .padding()
            }
            .onChange(of: current) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
            .onAppear {
                if let startAt, let line = lineAt(startAt) {
                    proxy.scrollTo(line.id, anchor: .center)
                }
            }
        }
    }

    private func lineRow(_ line: TranscriptLine, isCurrent: Bool) -> some View {
        let hidden = hidesText && !revealed.contains(line.id)
        return HStack(alignment: .top, spacing: 10) {
            Text(TimeText.format(line.start))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(line.text)
                    .font(.body)
                if showsJapanese {
                    if let japanese = line.japanese {
                        Text(japanese)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("翻訳中…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .redacted(reason: hidden ? .placeholder : [])
            if hidden {
                Button {
                    revealed.insert(line.id)
                } label: {
                    Image(systemName: "eye")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("この文を表示")
            }
            if loopLine?.id == line.id {
                Image(systemName: "repeat")
                    .foregroundStyle(.tint)
            }
        }
        .padding(12)
        .choiceTile(isCurrent ? .correct : .normal, cornerRadius: 12)
        .contentShape(Rectangle())
        .onTapGesture {
            if mode == .repeatLine { loopLine = line }
            seek(to: line.start, play: true)
        }
        .contextMenu {
            Button {
                mode = .repeatLine
                loopLine = line
                seek(to: line.start, play: true)
            } label: {
                Label("この文をくり返す", systemImage: "repeat")
            }
            Button {
                savingLine = line
            } label: {
                Label("フレーズ帳に保存", systemImage: "text.book.closed")
            }
            if TranslationSheet.isSupported {
                Button {
                    translatingText = line.text
                    showsTranslation = true
                } label: {
                    Label("日本語訳を見る", systemImage: "character.book.closed.ja")
                }
            }
            Button {
                UIPasteboard.general.string = line.text
            } label: {
                Label("コピー", systemImage: "doc.on.doc")
            }
        }
    }

    // MARK: - 再生

    private func lineAt(_ time: Double) -> TranscriptLine? {
        lines.last { $0.start <= time + 0.05 && time < $0.end + 0.4 }
    }

    private func seek(to seconds: Double, play: Bool) {
        let target = CMTime(seconds: max(seconds, 0), preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        currentTime = max(seconds, 0)
        if play { player.playImmediately(atRate: rate) }
    }

    private func startObserving() {
        guard timeObserver == nil else { return }
        player.defaultRate = rate
        if let startAt { seek(to: startAt, play: false) }
        let interval = CMTime(seconds: 0.1, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            let previous = currentTime
            let now = time.seconds
            guard now.isFinite else { return }
            currentTime = now
            guard player.rate != 0 else { return }
            switch mode {
            case .normal:
                break
            case .repeatLine:
                if let loopLine, now >= loopLine.end {
                    seek(to: loopLine.start, play: true)
                }
            case .stopEachLine:
                // 文の終わりを通り過ぎたら止める（自分で声に出して真似する時間）
                if lines.contains(where: { previous < $0.end && $0.end <= now }) {
                    player.pause()
                }
            }
        }
    }
}

// MARK: - フレーズを保存

private struct SavePhraseSheet: View {
    let line: TranscriptLine
    let clipID: UUID

    @Environment(EnglishStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var memo = ""
    @State private var showsTranslation = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("フレーズ", text: $text, axis: .vertical)
                } header: {
                    Text("フレーズ")
                } footer: {
                    Text("覚えたい部分だけ残して、あとは消してもかまいません。")
                }
                Section("意味・メモ") {
                    TextField("例：〜してもいい？（くだけた言い方）", text: $memo, axis: .vertical)
                    if TranslationSheet.isSupported {
                        Button {
                            showsTranslation = true
                        } label: {
                            Label("日本語訳を見る", systemImage: "character.book.closed.ja")
                        }
                    }
                }
            }
            .screenBackground()
            .navigationTitle("フレーズ帳に保存")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        store.addPhrase(text: text, memo: memo, clipID: clipID, start: line.start)
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .modifier(TranslationSheet(isPresented: $showsTranslation, text: text))
            .onAppear { text = line.text }
        }
    }
}
