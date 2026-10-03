import Foundation

/// 仕様書（PCIe Base Specification 7.1）の参照先
struct SpecRef: Hashable {
    let section: String
    let title: String
    let page: Int

    /// 「§4.2.7 Polling」のような表示用の名前（章番号がないときは § を付けない）
    var label: String {
        section.first?.isNumber == true ? "§\(section) \(title)" : "\(section)：\(title)"
    }
}

struct QuizQuestion: Identifiable, Hashable {
    let id: String
    let chapterID: String
    let question: String
    let choices: [String]
    let answer: Int          // choices の正解インデックス
    let explanation: String
    /// 選択肢ごとの解説（choices と同じ順番。空文字は解説なし）
    var choiceNotes: [String] = []
    var spec: SpecRef? = nil

    /// 「わからない」を選んだときの回答番号
    static let unknownChoice = -1

    func note(for index: Int) -> String? {
        guard choiceNotes.indices.contains(index), !choiceNotes[index].isEmpty else { return nil }
        return choiceNotes[index]
    }

    /// 選択肢の順番をシャッフルしたコピーを返す（正解インデックスと選択肢ごとの解説も追従）
    func shuffled() -> QuizQuestion {
        let order = Array(choices.indices).shuffled()
        var copy = QuizQuestion(id: id, chapterID: chapterID, question: question,
                                choices: order.map { choices[$0] },
                                answer: order.firstIndex(of: answer) ?? answer,
                                explanation: explanation, spec: spec)
        if choiceNotes.count == choices.count {
            copy.choiceNotes = order.map { choiceNotes[$0] }
        }
        return copy
    }
}

enum QuizData {
    static func questions(forChapter id: String) -> [QuizQuestion] {
        all.filter { $0.chapterID == id }
    }

    static func questions(forLevel level: Level) -> [QuizQuestion] {
        let ids = Set(LessonData.all.filter { $0.level == level }.map(\.id))
        return all.filter { ids.contains($0.chapterID) }
    }

    static func random(_ count: Int) -> [QuizQuestion] {
        Array(all.shuffled().prefix(count))
    }

    static func questions(ids: Set<String>) -> [QuizQuestion] {
        all.filter { ids.contains($0.id) }
    }

    static func q(_ id: String, _ chapter: String, _ question: String,
                          _ choices: [String], _ answer: Int, _ explanation: String) -> QuizQuestion {
        QuizQuestion(id: id, chapterID: chapter, question: question,
                     choices: choices, answer: answer, explanation: explanation)
    }

    /// 選択肢ごとの解説と仕様書の参照先を付けた全問題
    static let all: [QuizQuestion] = (core + extra).map { q in
        guard let n = QuizNotes.byID[q.id] else { return q }
        var copy = q
        if n.choices.count == q.choices.count { copy.choiceNotes = n.choices }
        copy.spec = n.spec
        return copy
    }

