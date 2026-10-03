import SwiftUI

struct QuizSessionView: View {
    let title: String
    let key: String
    let sourceQuestions: [QuizQuestion]
    /// 「新しい問題で挑戦」で使う、出題の作り直し（ランダム出題など）
    let regenerate: (() -> [QuizQuestion])?

    @Environment(ProgressStore.self) private var progress
    @State private var questions: [QuizQuestion] = []
    @State private var started = false
    @State private var index = 0
    @State private var selected: Int? = nil
    @State private var records: [AnswerRecord] = []
    @State private var finished = false
    @State private var isRetryOfWrong = false
    @State private var previousBest: Int? = nil
    @State private var reviewFilter: ReviewFilter = .wrong

    /// 苦手リストから出題するときのキー（最高記録は残さない）
    static let weakKey = "weak"

    private struct AnswerRecord: Identifiable {
        let question: QuizQuestion
        let selected: Int
        var id: String { question.id }
        var isCorrect: Bool { selected == question.answer }
    }

    private struct ChapterStat: Identifiable {
        let chapter: Chapter
        let correct: Int
        let total: Int
        var id: String { chapter.id }
        var ratio: Double { Double(correct) / Double(max(total, 1)) }
    }

    private enum ReviewFilter: String, CaseIterable, Identifiable {
        case wrong = "間違えた問題"
        case all = "すべて"
        var id: String { rawValue }
    }

    init(title: String, key: String, questions: [QuizQuestion],
         regenerate: (() -> [QuizQuestion])? = nil) {
        self.title = title
        self.key = key
        self.sourceQuestions = questions
        self.regenerate = regenerate
    }

