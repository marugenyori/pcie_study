import Foundation
import Observation

/// PC のサーバ（GET/PUT /api/sync）を通して、ブラウザ版と記録を同期する（docs/SYNC.md）
///
/// PC から読む → 手元の記録と混ぜる → 混ぜた結果を PC に書く、の順に動く。
/// PC につながらないときや、サーバが同期に対応していないときは何もしない。
@Observable
final class SyncClient {
    private(set) var isSyncing = false
    private(set) var lastSynced: Date?
    /// 最後の同期でうまくいかなかったときの説明
    private(set) var problem: String?

    @ObservationIgnored private let defaults: UserDefaults
    private static let lastSyncedKey = "syncLastSynced"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        lastSynced = defaults.object(forKey: Self.lastSyncedKey) as? Date
    }

    @MainActor
    func sync(progress: ProgressStore, english: EnglishStore, base: URL?) async {
        guard let base, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        let url = base.appending(path: "api/sync")
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 8
            let (data, response) = try await URLSession.shared.data(for: request)
            let code = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard code != 404 else {
                problem = "PC のサーバが同期に対応していません（docs/SYNC.md の準備が必要）"
                return
            }
            guard code == 200 else {
                problem = "PC から読めませんでした（HTTP \(code)）"
                return
            }
            let remote = data.isEmpty ? SyncDocument() : try SyncCoding.decoder.decode(SyncDocument.self, from: data)
            if let remoteProgress = remote.progress { progress.merge(remoteProgress) }
            if let remoteEnglish = remote.english { english.merge(remoteEnglish) }

            let merged = SyncDocument(version: 1, progress: progress.syncSnapshot(), english: english.syncSnapshot())
            var put = URLRequest(url: url)
            put.httpMethod = "PUT"
            put.setValue("application/json", forHTTPHeaderField: "Content-Type")
            put.httpBody = try SyncCoding.encoder.encode(merged)
            put.timeoutInterval = 15
            let (_, putResponse) = try await URLSession.shared.data(for: put)
            guard (putResponse as? HTTPURLResponse)?.statusCode == 200 else {
                problem = "PC に書けませんでした"
                return
            }
            problem = nil
            lastSynced = Date()
            defaults.set(lastSynced, forKey: Self.lastSyncedKey)
        } catch {
            // 家の外など、PC につながらないのはふつうのことなので、説明だけ残す
            problem = "PC につながりませんでした（\(error.localizedDescription)）"
        }
    }
}
