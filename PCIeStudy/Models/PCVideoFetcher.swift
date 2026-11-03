import Foundation

/// PC（仕様書QAサーバと同じ server.py）に YouTube の動画の保存を頼み、できたファイルを受け取る
///
/// 保存そのものは PC 上の yt-dlp が行う。PC 側の作り方は docs/PC_YOUTUBE_SERVER.md
/// - POST /api/youtube/download {"url": ...} → {"job": "..."}
/// - GET  /api/youtube/jobs/{job} → {"state": "queued|downloading|done|error", "progress": 0〜1, "title": ..., "error": ...}
/// - GET  /api/youtube/jobs/{job}/video → mp4
/// - GET  /api/youtube/jobs/{job}/subtitles → srt（英語字幕がないときは 404）
enum PCVideoFetcher {
    enum Failure: LocalizedError {
        case notConfigured
        case notSupported
        case failed(String)

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "PC のサーバのアドレスが未設定です。「学ぶ」タブの仕様書QAで、PC のアドレスを設定してください。"
            case .notSupported:
                return "PC のサーバが YouTube の保存に対応していません。PC 側の準備（docs/PC_YOUTUBE_SERVER.md）が必要です。"
            case .failed(let message):
                return message.isEmpty ? "PC での保存に失敗しました。" : "PC での保存に失敗しました：\(message)"
            }
        }
    }

    /// PC の youtube_library に保存してある動画を受け取る（ブラウザ版で取り込んだ動画を iPhone でも見るとき）
    static func fetchLibraryVideo(youtubeID: String, base: URL?) async throws -> URL {
        guard let base else { throw Failure.notConfigured }
        let url = base.appending(path: "api/youtube/library/\(youtubeID)/video")
        let (temporary, response) = try await URLSession.shared.download(from: url)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 { throw Failure.failed("PC にこの動画がありません") }
        guard code == 200 else { throw Failure.failed("HTTP \(code)") }
        let destination = EnglishStore.newFileURL(pathExtension: "mp4")
        try FileManager.default.moveItem(at: temporary, to: destination)
        return destination
    }

    struct Result {
        let title: String
        let videoFile: URL
        let subtitles: String?
    }

    private struct Job: Decodable {
        let job: String
    }

    private struct Status: Decodable {
        let state: String
        let progress: Double?
        let title: String?
        let error: String?
    }

    /// progress には (0〜1, 今の状況の説明) が届く
    static func fetch(_ videoURL: URL, base: URL?,
                      progress: @escaping @MainActor (Double, String) -> Void) async throws -> Result {
        guard let base else { throw Failure.notConfigured }

        var start = URLRequest(url: base.appending(path: "api/youtube/download"))
        start.httpMethod = "POST"
        start.setValue("application/json", forHTTPHeaderField: "Content-Type")
        start.httpBody = try JSONEncoder().encode(["url": videoURL.absoluteString])
        start.timeoutInterval = 15
        let (startData, startResponse) = try await URLSession.shared.data(for: start)
        let code = (startResponse as? HTTPURLResponse)?.statusCode ?? 0
        if code == 404 || code == 405 { throw Failure.notSupported }
        guard code == 200 else { throw Failure.failed(String(decoding: startData, as: UTF8.self)) }
        let job = try JSONDecoder().decode(Job.self, from: startData).job
        let jobURL = base.appending(path: "api/youtube/jobs/\(job)")

        // PC での保存が終わるのを待つ
        var title = ""
        while true {
            try Task.checkCancellation()
            try await Task.sleep(for: .seconds(2))
            let (data, _) = try await URLSession.shared.data(from: jobURL)
            let status = try JSONDecoder().decode(Status.self, from: data)
            title = status.title ?? title
            switch status.state {
            case "done":
                break
            case "error":
                throw Failure.failed(status.error ?? "")
            default:
                await progress((status.progress ?? 0) * 0.8, "PC で保存中…")
                continue
            }
            break
        }

        await progress(0.85, "iPhone に転送中…")
        let (temporary, videoResponse) = try await URLSession.shared.download(from: jobURL.appending(path: "video"))
        guard (videoResponse as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.failed("動画を受け取れませんでした") }
        let destination = EnglishStore.newFileURL(pathExtension: "mp4")
        try FileManager.default.moveItem(at: temporary, to: destination)

        var subtitles: String?
        if let (data, response) = try? await URLSession.shared.data(from: jobURL.appending(path: "subtitles")),
           (response as? HTTPURLResponse)?.statusCode == 200 {
            subtitles = String(decoding: data, as: UTF8.self)
        }
        await progress(1, "完了")
        return Result(title: title.isEmpty ? "YouTube の動画" : title, videoFile: destination, subtitles: subtitles)
    }
}
