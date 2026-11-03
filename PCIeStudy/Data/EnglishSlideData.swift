import Foundation

// 「英語で聞く」の追加レッスンのスライド（箱と矢印の並び）
// iPhone は EnglishSlides.swift の SimpleSlideView が、ブラウザ版は content.json の englishSlides から描く
// 矢印の symbol は SF Symbols の名前（ブラウザ版は web/visual.js で記号に置き換える）

struct SimpleSlide {
    enum Cell {
        case box(String, String?, Bool)
        case arrow(String, String?, Bool)
    }

    let rows: [[Cell]]
    let note: String
}


enum SimpleSlides {
    private static func b(_ text: String, _ detail: String? = nil, _ on: Bool) -> SimpleSlide.Cell { .box(text, detail, on) }
    private static func a(_ symbol: String, _ label: String? = nil, _ on: Bool) -> SimpleSlide.Cell { .arrow(symbol, label, on) }

    static func slide(lessonID: String, index i: Int) -> SimpleSlide? {
        switch lessonID {
        case "en-intro":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 1: rows = [[b("PCI", "8本を並べて同時に", false), a("arrow.right", nil, true), b("PCIe", "1本ずつ順に（シリアル）", true)]]
            case 2: rows = [[b("デバイス A", nil, true), a("arrow.left.arrow.right", "送信と受信を同時に", true), b("デバイス B", nil, true)]]
            case 3: rows = [[b("x1", nil, false), b("x4", nil, true), b("x16", nil, true)]]
            case 4: rows = [[b("新しいカード", nil, true), a("arrow.right", nil, true), b("古いスロット", "遅い速度で動く", true)]]
            case 5: rows = [[b("ソフトウェア", nil, true), a("arrow.right", "PCI と同じに見える", true), b("PCIe の機器", nil, true)]]
            default: rows = [[b("CPU", nil, true), a("arrow.left.arrow.right", "PCIe", true), b("GPU ・ SSD", nil, true)]]
            }
            return SimpleSlide(rows: rows, note: ["PCIe ＝ 機器を CPU につなぐ高速な道", "PCI は並列、PCIe はシリアル", "1レーンで送受信を同時に（全二重）", "レーンを束ねて速くする", "後方互換：古いスロットでも動く", "ソフトからは PCI とほぼ同じ"][i])
        case "en-generations":
            let gens: [(String, String)] = [("1.0", "2.5"), ("2.0", "5"), ("3.0", "8"), ("4.0", "16"), ("5.0", "32"), ("6.0", "64"), ("7.0", "128")]
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 2: rows = [[b("GT/s", "生の転送回数", true), a("arrow.right", "符号化を引く", true), b("GB/s", "実際のデータ", true)]]
            case 3: rows = [[b("Gen5 x16", nil, true), a("arrow.right", "片方向", true), b("約 63 GB/s", nil, true)]]
            case 5: rows = [[b("Gen5 対応", nil, true), a("arrow.left.arrow.right", "両方の最高", true), b("Gen4 対応", nil, true)], [b("Gen4 で動く", nil, true)]]
            default:
                let on: (Int) -> Bool = { n in i == 0 || (i == 1 && (n == 0 || n == 4)) || (i == 4 && n >= 5) }
                rows = [gens.prefix(4).enumerated().map { b("PCIe \($1.0)", "\($1.1) GT/s", on($0)) },
                        gens.suffix(3).enumerated().map { b("PCIe \($1.0)", "\($1.1) GT/s", on($0 + 4)) }]
            }
            return SimpleSlide(rows: rows, note: ["世代ごとにおよそ2倍", "1.0 は 2.5 GT/s、5.0 は 32 GT/s", "GT/s は符号化の前の数", "Gen5 x16 は片方向で約 63 GB/s", "6.0 は 64、7.0 は 128 GT/s", "両側が対応するいちばん速い速度で動く"][i])
        case "en-power":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 3, 4: rows = [["D0", "D1", "D2", "D3hot", "D3cold"].map { b($0, $0 == "D0" ? "完全に動く" : $0 == "D3cold" ? "電源なし" : nil, i == 3 ? $0 == "D0" : $0 == "D3cold") }]
            case 5: rows = [[b("L1", nil, false), a("arrow.right", nil, true), b("L1.1", nil, true), a("arrow.right", nil, true), b("L1.2", "さらに省電力", true)]]
            default: rows = [[b("L0", "ふつう", i == 0), a("arrow.right", "暇になったら", i == 1), b("L0s", "すぐ起きる", i == 1 || i == 2), b("L1", "もっと節約", i == 1 || i == 2)]]
            }
            return SimpleSlide(rows: rows, note: ["使っていないときに電力を節約", "ASPM：暇なら自分で L0s / L1 へ", "L1 は節約できるが起きるのが遅い", "機器の電源状態 D0〜D3（D0 が動作中）", "D3cold は電源が切れる → 設定し直し", "L1 サブステートでさらに節約（ノート PC）"][i])
        case "en-ordering":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 1: rows = [[b("書き込み 2", nil, true), a("xmark", "追い越せない", true), b("書き込み 1", nil, true)]]
            case 2: rows = [[b("読み出し", nil, true), a("xmark", "追い越せない", true), b("書き込み", "先に出た", true)], [b("新しいデータが返る", nil, true)]]
            case 3: rows = [[b("書き込み", nil, true), a("checkmark", "追い越せる", true), b("読み出し", nil, true)], [b("デッドロックを防ぐ", nil, true)]]
            case 4, 5: rows = [[b("TLP", "Relaxed Ordering", true), a("arrow.right", "順序は要らない", true), b("速く処理", nil, i == 5)]]
            default: rows = [[b("1", nil, true), a("arrow.right", nil, true), b("2", nil, true), a("arrow.right", nil, true), b("3", nil, true)]]
            }
            return SimpleSlide(rows: rows, note: ["ソフトが期待する順番を守る", "posted の書き込みどうしは追い越さない", "読み出しは前の書き込みを追い越さない", "書き込みは読み出しを追い越せる", "Relaxed Ordering：順序をゆるめる", "関係のないデータなら速くなる"][i])
        case "en-errors":
            let rows: [[SimpleSlide.Cell]] = [
                [b("訂正可能", "ハードが直す", [0, 1].contains(i)), b("訂正不可能", nil, [0, 2, 3, 4].contains(i))],
                i >= 2 && i <= 4 ? [b("致命的でない", "1つの通信だけ", i == 2 || i == 3), b("致命的", "信頼できない", i == 2 || i == 4)] : [],
                i == 5 ? [b("AER", "くわしい記録", true), a("arrow.right", nil, true), b("レジスタ", nil, true)] : [],
            ].filter { !$0.isEmpty }
            return SimpleSlide(rows: rows, note: ["エラーは2種類", "訂正可能：再送などで直る", "訂正不可能は「致命的でない」か「致命的」", "致命的でない：リンクは動き続ける", "致命的：リンクや機器を信頼できない", "AER がエラーの中身を記録する"][i])
        case "en-qos":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 0: rows = [(0...7).map { b("TC\($0)", nil, true) }]
            case 1, 2, 3: rows = [[b("TC0〜6", nil, true), a("arrow.right", nil, true), b("VC0", "バッファ ・ クレジット", true)],
                                  [b("TC7", i == 3 ? "音声など" : nil, true), a("arrow.right", i == 2 || i == 3 ? "待たずに進む" : nil, true), b("VC1", "バッファ ・ クレジット", true)]]
            case 4: rows = [[b("多くの機器", nil, true), a("arrow.right", nil, true), b("VC0 だけ", nil, true)]]
            default: rows = [[b("TC0 の中", "順序あり", true), b("TC0 と TC1 の間", "順序なし", false)]]
            }
            return SimpleSlide(rows: rows, note: ["TLP は TC（0〜7）を持つ", "TC を VC に割り当てる", "VC が違えば待たない", "時間に厳しいデータを先に", "多くの機器は VC0 だけ", "順序のきまりは同じ TC の中だけ"][i])
        case "en-sriov":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 4: rows = [[b("VF1", "ID 01:00.1", true), b("VF2", "ID 01:00.2", true)], [b("IOMMU", "VM ごとに分ける", true)]]
            case 5: rows = [[b("機器", nil, true), a("arrow.right", "先に聞く", true), b("変換", "キャッシュ", true)]]
            default: rows = [[b("PF", "ホストのドライバ", [0, 1].contains(i)), b("VF1", nil, i != 1), b("VF2", nil, i != 1)],
                             [b("ホスト", nil, i == 1), b("VM1", i == 3 ? "直接" : nil, i >= 2), b("VM2", i == 3 ? "直接" : nil, i >= 2)]]
            }
            return SimpleSlide(rows: rows, note: ["1つの機器を、多くの機器に見せる", "PF ＝ ホストが管理する本体", "VF ＝ VM に直接渡す軽い機能", "直接やりとり → コピーが要らない", "VF ごとの ID で VM を分ける", "ATS：アドレス変換を先に聞いておく"][i])
        case "en-equalization":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 0: rows = [[b("送信", "くっきり", true), a("arrow.right", "基板", true), b("受信", "ぼやける", true)]]
            case 3, 4: rows = [[b("送信側", "プリセット", true), a("arrow.left.arrow.right", i == 4 ? "よくなるまで試す" : "設定をやりとり", true), b("受信側", nil, true)]]
            case 5: rows = [[b("送信", nil, true), a("arrow.right", nil, true), b("リタイマ", "作り直す", true), a("arrow.right", nil, true), b("受信", nil, true)]]
            default: rows = [[b("送信側", "調整", true), a("arrow.right", nil, true), b("受信側", "調整", true)], [b("8 GT/s から", "立ち上げの途中で", i == 2)]]
            }
            return SimpleSlide(rows: rows, note: ["速いと信号が弱く・ぼやける", "送信側と受信側を調整する", "8 GT/s からは立ち上げの途中で", "おすすめの設定 ＝ プリセット", "よく見えるまで設定を試す", "リタイマが途中で作り直す"][i])
        case "en-mps":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 1: rows = [[b("RC", "512 B", true), a("arrow.right", nil, true), b("Switch", "256 B", true), a("arrow.right", nil, true), b("SSD", "512 B", true)], [b("全員が対応する 256 B", nil, true)]]
            case 2: rows = [[b("Header", nil, false), b("Data 128 B", nil, true)], [b("Header", nil, false), b("Data 512 B ・ 効率がよい", nil, true)]]
            case 3, 4, 5: rows = [[b("Read 4 KB", "MRRS まで", i == 3)], [a("arrow.down", i == 5 ? "境目で区切る" : nil, true)],
                                 [b("Cpl", nil, i >= 4), b("Cpl", nil, i >= 4), b("Cpl", nil, i >= 4), b("Cpl", nil, i >= 4)]]
            default: rows = [[b("Header", nil, false), b("Data", "MPS まで", true)]]
            }
            return SimpleSlide(rows: rows, note: ["MPS ＝ 1つの TLP のデータの上限", "経路の全員が対応する値にそろえる", "大きいほどヘッダの割合が減る", "MRRS ＝ 1回の読み出しの上限", "大きな読み出しは何回かに分けて返る", "分けるときは RCB の境目で"][i])
        case "en-pcie7":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 1: rows = [[b("PAM4", "そのまま", true), b("Flit Mode", "そのまま", true)]]
            case 2: rows = [[b("x16", nil, true), a("arrow.left.arrow.right", "両方向", true), b("約 512 GB/s", nil, true)]]
            case 3: rows = [[b("AI", nil, true), b("データセンター", nil, true), b("ネットワーク", nil, true)]]
            case 4: rows = [[b("電気", "近く", false), a("arrow.right", nil, true), b("光", "遠くまで", true)]]
            case 5: rows = [[b("2025 年", "仕様を公開", true)]]
            default: rows = [[b("PCIe 6.0", "64 GT/s", false), a("arrow.right", "2倍", true), b("PCIe 7.0", "128 GT/s", true)]]
            }
            return SimpleSlide(rows: rows, note: ["PCIe 7.0 は 128 GT/s", "PAM4 とフリットは 6.0 と同じ", "x16 で両方向約 512 GB/s", "AI ・ データセンター向け", "光の接続も検討中", "2025 年に会員へ公開"][i])
        case "en-128gt":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 1: rows = [[b("64.0 GT/s", "32 GBaud", false), a("arrow.right", "シンボルレート×2", true), b("128.0 GT/s", "64 GBaud", true)], [b("PAM4 ・ 1b/1b ・ フリットは同じ", nil, true)]]
            case 2, 3: rows = [[b("64.0 GT/s 以上", nil, true), a("arrow.right", nil, true), b("いつもフリットモード", i == 3 ? "Ordered Set も PAM4" : nil, true)]]
            case 4: rows = [[b("フリット", nil, true), a("arrow.right", nil, true), b("CRC", "まず", true), a("arrow.right", nil, true), b("FEC", "次に", true)]]
            case 5: rows = [[b("スクランブル", nil, true), a("arrow.right", nil, true), b("グレイ符号", nil, true), a("arrow.right", nil, true), b("プリコード", "必要なら", true), a("arrow.right", nil, true), b("PAM4", nil, true)]]
            default: rows = [[b("PCIe 6.x", "64 GT/s", false), a("arrow.right", nil, true), b("PCIe 7.0", "128 GT/s を足した", true)]]
            }
            return SimpleSlide(rows: rows, note: ["7.0 の新機能 ＝ 128 GT/s のための仕組み", "シンボルレートだけ2倍", "64 GT/s 以上はいつもフリット", "Ordered Set も PAM4 で送る", "CRC → FEC の順に付ける", "レーンごとに 4 段階で変換"][i])
        case "en-eq7":
            let speeds = ["8.0", "16.0", "32.0", "64.0", "128.0"]
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 3: rows = [[b("2.5 GT/s", nil, true), a("xmark", "直接は行けない", true), b("64.0 / 128.0", nil, true)]]
            case 4: rows = [[b("128.0 で動作中", nil, true), a("xmark", "やり直せない", true), b("128.0 の EQ", nil, true)]]
            case 5: rows = [[b("8.0", "飛ばす", false), b("16.0", "飛ばす", false), b("32.0", "ここから", true), b("64.0", nil, true), b("128.0", nil, true)]]
            default:
                let on: (Int) -> Bool = { n in i == 0 || (i == 1 && n >= 3) || (i == 2 && (n == 2 || n == 3)) }
                rows = [speeds.enumerated().flatMap { n, sp -> [SimpleSlide.Cell] in
                    n == 0 ? [b(sp, nil, on(n))] : [a("arrow.right", nil, on(n)), b(sp, nil, on(n))]
                }]
            }
            return SimpleSlide(rows: rows, note: ["1つの速度ずつ順に", "128.0 の EQ は 64.0 から", "64.0 の EQ は 32.0 から", "2.5 から直接は飛べない", "128.0 で動作中はやり直せない", "両端が対応なら 32.0 から始められる"][i])
        case "en-ffe":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 0, 1: rows = [[b("c-2", "新しい", i == 1), b("c-1", nil, true), b("c0", nil, true), b("c+1", nil, true)]]
            case 2, 3: rows = [[b("CTLE", nil, true), a("arrow.right", nil, true), b("DFE", "64 GT/s まで", true)]]
            default: rows = [[b("CTLE", nil, false), a("arrow.right", nil, true), b("FFE", i == 5 ? "29 タップ" : "大部分を担う", true), a("arrow.right", nil, true), b("DFE", "1 タップ", false)]]
            }
            return SimpleSlide(rows: rows, note: ["送信 FIR は 3 → 4 タップ", "増えたのはプレカーソル c-2", "参照受信器も大きく変わる", "64 GT/s までは CTLE ＋ DFE", "128 GT/s は FFE が主役", "FFE は 29 タップ"][i])
        case "en-precoding":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 5: rows = [[b("ソフトウェア", nil, true), a("arrow.right", "確かめる", true), b("Precoding On", "ビット", true)]]
            default: rows = [[b("受信側", nil, true), a("arrow.right", i == 2 || i == 4 ? "EQ TS2 で頼む" : "プリコードして", true), b("送信側", nil, true)],
                             [b(i == 1 ? "速度ごとに別々" : i == 3 ? "速度を変える前に" : i == 4 ? "128 GT/s は 1b/1b 版" : "32 GT/s 以上", nil, true)]]
            }
            return SimpleSlide(rows: rows, note: ["32 GT/s 以上で受信側が頼める", "データレートごとに別々", "EQ TS2 のビットで頼む", "切り替わる前に頼む", "128 GT/s は 1b/1b の EQ TS2", "有効かはステータスで確認"][i])
        case "en-halfflit":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 2: rows = [[b("受信側", nil, true), a("arrow.right", "Data Link Feature DLLP", true), b("送信側", nil, true)]]
            case 5: rows = [[b("前半", "TLP ・ TLP ・ TLP の頭", true), b("後半", "TLP の残り", true)], [b("途中まででも 1 個", nil, true)]]
            default: rows = [[b("前半", "0〜127", true), b("後半", "128〜235", true)],
                             [b(i == 3 ? "8 個まで" : i == 4 ? "4 個まで（128 GT/s 以上）" : "それぞれ上限あり", nil, i >= 1)]]
            }
            return SimpleSlide(rows: rows, note: ["TLP 領域 236 B を前半・後半に", "半分ごとに TLP の数の上限", "受信側が DLLP で伝える", "設定 00b：8 個まで", "設定 01b：4 個まで", "一部だけ入った TLP も 1 個"][i])
        case "en-regs7":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 1, 2: rows = [[b("bit 5", "64.0", false), b("bit 6", "128.0 以上", true)], [b("Vector 2", "bit 0 = 128.0", i == 2)]]
            case 3: rows = [[b("0110b", "64.0", false), b("0111b", "予約", false), b("1000b", "128.0", true)]]
            case 4: rows = [[b("Capabilities", nil, true), b("Control", nil, true), b("Status", nil, true)]]
            case 5: rows = [[b("128.0 のパリティ", nil, true), a("arrow.right", nil, true), b("16.0 GT/s の", "今までのレジスタ", true)]]
            default: rows = [[b("ソフトウェア", nil, true), a("arrow.right", nil, true), b("拡張されたレジスタ", nil, true)]]
            }
            return SimpleSlide(rows: rows, note: ["新しい速度はレジスタで見える", "bit 6 ＝ 128.0 GT/s 以上", "くわしくは Vector 2", "Current Link Speed 1000b ＝ 128.0", "128.0 GT/s 用の Capability", "パリティは 16.0 GT/s のレジスタに"][i])
        case "en-new6x":
            let rows: [[SimpleSlide.Cell]] = [
                [b("UIO", "順序なしの VC", [0, 1, 2].contains(i)), b("TDISP", "TEE に安全に", i == 0 || i == 3), b("SIOV", "SR-IOV の後継", i == 0 || i == 4)],
                i == 5 ? [b("7.1", "認証に耐量子暗号", true)] : [],
            ].filter { !$0.isEmpty }
            return SimpleSlide(rows: rows, note: ["7.0 は 6.x の機能をすべて含む", "UIO：順序のきまりに従わない", "UIO の要求は必ず Completion", "TDISP：機密計算に安全に割り当て", "SIOV：SR-IOV の後継", "7.1：耐量子暗号の認証"][i])
        case "en-flit":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 3: rows = [[b("フリット", "まるごと再送", true)], [b("TLP ごとの LCRC", "要らない", false), b("Seq 番号", "要らない", false)]]
            case 4: rows = [[b("新しいヘッダ形式", nil, true), b("Tag 14 ビット", nil, true)]]
            case 5: rows = [[b("Gen6 どうし", nil, true), a("arrow.right", nil, true), b("低い速度でもフリット", nil, true)]]
            default: rows = [[b("TLP", "236 B", i <= 1), b("DLP", "6 B", i == 0 || i == 2), b("CRC", "8 B", i == 0 || i == 2), b("FEC", "6 B", i == 0 || i == 2)]]
            }
            return SimpleSlide(rows: rows, note: ["フリットは 256 B", "236 B で TLP を運ぶ", "DLP 6 ・ CRC 8 ・ FEC 6", "再送はフリット単位", "ヘッダが新しくなり Tag は 14 ビット", "Gen6 どうしなら低速でもフリット"][i])
        case "en-l0p":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 2, 3: rows = [[b("x16", nil, true), a("arrow.right", i == 3 ? "通信は流れたまま" : "暇なとき", true), b("x4", nil, true)]]
            case 4: rows = [[b("L0s", "フリットでは使えない", false), a("arrow.right", nil, true), b("L0p", "代わりに", true)]]
            default: rows = [[b("L0p", "PCIe 6.0 から", true), a("arrow.right", nil, true), b("レーンを減らす", "止めずに", i == 1)]]
            }
            return SimpleSlide(rows: rows, note: ["L0p ＝ 6.0 の省電力", "止めずにレーンを減らす", "x16 → x4 など", "幅を変えても流れ続ける", "フリットでは L0s の代わり", "忙しさが変わるサーバで節約"][i])
        case "en-cxl":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 0, 1: rows = [[b("CXL", nil, true)], [a("arrow.down", i == 1 ? "トレーニングで決める" : nil, true)], [b("PCIe の物理層", "同じスロット", true)]]
            case 5: rows = [[b("PCIe 6.x", "64 GT/s ・ フリット", true), a("arrow.right", "もとにする", true), b("CXL 3.x", nil, true)]]
            default: rows = [[b("CXL.io", "列挙 ・ DMA", i == 2), b("CXL.cache", "ホストのメモリを", i == 3), b("CXL.mem", "機器のメモリを", i == 4)]]
            }
            return SimpleSlide(rows: rows, note: ["CXL は PCIe の物理層の上で動く", "同じスロット、トレーニングで決める", "CXL.io ＝ PCIe と同じ働き", "CXL.cache：ホストのメモリをキャッシュ", "CXL.mem：機器のメモリをふつうに使う", "CXL 3.x は PCIe 6.x がもと"][i])
        case "en-iommu":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 4, 5: rows = [[b("機器 A", nil, true), a(i == 4 ? "arrow.left.arrow.right" : "xmark", i == 4 ? "直接" : "直接はだめ", true), b("機器 B", nil, true)],
                               i == 5 ? [b("ACS", nil, true), a("arrow.right", "上へ", true), b("RC ・ IOMMU", "確かめる", true)] : []]
            default: rows = [[b("機器", i == 1 ? "ATC にキャッシュ" : i == 3 ? "PASID ごと" : nil, true), a("arrow.right", "DMA", true),
                              b("IOMMU", i == 2 ? "ページを用意（PRI）" : "アドレスを変換", true), a("arrow.right", nil, true), b("メモリ", "VM ごとに守る", i == 0)]]
            }
            return SimpleSlide(rows: rows.filter { !$0.isEmpty }, note: ["IOMMU：DMA のアドレスを変換して守る", "ATS：変換を機器にキャッシュ", "PRI：ページがなければ頼む", "PASID：複数のアドレス空間", "スイッチの下は機器どうし直接", "ACS：上へ回して IOMMU が確認"][i])
        case "en-ari":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 0: rows = [[b("Device 5 ビット", nil, false), b("Function 3 ビット", "8 個まで", true)]]
            case 1, 2, 3: rows = [[b("Device 5 ビット", nil, true), a("arrow.left.arrow.right", "合わせる", true), b("Function 3 ビット", nil, true)], [b("Function 8 ビット", i == 3 ? "256 個まで" : nil, i >= 2)]]
            case 4: rows = [[b("PF", nil, true), b("VF", nil, true), b("VF", nil, true), b("VF …", "たくさん", true)]]
            default: rows = [[b("PF", "sriov_numvfs", true), a("arrow.right", "数を変える", true), b("VF", nil, true)]]
            }
            return SimpleSlide(rows: rows, note: ["ふつうは Function 8 個まで", "ARI：Device と Function を合わせる", "8 ビットの Function 番号", "最大 256 Function", "VF をたくさん作る機器に必要", "VF の数は PF で変える"][i])
        case "en-msix":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 2, 3: rows = [[b("ベクタ 0", nil, true), b("ベクタ 1", nil, true), b("ベクタ 2", nil, true)], [b("CPU 0", nil, true), b("CPU 1", nil, true), b("CPU 2", nil, true)]]
            case 4: rows = [[b("MSI", "32 個まで", false), b("MSI-X", "2048 個まで", true)]]
            case 5: rows = [[b("データの書き込み", nil, false), a("arrow.right", "追い越さない", true), b("MSI-X の書き込み", nil, true)]]
            default: rows = [[b("アドレス", nil, i == 0), b("データ", nil, i == 0), b("マスク", nil, i == 0)], [b("BAR の中", "テーブル ・ PBA", i == 1)]]
            }
            return SimpleSlide(rows: rows, note: ["ベクタごとにアドレス・データ・マスク", "テーブルと PBA は BAR の中", "ベクタごとに別の CPU へ", "マルチキューの NIC ・ NVMe に必須", "MSI は 32、MSI-X は 2048", "ただの書き込み → 順序のきまりどおり"][i])
        case "en-wake":
            let rows: [[SimpleSlide.Cell]]
            switch i {
            case 3: rows = [[b("L1", nil, false), a("arrow.right", nil, true), b("L1.2", "検出回路まで止める", true)]]
            case 4, 5: rows = [[b("機器", "LTR", true), a("arrow.right", "許せる遅れ", true), b("プラットフォーム", i == 5 ? "深さを決める" : nil, true)]]
            default: rows = [[b("D3 の機器", nil, true), a("arrow.right", i == 1 ? "PM_PME メッセージ" : i == 2 ? "WAKE# ・ ビーコン" : "PME", true), b("システム", "起きる", true)]]
            }
            return SimpleSlide(rows: rows, note: ["PME でシステムを起こす", "リンクがあれば PM_PME", "止まっていれば WAKE#", "L1.2 は検出回路まで止める", "LTR：許せる遅れを伝える", "節約と起きる時間は引き換え"][i])
        default:
            return nil
        }
    }

    /// ブラウザ版に書き出すため、スライドのあるレッスンをすべて並べる
    static func all(lessonIDs: [String], count: (String) -> Int) -> [String: [SimpleSlide]] {
        var result: [String: [SimpleSlide]] = [:]
        for id in lessonIDs {
            let slides = (0..<count(id)).compactMap { slide(lessonID: id, index: $0) }
            if slides.count == count(id) { result[id] = slides }
        }
        return result
    }
}
