import SwiftUI

struct QuizSessionView: View {
    let title: String
    let key: String
    let sourceQuestions: [QuizQuestion]

    @Environment(ProgressStore.self) private var progress
    @State private var questions: [QuizQuestion] = []
    @State private var index = 0
    @State private var selected: Int? = nil
    @State private var correctCount = 0
    @State private var wrong: [QuizQuestion] = []
    @State private var finished = false
    @State private var isRetryOfWrong = false

    init(title: String, key: String, questions: [QuizQuestion]) {
        self.title = title
        self.key = key
        self.sourceQuestions = questions
    }

    var body: some View {
        Group {
            if questions.isEmpty {
                ProgressView()
            } else if finished {
                resultView
            } else {
                questionView(questions[index])
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if questions.isEmpty { start(with: sourceQuestions) }
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
                            .background(choiceBackground(i, q), in: RoundedRectangle(cornerRadius: 12))
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.separator)))
                        }
                        .buttonStyle(.plain)
                        .disabled(selected != nil)
                    }
                }

                if let selected {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(selected == q.answer ? "正解！" : "不正解",
                              systemImage: selected == q.answer ? "checkmark.seal.fill" : "xmark.octagon.fill")
                            .font(.headline)
                            .foregroundStyle(selected == q.answer ? .green : .red)
                        Text(q.explanation)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    Button {
                        goNext()
                    } label: {
                        Text(index + 1 < questions.count ? "次の問題へ" : "結果を見る")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
        .animation(.easeInOut(duration: 0.2), value: selected)
    }

    private func choiceBackground(_ i: Int, _ q: QuizQuestion) -> Color {
        guard let selected else { return Color(.systemBackground) }
        if i == q.answer { return .green.opacity(0.15) }
        if i == selected { return .red.opacity(0.15) }
        return Color(.systemBackground)
    }

    // MARK: - 結果画面

    private var resultView: some View {
        let ratio = Double(correctCount) / Double(max(questions.count, 1))
        return ScrollView {
            VStack(spacing: 20) {
                ZStack {
                    ProgressRing(value: ratio, lineWidth: 14, color: ratio >= 0.8 ? .green : (ratio >= 0.5 ? .orange : .red))
                    VStack {
                        Text("\(Int((ratio * 100).rounded()))%").font(.largeTitle.bold())
                        Text("\(correctCount) / \(questions.count)").foregroundStyle(.secondary)
                    }
                }
                .frame(width: 160, height: 160)
                .padding(.top)

                Text(message(for: ratio)).font(.headline)

                if !wrong.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("間違えた問題").font(.title3.bold())
                        ForEach(wrong) { q in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(q.question).font(.subheadline.bold())
                                Text("正解：\(q.choices[q.answer])").font(.subheadline).foregroundStyle(.green)
                                Text(q.explanation).font(.caption).foregroundStyle(.secondary)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Button {
                        start(with: wrong, retryOfWrong: true)
                    } label: {
                        Label("間違えた問題だけ解き直す", systemImage: "arrow.uturn.backward")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }

                Button {
                    start(with: sourceQuestions)
                } label: {
                    Label("もう一度", systemImage: "arrow.clockwise")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
        }
    }

    private func message(for ratio: Double) -> String {
        switch ratio {
        case 1: return "全問正解！完璧です"
        case 0.8...: return "よくできました！"
        case 0.5...: return "あと一歩。解説を読み直しましょう"
        default: return "章の解説を復習してから再挑戦しましょう"
        }
    }

    // MARK: - ロジック

    private func start(with list: [QuizQuestion], retryOfWrong: Bool = false) {
        isRetryOfWrong = retryOfWrong
        questions = list.map { $0.shuffled() }
        index = 0
        selected = nil
        correctCount = 0
        wrong = []
        finished = false
    }

    private func answer(_ i: Int, for q: QuizQuestion) {
        guard selected == nil else { return }
        selected = i
        let ok = (i == q.answer)
        if ok { correctCount += 1 } else { wrong.append(q) }
        progress.recordAnswer(correct: ok)
    }

    private func goNext() {
        if index + 1 < questions.count {
            index += 1
            selected = nil
        } else {
            finished = true
            if !isRetryOfWrong {
                progress.recordQuizResult(key: key, correct: correctCount, total: questions.count)
            }
        }
    }
}
