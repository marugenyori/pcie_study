import SwiftUI
import UIKit

/// クイズの問題について、Claude Code（このアプリのリポジトリを開いた新しいセッション）に頼む
struct ClaudeCodeRequestView: View {
    enum Kind {
        /// 問題について質問する（コードは変えない）
        case ask
        /// 指示どおりに問題を作り直してもらう
        case rewrite
    }

    let kind: Kind
    let question: QuizQuestion
    /// 選んだ選択肢（回答前なら nil）
    var selected: Int? = nil

    /// Claude Code で開くリポジトリとブランチ
    static let repository = "marugenyori/pcie_study"
    static let branch = "main"

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var text = ""
    @State private var copied = false
    @FocusState private var focused: Bool

    private var trimmed: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(question.question)
                        .font(.subheadline)
                    Text("正解：\(question.choices[question.answer])")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("対象の問題（\(question.id)）")
                }

                Section {
                    TextField(placeholder, text: $text, axis: .vertical)
                        .lineLimit(4...10)
                        .focused($focused)
                } header: {
                    Text(kind == .ask ? "聞きたいこと" : "どう作り直すか")
                } footer: {
                    Text(footer)
                }

                Section {
                    Button {
                        if let url = Self.sessionURL(prompt: prompt) { openURL(url) }
                    } label: {
                        Label("Claude Code で開く", systemImage: "arrow.up.forward.app")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppButtonStyle(.primary))
                    .disabled(kind == .rewrite && trimmed.isEmpty)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)

                    Button {
                        UIPasteboard.general.string = prompt
                        copied = true
                    } label: {
                        Label(copied ? "コピーしました" : "依頼文をコピー", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(AppButtonStyle(.secondary))
                    .disabled(kind == .rewrite && trimmed.isEmpty)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("Claude アプリ（なければブラウザ）で、このアプリのリポジトリを選んだ新しいセッションが開き、依頼文が入力された状態になります。内容を確かめて送信してください。うまく開かないときは、依頼文をコピーして貼り付けてください。")
                }
            }
            .screenBackground()
            .navigationTitle(kind == .ask ? "Claude Code に質問" : "問題を作り直す")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear { focused = true }
        }
    }

    private var placeholder: String {
        kind == .ask
            ? "例：なぜこの選択肢が正解なのか、図を使って説明して（空欄なら解説をくわしく頼みます）"
            : "例：選択肢が紛らわしいので、正解がはっきり1つに決まるように直して"
    }

    private var footer: String {
        kind == .ask
            ? "アプリのコードは変えずに、質問に答えてもらいます。"
            : "問題・選択肢ごとの解説・くわしい解説をまとめて直し、ビルドを確認して TestFlight に出すところまで頼みます。"
    }

    // MARK: 依頼文

    private var problemText: String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        var lines = [
            "問題ID：\(question.id)",
            "問題：\(question.question)",
            "選択肢：",
        ]
        for (i, choice) in question.choices.enumerated() {
            lines.append("  \(letters[min(i, letters.count - 1)]). \(choice)\(i == question.answer ? "（正解）" : "")")
        }
        lines.append("解説：\(question.explanation)")
        if let selected {
            if selected == QuizQuestion.unknownChoice {
                lines.append("わたしの回答：わからない")
            } else if question.choices.indices.contains(selected) {
                lines.append("わたしの回答：\(question.choices[selected])")
            }
        }
        return lines.joined(separator: "\n")
    }

    var prompt: String {
        switch kind {
        case .ask:
            let ask = trimmed.isEmpty ? "この問題の答えと、ほかの選択肢が違う理由を、くわしく説明してください。" : trimmed
            return """
            PCIe学習アプリのクイズについて質問です。コードは変更せず、答えだけ返してください。

            \(problemText)

            質問：\(ask)
            """
        case .rewrite:
            return """
            PCIe学習アプリのクイズの1問を、次の指示どおりに作り直してください。

            \(problemText)

            指示：\(trimmed)

            進め方：
            - CLAUDE.md の「クイズを追加・変更するとき」に従い、問題（Shared/QuizData*.swift）、選択肢ごとの解説（Shared/QuizNotes*.swift）、くわしい解説（Shared/QuizDetails*.swift）をそろえて直す。問題IDは変えない
            - 数値や仕様書の参照先を変えたときは「仕様書で未確認」とわたしに伝える
            - ビルドを確認し、プルリクエストを作って main にマージし、TestFlight に出す
            """
        }
    }

    /// claude.ai/code/new のリンク（Claude アプリがあればアプリで開く）
    static func sessionURL(prompt: String) -> URL? {
        // + や & などは、クエリの値の中では必ずエンコードする
        var allowed = CharacterSet.urlQueryAllowed
        allowed.remove(charactersIn: "+&=?/")
        func encode(_ value: String) -> String {
            value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
        }
        let query = [
            "q=\(encode(prompt))",
            "repo=\(encode(repository))",
            "branch=\(encode(branch))",
        ].joined(separator: "&")
        return URL(string: "https://claude.ai/code/new?\(query)")
    }
}
