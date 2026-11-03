import SwiftUI

// MARK: - 一覧

struct EnglishHomeView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var player = SpeechPlayer()
    @State private var downloader = VoiceDownloader()

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("英語で PCIe を聞く", systemImage: "ear")
                        .font(.headline)
                        .foregroundStyle(.tint)
                    Text("PCIe の仕組みを英語で聞いて、技術英語の耳を作ります。1つのレッスンは次の順に進めるのがおすすめです。")
                        .font(.subheadline)
                    VStack(alignment: .leading, spacing: 4) {
                        stepLine("1", "スライド：図を見ながら聞いて、何の話かつかむ")
                        stepLine("2", "聞く：英文を隠したまま聞き、次に英文を見ながら聞く")
                        stepLine("3", "問題：英語の質問に答えて、聞き取れたか確かめる")
                        stepLine("4", "書き取り：1文ずつ聞いて、抜けた単語を選ぶ")
                        stepLine("5", "単語：よく出る語の発音と、聞こえ方のコツ")
                        stepLine("6", "質問：わからないところを AI に聞く")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                Picker("速さ", selection: Binding(get: { player.speed }, set: { player.setSpeed($0) })) {
                    ForEach(SpeechPlayer.Speed.allCases) { Text($0.label).tag($0) }
                }
                Picker("発音", selection: Binding(get: { player.accent }, set: { player.setAccent($0) })) {
                    ForEach(SpeechPlayer.Accent.allCases) { Text($0.label).tag($0) }
                }
                Toggle("PC の AI の声を使う", isOn: Binding(get: { player.usesPCVoice }, set: { player.setUsesPCVoice($0) }))
                if player.usesPCVoice, let voice = player.accent.pcVoice {
                    voiceDownloadRow(voice: voice)
                }
                Button {
                    player.say("The Data Link Layer replays the TLP when it receives a NAK.", source: "sample")
                } label: {
                    Label("この設定で試しに聞く", systemImage: "speaker.wave.2")
                }
            } header: {
                Text("音声")
            } footer: {
                if player.usesPCVoice {
                    Text(pcVoiceNote)
                }
                if !player.hasEnhancedVoice(for: player.accent) {
                    Text("声が機械っぽいときは、iPhone の「設定」→「アクセシビリティ」→「読み上げコンテンツ」→「声」→「英語」で、「拡張」や「プレミアム」の声をダウンロードすると自然になります。")
                }
            }

            Section("耳を慣らす") {
                NavigationLink {
                    SpokenTermsView(player: player)
                } label: {
                    Label("PCIe の言葉の英語での読み方", systemImage: "character.bubble")
                }
            }

            Section {
                ForEach(EnglishData.all) { lesson in
                    NavigationLink {
                        EnglishLessonView(lesson: lesson, player: player)
                    } label: {
                        EnglishLessonRow(lesson: lesson, done: progress.isEnglishDone(lesson.id))
                    }
                }
            } header: {
                Text("レッスン（\(progress.englishDone.count) / \(EnglishData.all.count)）")
            }
        }
        .screenBackground()
        .navigationTitle("英語で聞く")
        .onDisappear { player.stop() }
    }

    /// PC の声を iPhone に保存する（家の外でも PC の声で聞くため）
    @ViewBuilder
    private func voiceDownloadRow(voice: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if downloader.isRunning {
                ProgressView(value: Double(downloader.done), total: Double(max(downloader.total, 1))) {
                    Text("PC の声を保存中… \(downloader.done) / \(downloader.total)").font(.caption)
                }
                Button("止める", role: .cancel) { downloader.cancel() }
                    .font(.caption.bold())
            } else {
                Button {
                    downloader.start(voice: voice, speed: player.speed.pcSpeed, skipping: progress.englishDone)
                } label: {
                    Label("PC の声をダウンロード（家の外でも使う）", systemImage: "arrow.down.circle")
                }
                Text("完了したレッスン（\(progress.englishDone.count) 本）の分はダウンロードしません。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack {
                Text("保存した音声：\(ByteCountFormatter.string(fromByteCount: downloader.savedBytes, countStyle: .file))")
                Spacer()
                if downloader.savedBytes > 0 && !downloader.isRunning {
                    Button("削除", role: .destructive) { downloader.removeAll() }
                        .buttonStyle(.borderless)
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            if let message = downloader.message {
                Text(message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    /// PC の声の状態の説明
    private var pcVoiceNote: String {
        if player.accent.pcVoice == nil {
            return "PC の AI の声はアメリカ・イギリスの発音だけです。この発音は iPhone の声で読みます。"
        }
        switch player.pcVoiceWorked {
        case true?: return "PC の AI の声で読んでいます（PC と同じ Wi‑Fi のとき）。家の外でも使うには、上の「PC の声をダウンロード」で保存しておきます。保存は今の発音・速さの分だけです。"
        case false?: return "PC の AI の声が使えなかったので、iPhone の声で読みました。PC のサーバが動いているか、PC 側の準備（docs/PC_TTS.md）ができているか確認してください。"
        case nil: return "PC と同じ Wi‑Fi のときは、PC の AI の声（Kokoro）で読みます。家の外では iPhone の声で読みます。"
        }
    }

    private func stepLine(_ number: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(number).bold().foregroundStyle(.tint)
            Text(text)
        }
    }
}

struct EnglishLessonRow: View {
    let lesson: EnglishLesson
    let done: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    LevelBadge(level: lesson.level)
                    Text(lesson.titleJa).font(.caption).foregroundStyle(.secondary)
                }
                Text(lesson.title).font(.body.weight(.medium))
            }
            Spacer()
            if done {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - 読み方

struct SpokenTermsView: View {
    let player: SpeechPlayer

    var body: some View {
        List {
            Section {
                ForEach(EnglishData.terms) { term in
                    Button {
                        player.say(term.speech, source: "term-\(term.id)")
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(term.written).font(.headline.monospaced())
                                    Text(term.reading).font(.subheadline).foregroundStyle(.tint)
                                }
                                Text(term.tip).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            SpeakerIcon(playing: player.isPlaying("term-\(term.id)"))
                        }
                    }
                    .buttonStyle(.plain)
                }
            } footer: {
                Text("タップすると読み上げます。英語の会議や動画では、略語が「1文字ずつ」読まれるものと「単語として」読まれるものがあるので、両方に慣れておきましょう。")
            }
        }
        .screenBackground()
        .navigationTitle("英語での読み方")
        .onDisappear { player.stop() }
    }
}

// MARK: - レッスン

struct EnglishLessonView: View {
    let player: SpeechPlayer

    enum Step: String, CaseIterable, Identifiable {
        case slides, listen, questions, dictation, words, qa
        var id: String { rawValue }
        var label: String {
            switch self {
            case .slides: return "スライド"
            case .listen: return "聞く"
            case .questions: return "問題"
            case .dictation: return "書き取り"
            case .words: return "単語"
            case .qa: return "質問"
            }
        }

        var symbol: String {
            switch self {
            case .slides: return "rectangle.on.rectangle"
            case .listen: return "ear"
            case .questions: return "checkmark.circle"
            case .dictation: return "pencil"
            case .words: return "textformat.abc"
            case .qa: return "bubble.left.and.bubble.right"
            }
        }
    }

    /// 前後のレッスンへ移れるように、画面の中で持つ
    @State private var lesson: EnglishLesson
    @State private var step: Step = .slides
    @Environment(\.dismiss) private var dismiss
    @Environment(\.goToTabRoot) private var goToTabRoot

    init(lesson: EnglishLesson, player: SpeechPlayer) {
        self.player = player
        _lesson = State(initialValue: lesson)
    }

    private var lessonIndex: Int? { EnglishData.all.firstIndex { $0.id == lesson.id } }
    private var previousLesson: EnglishLesson? {
        lessonIndex.flatMap { $0 > 0 ? EnglishData.all[$0 - 1] : nil }
    }
    private var nextLesson: EnglishLesson? {
        lessonIndex.flatMap { $0 + 1 < EnglishData.all.count ? EnglishData.all[$0 + 1] : nil }
    }

    private func open(_ other: EnglishLesson) {
        player.stop()
        lesson = other
        step = .slides
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        LevelBadge(level: lesson.level)
                        Text(lesson.titleJa).font(.caption).foregroundStyle(.secondary)
                    }
                    Text(lesson.title).font(.title.bold())
                }

                // ステップは6つあるので、横にすべらせて選ぶ
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Step.allCases) { item in
                            Button {
                                step = item
                            } label: {
                                Label(item.label, systemImage: item.symbol)
                            }
                            .buttonStyle(AppButtonStyle(step == item ? .primary : .secondary))
                            .controlSize(.small)
                        }
                    }
                }

                Group {
                switch step {
                case .slides: SlideStepView(lesson: lesson, player: player)
                case .listen: ListenStepView(lesson: lesson, player: player)
                case .questions: QuestionStepView(lesson: lesson, player: player)
                case .dictation: DictationStepView(lesson: lesson, player: player)
                case .words: WordsStepView(lesson: lesson, player: player)
                case .qa: LessonQAView(lesson: lesson)
                }
                }
                .id(lesson.id)

                HStack {
                    if let previousLesson {
                        Button { open(previousLesson) } label: {
                            Label(previousLesson.titleJa, systemImage: "chevron.left")
                        }
                        .buttonStyle(AppButtonStyle(.secondary))
                        .controlSize(.small)
                    }
                    Spacer()
                    if let nextLesson {
                        Button { open(nextLesson) } label: {
                            Label(nextLesson.titleJa, systemImage: "chevron.right")
                                .labelStyle(TrailingIconLabelStyle())
                        }
                        .buttonStyle(AppButtonStyle(.secondary))
                        .controlSize(.small)
                    }
                }

                if let chapter = LessonData.chapter(id: lesson.chapterID) {
                    Divider().padding(.vertical, 8)
                    NavigationLink {
                        ChapterDetailView(chapter: chapter)
                    } label: {
                        Label("日本語の章で確認：\(chapter.number). \(chapter.title)", systemImage: chapter.symbol)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppButtonStyle(.secondary))
                }
            }
            .padding()
            .frame(maxWidth: 720, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .screenBackground()
        .navigationTitle(lesson.titleJa)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                // どこからでも行きたい場所へ移れるメニュー
                Menu {
                    Section("このレッスン") {
                        ForEach(Step.allCases) { item in
                            Button { step = item } label: { Label(item.label, systemImage: item.symbol) }
                        }
                    }
                    Section("ほかのレッスン") {
                        if let previousLesson {
                            Button { open(previousLesson) } label: { Label("前：\(previousLesson.titleJa)", systemImage: "chevron.left") }
                        }
                        if let nextLesson {
                            Button { open(nextLesson) } label: { Label("次：\(nextLesson.titleJa)", systemImage: "chevron.right") }
                        }
                        Menu("すべてのレッスン") {
                            ForEach(EnglishData.all) { other in
                                Button(other.titleJa) { open(other) }
                            }
                        }
                    }
                    Section("戻る") {
                        Button { dismiss() } label: { Label("英語で聞くの一覧", systemImage: "list.bullet") }
                        Button { goToTabRoot(.learn) } label: { Label("学ぶのトップ", systemImage: "book") }
                        Button { goToTabRoot(.today) } label: { Label("今日", systemImage: "flame") }
                    }
                } label: {
                    Label("移動", systemImage: "arrow.triangle.turn.up.right.diamond")
                }
            }
        }
        .onChange(of: step) { player.stop() }
        .onDisappear { player.stop() }
    }
}

