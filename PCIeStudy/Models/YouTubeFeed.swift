import Foundation

/// YouTube チャンネルの新着動画（PC の yt-dlp で30本、PC が使えないときは公開の RSS フィードで15本）
struct YouTubeVideo: Identifiable, Hashable {
    let id: String
    let title: String
    let published: Date?
    let thumbnailURL: URL?

    var watchURL: URL { URL(string: "https://www.youtube.com/watch?v=\(id)")! }
}

enum YouTubeFeed {
    /// South Park 公式チャンネル（@southpark）
    static let southParkHandle = "southpark"
    /// チャンネルページから ID を読み取れないときに使う ID（South Park Studios）
    static let southParkFallbackID = "UC7R27sAWc_DqOldtI1JcYhQ"

    enum Failure: LocalizedError {
        case notFound(String)

        var errorDescription: String? {
            switch self {
            case .notFound(let detail):
                return "動画の一覧を読み込めませんでした。\n\(detail)"
            }
        }
    }

    /// PC のサーバ（yt-dlp）があればそこから、なければ YouTube の公開 RSS から一覧を読む
    ///
    /// YouTube の RSS はエラーを返すことがあるので、PC が使えるときは PC を優先する。
    static func latestVideos(handle: String, fallbackChannelID: String, pcBase: URL?) async throws -> [YouTubeVideo] {
        var problems: [String] = []
        if let pcBase {
            do {
                return try await videosFromPC(handle: handle, base: pcBase)
            } catch {
                problems.append("PC：\(error.localizedDescription)")
            }
        } else {
            problems.append("PC：アドレスが未設定")
        }
        do {
            return try await videosFromFeed(handle: handle, fallbackChannelID: fallbackChannelID)
        } catch {
            problems.append("YouTube の RSS：\(error.localizedDescription)")
        }
        throw Failure.notFound(problems.joined(separator: "\n"))
    }

    private struct PCList: Decodable {
        struct Item: Decodable {
            let id: String
            let title: String
            let published: String?
            let thumbnail: String?
        }

        let videos: [Item]
    }

    /// GET /api/youtube/channel?handle=southpark&limit=30（PC 側は docs/PC_YOUTUBE_SERVER.md）
    private static func videosFromPC(handle: String, base: URL) async throws -> [YouTubeVideo] {
        var components = URLComponents(url: base.appending(path: "api/youtube/channel"), resolvingAgainstBaseURL: false)
        components?.queryItems = [URLQueryItem(name: "handle", value: handle), URLQueryItem(name: "limit", value: "30")]
        guard let url = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            throw NSError(domain: "PC", code: code, userInfo: [NSLocalizedDescriptionKey:
                code == 404 ? "一覧の取得に未対応（PC 側の準備が必要）" : "HTTP \(code)"])
        }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return try JSONDecoder().decode(PCList.self, from: data).videos.map { item in
            YouTubeVideo(id: item.id, title: item.title,
                         published: item.published.flatMap { formatter.date(from: $0) },
                         thumbnailURL: item.thumbnail.flatMap(URL.init(string:))
                            ?? URL(string: "https://i.ytimg.com/vi/\(item.id)/mqdefault.jpg"))
        }
    }

    private static func videosFromFeed(handle: String, fallbackChannelID: String) async throws -> [YouTubeVideo] {
        let channelID = (try? await channelID(handle: handle)) ?? fallbackChannelID
        var request = URLRequest(url: URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelID)")!)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard code == 200 else {
            throw NSError(domain: "YouTube", code: code, userInfo: [NSLocalizedDescriptionKey: "HTTP \(code)"])
        }
        let videos = FeedParser.parse(data)
        guard !videos.isEmpty else {
            throw NSError(domain: "YouTube", code: 0, userInfo: [NSLocalizedDescriptionKey: "動画が0件"])
        }
        return videos
    }

    /// @handle のチャンネルページから、チャンネル ID（UC から始まる24文字）を読み取る
    private static func channelID(handle: String) async throws -> String? {
        var request = URLRequest(url: URL(string: "https://www.youtube.com/@\(handle)")!)
        request.timeoutInterval = 10
        let (data, _) = try await URLSession.shared.data(for: request)
        let html = String(decoding: data, as: UTF8.self)
        for pattern in [#""externalId":"(UC[A-Za-z0-9_-]{22})""#, #"channel/(UC[A-Za-z0-9_-]{22})"#] {
            if let range = html.range(of: pattern, options: .regularExpression) {
                let match = String(html[range])
                if let idRange = match.range(of: "UC[A-Za-z0-9_-]{22}", options: .regularExpression) {
                    return String(match[idRange])
                }
            }
        }
        return nil
    }
}

/// RSS（Atom）の <entry> から動画 ID・題名・公開日・サムネイルを取り出す
private final class FeedParser: NSObject, XMLParserDelegate {
    private var videos: [YouTubeVideo] = []
    private var inEntry = false
    private var element = ""
    private var text = ""
    private var videoID = ""
    private var title = ""
    private var published = ""
    private var thumbnail: URL?

    static func parse(_ data: Data) -> [YouTubeVideo] {
        let delegate = FeedParser()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.videos
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        element = elementName
        text = ""
        if elementName == "entry" {
            inEntry = true
            videoID = ""
            title = ""
            published = ""
            thumbnail = nil
        } else if inEntry, elementName == "media:thumbnail", let url = attributeDict["url"] {
            thumbnail = URL(string: url)
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        text += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard inEntry else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "yt:videoId": videoID = value
        case "title": if title.isEmpty { title = value }
        case "published": published = value
        case "entry":
            inEntry = false
            if !videoID.isEmpty {
                videos.append(YouTubeVideo(id: videoID, title: title,
                                           published: ISO8601DateFormatter().date(from: published),
                                           thumbnailURL: thumbnail))
            }
        default: break
        }
        text = ""
    }
}
