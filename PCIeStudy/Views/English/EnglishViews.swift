import SwiftUI

// MARK: - 一覧

struct EnglishHomeView: View {
    @Environment(ProgressStore.self) private var progress
    @State private var player = SpeechPlayer()

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
                        stepLine("1", "聞く：まず英文を隠したまま聞き、次に英文を見ながら聞く")
                        stepLine("2", "問題：英語の質問に答えて、聞き取れたか確かめる")
                        stepLine("3", "書き取り：1文ずつ聞いて、抜けた単語を選ぶ")
                        stepLine("4", "単語：よく出る語の発音と、聞こえ方のコツ")
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
                Button {
                    player.say("The Data Link Layer replays the TLP when it receives a NAK.", source: "sample")
                } label: {
                    Label("この設定で試しに聞く", systemImage: "speaker.wave.2")
                }
            } header: {
                Text("音声")
            } footer: {
                if !SpeechPlayer.hasEnhancedVoice(for: player.accent) {
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
                            Image(systemName: player.isPlaying("term-\(term.id)") ? "speaker.wave.3.fill" : "speaker.wave.2")
                                .foregroundStyle(.tint)
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
    let lesson: EnglishLesson
    let player: SpeechPlayer

    enum Step: String, CaseIterable, Identifiable {
        case listen, questions, dictation, words
        var id: String { rawValue }
        var label: String {
            switch self {
            case .listen: return "聞く"
            case .questions: return "問題"
            case .dictation: return "書き取り"
            case .words: return "単語"
            }
        }
    }

    @State private var step: Step = .listen

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

                Picker("ステップ", selection: $step) {
                    ForEach(Step.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)

                switch step {
                case .listen: ListenStepView(lesson: lesson, player: player)
                case .questions: QuestionStepView(lesson: lesson, player: player)
                case .dictation: DictationStepView(lesson: lesson, player: player)
                case .words: WordsStepView(lesson: lesson, player: player)
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
        .onChange(of: step) { player.stop() }
        .onDisappear { player.stop() }
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
                        Image(systemName: current ? "speaker.wave.3.fill" : "play.circle")
                            .foregroundStyle(.tint)
                            .frame(width: 24)
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
                    Image(systemName: player.isPlaying(source) ? "speaker.wave.3.fill" : "speaker.wave.2")
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
                        Image(systemName: player.isPlaying(source) ? "speaker.wave.3.fill" : "speaker.wave.2")
                            .foregroundStyle(.tint)
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