/// 文字のあとにアイコンを置くラベル（「次へ ›」のように）
struct TrailingIconLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.title
            configuration.icon
        }
    }
}

// MARK: スライド

/// 読み上げに合わせて、いま話している内容の図を出す
private struct SlideStepView: View {
    let lesson: EnglishLesson
    let player: SpeechPlayer

    @State private var index = 0
    @State private var showsEnglish = true
    @State private var showsJapanese = true

    private var source: String { "slides-\(lesson.id)" }
    private var texts: [String] { lesson.sentences.map(\.en) }
    private var isPlaying: Bool { player.isPlaying(source) }

    var body: some View {
        let sentence = lesson.sentences[index]
        VStack(spacing: 12) {
            VStack(spacing: 14) {
                EnglishSlide(lessonID: lesson.id, index: index)
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    if showsEnglish {
                        Text(sentence.en).font(.body)
                    }
                    if showsJapanese {
                        Text(sentence.ja).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .cardStyle()
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 30).onEnded { value in
                if value.translation.width < -30 { go(by: 1) }
                if value.translation.width > 30 { go(by: -1) }
            })

            HStack(spacing: 10) {
                Button { go(by: -1) } label: {
                    Image(systemName: "chevron.left")
                }
                .buttonStyle(AppButtonStyle(.secondary))
                .disabled(index == 0)
                .accessibilityLabel("前のスライド")

                Button {
                    if isPlaying {
                        player.stop()
                    } else {
                        player.play(texts, from: index, source: source)
                    }
                } label: {
                    Label(isPlaying ? "止める" : (index == 0 ? "最初から再生" : "ここから再生"),
                          systemImage: isPlaying ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.primary))

                Button { go(by: 1) } label: {
                    Image(systemName: "chevron.right")
                }
                .buttonStyle(AppButtonStyle(.secondary))
                .disabled(index == lesson.sentences.count - 1)
                .accessibilityLabel("次のスライド")
            }

            Text("\(index + 1) / \(lesson.sentences.count)　左右にスワイプでも切り替えられます")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Toggle("英文を表示", isOn: $showsEnglish)
                Toggle("日本語訳を表示", isOn: $showsJapanese)
            }
            .font(.subheadline)
            .padding()
            .cardStyle()
        }
        .onChange(of: player.currentIndex) { _, current in
            // 読み上げが次の文に進んだら、スライドもめくる
            if isPlaying, let current { index = current }
        }
    }

    private func go(by delta: Int) {
        let next = index + delta
        guard lesson.sentences.indices.contains(next) else { return }
        index = next
        if isPlaying { player.play(texts, from: next, source: source) }
    }
}

