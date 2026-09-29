import Foundation

/// TLPヘッダの1フィールド（非FLITモード、Gen1〜5）
struct TLPField: Identifiable, Hashable {
    let dw: Int          // 何DW目か（0始まり）
    let hi: Int          // 上位ビット（31〜0）
    let lo: Int          // 下位ビット
    let name: String     // 表示名（短縮）
    let fullName: String
    let detail: String

    var id: String { "\(dw)-\(hi)-\(name)" }
    var width: Int { hi - lo + 1 }
    var bitRange: String { hi == lo ? "bit \(hi)" : "bit \(hi):\(lo)" }
}

enum TLPHeaderFormat: String, CaseIterable, Identifiable {
    case memory3DW = "MRd/MWr 3DW"
    case memory4DW = "MRd/MWr 4DW"
    case completion = "Completion"

    var id: String { rawValue }

    var dwCount: Int {
        switch self {
        case .memory3DW, .completion: return 3
        case .memory4DW: return 4
        }
    }

    var fields: [TLPField] {
        var f = TLPHeaderFormat.commonDW0
        switch self {
        case .memory3DW:
            f += TLPHeaderFormat.requestDW1
            f += [
                TLPField(dw: 2, hi: 31, lo: 2, name: "Address[31:2]", fullName: "Address",
                         detail: "32ビットのアクセス先アドレス。DW境界なので下位2ビットは含まれず、バイト単位の位置はByte Enableで示します。"),
                TLPField(dw: 2, hi: 1, lo: 0, name: "PH", fullName: "Processing Hint",
                         detail: "TPH（TLP Processing Hints）使用時のヒント。TH=0のときは予約（0）。"),
            ]
        case .memory4DW:
            f += TLPHeaderFormat.requestDW1
            f += [
                TLPField(dw: 2, hi: 31, lo: 0, name: "Address[63:32]", fullName: "Address（上位）",
                         detail: "64ビットアドレスの上位32ビット。上位が0のアドレスには3DWヘッダを使わなければなりません。"),
                TLPField(dw: 3, hi: 31, lo: 2, name: "Address[31:2]", fullName: "Address（下位）",
                         detail: "64ビットアドレスの下位部分。"),
                TLPField(dw: 3, hi: 1, lo: 0, name: "PH", fullName: "Processing Hint",
                         detail: "TPH使用時のヒント。TH=0のときは予約。"),
            ]
        case .completion:
            f += [
                TLPField(dw: 1, hi: 31, lo: 16, name: "Completer ID", fullName: "Completer ID",
                         detail: "応答を返したFunctionのBDF。"),
                TLPField(dw: 1, hi: 15, lo: 13, name: "Status", fullName: "Completion Status",
                         detail: "000=SC（成功）、001=UR（Unsupported Request）、010=RRS（Request Retry Status。以前はCRS）、100=CA（Completer Abort）。それ以外は予約。"),
                TLPField(dw: 1, hi: 12, lo: 12, name: "BCM", fullName: "Byte Count Modified",
                         detail: "PCI-Xブリッジが使うフラグ。PCIeデバイスは通常0。"),
                TLPField(dw: 1, hi: 11, lo: 0, name: "Byte Count", fullName: "Byte Count",
                         detail: "このCompletionを含め、リクエスト完了までに残っているバイト数。読み出しが複数のCplDに分割されるとき、受信側はこれで最後かどうかを判断できます。"),
                TLPField(dw: 2, hi: 31, lo: 16, name: "Requester ID", fullName: "Requester ID",
                         detail: "元のリクエストを出したFunctionのBDF。Completionはこれを使ってID ルーティングされます。"),
                TLPField(dw: 2, hi: 15, lo: 8, name: "Tag", fullName: "Tag",
                         detail: "元のリクエストのTag。Requester IDと組み合わせて、どのリクエストへの応答かを特定します。"),
                TLPField(dw: 2, hi: 7, lo: 7, name: "R", fullName: "Reserved",
                         detail: "予約ビット。"),
                TLPField(dw: 2, hi: 6, lo: 0, name: "Lower Address", fullName: "Lower Address",
                         detail: "このCompletionに含まれる最初のバイトのアドレス下位7ビット。分割されたCplDの位置合わせに使われます。"),
            ]
        }
        return f
    }

