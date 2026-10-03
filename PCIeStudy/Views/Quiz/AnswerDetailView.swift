import SwiftUI

/// 回答したあとに出す解説（結果・選択肢ごとの解説・仕様書の参照先）
struct AnswerDetailView: View {
    let question: QuizQuestion
    /// 選んだ選択肢。「わからない」は QuizQuestion.unknownChoice
    let selected: Int
    @State private var showsChoiceNotes = true

    private var isCorrect: Bool { selected == question.answer }
    private var isUnknown: Bool { selected == QuizQuestion.unknownChoice }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Label(resultTitle, systemImage: resultSymbol)
                    .font(.headline)
                    .foregroundStyle(resultColor)
                if isUnknown {
                    Text("正解：\(question.choices[question.answer])")
                        .font(.subheadline.bold())
                }
                Text(question.explanation)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .choiceTile(isCorrect ? .correct : (isUnknown ? .normal : .wrong))

            if let detail = question.detail {
                VStack(alignment: .leading, spacing: 8) {
                    Label("くわしい解説", systemImage: "text.book.closed")
                        .font(.subheadline.bold())
                        .foregroundStyle(.tint)
                    Text(markdown: detail)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(cornerRadius: 14)
            }

            if !question.choiceNotes.isEmpty {
                DisclosureGroup(isExpanded: $showsChoiceNotes) {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(question.choices.enumerated()), id: \.offset) { i, choice in
                            choiceNoteRow(i, choice)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    Label("選択肢ごとの解説", systemImage: "list.bullet.rectangle")
                        .font(.subheadline.bold())
                }
                .padding()
                .cardStyle(cornerRadius: 14)
            }

            if let spec = question.spec {
                SpecRefView(spec: spec)
            }
        }
    }

    private var resultTitle: String {
        if isCorrect { return "正解！" }
        if isUnknown { return "わからなかった問題" }
        return "不正解"
    }

    private var resultSymbol: String {
        if isCorrect { return "checkmark.seal.fill" }
        if isUnknown { return "questionmark.circle.fill" }
        return "xmark.octagon.fill"
    }

    private var resultColor: Color {
        if isCorrect { return .green }
        if isUnknown { return .orange }
        return .red
    }

    private func choiceNoteRow(_ i: Int, _ choice: String) -> some View {
        let isAnswer = i == question.answer
        let isPicked = i == selected
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: isAnswer ? "checkmark.circle.fill" : (isPicked ? "xmark.circle.fill" : "circle"))
                .foregroundStyle(isAnswer ? Color.green : (isPicked ? Color.red : Color.secondary))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(choice)
                        .font(.subheadline.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    if isPicked && !isAnswer {
                        Text("あなたの回答")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.red.opacity(0.15), in: Capsule())
                            .foregroundStyle(.red)
                    }
                }
                Text(question.note(for: i) ?? (isAnswer ? "正解です。上の解説を見てください。" : ""))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// 仕様書の参照先
struct SpecRefView: View {
    let spec: SpecRef

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "book.closed.fill")
                .font(.title3)
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 3) {
                Text("仕様書の関連箇所")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Text(spec.label)
                    .font(.subheadline.bold())
                    .fixedSize(horizontal: false, vertical: true)
                Text("PCIe Base Specification 7.1・p.\(spec.page)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding()
        .cardStyle(cornerRadius: 14)
        .accessibilityElement(children: .combine)
    }
}

/// 「わからない」ボタン
struct UnknownAnswerButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label("わからない（答えを見る）", systemImage: "questionmark.circle")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(AppButtonStyle(.secondary))
        .tint(.orange)
    }
}
