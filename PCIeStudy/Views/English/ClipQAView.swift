import FoundationModels
import SwiftUI

/// 動画の文字起こしをもとに、iPhone 内の AI（Apple Intelligence）で要約・クイズ・質問をする
///
/// 通信も料金もかからない。Apple Intelligence に対応した iPhone で、オンにしているときだけ使える。
/// AI が一度に読める量には限りがあるので、長い動画は先頭から一定の文字数までを渡す。
@available(iOS 26.0, *)
struct ClipQAView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case summary, quiz, chat

        var id: String { rawValue }

        var label: String {
            switch self {
            case .summary: return "要約"
            case .quiz: return "クイズ"
            case .chat: return "質問"
            }
        }
    }

    let title: String
    let lines: [TranscriptLine]
    /// 時刻をタップしたときに、動画をその位置から再生する
    let onSeek: (Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var tab = Tab.summary

    private let model = SystemLanguageModel.default

    var body: some View {
        NavigationStack {
            Group {
                switch model.availability {
                case .available:
                    content
                case .unavailable(let reason):
                    unavailableView(reason)
                }
            }
            .screenBackground()
            .navigationTitle("動画で Q&A")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            Picker("内容", selection: $tab) {
                ForEach(Tab.allCases) { Text($0.label).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding()

            if ClipContext.isTruncated(lines) {
                Text("動画が長いので、最初の \(TimeText.format(ClipContext.coveredUntil(lines))) までの内容を使います")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            }

            switch tab {
            case .summary:
                ClipSummaryView(lines: lines, onSeek: seekAndClose)
            case .quiz:
                ClipQuizView(lines: lines, onSeek: seekAndClose)
            case .chat:
                ClipChatView(lines: lines, onSeek: seekAndClose)
            }
        }
    }

    private func seekAndClose(_ seconds: Double) {
        onSeek(seconds)
        dismiss()
    }

    private func unavailableView(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> some View {
        let message: String
        switch reason {
        case .deviceNotEligible:
            message = "この iPhone は Apple Intelligence に対応していないため、Q&A は使えません。"
        case .appleIntelligenceNotEnabled:
            message = "設定 →「Apple Intelligence と Siri」で Apple Intelligence をオンにすると使えます。"
        case .modelNotReady:
            message = "Apple Intelligence のデータを準備中です。しばらくしてからもう一度開いてください。"
        @unknown default:
            message = "今は Apple Intelligence を使えません。"
        }
        return ContentUnavailableView("Q&A を使えません", systemImage: "sparkles", description: Text(message))
    }
}

// MARK: - AI に渡す文字起こし

enum ClipContext {
    /// AI が一度に読める量（約4000トークン）に、質問と答えの分を残して収まる文字数
    static let characterLimit = 7000

    /// 時刻付きの文字起こし（[1:05] Hello ... の形）。長いときは先頭から characterLimit まで
    static func transcript(_ lines: [TranscriptLine]) -> String {
        included(lines).map { "[\(TimeText.format($0.start))] \($0.text)" }.joined(separator: "\n")
    }

    static func isTruncated(_ lines: [TranscriptLine]) -> Bool {
        included(lines).count < lines.count
    }

    static func coveredUntil(_ lines: [TranscriptLine]) -> Double {
        included(lines).last?.end ?? 0
    }

    private static func included(_ lines: [TranscriptLine]) -> [TranscriptLine] {
        var total = 0
        var result: [TranscriptLine] = []
        for line in lines {
            total += line.text.count + 8
            if total > characterLimit { break }
            result.append(line)
        }
        return result
    }

    static func instructions(_ lines: [TranscriptLine]) -> String {
        """
        あなたは、日本人の英語学習を手伝う先生です。
        以下は、英語の配信動画を文字起こししたものです。各行の先頭は動画の時刻 [分:秒] です。
        音声認識なので、聞き間違いが含まれることがあります。
        文字起こしに書かれていることだけをもとに答え、書かれていないことは「動画では触れていません」と答えてください。
        説明は日本語で、根拠になる英文を引用するときは、その行の時刻 [分:秒] も書いてください。

        --- 文字起こし ---
        \(transcript(lines))
        """
    }

    /// 文の中の [1:05] のような時刻を秒にする（タップで再生するため）
    static func timestamps(in text: String) -> [Double] {
        let pattern = #/\[(\d+):(\d{2})\]/#
        var seen: Set<Double> = []
        var result: [Double] = []
        for match in text.matches(of: pattern) {
            guard let minutes = Double(match.output.1), let seconds = Double(match.output.2) else { continue }
            let value = minutes * 60 + seconds
            if seen.insert(value).inserted { result.append(value) }
        }
        return result
    }

    @available(iOS 26.0, *)
    static func message(for error: Error) -> String {
        if let error = error as? LanguageModelSession.GenerationError {
            switch error {
            case .exceededContextWindowSize:
                return "AI が一度に読める量を超えました。会話をリセットしてください。"
            case .guardrailViolation:
                return "この内容には AI が答えられませんでした。"
            default:
                break
            }
        }
        return error.localizedDescription
    }
}

/// 答えの中の時刻を、タップで再生できるボタンとして並べる
private struct TimestampButtons: View {
    let text: String
    let onSeek: (Double) -> Void

    var body: some View {
        let times = ClipContext.timestamps(in: text)
        if !times.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(times, id: \.self) { time in
                        Button {
                            onSeek(time)
                        } label: {
                            Label(TimeText.format(time), systemImage: "play.fill")
                        }
                        .buttonStyle(AppButtonStyle(.secondary))
                        .controlSize(.small)
                    }
                }
            }
        }
    }
}