    var body: some View {
        Group {
            if !started {
                ProgressView()
            } else if questions.isEmpty {
                ContentUnavailableView("出題できる問題がありません", systemImage: "checkmark.seal",
                                       description: Text("苦手な問題はすべて克服しました"))
            } else if finished {
                resultView
            } else {
                questionView(questions[index])
            }
        }
        .screenBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !started { start(with: sourceQuestions) }
        }
    }

    // MARK: - 出題画面

    private func questionView(_ q: QuizQuestion) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ProgressView(value: Double(index), total: Double(questions.count))
                HStack {
                    Text("問題 \(index + 1) / \(questions.count)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                    Spacer()
                    if let chapter = LessonData.chapter(id: q.chapterID) {
                        Text(chapter.title)
                            .font(.caption)
                            .foregroundStyle(chapter.level.color)
                    }
                }

                Text(q.question)
                    .font(.title3.bold())
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 10) {
                    ForEach(Array(q.choices.enumerated()), id: \.offset) { i, choice in
                        Button {
                            answer(i, for: q)
                        } label: {
                            HStack(alignment: .top) {
                                Text(choice)
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                if let selected {
                                    if i == q.answer {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    } else if i == selected {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .choiceTile(choiceState(i, q))
                        }
                        .buttonStyle(.plain)
                        .disabled(selected != nil)
                    }
                }

                if let selected {
                    AnswerDetailView(question: q, selected: selected)
                        .id(q.id)
                } else {
                    UnknownAnswerButton { answer(QuizQuestion.unknownChoice, for: q) }
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            if selected != nil {
                Button {
                    goNext()
                } label: {
                    Text(index + 1 < questions.count ? "次の問題へ" : "結果を見る")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.primary))
                .padding(.horizontal)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: selected)
    }

    private func choiceState(_ i: Int, _ q: QuizQuestion) -> ChoiceState {
        guard let selected else { return .normal }
        if i == q.answer { return .correct }
        if i == selected { return .wrong }
        return .dimmed
    }

    // MARK: - 結果画面

    private var correctCount: Int { records.filter(\.isCorrect).count }

    private var wrongQuestions: [QuizQuestion] {
        records.filter { !$0.isCorrect }.map(\.question)
    }

    /// 章別クイズのときの章
    private var chapter: Chapter? { LessonData.chapter(id: key) }

    private var chapterStats: [ChapterStat] {
        Dictionary(grouping: records, by: \.question.chapterID)
            .compactMap { id, recs in
                LessonData.chapter(id: id).map {
                    ChapterStat(chapter: $0, correct: recs.filter(\.isCorrect).count, total: recs.count)
                }
            }
            .sorted { ($0.ratio, $0.chapter.number) < ($1.ratio, $1.chapter.number) }
    }

    private var resultView: some View {
        let ratio = Double(correctCount) / Double(max(questions.count, 1))
        return ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 12) {
                    ZStack {
                        ProgressRing(value: ratio, lineWidth: 14, color: scoreColor(ratio))
                        VStack {
                            Text("\(Int((ratio * 100).rounded()))%").font(.largeTitle.bold())
                            Text("\(correctCount) / \(questions.count)").foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 160, height: 160)
                    .padding(.top)

                    Text(message(for: ratio)).font(.headline)
                    if let note = bestNote(percent: Int((ratio * 100).rounded())) {
                        Text(note).font(.subheadline).foregroundStyle(.secondary)
                    }
                }

                nextActions

                if chapterStats.count > 1 {
                    chapterBreakdown
                }

                review
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    /// 次にやることの候補
    private var nextActions: some View {
        VStack(spacing: 10) {
            if !wrongQuestions.isEmpty {
                Button {
                    start(with: wrongQuestions, retryOfWrong: true)
                } label: {
                    Label("間違えた \(wrongQuestions.count) 問を解き直す", systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.primary))
                .controlSize(.large)
            }

            if let regenerate {
                Button {
                    start(with: regenerate())
                } label: {
                    Label(key == Self.weakKey ? "残っている苦手な問題に挑戦" : "新しい問題で挑戦",
                          systemImage: "shuffle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.secondary))
                .controlSize(.large)
            }

            Button {
                start(with: sourceQuestions.shuffled())
            } label: {
                Label("最初の問題をもう一度（順番を入れ替え）", systemImage: "arrow.clockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(AppButtonStyle(.secondary))
            .controlSize(.large)

            if let chapter {
                NavigationLink {
                    ChapterDetailView(chapter: chapter)
                } label: {
                    Label("「\(chapter.title)」の解説を読み直す", systemImage: "book")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.secondary))
                .controlSize(.large)

                if let next = LessonData.next(after: chapter) {
                    NavigationLink {
                        QuizSessionView(title: next.title, key: next.id,
                                        questions: QuizData.questions(forChapter: next.id))
                    } label: {
                        Label("次の章「\(next.title)」のクイズへ", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppButtonStyle(.secondary))
                    .controlSize(.large)
                }
            }

            let weak = QuizData.questions(ids: progress.weakQuestionIDs)
            if key != Self.weakKey && !weak.isEmpty {
                NavigationLink {
                    QuizSessionView.weakQuestions(progress: progress)
                } label: {
                    Label("苦手な問題に挑戦（全\(weak.count)問）", systemImage: "target")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.secondary))
                .tint(.orange)
                .controlSize(.large)
            }
        }
    }

    /// 複数の章から出題したときの章ごとの成績
    private var chapterBreakdown: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("章ごとの成績").font(.title3.bold())
            Text("正答率の低い順です。タップすると解説を開きます。")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(chapterStats) { stat in
                NavigationLink {
                    ChapterDetailView(chapter: stat.chapter)
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("\(stat.chapter.number). \(stat.chapter.title)")
                                .font(.subheadline.bold())
                            Spacer()
                            Text("\(stat.correct) / \(stat.total)")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(scoreColor(stat.ratio))
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                        ProgressView(value: stat.ratio)
                            .tint(scoreColor(stat.ratio))
                    }
                    .padding(12)
                    .cardStyle(cornerRadius: 12)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// 1問ずつのふり返り（自分の回答・正解・解説）
    private var review: some View {
        let shown = reviewFilter == .wrong ? records.filter { !$0.isCorrect } : records
        return VStack(alignment: .leading, spacing: 12) {
            Text("ふり返り").font(.title3.bold())
            Picker("表示", selection: $reviewFilter) {
                ForEach(ReviewFilter.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            if shown.isEmpty {
                Label("間違えた問題はありません", systemImage: "checkmark.seal.fill")
                    .foregroundStyle(.green)
                    .padding(.vertical, 8)
            }
            ForEach(shown) { record in
                reviewCard(record)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reviewCard(_ record: AnswerRecord) -> some View {
        let q = record.question
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: record.isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundStyle(record.isCorrect ? Color.green : Color.red)
                Text(q.question)
                    .font(.subheadline.bold())
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !record.isCorrect {
                Text("あなたの回答：\(record.selected == QuizQuestion.unknownChoice ? "わからない" : q.choices[record.selected])")
                    .font(.subheadline)
                    .foregroundStyle(record.selected == QuizQuestion.unknownChoice ? Color.orange : Color.red)
                if let note = q.note(for: record.selected) {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Text("正解：\(q.choices[q.answer])")
                .font(.subheadline)
                .foregroundStyle(.green)
            Text(q.explanation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let spec = q.spec {
                Label("仕様書 \(spec.label)（p.\(spec.page)）", systemImage: "book.closed")
                    .font(.caption2)
                    .foregroundStyle(.tint)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 12)
    }

    private func scoreColor(_ ratio: Double) -> Color {
        ratio >= 0.8 ? .green : (ratio >= 0.5 ? .orange : .red)
    }

    private func message(for ratio: Double) -> String {
        switch ratio {
        case 1: return "全問正解！完璧です"
        case 0.8...: return "よくできました！"
        case 0.5...: return "あと一歩。解説を読み直しましょう"
        default: return "章の解説を復習してから再挑戦しましょう"
        }
    }

    private func bestNote(percent: Int) -> String? {
        if isRetryOfWrong { return "間違えた問題の解き直しなので、最高記録には含めません" }
        guard key != Self.weakKey, let previousBest else { return nil }
        if percent > previousBest { return "自己ベスト更新！（これまでの最高 \(previousBest)%）" }
        return "これまでの最高 \(previousBest)%"
    }

    // MARK: - ロジック

    private func start(with list: [QuizQuestion], retryOfWrong: Bool = false) {
        started = true
        isRetryOfWrong = retryOfWrong
        questions = list.map { $0.shuffled() }
        index = 0
        selected = nil
        records = []
        finished = false
        reviewFilter = .wrong
    }

    private func answer(_ i: Int, for q: QuizQuestion) {
        guard selected == nil else { return }
        selected = i
        records.append(AnswerRecord(question: q, selected: i))
        progress.recordAnswer(questionID: q.id, correct: i == q.answer)
    }

    private func goNext() {
        if index + 1 < questions.count {
            index += 1
            selected = nil
        } else {
            previousBest = progress.bestScore(for: key)
            finished = true
            if !isRetryOfWrong && key != Self.weakKey {
                progress.recordQuizResult(key: key, correct: correctCount, total: questions.count)
            }
        }
    }
}

extension QuizSessionView {
    /// 苦手リストから出題するクイズ
    static func weakQuestions(progress: ProgressStore) -> QuizSessionView {
        QuizSessionView(title: "苦手な問題", key: weakKey,
                        questions: QuizData.questions(ids: progress.weakQuestionIDs).shuffled(),
                        regenerate: { QuizData.questions(ids: progress.weakQuestionIDs).shuffled() })
    }
}
