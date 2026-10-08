import Foundation

/// PCIe の動向ニュース（アプリのアップデートで更新する）
struct NewsItem: Identifiable, Hashable {
    enum Tag: String {
        case spec = "仕様"
        case roadmap = "ロードマップ"
        case compliance = "コンプライアンス"
        case event = "イベント"
        case ecn = "ECN"
        case industry = "業界"
        case product = "製品"
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
}

enum NewsData {
    /// このリストを最後に更新した日
    static let updated = "2026年10月8日"

    static var all: [NewsItem] {
        items.sorted { $0.date > $1.date }
    }

    private static let items: [NewsItem] = [
        NewsItem(
            id: "nova-lake-il", date: "2026-09", tag: .compliance,
            title: "Intel の次世代デスクトップ向け部品が PCI-SIG の互換性リストに",
            summary: "Intel 900 シリーズチップセットのルートポートと、PCIe 5.0 x16 のルートコンプレックスを持つ名前未公表の CPU が、インテグレーターズリスト（適合試験に合格した製品の一覧）に載りました。CPU は次世代の Nova Lake とみられていますが、Intel は認めていません。",
            source: "Club386",
            url: "https://www.club386.com/?p=158122"),
        NewsItem(
            id: "cadence-gen6", date: "2026-09-02", tag: .compliance,
            title: "Cadence の PCIe 6.0 IP が初回で適合試験に合格",
            summary: "TSMC N3 で作った PHY とコントローラの x8 構成が、64 GT/s での PCIe 6.0 適合試験に一度で合格し、インテグレーターズリストに載りました。試験は7月末のワークショップで行われました。",
            source: "EE Journal（Cadence の発表）",
            url: "https://www.eejournal.com/industry_news/cadence-subsystem-for-pcie-6-0-architecture-achieves-first-pass-pci-express-specification-compliance/"),
        NewsItem(
            id: "credo-gen6", date: "2026-08-31", tag: .compliance,
            title: "Credo の PCIe 6 リタイマがインテグレーターズリストに",
            summary: "Credo のリタイマ Toucan（Gen6 x16）が、64.0 GT/s での PCI-SIG 6.x リタイマ適合試験に合格しました。電気特性、相互接続性、6.0 で増えたリタイマのプロトコル要件が対象です。",
            source: "Business Wire（Credo）",
            url: "https://finviz.com/news/386943/credos-toucan-pcie-retimer-achieves-pci-express-compliance-and-joins-pci-express-6x-integrators-list"),
        NewsItem(
            id: "astera-gen6", date: "2026-08-04", tag: .compliance,
            title: "初の PCIe 6.x 適合試験ワークショップで、スイッチとリタイマが合格",
            summary: "PCI-SIG による初めての PCIe 6.x 適合試験ワークショップ（7月末まで）で、Astera Labs のスイッチ Scorpio とリタイマ Aries が合格しました。PAM4 の電気特性、コンフィグレーション、リンク層・トランザクション層の試験と、20以上の会員企業の機器との相互接続試験が行われました。",
            source: "Astera Labs（ブログ）",
            url: "https://asteralabs.com/resources/blog/industry-leading-high-volume-scorpio-smart-fabric-switches-and-aries-smart-retimers-achieve-compliance-at-first-pci-sig-6-x-workshop/"),
        NewsItem(
            id: "samsung-pm1763", date: "2026-07-09", tag: .product,
            title: "Samsung が PCIe 6.0 SSD「PM1763」を量産開始",
            summary: "AI サーバ向けの SSD で、16TB モデルは順次読み出し最大 28.4 GB/s、書き込み最大 21.9 GB/s。前の世代（PCIe 5.0 の PM1753）の2倍以上の性能です。耐量子暗号（PQC）や TDISP にも対応しています。",
            source: "StorageNewsletter",
            url: "https://www.storagenewsletter.com/2026/07/09/samsung-begins-mass-production-of-pm1763-ssd-optimized-for-next-generation-ai-infrastructure/"),
        NewsItem(
            id: "micron-9650", date: "2026-02", tag: .product,
            title: "Micron の 9650、PCIe 6.0 SSD として初の量産",
            summary: "PCIe 6.0 x4 で接続するデータセンター向け SSD です。順次読み出し 28 GB/s、書き込み 14 GB/s。形は E1.S と E3.S で、AI の推論用途を想定しています。",
            source: "heise online",
            url: "https://heise.de/-11176906"),
        NewsItem(
            id: "cxl-4", date: "2025-11-18", tag: .spec,
            title: "CXL 4.0 仕様を公開：PCIe 7.0 の上で 128 GT/s",
            summary: "PCIe の物理層を使うメモリ・アクセラレータ接続の規格 CXL が 4.0 になり、PCIe 7.0 に合わせて速度が 64 GT/s から 128 GT/s に倍増しました。x2 を通常の幅として使えるようになり、リタイマも最大4個まで使えます。",
            source: "Business Wire（CXL Consortium）",
            url: "https://www.businesswire.com/news/home/20251118275848/en/CXL-Consortium-Releases-the-Compute-Express-Link-4.0-Specification-Increasing-Speed-and-Bandwidth"),
        NewsItem(
            id: "base-7-1", date: "2026-09-03", tag: .spec,
            title: "PCIe Base Specification 7.1",
            summary: "7.0 にエラッタと承認済みの ECN を取り込んだ版です。CMA（デバイスの測定と認証）に耐量子暗号（PQC）のアルゴリズムを加える ECN なども含まれています。128.0 GT/s に関係しない変更は、6.5 にも同じものが入っています。",
            source: "PCIe Base Specification 7.1（表紙の日付）", url: nil),
        NewsItem(
            id: "viavi-gold-6", date: "2026-06-18", tag: .compliance,
            title: "PCIe 6.0 のコンプライアンス試験用プラットフォームが Gold Suite に採用",
            summary: "VIAVI の Xgig が、PCIe 6.0 のリンク層・トランザクション層の試験で PCI-SIG の Gold Suite に採用されました。PCI-SIG のコンプライアンスワークショップで、6.0 製品の相互接続性の確認に使われます。",
            source: "PR Newswire",
            url: "https://www.prnewswire.com/news-releases/viavi-pcie-6-0-platform-receives-pci-sig-gold-suite-acceptance-for-link-and-transaction-protocol-compliance-testing-302803904.html"),
        NewsItem(
            id: "pcie8-draft05", date: "2026-05-06", tag: .roadmap,
            title: "PCIe 8.0 仕様のドラフト 0.5 が会員に公開",
            summary: "256.0 GT/s を目指す PCIe 8.0 の、最初の本格的なドラフトです。2025年9月のドラフト 0.3 へのフィードバックが反映されています。新しいコネクタ技術の検討も進んでおり、正式版は2028年の予定どおりとされています。",
            source: "ServeTheHome",
            url: "https://www.servethehome.com/pci-sig-pcie-8-0-specification-draft-0-5-released/"),
        NewsItem(
            id: "devcon-2026", date: "2026-05-06", tag: .event,
            title: "PCI-SIG DevCon 2026 で光接続の相互接続デモ",
            summary: "5月6〜7日に米サンタクララで開かれた開発者会議で、PCIe 6.0 の IP、プロトコルアナライザ、光トランシーバ、スイッチを組み合わせ、電気と光をまたぐ構成でのプロトコル準拠を確かめるデモが行われました。",
            source: "Synopsys（イベント情報）",
            url: "https://www.synopsys.com/events/pci-sig-devcon.html"),
        NewsItem(
            id: "ecn-cma-pqc", date: "2025-11-06", tag: .ecn,
            title: "ECN：CMA の耐量子暗号（PQC）対応",
            summary: "デバイスの認証と測定（CMA）で使う暗号アルゴリズムに、量子コンピュータでも解読が難しい耐量子暗号を加える ECN です。Base 7.1 に取り込まれています。",
            source: "PCI-SIG ECN（文書の日付）", url: nil),
        NewsItem(
            id: "ecn-dsfc", date: "2025-09-18", tag: .ecn,
            title: "ECN：Dynamic Shared Flow Control の使用量の上限",
            summary: "Flit Mode の共有クレジット（Shared Flow Control）を動的に使うときの、使用量の上限について、未定義だった動作の明確化などを行う ECN です。Base 7.1 に取り込まれています。",
            source: "PCI-SIG ECN（文書の日付）", url: nil),
        NewsItem(
            id: "pcie8-draft03", date: "2025-09", tag: .roadmap,
            title: "PCIe 8.0 仕様のドラフト 0.3",
            summary: "PCIe 8.0 の最初のドラフト（0.3）が会員に公開されました。",
            source: "TechBriefly",
            url: "https://techbriefly.com/2026/05/08/pcie-8-0-draft-0-5-1-tb-s-bandwidth/"),
        NewsItem(
            id: "pcie8-announce", date: "2025-08-05", tag: .roadmap,
            title: "PCI-SIG が PCIe 8.0 を発表：256.0 GT/s、2028年までに",
            summary: "PCIe 7.0 の2倍となる 256.0 GT/s を目指し、x16 では双方向で最大 1 TB/s になります。新しいコネクタ技術の検討、遅延と FEC の目標の確認、後方互換性の維持、省電力などが目標に掲げられています。",
            source: "Business Wire（PCI-SIG）",
            url: "https://www.businesswire.com/news/home/20250805675479/en/PCI-SIG-Announces-PCI-Express-8.0-Specification-to-Reach-256.0-GTs"),
        NewsItem(
            id: "pcie7-release", date: "2025-06-11", tag: .spec,
            title: "PCIe 7.0 仕様を正式リリース：128.0 GT/s",
            summary: "PAM4 と Flit Mode を受け継ぎ、x16 で双方向 512 GB/s を実現します。AI/機械学習、800G イーサネット、クラウド、量子コンピューティングなどの用途を想定しています。仕様書の表紙の日付は2025年6月5日です。",
            source: "Business Wire（PCI-SIG）",
            url: "https://www.businesswire.com/news/home/20250611299049/en"),
        NewsItem(
            id: "optical-retimer", date: "2025-06-11", tag: .spec,
            title: "PCIe の光接続：Optical Aware Retimer ECN",
            summary: "リタイマを使って、光ファイバーを含むリンクで PCIe を動かすための初めての標準的な方法です。6.4 と 7.0 に追加されました。",
            source: "Business Wire（PCI-SIG）",
            url: "https://www.businesswire.com/news/home/20250611887972/en/PCI-SIG-Announces-PCIe-Optical-Interconnect-Solution"),
        NewsItem(
            id: "pcie6-delay", date: "2024-06", tag: .compliance,
            title: "PCIe 6.0・7.0 のコンプライアンス試験が予定より遅れる",
            summary: "PCI-SIG の開発者会議で、PCIe 6.0 と 7.0 の作業が当初の計画より遅れていることが示されました。PCIe 6.0 の適合試験は先送りされ、7.0 の適合試験も2027年から2028年に延期されました。",
            source: "heise online",
            url: "https://heise.de/en/news/It-gets-faster-later-Delays-with-PCIe-6-0-and-7-0-9765200.html"),
        NewsItem(
            id: "copprlink", date: "2024-05-01", tag: .spec,
            title: "PCIe 5.0・6.0 用のケーブル規格 CopprLink",
            summary: "PCI-SIG が、銅線ケーブルで PCIe 5.0（32.0 GT/s）と 6.0（64.0 GT/s）をつなぐための CopprLink ケーブル規格（筐体の中で使う内部用と、外へ出す外部用）を発表しました。",
            source: "Business Wire（PCI-SIG）",
            url: "https://www.businesswire.com/news/home/20240501529875/en/PCI-SIG%C2%AE-Announces-CopprLink%E2%84%A2-Cable-Specifications-for-PCIe%C2%AE-5.0-and-6.0-Technology"),
        NewsItem(
            id: "sig-1000", date: "2024-12-05", tag: .industry,
            title: "PCI-SIG の会員企業が1,000社に",
            summary: "PCIe の仕様を策定する PCI-SIG の会員企業数が、世界で1,000社に達しました。",
            source: "Business Wire（PCI-SIG）",
            url: "https://www.businesswire.com/news/home/20241205568741/en/PCI-SIG%C2%AE-Reaches-Milestone-of-1000-Member-Companies-Worldwide"),
    ]
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