// MARK: - 要約

@available(iOS 26.0, *)
private struct ClipSummaryView: View {
    let lines: [TranscriptLine]
    let onSeek: (Double) -> Void

    @State private var summary: String?
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if let summary {
                    Text(summary)
                        .font(.body)
                        .textSelection(.enabled)
                    TimestampButtons(text: summary, onSeek: onSeek)
                } else if !isWorking {
                    Text("動画で話されている内容を、日本語で短くまとめます。覚えておきたい英語の表現も3つ選びます。")
                        .foregroundStyle(.secondary)
                }
                if isWorking {
                    ProgressView("まとめています…")
                }
                if let errorMessage {
                    Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                }
                Button {
                    Task { await summarize() }
                } label: {
                    Text(summary == nil ? "要約する" : "もう一度まとめる").frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(summary == nil ? .primary : .secondary))
                .disabled(isWorking)
            }
            .padding()
            .cardStyle()
            .padding()
        }
    }

    private func summarize() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        let session = LanguageModelSession(instructions: ClipContext.instructions(lines))
        let prompt = """
        この動画の内容を、日本語で3〜5行に要約してください。
        そのあとに「覚えたい表現」として、動画に出てくる英語の表現を3つ選び、それぞれ英文・意味・時刻 [分:秒] を書いてください。
        """
        do {
            summary = try await session.respond(to: prompt).content
        } catch {
            errorMessage = ClipContext.message(for: error)
        }
    }
}

// MARK: - クイズ

@available(iOS 26.0, *)
@Generable
struct ClipQuiz {
    @Guide(description: "動画の内容についての理解度クイズ。3問から5問")
    var questions: [ClipQuizQuestion]
}

@available(iOS 26.0, *)
@Generable
struct ClipQuizQuestion {
    @Guide(description: "動画の内容についての英語の質問文")
    var question: String
    @Guide(description: "英語の選択肢。ちょうど4つ")
    var choices: [String]
    @Guide(description: "正解の選択肢の番号（0から3）")
    var answerIndex: Int
    @Guide(description: "正解の理由を日本語で。根拠の英文の時刻 [分:秒] も書く")
    var explanation: String
}

@available(iOS 26.0, *)
private struct ClipQuizView: View {
    let lines: [TranscriptLine]
    let onSeek: (Double) -> Void