    static let commonDW0: [TLPField] = [
        TLPField(dw: 0, hi: 31, lo: 29, name: "Fmt", fullName: "Format",
                 detail: "ヘッダ長とデータの有無。000=3DW/データなし、001=4DW/データなし、010=3DW/データあり、011=4DW/データあり、100=TLP Prefix。"),
        TLPField(dw: 0, hi: 28, lo: 24, name: "Type", fullName: "Type",
                 detail: "Fmtと組み合わせてTLPの種類を決めます。例：00000=メモリ、00100=Config Type0、01010=Completion、10rrr=Message（rrrはルーティング方法）。"),
        TLPField(dw: 0, hi: 23, lo: 23, name: "T9", fullName: "Tag[9]",
                 detail: "10-bit Tag使用時のTagの最上位ビット。"),
        TLPField(dw: 0, hi: 22, lo: 20, name: "TC", fullName: "Traffic Class",
                 detail: "0〜7のトラフィッククラス。ポートでVC（仮想チャネル）にマッピングされ、QoSに使われます。順序規則は同じTC内でのみ適用されます。"),
        TLPField(dw: 0, hi: 19, lo: 19, name: "T8", fullName: "Tag[8]",
                 detail: "10-bit Tag使用時のTagのビット8。"),
        TLPField(dw: 0, hi: 18, lo: 18, name: "A2", fullName: "Attr[2]（IDO）",
                 detail: "ID-Based Orderingビット。送信元が異なるTLP間の順序制約を緩めます。"),
        TLPField(dw: 0, hi: 17, lo: 17, name: "R", fullName: "Reserved（旧LN）",
                 detail: "予約ビット。以前はLN（Lightweight Notification）ビットでしたが、現在の仕様では予約で、別の用途に再割り当てできるようになっています。"),
        TLPField(dw: 0, hi: 16, lo: 16, name: "TH", fullName: "TLP Hints",
                 detail: "1のときTPH（処理ヒント）が有効で、PHフィールドが意味を持ちます。"),
        TLPField(dw: 0, hi: 15, lo: 15, name: "TD", fullName: "TLP Digest",
                 detail: "1のときTLP末尾にECRC（end-to-endのCRC）が付いています。"),
        TLPField(dw: 0, hi: 14, lo: 14, name: "EP", fullName: "Error Poisoned",
                 detail: "1のときデータが壊れていることを示します（Poisoned TLP）。受信側はデータを使ってはいけません。"),
        TLPField(dw: 0, hi: 13, lo: 12, name: "Attr", fullName: "Attr[1:0]",
                 detail: "bit13=Relaxed Ordering、bit12=No Snoop。"),
        TLPField(dw: 0, hi: 11, lo: 10, name: "AT", fullName: "Address Type",
                 detail: "ATS用。00=未変換アドレス、01=変換要求、10=変換済みアドレス。"),
        TLPField(dw: 0, hi: 9, lo: 0, name: "Length", fullName: "Length",
                 detail: "ペイロード長（DW単位）。0は1024DW（4KB）を意味します。データなしのMRdでは要求する読み出し長を示します。"),
    ]

    static let requestDW1: [TLPField] = [
        TLPField(dw: 1, hi: 31, lo: 16, name: "Requester ID", fullName: "Requester ID",
                 detail: "リクエストを出したFunctionのBDF（Bus 8bit / Device 5bit / Function 3bit）。Completionの返送先になります。"),
        TLPField(dw: 1, hi: 15, lo: 8, name: "Tag", fullName: "Tag",
                 detail: "未完了のリクエストを区別する番号。Requester IDとTagの組でCompletionを対応付けます。"),
        TLPField(dw: 1, hi: 7, lo: 4, name: "Last BE", fullName: "Last DW Byte Enables",
                 detail: "最後のDWのうち有効なバイト（ビットごとに1バイト）。1DWの転送では0000にします。"),
        TLPField(dw: 1, hi: 3, lo: 0, name: "1st BE", fullName: "First DW Byte Enables",
                 detail: "最初のDWのうち有効なバイト。例：1111=4バイトすべて、0011=下位2バイト。"),
    ]
}

/// Fmt/Type バイト（ヘッダの Byte 0）をデコードする
enum TLPTypeDecoder {
    static func decode(byte0: UInt8) -> String {
        let fmt = Int(byte0 >> 5) & 0b111
        let type = Int(byte0) & 0b11111
        let hasData = (fmt & 0b010) != 0
        let is4DW = (fmt & 0b001) != 0
        let size = is4DW ? "4DW" : "3DW"

        if fmt == 0b100 { return "TLP Prefix" }
        if fmt > 0b100 { return "予約（不正なFmt）" }

        switch type {
        case 0b00000:
            return hasData ? "MWr（Memory Write, \(size)）" : "MRd（Memory Read, \(size)）"
        case 0b00001:
            return hasData ? "予約" : "MRdLk（ロック付き Memory Read, \(size)）"
        case 0b00010:
            guard !is4DW else { return "予約（I/Oは3DWのみ）" }
            return hasData ? "IOWr（I/O Write）" : "IORd（I/O Read）"
        case 0b00100:
            guard !is4DW else { return "予約（Configは3DWのみ）" }
            return hasData ? "CfgWr0（Config Write Type 0）" : "CfgRd0（Config Read Type 0）"
        case 0b00101:
            guard !is4DW else { return "予約（Configは3DWのみ）" }
            return hasData ? "CfgWr1（Config Write Type 1）" : "CfgRd1（Config Read Type 1）"
        case 0b01010:
            guard !is4DW else { return "予約（Completionは3DWのみ）" }
            return hasData ? "CplD（データ付きCompletion）" : "Cpl（データなしCompletion）"
        case 0b01011:
            guard !is4DW else { return "予約" }
            return hasData ? "CplDLk（ロック付きCplD）" : "CplLk（ロック付きCpl）"
        case 0b01100:
            return hasData ? "FetchAdd（AtomicOp, \(size)）" : "予約"
        case 0b01101:
            return hasData ? "Swap（AtomicOp, \(size)）" : "予約"
        case 0b01110:
            return hasData ? "CAS（AtomicOp, \(size)）" : "予約"
        case 0b11011:
            if hasData { return "DMWr（Deferrable Memory Write, \(size)）" }
            return is4DW ? "予約" : "TCfgRd（廃止されたType。受信側はMalformed TLPとして扱う）"
        case 0b10000...0b10111:
            guard is4DW else { return "予約（Messageは4DW）" }
            let routing = ["Root Complexへ", "アドレスで", "IDで", "RCから全体へブロードキャスト",
                           "受信側で終端（Local）", "RCへ集約（PME_TO_Ack用）", "予約（受信側で終端）", "予約（受信側で終端）"][type & 0b111]
            return (hasData ? "MsgD（データ付きMessage）" : "Msg（Message）") + "・ルーティング：\(routing)"
        default:
            return "予約（未定義のType）"
        }
    }
}
