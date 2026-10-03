import Foundation
import Observation

/// PC で動かしている仕様書QAサーバ（PCIe_RAG の server.py）との通信
@Observable
final class SpecRAGClient {
    /// 例：http://192.168.1.10:8765
    private(set) var serverAddress: String

    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "specRAGServerAddress"
    static let defaultPort = 8765

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        serverAddress = defaults.string(forKey: Self.key) ?? ""
    }

    func setServerAddress(_ text: String) {
        serverAddress = text.trimmingCharacters(in: .whitespacesAndNewlines)
        defaults.set(serverAddress, forKey: Self.key)
    }

    var isConfigured: Bool { baseURL != nil }

    /// 「192.168.1.10」だけでも「http://192.168.1.10:8765」として扱う
    var baseURL: URL? {
        var text = serverAddress
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "http://" + text }
        guard var comps = URLComponents(string: text), comps.host?.isEmpty == false else { return nil }
        if comps.port == nil { comps.port = Self.defaultPort }
        comps.path = ""
        return comps.url
    }

    // MARK: API

    struct Health: Decodable {
        let ok: Bool
        let error: String?
        let chunks: Int
        let dense: Bool
        let ollama: Bool
        let chat_model: String
        let chat_model_ready: Bool
    }

    struct Source: Decodable, Identifiable, Hashable {
        let n: Int
        let doc: String
        let num: String?
        let title: String
        let page: Int
        let text: String
        var id: Int { n }

        var label: String {
            if let num, !num.isEmpty { return "§\(num) \(title)" }
            return title
        }
    }

    enum Event {
        case status(String)
        case sources([Source])
        case token(String)
        case done
        case failure(String)
    }

    enum ClientError: LocalizedError {
        case notConfigured
        case server(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured: return "サーバのアドレスが設定されていません"
            case .server(let message): return message
            }
        }
    }

    func health() async throws -> Health {
        guard let base = baseURL else { throw ClientError.notConfigured }
        var request = URLRequest(url: base.appending(path: "api/health"))
        request.timeoutInterval = 5
        let (data, _) = try await URLSession.shared.data(for: request)
        return try JSONDecoder().decode(Health.self, from: data)
    }

    /// 質問を送り、検索結果と回答を少しずつ受け取る（NDJSON のストリーム）
    func ask(_ question: String, history: [(q: String, a: String)]) -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let base = baseURL else { throw ClientError.notConfigured }
                    var request = URLRequest(url: base.appending(path: "api/ask"))
                    request.httpMethod = "POST"
                    request.timeoutInterval = 300
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    let body: [String: Any] = [
                        "q": question,
                        "history": history.suffix(2).map { ["q": $0.q, "a": $0.a] },
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                        var data = Data()
                        for try await byte in bytes { data.append(byte) }
                        let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["error"] as? String
                        throw ClientError.server(message ?? "サーバがエラーを返しました（\(http.statusCode)）")
                    }
                    for try await line in bytes.lines {
                        guard let data = line.data(using: .utf8),
                              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                              let type = obj["type"] as? String else { continue }
                        switch type {
                        case "status":
                            continuation.yield(.status(obj["text"] as? String ?? ""))
                        case "sources":
                            let results = (obj["results"] as? [[String: Any]]) ?? []
                            let json = try JSONSerialization.data(withJSONObject: results)
                            let sources = (try? JSONDecoder().decode([Source].self, from: json)) ?? []
                            continuation.yield(.sources(sources))
                        case "token":
                            continuation.yield(.token(obj["t"] as? String ?? ""))
                        case "done":
                            continuation.yield(.done)
                        case "error":
                            continuation.yield(.failure(obj["message"] as? String ?? "エラーが起きました"))
                        default:
                            break
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