// MARK: 聞く

private struct ListenStepView: View {
    let lesson: EnglishLesson
    let player: SpeechPlayer

    @State private var showsEnglish = false
    @State private var showsJapanese = false
    @State private var shadowing = false

    private var source: String { "listen-\(lesson.id)" }
    private var texts: [String] { lesson.sentences.map(\.en) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button {
                    if player.isPlaying(source) {
                        player.stop()
                    } else {
                        player.play(texts, source: source, pause: shadowing)
                    }
                } label: {
                    Label(player.isPlaying(source) ? "止める" : "最初から聞く",
                          systemImage: player.isPlaying(source) ? "stop.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.primary))

                Toggle("英文を表示", isOn: $showsEnglish)
                Toggle("日本語訳を表示", isOn: $showsJapanese)
                Toggle("1文ごとに止める（まねして言う）", isOn: $shadowing)
                    .onChange(of: shadowing) { player.stop() }
            }
            .font(.subheadline)
            .padding()
            .cardStyle()

            ForEach(Array(lesson.sentences.enumerated()), id: \.offset) { index, sentence in
                let current = player.isPlaying(source) && player.currentIndex == index
                Button {
                    player.play(texts, from: index, source: source, pause: shadowing)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        SpeakerIcon(playing: current, size: 36)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(sentence.en)
                                .font(.body)
                                .blur(radius: showsEnglish ? 0 : 6)
                                .accessibilityHidden(!showsEnglish)
                            if showsJapanese {
                                Text(sentence.ja)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .choiceTile(current ? .correct : .normal)
            }
        }
    }

    private var hint: String {
        if shadowing {
            return "1文読むごとに、同じ長さの間を空けます。聞こえたとおりに声に出してまねしましょう（リピーティング）。慣れたら、少し遅れてかぶせて言う「シャドーイング」にも挑戦。"
        }
        if !showsEnglish {
            return "まずは英文を見ずに聞いてみましょう。聞き取れなかった文は、タップするとそこから聞き直せます。"
        }
        return "英文を目で追いながら聞きます。聞こえ方と文字が違うところ（音がつながる・消える）に注目しましょう。"
    }
}

// MARK: 問題

private struct QuestionStepView: View {
    let lesson: EnglishLesson
    let player: SpeechPlayer
    @Environment(ProgressStore.self) private var progress

    /// 問題の番号 → 選んだ選択肢
    @State private var answers: [Int: Int] = [:]
    @State private var showsText = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("質問も英語で読み上げます。分からなければ「聞く」に戻って本文を聞き直しましょう。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("質問の英文を表示", isOn: $showsText)
                    .font(.subheadline)
                Button {
                    player.play(lesson.sentences.map(\.en), source: "passage-\(lesson.id)")
                } label: {
                    Label("本文をもう一度聞く", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.secondary))
            }
            .padding()
            .cardStyle()

            ForEach(Array(lesson.questions.enumerated()), id: \.offset) { index, question in
                questionCard(index: index, question: question)
            }

            if answers.count == lesson.questions.count {
                let correct = lesson.questions.indices.filter { answers[$0] == lesson.questions[$0].answer }.count
                VStack(spacing: 10) {
                    Text("\(lesson.questions.count)問中 \(correct)問 正解")
                        .font(.headline)
                    Button("もう一度解く") { answers = [:] }
                        .buttonStyle(AppButtonStyle(.secondary))
                        .controlSize(.small)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .cardStyle()
            }
        }
    }

    private func questionCard(index: Int, question: ListeningQuestion) -> some View {
        let source = "q-\(lesson.id)-\(index)"
        let chosen = answers[index]
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text("Q\(index + 1)").font(.headline).foregroundStyle(.tint)
                Text(question.question)
                    .font(.body.weight(.medium))
                    .blur(radius: showsText || chosen != nil ? 0 : 6)
                Spacer(minLength: 0)
                Button {
                    player.say(question.question, source: source)
                } label: {
                    SpeakerIcon(playing: player.isPlaying(source))
                }
                .accessibilityLabel("質問を聞く")
            }
            ForEach(Array(question.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                Button {
                    guard chosen == nil else { return }
                    answers[index] = choiceIndex
                    progress.recordEnglishAnswer()
                    if answers.count == lesson.questions.count {
                        progress.markEnglishDone(lesson.id)
                    }
                } label: {
                    Text(choice)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .choiceTile(state(chosen: chosen, choice: choiceIndex, answer: question.answer))
            }
            if chosen != nil {
                Text(markdown: (chosen == question.answer ? "正解！ " : "不正解。 ") + question.note)
                    .font(.subheadline)
            }
        }
        .padding()
        .cardStyle()
    }

    private func state(chosen: Int?, choice: Int, answer: Int) -> ChoiceState {
        guard let chosen else { return .normal }
        if choice == answer { return .correct }
        return choice == chosen ? .wrong : .dimmed
    }
}

// MARK: 書き取り

private struct DictationStepView: View {
    let lesson: EnglishLesson
    let player: SpeechPlayer

