import Foundation

struct GlossaryTerm: Identifiable, Hashable {
    enum Category: String, CaseIterable, Identifiable {
        case basics = "基本"
        case transaction = "トランザクション層"
        case dataLink = "データリンク層"
        case physical = "物理層"
        case config = "コンフィグ"
        case power = "電源・割り込み"
        case advanced = "拡張機能"

        var id: String { rawValue }
    }

    var id: String { term }
    let term: String
    let fullName: String
    let category: Category
    let description: String
}

enum GlossaryData {
    private static func t(_ term: String, _ full: String, _ cat: GlossaryTerm.Category, _ desc: String) -> GlossaryTerm {
        GlossaryTerm(term: term, fullName: full, category: cat, description: desc)
    }

    static let all: [GlossaryTerm] = [
        // 基本
        t("PCIe", "PCI Express", .basics, "CPUと周辺機器をつなぐ高速シリアルインターフェース。PCI-SIGが策定。"),
        t("PCI-SIG", "PCI Special Interest Group", .basics, "PCI/PCIe仕様を策定・管理する業界団体。"),
        t("レーン", "Lane", .basics, "送信用と受信用の差動ペア各1組からなる通信路の最小単位。"),
        t("リンク", "Link", .basics, "2つのポート間を結ぶ1本以上のレーンの束。x1〜x16などと表記。"),
        t("GT/s", "Giga Transfers per second", .basics, "1レーンあたりの生の転送速度。符号化オーバーヘッドを含む。"),
        t("RC", "Root Complex", .basics, "CPU・メモリとPCIe階層をつなぐツリーの根。"),
        t("RP", "Root Port", .basics, "Root Complexが持つダウンストリームポート。仮想PCI-PCIブリッジとして見える。"),
        t("EP", "Endpoint", .basics, "GPUやSSDなどツリーの末端にあるデバイス。"),
        t("RCiEP", "Root Complex Integrated Endpoint", .basics, "Root Complexに統合され、リンクを持たないエンドポイント。"),
        t("スイッチ", "Switch", .basics, "1つのアップストリームポートと複数のダウンストリームポートを持ち、TLPを中継する。"),
        t("USP / DSP", "Upstream Port / Downstream Port", .basics, "CPU側を向くポートがUSP、デバイス側を向くポートがDSP。"),
        t("BDF", "Bus / Device / Function", .basics, "Functionを識別する16ビットのID（8/5/3ビット）。Requester IDなどに使用。"),
        t("リタイマ", "Retimer", .basics, "信号を一度受信してクロックを再生し送り直す中継IC。LTSSMに参加する。長距離配線で使われる。"),
        t("CXL", "Compute Express Link", .basics, "PCIe物理層上で動作するキャッシュコヒーレントなインターコネクト。CXL.io/cache/memの3プロトコル。"),

        // トランザクション層
        t("TLP", "Transaction Layer Packet", .transaction, "トランザクション層が生成するパケット。読み書き・設定・メッセージ・応答を運ぶ。"),
        t("MRd / MWr", "Memory Read / Memory Write", .transaction, "メモリ空間への読み出し／書き込みリクエスト。MWrはPosted。"),
        t("CplD", "Completion with Data", .transaction, "データ付きのコンプリーション。読み出し要求への応答。"),
        t("Posted", "Posted Request", .transaction, "応答（Completion）を必要としないリクエスト。MWrとMessage。"),
        t("Non-Posted", "Non-Posted Request", .transaction, "必ずCompletionが返るリクエスト。MRd、IO、Config、AtomicOp。"),
        t("DW", "Double Word", .transaction, "4バイト。TLPのヘッダ長やLengthはDW単位。"),
        t("Tag", "Tag", .transaction, "未完了のリクエストを識別する番号。Requester IDと組でCompletionを対応付ける。"),
        t("MPS", "Max Payload Size", .transaction, "1つのTLPが運べる最大データ量（128〜4096バイト）。"),
        t("MRRS", "Max Read Request Size", .transaction, "1回の読み出し要求の最大サイズ。"),
        t("RCB", "Read Completion Boundary", .transaction, "読み出しの応答を分割する境界（64または128バイト）。"),
        t("ECRC", "End-to-end CRC", .transaction, "トランザクション層が付ける任意の32ビットCRC。送信元から宛先まで保護する。"),
        t("TC", "Traffic Class", .transaction, "TLPの優先度クラス（0〜7）。VCにマッピングされる。"),
        t("VC", "Virtual Channel", .transaction, "独立したバッファとフロー制御を持つ仮想的な通信路。"),
        t("RO", "Relaxed Ordering", .transaction, "順序規則を緩めて追い越しを許可するTLP属性。"),
        t("Poisoned TLP", "Poisoned TLP (EP=1)", .transaction, "データが壊れていることを示すTLP。受信側はデータを使ってはいけない。"),
        t("AtomicOp", "Atomic Operation", .transaction, "FetchAdd・Swap・CASの不可分操作を行うリクエスト。"),
        t("フロー制御クレジット", "Flow Control Credit", .transaction, "受信バッファの空きを表す単位。ヘッダ1個またはデータ16バイト。"),

        // データリンク層
        t("DLLP", "Data Link Layer Packet", .dataLink, "隣接ポート間でやり取りする短いパケット。ACK/NAK、フロー制御、電源管理など。"),
        t("LCRC", "Link CRC", .dataLink, "データリンク層がTLPに付ける32ビットCRC。リンクごとに付け直される。"),
        t("ACK / NAK", "Acknowledge / Negative Acknowledge", .dataLink, "TLPの受信成功／失敗を通知するDLLP。NAKで再送が起きる。"),
        t("リプレイバッファ", "Replay Buffer", .dataLink, "ACKされるまで送信済みTLPを保持するバッファ。"),
        t("REPLAY_TIMER", "Replay Timer", .dataLink, "ACK/NAKが来ないときに再送を起動するタイマ。"),
        t("REPLAY_NUM", "Replay Number", .dataLink, "再送回数のカウンタ（Non-Flit Modeでは3ビットで、再送ごとに2ずつ増える）。4回目の再送でロールオーバーし、リンクの再トレーニングを要求する。Flit ModeではFLIT_REPLAY_NUMを使う。"),
        t("InitFC / UpdateFC", "Flow Control DLLP", .dataLink, "フロー制御クレジットの初期化／更新を行うDLLP。"),
        t("DL_Active", "Data Link Active", .dataLink, "データリンク層がTLPを送受信できる状態。"),

        // 物理層
        t("LTSSM", "Link Training and Status State Machine", .physical, "リンクの初期化・速度変更・省電力・回復を管理する状態機械。"),
        t("TS1 / TS2", "Training Sequence 1/2", .physical, "リンクトレーニングで交換するOrdered Set。速度・幅・レーン番号などを伝える。"),
        t("SKP", "Skip Ordered Set", .physical, "両端のクロック周波数差を吸収するためのOrdered Set。"),
        t("EIOS / EIEOS", "Electrical Idle (Exit) Ordered Set", .physical, "Electrical Idleへの突入／脱出を示すOrdered Set。"),
        t("FTS", "Fast Training Sequence", .physical, "L0sからの高速復帰に使うOrdered Set。Non-Flit Modeのみ。"),
        t("8b/10b", "8b/10b encoding", .physical, "8ビットを10ビットに変換する符号化。Gen1/2。効率80%。"),
        t("128b/130b", "128b/130b encoding", .physical, "128ビットごとに2ビットのSync Headerを付ける符号化。Gen3〜5。"),
        t("PAM4", "4-level Pulse Amplitude Modulation", .physical, "4値で1シンボル2ビットを送る変調。Gen6以降。"),
        t("NRZ", "Non-Return-to-Zero", .physical, "0/1の2値で送る方式。Gen5まで。"),
        t("FLIT", "Flow Control Unit", .physical, "Gen6で導入された256バイト固定長の転送単位。TLP・DLP・CRC・FECを含む。"),
        t("FEC", "Forward Error Correction", .physical, "受信側で誤りを訂正できる冗長符号。Gen6のPAM4で必須。"),
        t("CDR", "Clock and Data Recovery", .physical, "受信データの変化点からクロックを再生する回路。"),
        t("イコライゼーション", "Equalization", .physical, "伝送路の損失を補償する処理。送信側FFE、受信側CTLE/DFE。Gen3以降はトレーニングで係数を調整。"),
        t("SRIS", "Separate Refclk with Independent SSC", .physical, "両端が独立したリファレンスクロック（スペクトラム拡散あり）で動作する方式。"),
        t("スクランブル", "Scrambling", .physical, "LFSR出力とのXORでビット列をランダム化し、EMIと長い同符号連続を防ぐ処理。"),

        // コンフィグ
        t("コンフィグ空間", "Configuration Space", .config, "各Functionが持つ4KBの設定レジスタ空間。先頭256バイトがPCI互換。"),
        t("ECAM", "Enhanced Configuration Access Mechanism", .config, "コンフィグ空間をメモリ空間にマップしてアクセスする方式。"),
        t("BAR", "Base Address Register", .config, "デバイスのメモリ/I/O領域の割り当てアドレスを設定するレジスタ。"),
        t("Type 0 / Type 1", "Header Type", .config, "Type 0はEndpoint、Type 1はブリッジのコンフィグヘッダ形式。"),
        t("列挙", "Enumeration", .config, "ソフトウェアがデバイスを探索し、バス番号やBARを割り当てる処理。"),
        t("Capability", "Capability Structure", .config, "コンフィグ空間内の機能記述ブロック。連結リストでたどる。"),
        t("ARI", "Alternative Routing-ID Interpretation", .config, "Device番号をFunction番号に流用し、最大256 Functionを扱う機能。"),

        // 電源・割り込み
        t("INTx", "Legacy Interrupt", .power, "旧PCIの割り込み線をメッセージで模倣する方式。"),
        t("MSI", "Message Signaled Interrupt", .power, "メモリ書き込みで割り込みを通知する方式。最大32ベクタ。"),
        t("MSI-X", "MSI eXtended", .power, "ベクタごとにアドレス・データ・マスクを持つ拡張MSI。最大2048ベクタ。"),
        t("ASPM", "Active State Power Management", .power, "ハードウェアが自律的にリンクをL0s/L1へ移行させる省電力機能（Flit ModeではL1のみ）。"),
        t("L0s / L1 / L2", "Link Power States", .power, "リンクの省電力状態。数字が大きいほど深く、復帰に時間がかかる。L0sはFlit Modeでは使えない。"),
        t("L1.1 / L1.2", "L1 PM Substates", .power, "L1をさらに深くするサブステート。CLKREQ#で復帰を合図する。"),
        t("L0p", "L0p", .power, "Gen6で追加された、リンクを止めずに使用レーン数を減らす省電力状態。"),
        t("D0 / D3hot / D3cold", "Device Power States", .power, "デバイスの電源状態。D3coldは主電源オフ。"),
        t("PME", "Power Management Event", .power, "低電力状態のデバイスがシステムを起こすためのイベント。"),
        t("LTR", "Latency Tolerance Reporting", .power, "デバイスが許容できる遅延を通知し、省電力の深さを決める仕組み。"),

        // 拡張機能
        t("AER", "Advanced Error Reporting", .advanced, "エラーの詳細ステータスとTLPヘッダを記録・報告する拡張Capability。"),
        t("DPC", "Downstream Port Containment", .advanced, "致命的エラー時にダウンストリームポートがリンクを切り離して影響を封じ込める機能。"),
        t("SR-IOV", "Single Root I/O Virtualization", .advanced, "1つのデバイスをPFと複数のVFに分け、VMに直接割り当てる仕組み。"),
        t("PF / VF", "Physical Function / Virtual Function", .advanced, "SR-IOVの管理用の完全な機能（PF）と、VMに割り当てる軽量な機能（VF）。"),
        t("ATS", "Address Translation Services", .advanced, "デバイスがIOMMUのアドレス変換結果をキャッシュする仕組み。"),
        t("ACS", "Access Control Services", .advanced, "ピアツーピア通信を制御・リダイレクトしてデバイス間を隔離する機能。"),
        t("PASID", "Process Address Space ID", .advanced, "同じデバイス内でアドレス空間（プロセス）を区別するID。"),
        t("IOMMU", "I/O Memory Management Unit", .advanced, "デバイスのDMAアドレスを変換・保護するハードウェア（VT-d、AMD-Viなど）。"),
        t("RRS", "Request Retry Status", .transaction, "Completion Statusの一つ（010b）。準備中のため後で再試行してほしいことを示す。以前はCRSと呼ばれていた。"),
        t("DL_Feature", "Data Link Feature", .dataLink, "DL_Initの前にScaled Flow Controlなどの機能を相手と交換するデータリンク層の状態（任意）。"),
        t("TLPs per Half Flit", "TLPs per Half Flit", .dataLink, "Flitの前半・後半それぞれに入れてよいTLP数の上限（8または4）。共通の最高速度が128.0 GT/s以上で01bなら4。Data Link Feature DLLPで伝える。"),
        t("Supported Link Speeds Vector 2", "Supported Link Speeds Vector 2", .config, "128.0 GT/s以上の対応速度を示すフィールド（bit 0 = 128.0 GT/s）。Physical Layer 128.0 GT/s Extended Capabilityにある。"),
        t("プリコーディング", "Precoding", .physical, "32.0 GT/s以上で受信側が要求できる送信側の符号変換。グレイ符号化と組み合わせて、受信側DFEの誤り伝搬によるエラーの影響を抑える。速度ごとにEQ TS2系のTransmitter Precode Requestで要求する。"),
        t("グレイ符号化", "Gray Coding", .physical, "PAM4で2ビットを電圧レベルに割り当てる際、隣り合うレベルの違いが1ビットになるようにする符号化。64.0 GT/s以上で使う。"),
        t("Equalization Bypass", "Equalization Bypass to Highest NRZ Rate", .physical, "8.0 / 16.0 GT/sのイコライゼーションを省き、32.0 GT/sから始める任意の仕組み。"),
        t("UIO", "Unordered I/O", .transaction, "順序規則に縛られない専用の仮想チャネルで運ぶTLP。UIOのRequestはすべてCompletionが必要。"),
        t("TDISP", "TEE Device Interface Security Protocol", .advanced, "機密計算（TEE）向けに、デバイスのインターフェース（TDI）を安全に割り当てるためのプロトコル。"),
        t("SIOV", "Scalable I/O Virtualization", .advanced, "SR-IOVの後継として位置付けられるI/O仮想化の仕組み。"),
        t("Hot Plug", "Hot Plug", .advanced, "システム稼働中のデバイス抜き差しをサポートする機能。"),
    ]
}
