import Foundation
import FoundationModels

/// iPhone 内の AI（Apple Intelligence、iOS 26 以上）との会話。前の質問と答えを覚えたまま続けて聞ける
final class AppleAIConversation {
    enum Failure: LocalizedError {
        case unavailable(String)

        var errorDescription: String? {
            switch self {
            case .unavailable(let reason): return reason
            }
        }
    }

    /// LanguageModelSession（iOS 26 より前の型では持てないので AnyObject で持つ）
    private var session: AnyObject?

    private static let instructions = """
        あなたは、PCIe（PCI Express）を学んでいる日本人を手伝う先生です。
        日本語で、専門用語には短い説明を添えて、わかりやすく答えてください。
        数値やビット位置など細かい仕様は間違えることがあるので、確かでないときはそう書き、PCIe Base Specification で確かめるよう勧めてください。
        """

    /// 使えないときは理由、使えるときは nil
    static var unavailableReason: String? {
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return nil
            case .unavailable(.deviceNotEligible):
                return "この iPhone は Apple Intelligence に対応していません（iPhone 15 Pro 以降が必要）。"
            case .unavailable(.appleIntelligenceNotEnabled):
                return "設定 →「Apple Intelligence と Siri」で Apple Intelligence をオンにすると使えます。"
            case .unavailable(.modelNotReady):
                return "Apple Intelligence のデータを準備中です。しばらくしてから試してください。"
            case .unavailable:
                return "今は Apple Intelligence を使えません。"
            }
        }
        return "Apple Intelligence に聞くには iOS 26 以上が必要です。"
    }

    func ask(_ question: String) async throws -> String {
        if let reason = Self.unavailableReason { throw Failure.unavailable(reason) }
        guard #available(iOS 26.0, *) else { throw Failure.unavailable("iOS 26 以上が必要です。") }
        let current = (session as? LanguageModelSession) ?? LanguageModelSession(instructions: Self.instructions)
        session = current
        do {
            return try await current.respond(to: question).content
        } catch let error as LanguageModelSession.GenerationError {
            // 覚えている会話が長くなりすぎたら、次は新しい会話で始める
            session = nil
            if case .exceededContextWindowSize = error {
                throw Failure.unavailable("会話が長くなりすぎました。もう一度質問すると、新しい会話で答えます。")
            }
            if case .guardrailViolation = error {
                throw Failure.unavailable("この質問には Apple Intelligence が答えられませんでした。")
            }
            throw error
        }
    }

    func reset() {
        session = nil
    }
}
