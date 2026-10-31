import SwiftUI
import UIKit

/// クイズの問題について Claude に質問し、回答をアプリ内に表示する（claude.ai のセッションは作らない）
struct ClaudeAskView: View {
    let question: QuizQuestion
    /// 選んだ選択肢（「わからない」は QuizQuestion.unknownChoice）
    var selected: Int? = nil

    @Environment(\.dismiss) private var dismiss
    @State private var chat = ClaudeChat(system: ClaudeAskView.systemPrompt)
    @State private var input = ""
    @State private var keyInput = ""
    @State private var showsKeySettings = false
    @FocusState private var focused: Bool

    private var trimmed: String { input.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        questionCard

                        if !chat.hasAPIKey || showsKeySettings {
                            keyCard
                        } else if chat.turns.isEmpty {
                            suggestions
                        }

                        ForEach(chat.turns) { turn in
                            bubble(turn)
                        }

                        if chat.isThinking {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("考えています…").font(.subheadline).foregroundStyle(.secondary)
                            }
                            .padding(.horizontal)
                        }

                        if let error = chat.errorMessage {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .font(.subheadline)
                                .foregroundStyle(.red)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .cardStyle(cornerRadius: 14)
                        }

                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding()
                    .frame(maxWidth: 720, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: chat.turns.last?.text) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if chat.hasAPIKey && !showsKeySettings { inputBar }
            }
            .screenBackground()
            .navigationTitle("Claude に質問")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") {
                        chat.cancel()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if !chat.turns.isEmpty {
                            Button {
                                UIPasteboard.general.string = transcript
                            } label: {
                                Label("やりとりをコピー", systemImage: "doc.on.doc")
                            }
                            Button {
                                chat.reset()
                            } label: {
                                Label("最初から聞き直す", systemImage: "arrow.counterclockwise")
                            }
                        }
                        Button {
                            showsKeySettings.toggle()
                        } label: {
                            Label("API キーの設定", systemImage: "key")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .onDisappear { chat.cancel() }
    }

    // MARK: 部品

    private var questionCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("対象の問題（\(question.id)）")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(question.question).font(.subheadline.weight(.medium))
            Text("正解：\(question.choices[question.answer])")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 14)
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("よくある質問").font(.caption.bold()).foregroundStyle(.secondary)
            ForEach(Self.suggestedQuestions, id: \.self) { text in
                Button {
                    ask(text)
                } label: {
                    Text(text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(AppButtonStyle(.secondary))
                .controlSize(.small)
            }
        }
    }

    private var keyCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Claude API キー", systemImage: "key.fill")
                .font(.headline)
            Text("アプリから直接 Claude に質問するには、Anthropic の API キーが必要です。キーはこの iPhone のキーチェーンにだけ保存されます。料金はサブスクリプションとは別の従量課金で、質問1回あたり数円程度です。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Link(destination: URL(string: "https://console.anthropic.com/settings/keys")!) {
                Label("Claude Console でキーを作る", systemImage: "arrow.up.forward.square")
                    .font(.subheadline)
            }
            SecureField("sk-ant-…", text: $keyInput)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .padding(10)
                .background(Color(.tertiarySystemFill), in: RoundedRectangle(cornerRadius: 10))
            HStack {
                Button("保存") {
                    chat.saveAPIKey(keyInput)
                    keyInput = ""
                    showsKeySettings = false
                }
                .buttonStyle(AppButtonStyle(.primary))
                .controlSize(.small)
                .disabled(keyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if chat.hasAPIKey {
                    Button("キーを削除", role: .destructive) {
                        chat.deleteAPIKey()
                    }
                    .buttonStyle(AppButtonStyle(.secondary))
                    .controlSize(.small)
                    Spacer()
                    Button("閉じる") { showsKeySettings = false }
                        .controlSize(.small)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 14)
    }

    private func bubble(_ turn: ClaudeChat.Turn) -> some View {
        let isUser = turn.role == .user
        return HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 4) {
                if !isUser {
                    Label("Claude", systemImage: "sparkles")
                        .font(.caption.bold())
                        .foregroundStyle(.tint)
                }
                Text(markdown: turn.display)
                    .font(.body)
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .background {
                if isUser {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.tint.opacity(0.15))
                }
            }
            .modifier(AssistantCard(active: !isUser))
            if !isUser { Spacer(minLength: 0) }
        }
        .opacity(turn.display.isEmpty ? 0 : 1)
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField(chat.turns.isEmpty ? "この問題について聞きたいこと" : "続けて質問する", text: $input, axis: .vertical)
                .lineLimit(1...5)
                .focused($focused)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            if chat.isStreaming {
                Button {
                    chat.cancel()
                } label: {
                    Image(systemName: "stop.circle.fill").font(.title)
                }
                .accessibilityLabel("止める")
            } else {
                Button {
                    ask(trimmed)
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(trimmed.isEmpty)
                .accessibilityLabel("送信")
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: 送信

    private func ask(_ text: String) {
        guard !text.isEmpty else { return }
        if chat.turns.isEmpty {
            chat.send(problemContext + "\n\n質問：" + text, display: text)
        } else {
            chat.send(text)
        }
        input = ""
        focused = false
    }

    private var transcript: String {
        chat.turns.map { ($0.role == .user ? "わたし：" : "Claude：") + $0.display }
            .joined(separator: "\n\n")
    }

    /// 1つ目の質問に付ける、問題の情報
    private var problemContext: String {
        let letters = ["A", "B", "C", "D", "E", "F"]
        var lines = [
            "次のクイズの問題について質問します。",
            "",
            "問題ID：\(question.id)",
            "問題：\(question.question)",
            "選択肢：",
        ]
        for (i, choice) in question.choices.enumerated() {
            var line = "  \(letters[min(i, letters.count - 1)]). \(choice)"
            if i == question.answer { line += "（正解）" }
            if let note = question.note(for: i), !note.isEmpty { line += " … アプリの解説：\(note)" }
            lines.append(line)
        }
        lines.append("アプリの解説：\(question.explanation)")
        if let detail = question.detail { lines.append("くわしい解説：\(detail)") }
        if let spec = question.spec {
            lines.append("仕様書の参照先：\(spec.label)（PCIe Base Specification 7.1、p.\(spec.page)）")
        }
        if let selected {
            if selected == QuizQuestion.unknownChoice {
                lines.append("わたしの回答：わからない")
            } else if question.choices.indices.contains(selected) {
                lines.append("わたしの回答：\(question.choices[selected])")
            }
        }
        return lines.joined(separator: "\n")
    }

    static let suggestedQuestions = [
        "なぜこれが正解なのか、仕組みから説明して",
        "ほかの選択肢が違う理由を教えて",
        "実際の機器ではどんな場面で関係する？",
        "この問題の解説に誤りや紛らわしい点はない？",
    ]

    static let systemPrompt = """
    あなたは、PCIe を学ぶ iOS アプリ「PCIe学習」の先生です。利用者はクイズに答えたあと、その問題について質問しています。

    - 日本語で答え、専門用語には短い説明を添える
    - 根拠は PCIe Base Specification（最新は 7.1）に基づく。章番号・ページ・ビット位置・数値に確信がないときはそう書き、仕様書で確かめるよう勧める
    - アプリの問題や解説に誤りや紛らわしい点があると思ったら、はっきり指摘する
    - 画面は簡易的な表示なので、見出し（#）・表・コードブロックは使わず、短い段落と「- 」の箇条書き、**太字** だけで書く。流れは「A → B → C」のように矢印で示す
    - まず結論を1〜2文で述べ、そのあとに理由を説明する。長くなりすぎないようにする
    """
}

/// Claude の回答の吹き出し（アプリのカードの見た目）
private struct AssistantCard: ViewModifier {
    let active: Bool

    func body(content: Content) -> some View {
        if active {
            content
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardStyle(cornerRadius: 14)
        } else {
            content
        }
    }
}
