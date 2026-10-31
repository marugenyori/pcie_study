import AVKit
import UIKit
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
    @State private var player: AVPlayer
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

    init(clip: EnglishClip, startAt: Double? = nil) {
        clipID = clip.id
        self.startAt = startAt
        _player = State(initialValue: AVPlayer(url: EnglishStore.fileURL(for: clip)))
    }

    private var clip: EnglishClip? { store.clip(id: clipID) }
    private var lines: [TranscriptLine] { clip?.lines ?? [] }

    var body: some View {
        VStack(spacing: 0) {
            VideoPlayer(player: player)
                .aspectRatio(16 / 9, contentMode: .fit)
                .background(Color.black)

            controls
                .padding(.horizontal)
                .padding(.vertical, 10)

            if clip?.lines == nil {
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        hidesText.toggle()
                        revealed = []
                    } label: {
                        Image(systemName: hidesText ? "eye.slash" : "eye")
                    }
                    .accessibilityLabel(hidesText ? "英文を表示する" : "英文を隠す")
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
        .modifier(TranslationSheet(isPresented: $showsTranslation, text: translatingText))
        .alert("文字起こしできませんでした", isPresented: Binding(get: { transcribeError != nil },
                                                       set: { if !$0 { transcribeError = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(transcribeError ?? "")
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
                }
            }
            .padding()
            .cardStyle()
            .padding()
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
            Text(line.text)
                .font(.body)
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