    @State private var index = 0
    @State private var choices: [String] = []
    @State private var chosen: String?
    @State private var correctCount = 0

    private var items: [EnglishSentence] { lesson.dictationItems }
    private var source: String { "dictation-\(lesson.id)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if index < items.count, let key = items[index].key {
                let item = items[index]
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(index + 1) / \(items.count)　聞こえた単語を選んでください")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        player.say(item.en, source: source)
                    } label: {
                        Label(player.isPlaying(source) ? "再生中…" : "もう一度聞く", systemImage: "speaker.wave.2.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppButtonStyle(.primary))

                    Text(chosen == nil ? masked(item.en, key: key) : item.en)
                        .font(.body)
                    if chosen != nil {
                        Text(item.ja).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding()
                .cardStyle()

                ForEach(choices, id: \.self) { choice in
                    Button {
                        guard chosen == nil else { return }
                        chosen = choice
                        if choice == key { correctCount += 1 }
                    } label: {
                        Text(choice)
                            .font(.body.weight(.medium))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .choiceTile(state(choice, key: key))
                }

                if chosen != nil {
                    Button(index + 1 < items.count ? "次の文へ" : "結果を見る") {
                        index += 1
                        prepare(play: true)
                    }
                    .buttonStyle(AppButtonStyle(.primary))
                    .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 12) {
                    Text("\(items.count)問中 \(correctCount)問 正解")
                        .font(.headline)
                    Text("間違えた語は「単語」タブや、「聞く」で英文を表示して確かめましょう。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("もう一度") {
                        index = 0
                        correctCount = 0
                        prepare(play: true)
                    }
                    .buttonStyle(AppButtonStyle(.secondary))
                }
                .frame(maxWidth: .infinity)
                .padding()
                .cardStyle()
            }
        }
        .onAppear { prepare(play: false) }
    }

    private func prepare(play: Bool) {
        chosen = nil
        guard index < items.count, let key = items[index].key else {
            player.stop()
            return
        }
        let others = Set(items.compactMap(\.key)).subtracting([key]).shuffled().prefix(3)
        choices = ([key] + others).shuffled()
        if play { player.say(items[index].en, source: source) }
    }

    private func masked(_ text: String, key: String) -> String {
        guard let range = text.range(of: key) else { return text }
        return text.replacingCharacters(in: range, with: "＿＿＿＿")
    }

    private func state(_ choice: String, key: String) -> ChoiceState {
        guard let chosen else { return .normal }
        if choice == key { return .correct }
        return choice == chosen ? .wrong : .dimmed
    }
}

// MARK: 単語

private struct WordsStepView: View {
    let lesson: EnglishLesson
    let player: SpeechPlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("タップすると発音を聞けます。カタカナの読みと、実際の聞こえ方の違いに注目しましょう。")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(lesson.words, id: \.word) { word in
                let source = "word-\(lesson.id)-\(word.word)"
                Button {
                    player.say(word.word, source: source)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(word.word).font(.headline)
                            Text(word.ja).font(.subheadline)
                            Text(word.tip).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                        SpeakerIcon(playing: player.isPlaying(source))
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .cardStyle()
            }
        }
    }
}

/// 押しやすい大きさの、丸いスピーカーのボタンの絵（タップできる範囲は 44pt 以上）
struct SpeakerIcon: View {
    var playing: Bool
    var size: CGFloat = 44

