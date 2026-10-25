import Foundation

/// PCIe の動向ニュース
/// 中身は Shared/news.json。アプリは GitHub 上の最新の news.json を読み込んで App Group に保存し、
/// ウィジェットもそれを使う。読み込めないときはアプリに同梱した news.json を使う
struct NewsItem: Identifiable, Hashable, Codable {
    enum Tag: String, Codable {
        case spec, roadmap, compliance, event, ecn, industry, product

        var label: String {
            switch self {
            case .spec: return "仕様"
            case .roadmap: return "ロードマップ"
            case .compliance: return "コンプライアンス"
            case .event: return "イベント"
            case .ecn: return "ECN"
            case .industry: return "業界"
            case .product: return "製品"
            }
        }
    }

    let id: String
    /// 並べ替え用（yyyy-MM-dd。日が不明なら月や年まで）
    let date: String
    let tag: Tag
    let title: String
    let summary: String
    /// 出典
    let source: String
    let url: String?

    init(id: String, date: String, tag: Tag, title: String, summary: String, source: String, url: String?) {
        self.id = id
        self.date = date
        self.tag = tag
        self.title = title
        self.summary = summary
        self.source = source
        self.url = url
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        date = try c.decode(String.self, forKey: .date)
        // 知らない分類が来ても、ほかのニュースまで読めなくならないようにする
        tag = Tag(rawValue: (try? c.decode(String.self, forKey: .tag)) ?? "") ?? .industry
        title = try c.decode(String.self, forKey: .title)
        summary = try c.decode(String.self, forKey: .summary)
        source = try c.decode(String.self, forKey: .source)
        url = try c.decodeIfPresent(String.self, forKey: .url)
    }
}

/// news.json の中身
struct NewsFeed: Codable {
    /// 最後に更新した日（yyyy-MM-dd）
    let updated: String
    let items: [NewsItem]
}

enum NewsData {
    /// GitHub 上の最新版（リポジトリは公開）
    static let remoteURL = URL(string: "https://raw.githubusercontent.com/marugenyori/pcie_study/main/Shared/news.json")!

    /// 新しいニュースを保存したときに送る通知
    static let didChange = Notification.Name("NewsDataDidChange")

    private enum Keys {
        static let cache = "newsFeedJSON"
        static let fetchedAt = "newsFeedFetchedAt"
    }

    /// 保存してある最新版、なければ同梱版
    static var feed: NewsFeed {
        if let data = AppGroup.defaults.data(forKey: Keys.cache),
           let feed = try? JSONDecoder().decode(NewsFeed.self, from: data),
           feed.updated >= bundled.updated {
            return feed
        }
        return bundled
    }

    static var all: [NewsItem] {
        feed.items.sorted { $0.date > $1.date }
    }

    /// 表示用の最終更新日（2026年10月25日）
    static var updated: String {
        let parts = feed.updated.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return feed.updated }
        return "\(parts[0])年\(parts[1])月\(parts[2])日"
    }

    private static let bundled: NewsFeed = {
        guard let url = Bundle.main.url(forResource: "news", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let feed = try? JSONDecoder().decode(NewsFeed.self, from: data) else {
            return NewsFeed(updated: "", items: [])
        }
        return feed
    }()

    /// GitHub から最新版を読み込んで保存する。中身が変わったら true
    /// - Parameter minInterval: 前回からこの秒数がたっていなければ読みに行かない
    @discardableResult
    static func refresh(minInterval: TimeInterval = 3 * 3600) async -> Bool {
        let defaults = AppGroup.defaults
        let last = defaults.double(forKey: Keys.fetchedAt)
        guard Date.now.timeIntervalSince1970 - last >= minInterval else { return false }
        var request = URLRequest(url: remoteURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 15
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let feed = try? JSONDecoder().decode(NewsFeed.self, from: data),
              !feed.items.isEmpty else { return false }
        defaults.set(Date.now.timeIntervalSince1970, forKey: Keys.fetchedAt)
        let changed = defaults.data(forKey: Keys.cache) != data
        if changed {
            defaults.set(data, forKey: Keys.cache)
            await MainActor.run { NotificationCenter.default.post(name: didChange, object: nil) }
        }
        return changed
    }
}

extension NewsItem {
    /// 表示用の日付（2026年5月6日 / 2025年9月 / 2025年）
    var dateLabel: String {
        let parts = date.split(separator: "-").compactMap { Int($0) }
        switch parts.count {
        case 3: return "\(parts[0])年\(parts[1])月\(parts[2])日"
        case 2: return "\(parts[0])年\(parts[1])月"
        default: return "\(parts.first ?? 0)年"
        }
    }
}

/// ウィジェットからニュースを開くためのリンク（pciestudy://news/<id>）
enum NewsLink {
    static let scheme = "pciestudy"

    static func url(for item: NewsItem) -> URL? {
        URL(string: "\(scheme)://news/\(item.id)")
    }

    /// リンクが指すニュース（ニュース以外のリンクや、見つからないときは nil）
    static func item(from url: URL) -> NewsItem? {
        guard url.scheme == scheme, url.host == "news" else { return nil }
        let id = url.lastPathComponent
        return NewsData.all.first { $0.id == id }
    }
}
