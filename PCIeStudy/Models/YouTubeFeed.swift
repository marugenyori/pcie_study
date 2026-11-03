import Foundation

/// YouTube チャンネルの新着動画（公開の RSS フィード。最新15本まで）
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
        case notFound

        var errorDescription: String? {
            "動画の一覧を読み込めませんでした。ネットにつながっているか確認してください。"
        }
    }

    static func latestVideos(handle: String, fallbackChannelID: String) async throws -> [YouTubeVideo] {
        let channelID = (try? await channelID(handle: handle)) ?? fallbackChannelID
        var request = URLRequest(url: URL(string: "https://www.youtube.com/feeds/videos.xml?channel_id=\(channelID)")!)
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw Failure.notFound }
        let videos = FeedParser.parse(data)
        guard !videos.isEmpty else { throw Failure.notFound }
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
