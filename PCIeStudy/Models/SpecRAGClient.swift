import Foundation
import Observation

/// PC で動かしている仕様書QAサーバ（PCIe_RAG の server.py）との通信
@Observable
final class SpecRAGClient {
    /// 例：http://192.168.1.10:8765
    private(set) var serverAddress: String

    /// PC の Ollama に入っている回答用モデル（サーバが一覧を返さないときは空）
    private(set) var models: [String] = []
    /// サーバが既定にしているモデル
    private(set) var defaultModel: String?
    /// 選んだモデル（空ならサーバの既定）
    private(set) var selectedModel: String

    @ObservationIgnored private let defaults: UserDefaults
    private static let key = "specRAGServerAddress"
    private static let modelKey = "specRAGModel"
    static let defaultPort = 8765

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        serverAddress = defaults.string(forKey: Self.key) ?? ""
        selectedModel = defaults.string(forKey: Self.modelKey) ?? ""
    }

    func selectModel(_ name: String) {
        selectedModel = name
        defaults.set(name, forKey: Self.modelKey)
    }

    /// 実際に使うモデル（選んだものが PC になければサーバの既定）
    var effectiveModel: String? {
        if models.contains(selectedModel) { return selectedModel }
        return defaultModel ?? models.first
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

    /// 回答用モデルの一覧を読む（GET /api/models）。
    /// ["a", "b"] と {"models": ["a"] または [{"name": "a"}], "default": "a"} のどちらの形でも受け付ける
    func loadModels() async {
        guard let base = baseURL else { return }
        var request = URLRequest(url: base.appending(path: "api/models"))
        request.timeoutInterval = 5
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw ClientError.server("") }
            let json = try JSONSerialization.jsonObject(with: data)
            var list: [Any] = []
            var fallback: String?
            if let array = json as? [Any] {
                list = array
            } else if let obj = json as? [String: Any] {
                list = (obj["models"] as? [Any]) ?? []
                fallback = (obj["default"] as? String) ?? (obj["chat_model"] as? String)
            }
            models = list.compactMap { item in
                if let name = item as? String { return name }
                return (item as? [String: Any])?["name"] as? String
            }
            defaultModel = fallback
        } catch {
            models = []
            defaultModel = nil
        }
    }

    /// 質問を送り、検索結果と回答を少しずつ受け取る（NDJSON のストリーム）
    func ask(_ question: String, history: [(q: String, a: String)], model: String?) -> AsyncThrowingStream<Event, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let base = baseURL else { throw ClientError.notConfigured }
                    var request = URLRequest(url: base.appending(path: "api/ask"))
                    request.httpMethod = "POST"
                    // 大きいモデルは最初の文字が出るまで時間がかかるので、待ち時間を長めにする
                    request.timeoutInterval = 1200
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    var body: [String: Any] = [
                        "q": question,
                        "history": history.suffix(2).map { ["q": $0.q, "a": $0.a] },
                    ]
                    if let model { body["model"] = model }
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