    private static let core: [QuizQuestion] = [
        // 1. PCIeとは
        q("intro-1", "intro", "PCIeの1レーンを構成する信号線はどれ？",
          ["送信用差動ペア1組のみ", "送信用と受信用の差動ペア各1組", "送受信兼用のシングルエンド線2本", "32本のパラレル線"],
          1, "1レーンは送信用・受信用それぞれの差動ペア（計4本）で構成され、全二重で通信します。"),
        q("intro-2", "intro", "旧PCIと比べたPCIeの特徴として誤っているものは？",
          ["ポイントツーポイント接続", "全二重通信", "共有バスで複数デバイスが帯域を分け合う", "クロックをデータに埋め込む"],
          2, "共有バスはPCIの特徴です。PCIeは各リンクを1対1で専有します。"),
        q("intro-3", "intro", "「GT/s」が表すものは？",
          ["符号化後の実データ速度", "1秒あたりの転送（ビット）回数で、符号化オーバーヘッドを含む", "1秒あたりのパケット数", "リンク全体の双方向合計帯域"],
          1, "GT/sは生の転送レートです。実データ速度は符号化効率やレーン数を掛けて求めます。"),

        // 2. トポロジ
        q("topo-1", "topology", "BDFのDevice番号は何ビット？",
          ["3ビット", "5ビット", "8ビット", "16ビット"],
          1, "Bus 8ビット、Device 5ビット、Function 3ビットの計16ビットです。"),
        q("topo-2", "topology", "CPU・メモリとPCIe階層をつなぐ根の部分を何と呼ぶ？",
          ["Endpoint", "Switch", "Root Complex", "Retimer"],
          2, "Root Complex（RC）がツリーの根で、ルートポートを通じて下流のデバイスにつながります。"),
        q("topo-3", "topology", "ARIを有効にすると、1デバイスで使えるFunction数の上限は？",
          ["8", "32", "256", "4096"],
          2, "ARIはDevice番号の5ビットもFunction番号に使い、8ビット＝最大256 Functionを扱えます。"),
        q("topo-4", "topology", "スイッチはソフトウェアからどのように見える？",
          ["1つのEndpoint", "複数の仮想PCI-PCIブリッジの集合", "Root Complexの一部", "見えない（透過）"],
          1, "スイッチの各ポートはType 1ヘッダを持つ仮想ブリッジとして列挙されます。"),

        // 3. 世代
        q("gen-1", "generations", "Gen3で採用された符号化方式は？",
          ["8b/10b", "64b/66b", "128b/130b", "PAM4 + FLIT"],
          2, "Gen3〜Gen5は128b/130bです。2ビットのSync Headerを付けるだけなので効率は約98.5%です。"),
        q("gen-2", "generations", "Gen4 x4 リンクの片方向の実効帯域に最も近いのは？",
          ["約2 GB/s", "約4 GB/s", "約7.9 GB/s", "約16 GB/s"],
          2, "16 GT/s × 128/130 × 4レーン ÷ 8 ≒ 7.88 GB/s です。"),
        q("gen-3", "generations", "8b/10b符号化の効率は？",
          ["50%", "80%", "98.5%", "100%"],
          1, "8ビットのデータを10ビットで送るので80%です。Gen1/Gen2で使われます。"),
        q("gen-4", "generations", "Gen5のカードをGen3のスロットに挿すとどうなる？",
          ["動作しない", "Gen3の速度で動作する", "Gen5の速度で動作する", "x1でのみ動作する"],
          1, "リンクは両端が対応する最高速度で動作するため、Gen3で動きます（後方互換）。"),

        // 4. レイヤ
        q("layer-1", "layers", "ACK/NAKによる再送を担当する層は？",
          ["トランザクション層", "データリンク層", "物理層", "アプリケーション層"],
          1, "データリンク層がシーケンス番号とLCRCを付け、ACK/NAKで再送を管理します。"),
        q("layer-2", "layers", "スイッチを越えて送信元から宛先まで届くパケットは？",
          ["TLP", "DLLP", "Ordered Set", "すべて"],
          0, "DLLPとOrdered Setは隣接ポート間（1リンク）でのみやり取りされます。"),
        q("layer-3", "layers", "ECRCとLCRCの違いとして正しいものは？",
          ["ECRCはリンクごとに付け直される", "LCRCはend-to-endで保護する", "ECRCはend-to-end、LCRCは1リンク区間を保護する", "どちらも物理層が付加する"],
          2, "LCRCはリンクごとにデータリンク層が付け直し、ECRC（任意）はトランザクション層が付けて宛先まで変わりません。"),

        // 5. TLP
        q("tlp-1", "tlp", "Posted Requestに該当するのは？",
          ["Memory Read", "Memory Write", "Configuration Write", "I/O Write"],
          1, "Memory WriteとMessageはPostedで、Completionを返しません。IOWr・CfgWrはNon-Postedです。"),
        q("tlp-2", "tlp", "TLPヘッダのLengthフィールドが0のとき、ペイロード長は？",
          ["0バイト", "1DW", "1024DW（4KB）", "不正なTLP"],
          2, "Lengthは10ビットのDW単位で、0は1024DW＝4096バイトを意味します。"),
        q("tlp-3", "tlp", "64ビットアドレスのMemory Writeのヘッダサイズは？",
          ["3DW（12バイト）", "4DW（16バイト）", "5DW（20バイト）", "8DW（32バイト）"],
          1, "64ビットアドレスでは4DWヘッダを使います（Fmt=011）。"),
        q("tlp-4", "tlp", "CompletionとRequestを対応付けるのに使うフィールドは？",
          ["TCとAttr", "Requester IDとTag", "Byte Enable", "Address"],
          1, "Completionには元のRequester IDとTagが入っており、これで対応付けます。"),
        q("tlp-5", "tlp", "Completion Status「UR」の意味は？",
          ["Unsupported Request", "Unknown Receiver", "Update Required", "Unrecoverable Retry"],
          0, "UR（Unsupported Request）は、応答側がそのリクエストをサポートしていないことを示します。"),
        q("tlp-6", "tlp", "リクエストについて守るべきアドレス境界のルールは？",
          ["1KB境界をまたがない", "4KB境界をまたがない", "64KB境界をまたがない", "制約はない"],
          1, "メモリリクエストは4KBのアドレス境界をまたいではいけません。"),

        // 6. データリンク層
        q("dll-1", "datalink", "TLPに付くシーケンス番号のビット数は（Gen1〜5）？",
          ["8ビット", "10ビット", "12ビット", "16ビット"],
          2, "12ビットのシーケンス番号（0〜4095）が使われます。"),
        q("dll-2", "datalink", "NAKを受けた送信側の動作は？",
          ["エラーのTLPだけ再送する", "NAKの番号より後のTLPをすべて再送する", "リンクをリセットする", "何もしない"],
          1, "Go-Back-N方式で、NAKが示す番号より後のTLPをリプレイバッファから順に再送します。"),
        q("dll-3", "datalink", "再送を繰り返してREPLAY_NUMがロールオーバーするとどうなる？",
          ["TLPを破棄する", "物理層がRecoveryに入りリンクを再トレーニングする", "システムがリセットされる", "速度が自動的にGen1固定になる"],
          1, "REPLAY_NUMは4回目の再送のタイミングでロールオーバーします。データリンク層は物理層にリンクの再トレーニングを要求し（LTSSMはRecoveryへ）、終わってから再送を続けます。"),
        q("dll-4", "datalink", "ACK DLLPが途中で壊れて届かなかった場合、どう回復する？",
          ["回復できない", "REPLAY_TIMERの満了で送信側が再送し、受信側は重複を捨ててACKを返す", "受信側がNAKを送る", "物理層がTLPを再生成する"],
          1, "REPLAY_TIMERが満了すると再送が起き、受信側は既に受けたシーケンス番号を重複として破棄しACKを返します。"),

        // 7. フロー制御
        q("fc-1", "flowcontrol", "データクレジット1単位は何バイト？",
          ["4バイト", "16バイト", "64バイト", "256バイト"],
          1, "データクレジット1は4DW＝16バイトです。"),
        q("fc-2", "flowcontrol", "256バイトのMemory Writeが消費するクレジットは？",
          ["PH 1, PD 16", "PH 1, PD 64", "NPH 1, NPD 16", "PH 16, PD 1"],
          0, "MWrはPosted。ヘッダ1個でPH 1、256÷16=16でPD 16です。"),
        q("fc-3", "flowcontrol", "InitFCで初期クレジット値0を通知した場合の意味は？",
          ["送信禁止", "無限クレジット", "後で通知する", "エラー"],
          1, "0は無限クレジットを意味します。エンドポイントはCompletionに無限クレジットを通知します。"),
        q("fc-4", "flowcontrol", "クレジット方式のフロー制御の利点は？",
          ["受信バッファのあふれでTLPが捨てられない", "レイテンシがゼロになる", "CRCが不要になる", "リンク幅が広がる"],
          0, "送信前に受信側の空きを確認できるため、バッファオーバーフローによる破棄が起きません。"),

        // 8. 物理層
        q("phy-1", "physical", "クロック周波数の差を吸収するためのOrdered Setは？",
          ["TS1", "SKP", "EIOS", "FTS"],
          1, "SKP Ordered Setの長さを調整することで、両端のクロック周波数の差（SRNSで最大600ppm、SRISではさらに大きい）を吸収します。"),
        q("phy-2", "physical", "128b/130bのSync Header「01b」が示すのは？",
          ["Data Block", "Ordered Set Block", "エラー", "アイドル"],
          1, "10bがData Block、01bがOrdered Set Blockです。"),
        q("phy-3", "physical", "スクランブルを行う主な目的は？",
          ["暗号化", "エラー訂正", "ビット列の偏りを減らしEMIとCDRロック喪失を防ぐ", "圧縮"],
          2, "LFSRとのXORでビット列をランダム化し、スペクトル集中と長い連続を防ぎます。暗号ではありません。"),
        q("phy-4", "physical", "PCIeのリファレンスクロックの周波数は？",
          ["25 MHz", "100 MHz", "125 MHz", "250 MHz"],
          1, "PCIeのリファレンスクロックは100 MHzです。"),

        // 9. LTSSM
        q("ltssm-1", "ltssm", "リンクが最初にL0に到達するときの速度は？",
          ["常にGen1（2.5 GT/s）", "両者の最高速度", "Gen3（8 GT/s）", "ランダム"],
          0, "最初は必ず2.5 GT/sでリンクアップし、その後Recovery経由で高速な世代に切り替えます。"),
        q("ltssm-2", "ltssm", "リンク幅とレーン番号が決まるLTSSMの状態は？",
          ["Detect", "Polling", "Configuration", "Recovery"],
          2, "Configurationでリンク番号・レーン番号を交渉し、リンク幅を確定します。"),
        q("ltssm-3", "ltssm", "相手の受信終端（負荷）を検出して接続を確認する状態は？",
          ["Detect", "Polling", "L0s", "Loopback"],
          0, "Detect.Activeで受信終端の有無を検出します。"),
        q("ltssm-4", "ltssm", "L0sから復帰するときに使うOrdered Setは？",
          ["TS1", "FTS", "SKP", "EIOS"],
          1, "L0sはFTS（Fast Training Sequence）で、通常はRecoveryを経ずに直接L0へ戻ります（L1はRecovery経由）。なおL0sとFTSはNon-Flit Modeだけの仕組みで、Flit Modeでは使えません。"),

        // 10. コンフィグ空間
        q("cfg-1", "config", "PCIe Functionのコンフィグ空間のサイズは？",
          ["64バイト", "256バイト", "4KB", "64KB"],
          2, "先頭256バイトがPCI互換、合計4KBです。拡張部分はECAMでアクセスします。"),
        q("cfg-2", "config", "ECAMでBus 1, Device 0, Function 0, Offset 0のアドレスは（Base=0）？",
          ["0x00001000", "0x00008000", "0x00100000", "0x01000000"],
          2, "Bus<<20 なので 1<<20 = 0x00100000 です。"),
        q("cfg-3", "config", "メモリBARに全1を書いて FFF00000h が読めた（下位ビットはマスク済み）。サイズは？",
          ["64KB", "256KB", "1MB", "16MB"],
          2, "~FFF00000h + 1 = 00100000h = 1MB です。"),
        q("cfg-4", "config", "存在しないFunctionのVendor IDを読んだときの値は？",
          ["0000h", "FFFFh", "8086h", "エラーで停止"],
          1, "応答がない（UR）場合はオール1が返り、Vendor ID = FFFFhで不在と判断します。"),
        q("cfg-5", "config", "ブリッジが持つヘッダタイプは？",
          ["Type 0", "Type 1", "Type 2", "Type 3"],
          1, "ルートポートやスイッチポートはType 1ヘッダで、バス番号やアドレス範囲を持ちます。"),

        // 11. 割り込み・電源
        q("int-1", "interrupts", "MSI-Xで使える最大ベクタ数は？",
          ["4", "32", "256", "2048"],
          3, "MSIは最大32、MSI-Xは最大2048ベクタです。"),
        q("int-2", "interrupts", "MSIの実体は何？",
          ["専用の割り込み信号線", "特定アドレスへのMemory Write TLP", "DLLP", "Ordered Set"],
          1, "MSI/MSI-Xは決められたアドレスへのメモリ書き込みで、通常のTLPと同じ経路を通ります。"),
        q("int-3", "interrupts", "ハードウェアが自律的にリンクを省電力状態にする仕組みは？",
          ["PME", "ASPM", "LTR", "D3cold"],
          1, "ASPM（Active State Power Management）がアイドル時にL0s/L1へ自動遷移させます。"),
        q("int-4", "interrupts", "コンフィグアクセスは可能だが機能停止しているデバイス状態は？",
          ["D0", "D1", "D3hot", "D3cold"],
          2, "D3hotは電源が来ていてコンフィグ空間にアクセスできます。D3coldは主電源オフです。"),

        // 12. 順序・エラー
        q("ord-1", "ordering", "Read Requestは先行するPosted Writeを追い越せる？（属性なし）",
          ["追い越せる", "追い越せない", "TC次第", "必ず追い越す"],
          1, "追い越せないため、書いた後に読めば書き込みが反映済みになります（write flush）。"),
        q("ord-2", "ordering", "デッドロック回避のために許されている追い越しは？",
          ["Posted WriteがNon-Posted Requestを追い越す", "CompletionがPosted Writeを追い越す", "Read RequestがPosted Writeを追い越す", "どれも許されない"],
          0, "Posted WriteはNon-Posted Requestを追い越せなければなりません（そうしないとデッドロックが起きうる）。Completionを追い越すことは許されていますが、通常は必須ではありません。"),
        q("ord-3", "ordering", "Completion Timeoutのエラー分類は（デフォルト）？",
          ["Correctable", "Uncorrectable Non-Fatal", "Uncorrectable Fatal", "エラーではない"],
          1, "Completion TimeoutはNon-Fatalで、そのトランザクションのみ失敗します。"),
        q("ord-4", "ordering", "Replay Timeoutのエラー分類は？",
          ["Correctable", "Uncorrectable Non-Fatal", "Uncorrectable Fatal", "エラーではない"],
          0, "再送でハードウェアが回復できるため、Correctableに分類されます。"),
        q("ord-5", "ordering", "エラー時にダウンストリームポートがリンクを自動で切り離す機能は？",
          ["AER", "DPC", "ACS", "ATS"],
          1, "DPC（Downstream Port Containment）です。AERはエラーの詳細報告の仕組みです。"),

        // 13. 仮想化
        q("virt-1", "virtualization", "SR-IOVでVMに直接割り当てる軽量な機能は？",
          ["PF", "VF", "RCiEP", "ATC"],
          1, "VF（Virtual Function）をVMへパススルーします。PFは管理を担う完全な機能です。"),
        q("virt-2", "virtualization", "デバイスがアドレス変換結果をキャッシュする仕組みは？",
          ["ACS", "ATS", "ARI", "AER"],
          1, "ATSでIOMMUに変換を問い合わせ、デバイス内のATCにキャッシュします。"),
        q("virt-3", "virtualization", "スイッチ配下のピアツーピア通信を上流へリダイレクトして隔離する機能は？",
          ["ACS", "PASID", "PRI", "LTR"],
          0, "ACS（Access Control Services）です。IOMMUグループの分かれ方に影響します。"),

        // 14. Gen6以降
        q("g6-1", "gen6", "Gen6で採用された変調方式は？",
          ["NRZ", "PAM4", "QAM16", "PAM3"],
          1, "4値のPAM4で1シンボル2ビットを送り、シンボルレートを据え置いたまま速度を倍にしました。"),
        q("g6-2", "gen6", "Gen6のFLITのサイズは？",
          ["128バイト", "256バイト", "512バイト", "可変長"],
          1, "256バイト固定で、TLP 236B・DLP 6B・CRC 8B・FEC 6Bで構成されます。"),
        q("g6-3", "gen6", "Gen6でFECが必須になった主な理由は？",
          ["暗号化のため", "PAM4でビット誤り率が大きく上がったため", "レーン数を減らすため", "後方互換のため"],
          1, "PAM4はアイ開口が小さく誤り率が高くなるため、FECで訂正します。"),
        q("g6-4", "gen6", "リンクを止めずに使用レーン数を減らすGen6の省電力状態は？",
          ["L0s", "L0p", "L1.2", "L2"],
          1, "L0pはトラフィックを継続したままリンク幅を動的に縮小します。"),
        q("g6-5", "gen6", "PCIe 7.0の転送速度は？",
          ["64 GT/s", "96 GT/s", "128 GT/s", "256 GT/s"],
          2, "PCIe 7.0は128 GT/sです。256 GT/sは次世代の目標値です。"),

        // 15. PCIe 7.0の新機能
        q("p7-1", "pcie7", "PCIe 7.0（Base 7.0）と6.4の関係として、仕様書に書かれているものは？",
          ["同じECN・エラッタを含み、128.0 GT/s関連の変更が加わっている", "7.0で初めてFlit Modeが導入された", "7.0で初めてPAM4が導入された", "7.0で初めてL0pが導入された"],
          0, "Base 7.1の記載では、7.0と6.4は同じ承認済みECN・エラッタを反映しており、差分は編集上の変更と128.0 GT/s関連の変更です。"),
        q("p7-2", "pcie7", "128.0 GT/sのイコライゼーションを始められるのは、どの速度で動作しているとき？",
          ["2.5 GT/s", "32.0 GT/s", "64.0 GT/s", "128.0 GT/s"],
          2, "128.0 GT/sのイコライゼーション（やり直しを含む）は、64.0 GT/sからのみ開始できます。"),
        q("p7-3", "pcie7", "Link StatusのCurrent Link Speedが128.0 GT/sを示すときの値は？",
          ["0110b", "0111b", "1000b", "1111b"],
          2, "1000bはSupported Link Speeds Vector 2のbit 0（128.0 GT/s）を指します。0111bは予約です。"),
        q("p7-4", "pcie7", "Physical Layer 128.0 GT/s Extended CapabilityのExtended Capability IDは？",
          ["0026h", "002Ah", "0031h", "0039h"],
          3, "128.0 GT/s用のPhysical Layer Extended CapabilityのIDは0039hです。"),
        q("p7-5", "pcie7", "TLPs per Half Flitが01bで、両端に共通する最高速度が128.0 GT/sのとき、半Flitに入れてよいTLPの数は？",
          ["2個まで", "4個まで", "8個まで", "制限なし"],
          1, "01bは「共通の最高速度が128.0 GT/s以上なら、どのデータレートでも半Flitあたり4 TLPまで」を意味します。途中まで入ったTLPも1個と数えます。"),
        q("p7-6", "pcie7", "仕様の参照受信器で、128.0 GT/sの受信等化の大部分を担うのは？",
          ["多タップのDFE", "FFE（29タップ）", "送信側のプリコーディング", "FEC"],
          1, "128.0 GT/sでは受信等化の大部分をFFE（プレカーソル4・ポストカーソル24の29タップ）が担い、DFEは1タップだけです。"),
        q("p7-7", "pcie7", "64.0 / 128.0 GT/sの送信イコライザ（FIR）のタップ構成は？",
          ["3タップ（プレカーソル1）", "4タップ（プレカーソル2）", "2タップ（ポストカーソルのみ）", "29タップ"],
          1, "64.0 / 128.0 GT/sの送信FIRはc-2, c-1, c0, c+1の4タップで、プレカーソルが2つあります。"),

        // ---- 追加問題
        q("intro-4", "intro", "PCIeの仕様を策定・管理している業界団体は？",
          ["JEDEC", "USB-IF", "PCI-SIG", "IEEE"],
          2, "PCI ExpressはPCI-SIG（PCI Special Interest Group）が策定しています。"),
        q("intro-5", "intro", "x8リンクに含まれる差動ペアは全部でいくつ？",
          ["8ペア", "16ペア", "32ペア", "64ペア"],
          1, "1レーンは送信用と受信用の2ペアなので、x8では8×2＝16ペア（信号線は32本）です。"),
        q("intro-6", "intro", "Base 7.1が動作を規定しているリンク幅に含まれないものは？",
          ["x1", "x4", "x16", "x32"],
          3, "仕様書はx1、x2、x4、x8、x16のリンク幅について動作を規定しています。"),
        q("intro-7", "intro", "受信したデータの変化点からクロックを再生する回路は？",
          ["CDR", "LFSR", "FEC", "ECAM"],
          0, "CDR（Clock and Data Recovery）がデータ中の遷移からクロックを取り出します。PCIeはクロックをデータに埋め込んで送ります。"),
        q("intro-8", "intro", "2.5 GT/sで動作するx8リンクの、片方向の生の帯域（符号化前）は？",
          ["2.5 Gbit/s", "16 Gbit/s", "20 Gbit/s", "40 Gbit/s"],
          2, "2.5 GT/s × 8レーン＝20 Gbit/sです（仕様書の例と同じ）。8b/10bを除いた実データは16 Gbit/sになります。"),
        q("topo-5", "topology", "BDF「03:1f.7」のDevice番号（10進）は？",
          ["3", "7", "15", "31"],
          3, "Bus:Device.Function の順で、Device は16進の 1f＝31 です。"),
        q("topo-6", "topology", "CPU（Root Complex）から遠ざかる方向を何と呼ぶ？",
          ["アップストリーム", "ダウンストリーム", "ピアツーピア", "ブロードキャスト"],
          1, "CPUから遠い方向がダウンストリーム、CPUに近い方向がアップストリームです。"),
        q("topo-7", "topology", "RCiEPの説明として正しいものは？",
          ["スイッチの下流にあるEndpoint", "Root Complexに統合され、リンクを持たないEndpoint", "PCI-PCIブリッジの一種", "Retimerを内蔵したEndpoint"],
          1, "RCiEP（Root Complex Integrated Endpoint）はチップセットやSoCに統合され、PCIeリンクを介さないEndpointです。"),
        q("topo-8", "topology", "1本のPCIeリンクにつながるポートの数は？",
          ["1つ", "2つ", "最大8つ", "最大32個"],
          1, "PCIeはポイントツーポイント接続なので、1本のリンクには必ず2つのポートだけがつながります。"),
        q("topo-9", "topology", "スイッチが持つアップストリームポートの数は？",
          ["0", "1", "2", "ダウンストリームポートと同じ数"],
          1, "スイッチはアップストリームポート1つと、複数のダウンストリームポートを持ちます。"),
        q("gen-5", "generations", "128b/130bのSync Headerは何ビット？",
          ["1ビット", "2ビット", "8ビット", "10ビット"],
          1, "128ビットのペイロードごとに2ビットのSync Headerを付けるので、130ビットになります。"),
        q("gen-6", "generations", "Gen5（32 GT/s）x16の、片方向の実効帯域（符号化後）に最も近いのは？",
          ["約32 GB/s", "約63 GB/s", "約128 GB/s", "約256 GB/s"],
          1, "32 × 128/130 × 16 ÷ 8 ≒ 63 GB/sです。"),
        q("gen-7", "generations", "5.0 GT/s（Gen2）で使われる符号化は？",
          ["8b/10b", "128b/130b", "1b/1b", "64b/66b"],
          0, "2.5 GT/sと5.0 GT/sは8b/10bです。"),
        q("gen-8", "generations", "Flit Modeのサポートが必須になるのはどんなポート？",
          ["すべてのポート", "16.0 GT/s以上をサポートするポート", "32.0 GT/sを超えるデータレートをサポートするポート", "x16のポートだけ"],
          2, "Non-Flit Modeのサポートは必須で、Flit Modeは32.0 GT/sを超える（つまり64.0 GT/s以上の）データレートをサポートする場合に必須です。"),
        q("gen-9", "generations", "8.0 GT/sの1レーンの、符号化後の実効データレートに最も近いのは？",
          ["約6.4 Gbit/s", "約7.9 Gbit/s", "8.0 Gbit/sちょうど", "約10 Gbit/s"],
          1, "8.0 × 128/130 ≒ 7.88 Gbit/sです（仕様書の表では「~8 Gbit/s」）。"),
        q("layer-4", "layers", "TLPを生成・解釈する層は？",
          ["トランザクション層", "データリンク層", "物理層", "どの層でもない"],
          0, "トランザクション層がソフトウェアやデバイスの要求をTLPに変換し、受け取ったTLPを解釈します。"),
        q("layer-5", "layers", "LTSSM（リンク初期化の状態機械）があるのはどの層？",
          ["トランザクション層", "データリンク層", "物理層（論理サブブロック）", "物理層（電気サブブロック）"],
          2, "LTSSMは物理層の論理サブブロックにあります。"),
        q("layer-6", "layers", "Non-Flit ModeのDLLPに付くCRCは何ビット？",
          ["8ビット", "16ビット", "32ビット", "付かない"],
          1, "DLLPには16ビットのCRCが付きます。TLPのLCRCは32ビットです。"),
        q("layer-7", "layers", "受け取ったTLPのLCRCとシーケンス番号を確認するのはどの層？",
          ["トランザクション層", "データリンク層", "物理層", "ソフトウェア"],
          1, "データリンク層がLCRCとシーケンス番号を確認し、正しければトランザクション層に渡してACKを返します。"),
        q("tlp-7", "tlp", "Fmtフィールドが010bのTLPの形式は？",
          ["3DWヘッダ、データなし", "4DWヘッダ、データなし", "3DWヘッダ、データあり", "TLP Prefix"],
          2, "Fmt=010bは3DWヘッダでデータありです（例：32ビットアドレスのMWr）。"),
        q("tlp-8", "tlp", "Completionのルーティング方法は？",
          ["アドレスルーティング", "IDルーティング", "ブロードキャスト", "暗黙のルーティング"],
          1, "CompletionはRequester IDを宛先にしたIDルーティングで返り、3DWヘッダを使います。"),
        q("tlp-9", "tlp", "CompletionのByte Countフィールドが0のとき、残りのバイト数は？",
          ["0バイト", "1バイト", "4095バイト", "4096バイト"],
          3, "Byte Countは12ビットで、0000 0000 0000bは4096バイトを表します。"),
        q("tlp-10", "tlp", "Completion Statusの100bは何を意味する？",
          ["Successful Completion", "Unsupported Request", "Request Retry Status", "Completer Abort"],
          3, "000b=SC、001b=UR、010b=RRS、100b=CA です。"),
        q("tlp-11", "tlp", "ヘッダのEPビットが1のTLPは何を示す？",
          ["ECRCが付いている", "データが壊れている（Poisoned）", "優先度が高い", "ヘッダが4DWである"],
          1, "EP（Error Poisoned）が1のTLPはPoisoned TLPで、データが壊れていることを示します。"),
        q("tlp-12", "tlp", "4GB未満のアドレスにアクセスするメモリリクエストのヘッダ形式は？",
          ["3DW（32ビット形式）を使わなければならない", "4DW（64ビット形式）を使わなければならない", "どちらでもよい", "MPSによって決まる"],
          0, "4GB未満のアドレスには32ビット形式（3DWヘッダ）を使わなければなりません。"),
        q("dll-5", "datalink", "TLPに付けるLCRCは何ビット？",
          ["8ビット", "16ビット", "32ビット", "64ビット"],
          2, "TLPには32ビットのLCRCが付きます（Non-Flit Mode）。"),
        q("dll-6", "datalink", "ACK DLLPに入っているシーケンス番号の意味は？",
          ["次に送ってほしいTLPの番号", "最後に正しく受け取ったTLPの番号", "エラーのあったTLPの番号", "送信側の現在の番号"],
          1, "ACK/NAKには、受信側が最後に正しく受け取ったTLPの番号（NEXT_RCV_SEQ − 1）が入ります。"),
        q("dll-7", "datalink", "ACKを受け取るまで送信済みのTLPを保持しておくバッファは？",
          ["受信バッファ", "リプレイ（Retry）バッファ", "フロー制御バッファ", "MSI-Xテーブル"],
          1, "送信済みのTLPはACKが返るまでリプレイバッファ（仕様ではRetry Buffer）に保持され、NAKやタイムアウトのときはここから再送します。"),
        q("dll-8", "datalink", "データリンク層でTLPの送受信ができる状態は？",
          ["DL_Inactive", "DL_Feature", "DL_Init", "DL_Active"],
          3, "フロー制御の初期化が終わってDL_Activeになると、TLPを送受信できます。"),
        q("dll-9", "datalink", "Non-Flit ModeでREPLAY_NUMは再送のたびにいくつ増える？",
          ["1", "2", "4", "8"],
          1, "Non-Flit ModeではREPLAY_NUM（3ビット）を再送ごとに2増やし、4回目の再送でロールオーバーします。"),
        q("dll-10", "datalink", "DL_Feature状態で交換する機能の代表例は？",
          ["Scaled Flow Control", "MSI-X", "ECRC", "SR-IOV"],
          0, "DL_Featureでは、Scaled Flow ControlなどのData Link Featureを相手と交換します。"),
        q("fc-5", "flowcontrol", "フロー制御クレジットの種類はいくつ？",
          ["2種類", "3種類", "6種類", "8種類"],
          2, "Posted・Non-Posted・Completionのそれぞれにヘッダとデータのクレジットがあるので6種類です（PH、PD、NPH、NPD、CplH、CplD）。"),
        q("fc-6", "flowcontrol", "データなしのMemory Read Requestが消費するクレジットは？",
          ["NPH 1", "NPH 1とNPD 1", "PH 1", "CplH 1"],
          0, "MRdはNon-Postedでデータを運ばないので、NPHを1つだけ消費します。"),
        q("fc-7", "flowcontrol", "受信側が解放したクレジットを送信側に通知するDLLPは？",
          ["InitFC1", "InitFC2", "UpdateFC", "Ack"],
          2, "受信側はバッファを空けるたびにUpdateFC DLLPで送信側に通知します。"),
        q("fc-8", "flowcontrol", "Scaled Flow Controlのサポートが必須になるのは？",
          ["すべてのポート", "8.0 GT/s以上をサポートするポート", "16.0 GT/s以上をサポートするポート", "Flit Modeのポートだけ"],
          2, "16.0 GT/s以上のデータレートをサポートするポートはScaled Flow Controlをサポートしなければなりません。"),
        q("fc-9", "flowcontrol", "Scaled Flow Controlを使わないとき、ヘッダクレジットのカウンタ（HdrFC）は何ビット？",
          ["8ビット", "10ビット", "12ビット", "16ビット"],
          0, "Scaled Flow Controlを使わない場合、HdrFCは8ビット、DataFCは12ビットです。"),
        q("fc-10", "flowcontrol", "64バイトのMemory Writeが消費するデータクレジット（PD）は？",
          ["1", "4", "16", "64"],
          1, "データクレジット1は16バイトなので、64÷16＝4です。"),
        q("phy-5", "physical", "8b/10b（2.5 / 5.0 GT/s）のスクランブラが使うLFSRの次数は？",
          ["8", "16", "23", "32"],
          1, "8b/10bでは16次の多項式のLFSRを使います。"),
        q("phy-6", "physical", "128b/130bのスクランブラが使うLFSRの次数は？",
          ["16", "23", "31", "64"],
          1, "128b/130bではレーンごとに23次のLFSRを使います。"),
        q("phy-7", "physical", "Electrical Idle（無信号状態）に入る前に送るOrdered Setは？",
          ["EIOS", "EIEOS", "SKP", "SDS"],
          0, "EIOS（Electrical Idle Ordered Set）を送ってからElectrical Idleに入ります。"),
        q("phy-8", "physical", "8.0〜32.0 GT/sの送信イコライゼーションのプリセットはいくつ定義されている？",
          ["P0〜P3の4つ", "P0〜P7の8つ", "P0〜P10の11個", "P0〜P15の16個"],
          2, "送信プリセットはP0〜P10の11個が定義されています。"),
        q("phy-9", "physical", "差動ペアの＋と−を逆に配線しても動作させる機能は？",
          ["レーン反転", "極性反転（Polarity Inversion）", "デスキュー", "スクランブル"],
          1, "受信側がPolling中に極性を検出して反転させます。"),
        q("phy-10", "physical", "8.0〜32.0 GT/s（Non-Flit Mode）で、TLPの先頭に付けるものは？",
          ["STPシンボル（1シンボル）", "STPトークン（4バイト、シーケンス番号を含む）", "SDPトークン", "ENDシンボル"],
          1, "128b/130bではTLP長とシーケンス番号などを含む4バイトのSTPトークンを先頭に付けます。ENDはありません。"),
        q("ltssm-5", "ltssm", "Detect.QuietからDetect.Activeに進むタイムアウトは？",
          ["2 ms", "12 ms", "24 ms", "48 ms"],
          1, "12 msのタイムアウト、または受信レーンでElectrical Idleの終了を検出するとDetect.Activeに進みます。"),
        q("ltssm-6", "ltssm", "Polling.ActiveからPolling.Configurationに進むために、最低いくつのTS1を送信する必要がある？",
          ["8個", "16個", "1024個", "4096個"],
          2, "1024個以上のTS1を送信し、かつ全レーンで8個連続のトレーニングシーケンスを受信すると進みます。"),
        q("ltssm-7", "ltssm", "Polling.Configurationのタイムアウト（Detectに戻るまで）は？",
          ["12 ms", "24 ms", "48 ms", "100 ms"],
          2, "48 msのタイムアウトでDetectに戻ります。"),
        q("ltssm-8", "ltssm", "Hot Resetからほかに指示がないとき、Detectに戻るまでのタイムアウトは？",
          ["2 ms", "12 ms", "24 ms", "48 ms"],
          0, "Hot Resetは2 msのタイムアウトでDetectに移ります。"),
        q("ltssm-9", "ltssm", "仕様で「到達できない状態」と明記されているのは？",
          ["Polling.Compliance", "Polling.Speed", "Recovery.Speed", "Loopback"],
          1, "リンクは必ず2.5 GT/sでL0に到達し、速度変更はRecoveryで行うため、Polling.Speedには到達しません。"),
        q("ltssm-10", "ltssm", "Configuration.Idleで1（リンクアップ）になる変数は？",
          ["LinkUp", "DL_Up", "Link Active", "REPLAY_NUM"],
          0, "Configuration.IdleでLinkUpが1になります。"),
        q("cfg-6", "config", "ECAMで1つのバスが占めるアドレス範囲の大きさは？",
          ["4KB", "256KB", "1MB", "256MB"],
          2, "32デバイス × 8ファンクション × 4KB ＝ 1MBです。"),
        q("cfg-7", "config", "Type 0ヘッダでBAR0〜BAR5が並ぶオフセットは？",
          ["00h〜0Ch", "10h〜24h", "28h〜3Ch", "100h〜"],
          1, "BAR0〜BAR5は10h〜24hの6個です。"),
        q("cfg-8", "config", "Capabilities Pointerがあるオフセットは？",
          ["0Eh", "10h", "34h", "100h"],
          2, "34hのCapabilities Pointerから、PCI互換領域のCapabilityの連結リストをたどります。"),
        q("cfg-9", "config", "Header Typeレジスタのbit 7の意味は？",
          ["Type 1ヘッダである", "Multi-Function Device", "BISTに対応", "64ビットBARを持つ"],
          1, "bit 7が1なら、Function 0以外のFunctionを持つ可能性があることを示します。"),
        q("cfg-10", "config", "Type 1ヘッダのSecondary Bus Numberのオフセットは？",
          ["18h", "19h", "1Ah", "1Bh"],
          1, "18hがPrimary、19hがSecondary、1AhがSubordinate Bus Numberです。"),
        q("int-5", "interrupts", "PCIeでINTx割り込みを伝える方法は？",
          ["専用の割り込み線", "Assert_INTx / Deassert_INTxメッセージ", "MSIと同じMemory Write", "DLLP"],
          1, "PCIeには割り込み線がないので、Assert_INTx／Deassert_INTxメッセージで旧PCIの割り込み線の状態を伝えます。"),
        q("int-6", "interrupts", "MSI-Xのテーブル（ベクタごとのアドレス・データ・マスク）はどこにある？",
          ["コンフィグ空間のMSI-X Capabilityの中", "デバイスのBARが指すメモリ空間の中", "ホストのメモリ", "Root Complexの中"],
          1, "MSI-XテーブルとPBAはデバイスのBAR空間に置かれ、Capabilityはその場所（BARとオフセット）を示します。"),
        q("int-7", "interrupts", "L1.2から復帰するときの合図に使う信号は？",
          ["PERST#", "CLKREQ#", "WAKE#", "PRSNT#"],
          1, "L1 PM SubstatesではCLKREQ#を使ってL1.2への出入りを制御します。"),
        q("int-8", "interrupts", "Flit Modeでは使えないリンクの省電力状態は？",
          ["L0s", "L1", "L1.2", "L0p"],
          0, "L0sはFlit Modeでは使えません。代わりにL0pでリンク幅を減らして省電力化します。"),
        q("int-9", "interrupts", "デバイスが許容できる遅延を通知し、プラットフォームの省電力の深さを決める仕組みは？",
          ["ASPM", "LTR", "PME", "OBFF"],
          1, "LTR（Latency Tolerance Reporting）で、デバイスが許容できる遅延を通知します。"),
        q("ord-6", "ordering", "PCIeの順序規則が適用される範囲は？",
          ["リンク上のすべてのTLP", "同じTraffic Class（TC）のTLPの間", "同じVirtual Channelのうち、同じ送信元のTLPだけ", "同じアドレスへのTLPだけ"],
          1, "順序規則は1つのTCの中で適用され、TCが異なるトランザクション間には順序の要求はありません。"),
        q("ord-7", "ordering", "Relaxed Ordering（RO）が1のPosted Requestは、前のPosted Requestを追い越せる？",
          ["追い越せない", "追い越してよい", "必ず追い越す", "TCが違う場合だけ追い越せる"],
          1, "ROが1のPosted Requestは、ほかのPosted Requestを追い越すことが許されています。"),
        q("ord-8", "ordering", "Non-Posted Request同士の追い越しは？",
          ["禁止", "許されている", "Relaxed Orderingが必要", "IDOが必要"],
          1, "Non-Posted Requestは、ほかのNon-Posted Requestを追い越すことが許されています。"),
        q("ord-9", "ordering", "Malformed TLPの既定の重大度は？",
          ["Correctable", "Uncorrectable Non-Fatal", "Uncorrectable Fatal", "エラーではない"],
          2, "Malformed TLPは既定でUncorrectable Fatalです（AERがあれば重大度を変更できる）。"),
        q("ord-10", "ordering", "AERのHeader Logに記録されるものは？",
          ["エラーを起こしたTLPのヘッダ", "リンクの速度と幅", "最後に送ったDLLP", "MSI-Xのベクタ番号"],
          0, "AERはエラーの原因になったTLPのヘッダ（とプレフィックス）を記録し、原因の特定に使えます。"),
        q("virt-4", "virtualization", "ARIを有効にしたとき、Function番号に使えるビット数は？",
          ["3ビット", "5ビット", "8ビット", "16ビット"],
          2, "ARIではDevice番号の5ビットとFunction番号の3ビットを合わせた8ビットをFunction番号として使います。"),
        q("virt-5", "virtualization", "SR-IOV Extended CapabilityのIDは？",
          ["000Dh", "000Eh", "000Fh", "0010h"],
          3, "SR-IOV Extended CapabilityのIDは0010hです。"),
        q("virt-6", "virtualization", "ATSを使うデバイスが、変換結果を保持しておく場所は？",
          ["IOMMUのページテーブル", "ATC（Address Translation Cache）", "MSI-Xテーブル", "Retry Buffer"],
          1, "デバイスはIOMMUに問い合わせた変換結果を、自身のATCにキャッシュします。"),
        q("virt-7", "virtualization", "PASIDの役割は？",
          ["デバイス内でアドレス空間（プロセス）を区別する", "VFの数を増やす", "エラーを報告する", "リンク速度を上げる"],
          0, "PASIDは同じデバイスの中でアドレス空間（プロセス）を区別するためのIDです。"),
        q("virt-8", "virtualization", "ACS Extended CapabilityのIDは？",
          ["0001h", "000Dh", "001Dh", "001Eh"],
          1, "ACS Extended CapabilityのIDは000Dhです。"),
        q("g6-6", "gen6", "256バイトのFLITのうち、CRCに使われるのは何バイト？",
          ["4バイト", "6バイト", "8バイト", "16バイト"],
          2, "FLITはTLP 236＋DLP 6＋CRC 8＋FEC 6バイトです。"),
        q("g6-7", "gen6", "256バイトのFLITのうち、FECに使われるのは何バイト？",
          ["2バイト", "6バイト", "8バイト", "12バイト"],
          1, "FECは6バイトです。"),
        q("g6-8", "gen6", "FLITのうちTLPを入れられる領域は何バイト？",
          ["128バイト", "236バイト", "242バイト", "256バイト"],
          1, "TLP領域は236バイトで、前半（0〜127）と後半（128〜235）に分かれます。"),
        q("g6-9", "gen6", "Flit ModeをサポートするFunctionが必ずサポートするTag Completerの能力は？",
          ["5-Bit Tag", "8-Bit Tag", "10-Bit Tag", "14-Bit Tag"],
          3, "Flit ModeをサポートするFunctionは14-Bit Tag Completerをサポートしなければならず、それにより10-Bit Tag Completerもサポートします。"),
        q("g6-10", "gen6", "32.0 GT/s以下（NRZ）のデータレートのビット誤り率（BER）の目標値は？",
          ["10⁻⁶", "10⁻⁹", "10⁻¹²", "10⁻¹⁵"],
          2, "32.0 GT/s以下のBER目標は10⁻¹²で、PAM4ではこれより大幅に悪くなることを前提にFECを使います（FBERは10⁻⁶）。"),
        q("p7-8", "pcie7", "128.0 GT/sの参照受信器のCTLEで、DCゲインを調整できる範囲は？",
          ["0〜-6 dB", "0〜-15 dB（1 dB刻み）", "0〜-30 dB", "調整できない"],
          1, "128.0 GT/sのbehavioral CTLEは6つの極と3つのゼロを持ち、DCゲインは0〜-15 dBを1 dB刻みで調整します。"),
        q("p7-9", "pcie7", "128.0 GT/sの参照受信器のFFE（29タップ）のうち、プレカーソルのタップ数は？",
          ["1", "2", "4", "24"],
          2, "29タップのうちプレカーソルが4、ポストカーソルが24です。"),
        q("p7-10", "pcie7", "128.0 GT/s用の送信プリセットを相手に伝えるOrdered Setは？",
          ["EQ TS2", "128b/130b EQ TS2", "1b/1b EQ TS2", "SKP"],
          2, "128.0 GT/sのイコライゼーションで使うプリセットは1b/1b EQ TS2で伝えます。"),
        q("p7-11", "pcie7", "128.0 GT/sで起きたパリティエラーが記録されるのは？",
          ["128.0 GT/s Status Register", "16.0 GT/sのData Parity Mismatch Statusレジスタ群", "AERのHeader Log", "Link Status Register"],
          1, "128.0 GT/sのパリティエラーは、既存の16.0 GT/s Data Parity Mismatch Statusレジスタ群に記録されます。"),
        q("p7-12", "pcie7", "Link Capabilities 2のSupported Link Speeds Vectorで、bit 6が1のときの意味は？",
          ["64.0 GT/sに対応", "128.0 GT/s以上に対応（詳細はVector 2）", "Flit Modeに対応", "予約"],
          1, "bit 6は「128.0 GT/s以上」を示し、具体的な速度はSupported Link Speeds Vector 2に書かれます。"),
    ]
}