    @State private var questions: [ClipQuizQuestion] = []
    @State private var selected: [Int: Int] = [:]
    @State private var isWorking = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(questions.enumerated()), id: \.offset) { index, question in
                    questionCard(index, question)
                }
                if questions.isEmpty && !isWorking {
                    Text("動画の内容について、英語の4択クイズを作ります。")
                        .foregroundStyle(.secondary)
                }
                if isWorking {
                    ProgressView("クイズを作っています…")
                }
                if let errorMessage {
                    Text(errorMessage).font(.subheadline).foregroundStyle(.red)
                }
                Button {
                    Task { await makeQuiz() }
                } label: {
                    Text(questions.isEmpty ? "クイズを作る" : "別の問題を作る").frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(questions.isEmpty ? .primary : .secondary))
                .disabled(isWorking)
            }
            .padding()
        }
    }

    private func questionCard(_ index: Int, _ question: ClipQuizQuestion) -> some View {
        let answered = selected[index]
        return VStack(alignment: .leading, spacing: 10) {
            Text("Q\(index + 1). \(question.question)")
                .font(.body.weight(.semibold))
            ForEach(Array(question.choices.enumerated()), id: \.offset) { choiceIndex, choice in
                Button {
                    if answered == nil { selected[index] = choiceIndex }
                } label: {
                    Text(choice)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .choiceTile(state(answered: answered, choice: choiceIndex, correct: question.answerIndex))
                }
                .buttonStyle(.plain)
            }
            if answered != nil {
                Text(question.explanation)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                TimestampButtons(text: question.explanation, onSeek: onSeek)
            }
        }
        .padding()
        .cardStyle()
    }

    private func state(answered: Int?, choice: Int, correct: Int) -> ChoiceState {
        guard let answered else { return .normal }
        if choice == correct { return .correct }
        if choice == answered { return .wrong }
        return .dimmed
    }

    private func makeQuiz() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        let session = LanguageModelSession(instructions: ClipContext.instructions(lines))
        do {
            let quiz = try await session.respond(
                to: "この動画の内容について、聞き取れたかを確かめる英語の4択クイズを作ってください。",
                generating: ClipQuiz.self
            ).content
            // 選択肢の数や正解の番号がおかしい問題は除く
            questions = quiz.questions.filter { $0.choices.count >= 2 && $0.choices.indices.contains($0.answerIndex) }
            selected = [:]
            if questions.isEmpty { errorMessage = "うまく問題を作れませんでした。もう一度試してください。" }
        } catch {
            errorMessage = ClipContext.message(for: error)
        }
    }
}

// MARK: - 質問（チャット）

@available(iOS 26.0, *)
private struct ClipChatView: View {
    private struct Message: Identifiable {
        let id = UUID()
        let fromUser: Bool
        let text: String
    }

    let lines: [TranscriptLine]
    let onSeek: (Double) -> Void

    @State private var session: LanguageModelSession?
    @State private var messages: [Message] = []
    @State private var input = ""
    @State private var isWorking = false

    private let examples = [
        "この配信者は何について話している？",
        "「homie」ってどういう意味？",
        "聞き取りにくそうな表現を教えて",
    ]

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if messages.isEmpty {
                            Text("動画の内容や英語の表現について、日本語でも英語でも質問できます。")
                                .foregroundStyle(.secondary)
                            ForEach(examples, id: \.self) { example in
                                Button(example) { input = example }
                                    .buttonStyle(AppButtonStyle(.secondary))
                                    .controlSize(.small)
                            }
                        }
                        ForEach(messages) { message in
                            bubble(message).id(message.id)
                        }
                        if isWorking {
                            ProgressView().padding(.leading)
                        }
                    }
                    .padding()
                }
                .onChange(of: messages.count) {
                    if let last = messages.last {
                        withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                if !messages.isEmpty {
                    Button {
                        messages = []
                        session = nil
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("会話をリセット")
                    .padding(.bottom, 8)
                }
                TextField("質問を入力", text: $input, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.roundedBorder)
                Button {
                    Task { await send() }
                } label: {
                    Image(systemName: "arrow.up.circle.fill").font(.title)
                }
                .disabled(isWorking || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityLabel("送信")
            }
            .padding()
        }
    }

    private func bubble(_ message: Message) -> some View {
        VStack(alignment: message.fromUser ? .trailing : .leading, spacing: 6) {
            Text(message.text)
                .textSelection(.enabled)
                .padding(12)
                .background(message.fromUser ? AnyShapeStyle(.tint.opacity(0.18)) : AnyShapeStyle(Color(.secondarySystemBackground)),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !message.fromUser {
                TimestampButtons(text: message.text, onSeek: onSeek)
            }
        }
        .frame(maxWidth: .infinity, alignment: message.fromUser ? .trailing : .leading)
    }

    private func send() async {
        let question = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        input = ""
        messages.append(Message(fromUser: true, text: question))
        isWorking = true
        defer { isWorking = false }

        let current = session ?? LanguageModelSession(instructions: ClipContext.instructions(lines))
        session = current
        do {
            let answer = try await current.respond(to: question).content
            messages.append(Message(fromUser: false, text: answer))
        } catch {
            // 読める量を超えたら、次の質問は新しい会話で始める
            session = nil
            messages.append(Message(fromUser: false, text: ClipContext.message(for: error)))
        }
    }
}
