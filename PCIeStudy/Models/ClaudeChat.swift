import Foundation
import Observation
import UIKit

/// Claude API（Messages API）に直接質問して、回答をアプリ内に表示する。
/// claude.ai のセッションは作らない。API キーはキーチェーンに保存する
@MainActor
@Observable
final class ClaudeChat {
    struct Turn: Identifiable, Equatable {
        enum Role: String { case user, assistant }
        let id = UUID()
        let role: Role
        var text: String
        /// 画面に出す文（1つ目の質問は問題の情報を含むので、表示用を別に持つ）
        var display: String
    }

    static let model = "claude-opus-5-5"
    private static let keyAccount = "anthropicAPIKey"

    private(set) var turns: [Turn] = []
    private(set) var isStreaming = false
    /// 回答の最初の文字が届くまで（考えている間）
    private(set) var isThinking = false
    private(set) var errorMessage: String?
    private(set) var hasAPIKey: Bool

    @ObservationIgnored private let system: String
    @ObservationIgnored private var task: Task<Void, Never>?

    init(system: String) {
        self.system = system
        hasAPIKey = KeychainStore.read(Self.keyAccount) != nil
    }

    // MARK: API キー

    func saveAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        KeychainStore.save(trimmed, for: Self.keyAccount)
        hasAPIKey = true
        errorMessage = nil
    }

    func deleteAPIKey() {
        KeychainStore.delete(Self.keyAccount)
        hasAPIKey = false
    }

    // MARK: 質問

    /// text は API に送る文、display は画面に出す文
    func send(_ text: String, display: String? = nil) {
        guard !isStreaming, let key = KeychainStore.read(Self.keyAccount) else { return }
        errorMessage = nil
        turns.append(Turn(role: .user, text: text, display: display ?? text))
        turns.append(Turn(role: .assistant, text: "", display: ""))
        isStreaming = true
        isThinking = true
        UIApplication.shared.isIdleTimerDisabled = true
        let history = turns.dropLast().map { ["role": $0.role.rawValue, "content": $0.text] }
        task = Task { [weak self] in
            await self?.stream(messages: Array(history), apiKey: key)
        }
    }

    func cancel() {
        task?.cancel()
    }

    func reset() {
        cancel()
        turns = []
        errorMessage = nil
    }

    private func finish(error: String?) {
        isStreaming = false
        isThinking = false
        UIApplication.shared.isIdleTimerDisabled = false
        errorMessage = error
        // 何も返ってこなかったときは、空の回答と、その質問を取り消す（もう一度送れるように）
        if let last = turns.last, last.role == .assistant, last.text.isEmpty {
            turns.removeLast()
            if let user = turns.last, user.role == .user { turns.removeLast() }
        }
    }

    private func append(_ delta: String) {
        guard let index = turns.indices.last else { return }
        isThinking = false
        turns[index].text += delta
        turns[index].display = turns[index].text
    }

    private func clearAnswer() {
        guard let index = turns.indices.last else { return }
        turns[index].text = ""
        turns[index].display = ""
    }

    private func stream(messages: [[String: String]], apiKey: String) async {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2026-10-21", forHTTPHeaderField: "anthropic-version")
        // 安全上の理由で断られたとき、サーバ側で別のモデルに自動で回す
        request.setValue("server-side-fallback-2026-07-01", forHTTPHeaderField: "anthropic-beta")
        let body: [String: Any] = [
            "model": Self.model,
            "max_tokens": 16000,
            "stream": true,
            "system": system,
            "output_config": ["effort": "medium"],
            "fallbacks": "default",
            "messages": messages,
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (bytes, response) = try await URLSession.shared.bytes(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            if status != 200 {
                var raw = ""
                for try await line in bytes.lines { raw += line }
                await finish(error: Self.describe(status: status, body: raw))
                return
            }
            var stopReason: String?
            for try await line in bytes.lines {
                guard line.hasPrefix("data:") else { continue }
                let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                guard let data = payload.data(using: .utf8),
                      let event = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let type = event["type"] as? String else { continue }
                switch type {
                case "content_block_start":
                    // 別のモデルに切り替わったら、それまでの途中の回答は捨てる
                    if let block = event["content_block"] as? [String: Any], block["type"] as? String == "fallback" {
                        await clearAnswer()
                    }
                case "content_block_delta":
                    if let delta = event["delta"] as? [String: Any],
                       delta["type"] as? String == "text_delta",
                       let text = delta["text"] as? String {
                        await append(text)
                    }
                case "message_delta":
                    if let delta = event["delta"] as? [String: Any], let reason = delta["stop_reason"] as? String {
                        stopReason = reason
                    }
                case "error":
                    let message = (event["error"] as? [String: Any])?["message"] as? String ?? "不明なエラー"
                    await finish(error: "回答の途中でエラーになりました：\(message)")
                    return
                default:
                    break
                }
            }
            switch stopReason {
            case "refusal":
                await clearAnswer()
                await finish(error: "この質問には答えられないと判断されました。聞き方を変えてみてください。")
            case "max_tokens":
                await append("\n\n（長すぎるため、ここで途切れました）")
                await finish(error: nil)
            default:
                await finish(error: nil)
            }
        } catch is CancellationError {
            await finish(error: nil)
        } catch let error as URLError where error.code == .cancelled {
            await finish(error: nil)
        } catch {
            await finish(error: "通信できませんでした：\(error.localizedDescription)")
        }
    }

    private static func describe(status: Int, body: String) -> String {
        var message = ""
        if let data = body.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any] {
            message = error["message"] as? String ?? ""
        }
        switch status {
        case 401: return "API キーが正しくないようです。キーを入れ直してください。"
        case 403: return "この API キーでは使えません（権限がありません）。\(message)"
        case 429: return "利用の上限に達しました。少し待ってから、もう一度試してください。\(message)"
        case 400 where message.contains("credit"):
            return "API のクレジット（前払いの残高）が足りません。Claude Console の「Billing」で確認してください。"
        case 500...599: return "Claude 側が混み合っています。少し待ってから、もう一度試してください。"
        default: return "エラー（\(status)）：\(message)"
        }
    }
}