    var body: some View {
        Image(systemName: playing ? "speaker.wave.3.fill" : "speaker.wave.2.fill")
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(.tint))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(playing ? "再生中" : "読み上げる")
    }
}

// MARK: 質問

/// レッスンの内容について質問する（iPhone の Apple Intelligence、または Claude Code・仕様書）
private struct LessonQAView: View {
    let lesson: EnglishLesson

    private struct Message: Identifiable {
        let id = UUID()
        let question: String
        var answer = ""
        var error: String?
        var finished = false
    }

    @Environment(\.openURL) private var openURL
    @State private var conversation: AppleAIConversation
    @State private var messages: [Message] = []
    @State private var input = ""
    @State private var isWorking = false

    init(lesson: EnglishLesson) {
        self.lesson = lesson
        _conversation = State(initialValue: AppleAIConversation(context: Self.context(lesson)))
    }

    /// AI に渡すレッスンの内容
    private static func context(_ lesson: EnglishLesson) -> String {
        let sentences = lesson.sentences.map { "- \($0.en)（\($0.ja)）" }.joined(separator: "\n")
        let words = lesson.words.map { "- \($0.word)：\($0.ja)" }.joined(separator: "\n")
        return """
            いま学んでいるのは、英語のリスニング教材「\(lesson.title)（\(lesson.titleJa)）」です。
            英文の意味・文法・発音・PCIe の内容について質問されたら、この教材をもとに答えてください。
            英語の言い回しを聞かれたら、例文もつけてください。

            --- 英文（日本語訳） ---
            \(sentences)

            --- 単語 ---
            \(words)
            """
    }

