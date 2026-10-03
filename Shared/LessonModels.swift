import Foundation

enum Level: String, CaseIterable, Identifiable, Hashable {
    case beginner = "入門"
    case intermediate = "中級"
    case advanced = "上級"

    var id: String { rawValue }
}

/// 解説テキストを構成するブロック。テキストは Markdown（**太字** や `コード`）を使える
enum ContentBlock: Hashable {
    case heading(String)
    case text(String)
    case bullets([String])
    case table(header: [String], rows: [[String]])
    case note(String)      // ポイント・補足
    case figure(String)    // 等幅で表示する図（ASCII）
}

/// 章から開ける図解
enum DiagramKind: String, CaseIterable, Identifiable, Hashable {
    case topology
    case layers
    case tlpHeader
    case ackNak
    case ltssm

    var id: String { rawValue }

    var title: String {
        switch self {
        case .topology: return "トポロジとBDF"
        case .layers: return "レイヤとカプセル化"
        case .tlpHeader: return "TLPヘッダ構造"
        case .ackNak: return "ACK/NAK 再送シミュレータ"
        case .ltssm: return "LTSSM 状態遷移"
        }
    }

    var subtitle: String {
        switch self {
        case .topology: return "RC・スイッチ・EPの階層をタップして確認"
        case .layers: return "TLPが各層で包まれる様子をステップ表示"
        case .tlpHeader: return "各フィールドをタップ／Fmt・Typeデコーダ"
        case .ackNak: return "エラーを注入して再送の動きを体験"
        case .ltssm: return "リンクアップの流れを再生・手動遷移"
        }
    }

    var symbol: String {
        switch self {
        case .topology: return "point.3.connected.trianglepath.dotted"
        case .layers: return "square.stack.3d.up"
        case .tlpHeader: return "tablecells"
        case .ackNak: return "arrow.triangle.2.circlepath"
        case .ltssm: return "arrow.triangle.branch"
        }
    }
}

struct Chapter: Identifiable, Hashable {
    let id: String
    let number: Int
    let title: String
    let summary: String
    let level: Level
    let symbol: String
    let blocks: [ContentBlock]
    var diagram: DiagramKind? = nil
}