    private let examples = [
        "2文目の文法を説明して",
        "このレッスンでいちばん大事なポイントは？",
        "似た意味の英語の言い方を教えて",
        "この内容を英語で人に説明する練習をしたい",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label("このレッスンについて質問", systemImage: "bubble.left.and.bubble.right")
                    .font(.headline)
                Text("英文の意味・文法・発音や、PCIe の内容について聞けます。iPhone の中の AI（Apple Intelligence）が、このレッスンの英文をもとに答えます。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let reason = AppleAIConversation.unavailableReason {
                    Label(reason, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(examples, id: \.self) { example in
                            Button(example) { input = example }
                                .buttonStyle(AppButtonStyle(.secondary))
                                .controlSize(.small)
                        }
                    }
                }
            }
            .padding()
            .cardStyle()

            ForEach(messages) { message in
                VStack(alignment: .leading, spacing: 8) {
                    Text(message.question)
                        .padding(10)
                        .foregroundStyle(.white)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.tint))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    if !message.finished {
                        ProgressView()
                    }
                    if !message.answer.isEmpty {
                        Text(message.answer).textSelection(.enabled)
                    }
                    if let error = message.error {
                        Text(error).font(.callout).foregroundStyle(.red)
                    }
                    if message.finished {
                        HStack {
                            Button {
                                askClaudeCode(message.question)
                            } label: {
                                Label("Claude Code に聞く", systemImage: "chevron.left.forwardslash.chevron.right")
                            }
                            NavigationLink {
                                AskSpecView(initialQuestion: message.question)
                            } label: {
                                Label("仕様書に聞く", systemImage: "book.and.wrench")
                            }
                        }
                        .font(.caption.bold())
                        .buttonStyle(.borderless)
                    }
                }
                .padding()
                .cardStyle()
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("質問を入力（日本語でも英語でも）", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Color(.secondarySystemBackground)))
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.largeTitle)
                }
                .disabled(isWorking || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("送信")
            }
            if AppleAIConversation.unavailableReason != nil {
                Button {
                    askClaudeCode(input)
                } label: {
                    Label("Claude Code に聞く", systemImage: "chevron.left.forwardslash.chevron.right")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.secondary))
                .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func send() async {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        input = ""
        messages.append(Message(question: question))
        let index = messages.count - 1
        isWorking = true
        defer { isWorking = false }
        do {
            messages[index].answer = try await conversation.ask(question)
        } catch {
            messages[index].error = error.localizedDescription
        }
        messages[index].finished = true
    }

    private func askClaudeCode(_ question: String) {
        let text = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let prompt = """
            PCIe学習アプリの「英語で聞く」のレッスン「\(lesson.title)」（PCIeStudy/Data/EnglishData*.swift の \(lesson.id)）について質問です。
            コードは変えずに、日本語で答えてください。

            質問：\(text)
            """
        if let url = ClaudeCodeRequestView.sessionURL(prompt: prompt) { openURL(url) }
    }
}
