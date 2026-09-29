import Foundation

extension LessonData {
    // MARK: - 上級

    static let advanced: [Chapter] = [
        Chapter(
            id: "ltssm",
            number: 9,
            title: "LTSSM（リンク初期化）",
            summary: "Detect→Polling→Configuration→L0 と Recovery",
            level: .advanced,
            symbol: "arrow.triangle.branch",
            blocks: [
                .text("**LTSSM（Link Training and Status State Machine）** は物理層にある状態機械で、リンクの初期化・速度変更・省電力状態・エラーからの回復を管理します。"),
                .heading("主な状態"),
                .table(header: ["状態", "役割"], rows: [
                    ["Detect", "相手の受信終端（負荷）を検出して、つながっているか確認"],
                    ["Polling", "TS1/TS2を交換し、ビット・シンボルロック、極性反転を確立"],
                    ["Configuration", "リンク番号・レーン番号を決め、リンク幅を確定"],
                    ["L0", "通常動作。TLP/DLLPをやり取りする"],
                    ["Recovery", "速度変更、イコライゼーション、エラーからの再同期"],
                    ["L0s / L1 / L2", "省電力状態"],
                    ["Disabled", "ソフトウェアがリンクを無効化"],
                    ["Loopback", "テスト用の折り返し"],
                    ["Hot Reset", "リンク経由で下流をリセット"],
                ]),
                .heading("リンクアップの流れ"),
                .figure("""
                Detect.Quiet -> Detect.Active
                  -> Polling.Active -> Polling.Configuration
                  -> Configuration.* (width / lane #)
                  -> L0   (at 2.5 GT/s)
                  -> Recovery.RcvrLock -> Recovery.RcvrCfg
                  -> Recovery.Speed    (change rate)
                  -> Recovery.RcvrLock
                  -> Recovery.Equalization (Gen3+)
                  -> Recovery.RcvrLock -> RcvrCfg -> Idle
                  -> L0   (at target speed)
                """),
                .text("重要なのは、**リンクは必ず Gen1（2.5 GT/s）で最初にリンクアップする** という点です。そのあと TS1/TS2 で互いの対応速度を伝え合い、Recovery を経由して高速な世代へ切り替えます。"),
                .heading("Recoveryに入る場面"),
                .bullets([
                    "速度変更（Gen1 → Gen3 など）とイコライゼーション",
                    "ビットロック／ブロックアラインメントの喪失など受信エラー",
                    "データリンク層の **REPLAY_NUM** ロールオーバー（4回目の再送のタイミング）",
                    "L1 からの復帰（L0s は通常 FTS を使って直接 L0 に戻り、失敗したときだけ Recovery に入る）",
                    "リンク幅の変更や、ソフトウェアによる **Retrain Link** 要求",
                ]),
                .heading("Configurationのサブステート"),
                .bullets([
                    "**Linkwidth.Start / Accept**：下流ポートがリンク番号を提案し、上流ポートが受け入れる",
                    "**Lanenum.Wait / Accept**：レーン番号の割り当て（レーン反転もここで判明）",
                    "**Complete / Idle**：TS2 で最終確認し、アイドルデータを交換して L0 へ",
                ]),
                .note("最近の世代では、両端が対応していれば中間の速度でのイコライゼーションを省いて最高のNRZ速度（32 GT/s）へ直接進む **Equalization Bypass to Highest NRZ Rate** や、イコライゼーション自体を省く **No Equalization Needed** も定義されています。Flit Mode では Configuration.Idle / Recovery.Idle でアイドルデータの代わりに IDLE Flit を交換します。"),
                .note("Linux では `lspci -vv` の **LnkCap**（能力）と **LnkSta**（現在の速度と幅）を比べると、想定どおりにリンクアップしているか確認できます。「Speed 8GT/s (downgraded)」のような表示は Recovery での速度交渉がうまくいかなかったサインです。"),
            ],
            diagram: .ltssm
        ),
        Chapter(
            id: "config",
            number: 10,
            title: "コンフィグ空間と列挙",
            summary: "ECAM、Type0/1ヘッダ、BAR、Capability",
            level: .advanced,
            symbol: "list.bullet.rectangle",
            blocks: [
                .text("各 Function は **4KB のコンフィグレーション空間** を持ちます。先頭 256 バイトは PCI 互換領域、残り（100h〜FFFh）は PCIe で追加された **拡張コンフィグレーション空間** です。"),
                .heading("アクセス方法"),
                .bullets([
                    "**レガシー方式**：I/O ポート `CF8h`（アドレス）と `CFCh`（データ）。先頭 256 バイトのみ",
                    "**ECAM（Enhanced Configuration Access Mechanism）**：コンフィグ空間全体をメモリ空間にマップ。4KB すべてにアクセス可能",
                ]),
                .figure("""
                ECAM address =
                  Base + (Bus << 20) | (Dev << 15)
                       | (Func << 12) | Offset
                """),
                .heading("Type 0 ヘッダ（Endpoint）"),
                .table(header: ["Offset", "内容"], rows: [
                    ["00h", "Vendor ID / Device ID"],
                    ["04h", "Command / Status"],
                    ["08h", "Revision ID / Class Code"],
                    ["0Ch", "Cache Line Size / Latency Timer / Header Type / BIST"],
                    ["10h–24h", "BAR0〜BAR5"],
                    ["2Ch", "Subsystem Vendor ID / Subsystem ID"],
                    ["34h", "Capabilities Pointer"],
                    ["3Ch", "Interrupt Line / Interrupt Pin"],
                ]),
                .heading("Type 1 ヘッダ（ブリッジ）"),
                .text("ルートポートやスイッチのポートは Type 1 ヘッダを持ちます。BAR は2つだけで、代わりに次のような転送範囲の設定があります。"),
                .bullets([
                    "**Primary / Secondary / Subordinate Bus Number**（18h）：自分の上流バス、直下のバス、配下の最大バス番号",
                    "**Memory Base / Limit**（20h）：下流へ転送するメモリアドレス範囲",
                    "**64-bit Memory Base / Limit**（24h〜、上位32ビットは 28h/2Ch）：64ビット対応のメモリ範囲。以前の版では Prefetchable Memory Base / Limit と呼ばれていた",
                    "**I/O Base / Limit**（1Ch）",
                ]),
                .heading("BARのサイズ判定"),
                .bullets([
                    "BAR に全ビット1（`FFFFFFFFh`）を書き込み、読み戻す",
                    "下位の属性ビット（メモリBARは下位4ビット）をマスクし、ビット反転して +1 するとサイズになる",
                    "bit0：0=メモリ、1=I/O。bit[2:1]：00=32bit、10=64bit（次のBARと対）。bit3：以前は Prefetchable だったが 7.1 では定義なし（互換性のため、64ビットBARでは1、32ビットBARでは0が強く推奨）",
                ]),
                .figure("""
                read back : FFF0000Ch
                mask      : FFF00000h
                size      : ~FFF00000h + 1 = 00100000h (1 MB)
                attr (Ch) : 64-bit (bit3=1, legacy)
                """),
                .heading("列挙（Enumeration）"),
                .bullets([
                    "ファームウェアや OS は Bus 0 から **深さ優先** でデバイスを探します",
                    "Vendor ID を読んで `FFFFh` なら、そこには何もいません",
                    "Type 1 ヘッダ（ブリッジ）を見つけたら、次のバス番号を Secondary に割り当て、Subordinate を一時的に FFh にして下流を探索し、戻ってきたら確定値を書き込みます",
                    "Type 0 のコンフィグ要求は直下のデバイス用、**Type 1 は下流へ転送用** で、宛先バスに着いたブリッジが Type 0 に変換します",
                ]),
                .heading("Capability"),
                .table(header: ["名前", "ID", "空間"], rows: [
                    ["Power Management", "01h", "PCI互換"],
                    ["MSI", "05h", "PCI互換"],
                    ["PCI Express", "10h", "PCI互換"],
                    ["MSI-X", "11h", "PCI互換"],
                    ["AER", "0001h", "拡張"],
                    ["ACS", "000Dh", "拡張"],
                    ["ARI", "000Eh", "拡張"],
                    ["ATS", "000Fh", "拡張"],
                    ["SR-IOV", "0010h", "拡張"],
                    ["DPC", "001Dh", "拡張"],
                    ["L1 PM Substates", "001Eh", "拡張"],
                ]),
                .note("Capability は連結リストです。PCI 互換領域は 34h のポインタから、拡張領域は 100h から順にたどります。「ツール」タブで ECAM アドレスと BAR サイズを計算できます。"),
            ]
        ),
        Chapter(
            id: "interrupts",
            number: 11,
            title: "割り込みと電源管理",
            summary: "INTx・MSI・MSI-X、D状態とL状態、ASPM",
            level: .advanced,
            symbol: "bolt",
            blocks: [
                .heading("割り込みの3方式"),
                .table(header: ["方式", "仕組み", "ベクタ数"], rows: [
                    ["INTx", "Assert/Deassert_INTx メッセージで旧PCIの割り込み線を模倣", "4本（共有）"],
                    ["MSI", "決められたアドレスへのメモリ書き込みが割り込みになる", "最大32"],
                    ["MSI-X", "BAR内のテーブルにベクタごとのアドレス・データ・マスク", "最大2048"],
                ]),
                .bullets([
                    "PCIe には割り込み専用の信号線がありません。MSI/MSI-X は **ただの MWr TLP** なので、他のデータと同じ経路・順序規則で届きます",
                    "そのため「データを書いてから割り込みを送る」とき、割り込みがデータを追い越さないことが順序規則で保証されます",
                    "MSI-X はベクタごとに宛先 CPU を変えられるため、マルチキューの NIC や NVMe で必須級の機能です",
                    "MSI-X テーブルと **PBA（Pending Bit Array）** は、デバイスの BAR 空間内に置かれます",
                ]),
                .heading("デバイスの電源状態（D状態）"),
                .table(header: ["状態", "内容"], rows: [
                    ["D0", "動作中"],
                    ["D1 / D2", "中間の省電力状態（任意）"],
                    ["D3hot", "電源は来ているが機能停止。コンフィグアクセスは可能"],
                    ["D3cold", "主電源オフ"],
                ]),
                .heading("リンクの電源状態（L状態）"),
                .table(header: ["状態", "内容", "復帰"], rows: [
                    ["L0", "通常動作", "—"],
                    ["L0s", "片方向ずつ送信を止める（Flit Modeでは使えない）", "FTSで非常に速い"],
                    ["L1", "両方向停止", "Recovery経由"],
                    ["L1.1 / L1.2", "L1のサブステート。より深く省電力", "さらに遅い"],
                    ["L2 / L3", "補助電源のみ／電源オフ", "再初期化"],
                ]),
                .heading("ASPMとソフトウェア制御"),
                .bullets([
                    "**ASPM（Active State Power Management）**：アイドルを検出したハードウェアが自律的に L0s / L1 に入る（Flit Mode では L0s は使えず、代わりに L0p でレーン数を減らす）",
                    "**PCI-PM（ソフトウェア制御）**：OS がデバイスを D3hot にすると、リンクは L1 に移行する",
                    "**L1 PM Substates**：L1.2 では受信器の検出回路まで止め、**CLKREQ#** 信号で復帰を合図する。ノートPCのバッテリ持ちに大きく影響",
                    "**LTR（Latency Tolerance Reporting）**：デバイスが許容できる遅延を通知し、プラットフォームがどこまで深く眠れるか判断する",
                ]),
                .heading("ウェイクアップ"),
                .text("D3 状態のデバイスは **PME（Power Management Event）** を使ってシステムを起こします。リンクが生きていれば PM_PME メッセージを送り、L2 のように止まっている場合は **WAKE#** 信号（または Beacon）でプラットフォームに通知します。"),
                .note("省電力状態は復帰遅延とのトレードオフです。低遅延が重要なサーバでは ASPM を無効にすることも多くあります。"),
            ]
        ),
        Chapter(
            id: "ordering",
            number: 12,
            title: "順序規則・QoS・エラー処理",
            summary: "追い越しルール、TC/VC、AER",
            level: .advanced,
            symbol: "exclamationmark.triangle",
            blocks: [
                .heading("なぜ順序規則が必要か"),
                .text("PCIe はパケットをバッファリングして転送するため、TLP がどの順序で届くかをルール化しないと、ソフトウェアが正しく動きません。基本となるのは **プロデューサ・コンシューマモデル** の保証です：「データを書いてからフラグを書く」と、フラグを見た側は必ず新しいデータを読めます。"),
                .heading("主な追い越しルール（属性なしの場合）"),
                .bullets([
                    "Posted Write は前の Posted Write を **追い越さない**",
                    "Read Request は前の Posted Write を **追い越さない** → 書いた後に読めば書き込みが反映済み（読み出しによる **write flush**）",
                    "Completion は前の Posted Write を **追い越さない**",
                    "Posted Write は、詰まっている Non-Posted Request を **追い越せなければならない**（そうしないとデッドロックが起きうる）。Completion を追い越すことは許されているが、必須ではない（PCI/PCI-X ブリッジ方向などの例外を除く）",
                ]),
                .heading("順序を緩める属性"),
                .bullets([
                    "**Relaxed Ordering（RO）**：Posted Write どうし等の追い越しを許可し、性能を上げる",
                    "**ID-Based Ordering（IDO）**：送信元（Requester ID）が異なる TLP 間の順序を問わない",
                    "**No Snoop（NS）**：CPU キャッシュのスヌープを不要とする（順序ではなくキャッシュコヒーレンシの属性）",
                ]),
                .heading("QoS：TCとVC"),
                .text("TLP には **TC（Traffic Class：0〜7）** が付き、各ポートで **VC（Virtual Channel）** にマッピングされます。VC ごとにバッファとフロー制御が独立しているため、あるトラフィックが詰まっても別の VC は流れ続けます。順序規則は同じ TC 内でのみ適用されます。多くのシステムは TC0 / VC0 だけを使います。"),
                .heading("エラーの分類"),
                .table(header: ["分類", "例", "対応"], rows: [
                    ["Correctable", "Receiver Error, Bad TLP, Bad DLLP, Replay Timeout", "ハードウェアが自動回復"],
                    ["Uncorrectable Non-Fatal", "Poisoned TLP, Completion Timeout, Unsupported Request, ECRC Error", "そのトランザクションのみ失敗。リンクは健全"],
                    ["Uncorrectable Fatal", "Data Link Protocol Error, Malformed TLP, Receiver Overflow, Surprise Down", "リンクの信頼性が失われる。リセットが必要"],
                ]),
                .heading("エラーの報告"),
                .bullets([
                    "検出したデバイスは **ERR_COR / ERR_NONFATAL / ERR_FATAL** メッセージをルートポートへ送ります",
                    "**AER（Advanced Error Reporting）** 拡張 Capability に、詳細なステータスと問題の TLP ヘッダ（Header Log）が記録されます",
                    "OS の AER ドライバが割り込みで通知を受け、ログ出力やデバイスのリセット・復旧を行います",
                    "**DPC（Downstream Port Containment）**：致命的エラー時にダウンストリームポートがリンクを自動で切り離し、エラーの波及を防ぎます",
                ]),
                .note("Linux の `dmesg` に出る「PCIe Bus Error: severity=Corrected, type=Physical Layer」のようなログは AER によるものです。Correctable が大量に出る場合は、信号品質の問題を疑いましょう。"),
            ]
        ),
        Chapter(
            id: "virtualization",
            number: 13,
            title: "仮想化支援（SR-IOVなど）",
            summary: "PF/VF、ARI、ATS、ACS",
            level: .advanced,
            symbol: "square.on.square",
            blocks: [
                .text("クラウドや仮想化環境では、1つの物理デバイスを複数の仮想マシン（VM）で効率よく共有する必要があります。PCIe にはそのための機能がいくつも定義されています。"),
                .heading("SR-IOV（Single Root I/O Virtualization）"),
                .bullets([
                    "**PF（Physical Function）**：SR-IOV Capability を持つ完全な機能。VF の作成や管理を担う",
                    "**VF（Virtual Function）**：データ転送に必要な最小限のリソースを持つ軽量な Function。独自の BDF を持つ",
                    "VF を VM に直接割り当てる（パススルー、Linux では VFIO）ことで、ハイパーバイザを介さずにほぼネイティブ性能が出ます",
                    "VF の数は PF の設定で変えられます（例：Linux の `sriov_numvfs`）",
                ]),
                .figure("""
                       [ SR-IOV NIC ]
                   PF0     VF0   VF1   VF2 ...
                    |       |     |     |
                  Host     VM1   VM2   VM3
                """),
                .heading("ARI（Alternative Routing-ID Interpretation）"),
                .text("通常の BDF では1デバイスあたり8 Function までですが、ARI を有効にすると Device 番号の5ビットと Function 番号の3ビットを合わせて **8ビットの Function 番号** として扱い、最大256 Function を使えます。多数の VF を持つデバイスに必要です。"),
                .heading("IOMMUとアドレス変換"),
                .bullets([
                    "**IOMMU**（Intel VT-d、AMD-Vi など）は、デバイスが出す DMA アドレスを変換し、VM が他の VM のメモリにアクセスしないよう保護します",
                    "**ATS（Address Translation Services）**：デバイスが IOMMU に変換を事前に問い合わせ、自身の **ATC（Address Translation Cache）** にキャッシュします",
                    "**PRI（Page Request Interface）**：変換先のページが存在しない場合に、デバイスがページの用意を要求できます",
                    "**PASID**：同じデバイス内でアドレス空間（プロセス）を区別するための ID を TLP に付加します",
                ]),
                .heading("ACS（Access Control Services）"),
                .text("スイッチの配下にあるデバイス同士は、通常は RC を経由せず **ピアツーピア** で直接通信できます。これは VM 間の隔離を破る恐れがあるため、ACS でピアツーピア要求を強制的に上流（RC と IOMMU）へリダイレクトします。ACS の有無は Linux の **IOMMU グループ** の分かれ方に影響します。"),
                .note("SR-IOV は VF 単位でパススルーするため、VM のライブマイグレーションが難しくなるというトレードオフがあります。"),
            ]
        ),
        Chapter(
            id: "gen6",
            number: 14,
            title: "Gen6以降と最新動向",
            summary: "PAM4、FLITモード、FEC、L0p、CXL",
            level: .advanced,
            symbol: "sparkles",
            blocks: [
                .heading("PAM4"),
                .text("Gen5 までは0と1の2値（**NRZ**）で送っていましたが、Gen6 は4つの電圧レベルで1シンボルあたり2ビットを送る **PAM4** を採用しました。シンボルレートは Gen5 と同じ 32 GBaud のまま、データレートを 64 GT/s に倍増しています。"),
                .figure("""
                NRZ : 2 levels, 1 bit/UI   |  _|‾|_
                PAM4: 4 levels, 2 bit/UI   |  11 10 01 00
                """),
                .text("代償として、電圧レベル間の間隔（アイ開口）が約1/3になり、ビット誤り率が大きく上がります（FBER 約 10⁻⁶）。そのため **FEC（前方誤り訂正）** が必須になりました。"),
                .heading("FLITモード"),
                .text("Gen6 では可変長の TLP をそのまま送るのではなく、**256バイト固定長の FLIT** に詰めて送ります。"),
                .table(header: ["領域", "バイト数"], rows: [
                    ["TLP", "236"],
                    ["DLP（データリンク層情報）", "6"],
                    ["CRC", "8"],
                    ["FEC", "6"],
                ]),
                .bullets([
                    "ACK/NAK と再送は FLIT 単位になり、TLP ごとの LCRC・シーケンス番号は不要になりました",
                    "軽量な FEC で大半のエラーを訂正し、残りは CRC で検出して再送します。低遅延を保つため FEC はあえて弱めに設計されています",
                    "Sync Header が不要になり、符号化は **1b/1b**（オーバーヘッドなし）",
                    "FLIT モードでは TLP ヘッダ形式も刷新され、Tag は14ビットに拡張されています",
                    "Gen6 対応デバイスどうしなら、低い速度でも FLIT モードで動作できます",
                ]),
                .heading("L0p"),
                .text("**L0p** は Gen6 で追加された省電力状態で、リンクを止めずに使用レーン数を動的に減らします（例：x16 → x4）。帯域が要らないときの消費電力を、トラフィックを中断せずに削減できます。"),
                .heading("Gen7 とその先"),
                .bullets([
                    "**PCIe 7.0**（2025年に正式版、仕様書の日付は2025年5月29日）：128 GT/s、PAM4 と FLIT を継承。x16 で片方向 256 GB/s（生の値）。詳しくは第15章",
                    "主な用途は AI/ML アクセラレータ、800G/1.6T イーサネット、データセンター向けストレージ",
                    "PCI-SIG は 256 GT/s を目標に次世代（PCIe 8.0）の策定を進めています",
                    "高速化で基板損失が増えるため、信号を再生成する **リタイマ** や、光接続の検討も進んでいます",
                ]),
                .heading("CXL（Compute Express Link）"),
                .text("**CXL** は PCIe の物理層の上で動くキャッシュコヒーレントなインターコネクトです。PCIe スロットと同じ形状で、リンクトレーニング時に CXL モードを交渉します。"),
                .table(header: ["プロトコル", "用途"], rows: [
                    ["CXL.io", "PCIe と同等（列挙・設定・DMA）"],
                    ["CXL.cache", "デバイスがホストメモリをコヒーレントにキャッシュ"],
                    ["CXL.mem", "ホストがデバイス上のメモリを通常のメモリとして使う"],
                ]),
                .note("CXL 3.x は PCIe 6.x の 64 GT/s・FLIT 方式をベースにしています。メモリ拡張やメモリプーリングの用途で採用が進んでいます。"),
            ]
        ),
        Chapter(
            id: "pcie7",
            number: 15,
            title: "PCIe 7.0の新機能",
            summary: "128 GT/s、イコライゼーション手順、TLPs per Half Flit、新レジスタ",
            level: .advanced,
            symbol: "7.circle",
            blocks: [
                .text("仕様書（Base 7.1）の「Status of this Document」と改版履歴によると、**PCIe 7.0 は 6.4 と同じ ECN・エラッタを含み、そこに 128.0 GT/s に関する変更を加えたもの** です。7.0 と 6.4 の差分を示す Change Bar 版も「編集上の変更と 128.0 GT/s 関連の変更」を示すものとされています。つまり 7.0 の新機能は、ほぼすべて **128.0 GT/s を実現するための仕組み** です。"),
                .note("7.1 は 7.0 にエラッタと承認済み ECN を加えた版です。128.0 GT/s に関係しない 7.1 の ECN とエラッタは 6.5 にも含まれています。"),

                .heading("128.0 GT/s の信号方式"),
                .table(header: ["項目", "6.x（64.0 GT/s）", "7.0（128.0 GT/s）"], rows: [
                    ["変調", "PAM4", "PAM4"],
                    ["符号化", "1b/1b", "1b/1b"],
                    ["シンボルレート（計算値）", "32 GBaud", "64 GBaud"],
                    ["データストリーム", "Flit Mode", "Flit Mode"],
                    ["x16 の片方向（生の値）", "128 GB/s", "256 GB/s"],
                ]),
                .text("変調・符号化・FLIT の構造は 64.0 GT/s と同じで、シンボルレートを倍にしています。64.0 GT/s 以上のデータレートでは必ず Flit Mode を使い、データストリームも Ordered Set もすべて PAM4 で送ります。"),
                .text("送信側の処理順序は、Flit 単位で **CRC → FEC** を付け、バイト単位で各レーンに振り分けたあと、レーンごとに **スクランブル → グレイ符号化（2ビット単位）→ プリコーディング（有効な場合）→ PAM4 の電圧レベル** の順です。"),
                .figure("""
                Flit : TLP + DLP -> CRC -> FEC      (256 B)
                        | byte-interleave to lanes
                Lane : scramble -> Gray code -> precode -> PAM4
                """),

                .heading("イコライゼーションの手順"),
                .text("イコライゼーションは 8.0 → 16.0 → 32.0 → 64.0 → 128.0 GT/s の順に、1つずつ成功させていきます。7.0 では次のルールが加わりました。"),
                .bullets([
                    "**128.0 GT/s のイコライゼーション（やり直しを含む）は、64.0 GT/s で動作している状態からしか始められない**",
                    "同様に 64.0 GT/s のイコライゼーションは 32.0 GT/s からのみ。2.5 / 5.0 GT/s から 64.0 / 128.0 GT/s へ直接イコライゼーションすることはできない",
                    "128.0 GT/s で動作中に 128.0 GT/s のイコライゼーションをやり直すことはできない（64.0 GT/s も同様）",
                    "両端が対応していれば、8.0 / 16.0 GT/s を飛ばして 32.0 GT/s から始める **Equalization Bypass to Highest NRZ Rate** が使える。例：2.5 GT/s で L0 → 32.0 GT/s でイコライゼーション → 64.0 → 128.0 GT/s",
                    "フェーズ（Phase 0〜3）の情報は TS0 または TS1 Ordered Set の EC フィールドで伝え、128.0 GT/s 用の送信プリセットは **1b/1b EQ TS2** Ordered Set で伝える",
                ]),
                .figure("""
                2.5 GT/s L0
                  -> EQ @ 8.0 -> 16.0 -> 32.0      (NRZ)
                  -> EQ @ 64.0   (start from 32.0 only)
                  -> EQ @ 128.0  (start from 64.0 only)
                """),

                .heading("送受信のイコライザ"),
                .table(header: ["", "8.0〜32.0 GT/s", "64.0 / 128.0 GT/s"], rows: [
                    ["送信 FIR", "3タップ（c-1, c0, c+1）", "4タップ（c-2, c-1, c0, c+1）。プレカーソルが2つ"],
                    ["係数の制約", "c-1, c+1 は0以下", "c-2 は0以上、c-1, c+1 は0以下"],
                ]),
                .text("仕様が定める参照受信器（behavioral Rx）は、128.0 GT/s で大きく変わりました。64.0 GT/s までは CTLE と DFE の組み合わせでしたが、128.0 GT/s では **受信側の等化の大部分を FFE（フィードフォワード等化器）が担います**。"),
                .bullets([
                    "**CTLE**：6つの極と3つのゼロを持ち、DCゲインは 0〜-15 dB を 1 dB 刻みで調整",
                    "**FFE**：29タップの FIR フィルタ（プレカーソル4、ポストカーソル24）",
                    "**DFE**：特定の伝送路で有利なため、1タップだけ参照イコライザに含まれる",
                ]),

                .heading("プリコーディング"),
                .text("32.0 GT/s 以上では、受信側が送信側にプリコーディングを要求できます。要求は速度ごとに独立していて、その速度に切り替える前（Recovery.Speed に入る前）の EQ TS2 系 Ordered Set の **Transmitter Precode Request** ビットで行います。128.0 GT/s では 1b/1b EQ TS2 を使います。有効になったかどうかは 128.0 GT/s Status Register の **Transmitter Precoding On 128.0 GT/s** ビットで確認できます。"),

                .heading("TLPs per Half Flit"),
                .text("Flit の TLP 領域（236バイト）は前半（バイト0〜127）と後半（バイト128〜235）に分かれ、それぞれに詰めてよい TLP の数に上限があります。受信側は自分の要求を Data Link Feature DLLP の **TLPs per Half Flit** フィールドで伝え、送信側はそれに従います。"),
                .table(header: ["値", "意味"], rows: [
                    ["00b", "どのデータレートでも、半 Flit あたり8 TLP まで"],
                    ["01b", "両端に共通する最高のデータレートが 128.0 GT/s 以上なら、どのデータレートでも半 Flit あたり4 TLP まで。それ以外は8 TLP まで"],
                    ["1xb", "予約（送信側は 01b として扱う）"],
                ]),
                .bullets([
                    "途中まで入った TLP も1個として数える",
                    "受信側はこのルールをチェックしてよく、違反は Data Link Protocol Error として記録される",
                    "Payload Flit を送り始めた後に上限が変わると、再送バッファ内の Flit が新しい上限に合わず致命的になりうるため、128.0 GT/s で動かすポートはできるだけ早く（LinkUp=0 の Configuration.Complete の時点で）128.0 GT/s を広告することが強く推奨されている",
                ]),

                .heading("ソフトウェアから見える変更"),
                .text("128.0 GT/s の追加に合わせて、速度を表すレジスタが拡張されました。"),
                .bullets([
                    "**Link Capabilities 2 の Supported Link Speeds Vector**：bit 5 が 64.0 GT/s、**bit 6 は「128.0 GT/s 以上」**を意味し、詳細は新しい **Supported Link Speeds Vector 2** に書かれる",
                    "**Current Link Speed（Link Status）**：0001b〜0110b が従来の Vector の bit 0〜5 に対応し、**1000b が Vector 2 の bit 0（= 128.0 GT/s）**。0111b は予約",
                    "**Physical Layer 128.0 GT/s Extended Capability**（ID **0039h**）を新設。128.0 GT/s に対応するポートは実装が必要",
                ]),
                .table(header: ["オフセット", "レジスタ", "主な内容"], rows: [
                    ["04h", "128.0 GT/s Capabilities", "Supported Link Speeds Vector 2（bit 0 = 128.0 GT/s）、Lower SKP OS 生成／受信の対応速度"],
                    ["08h", "128.0 GT/s Control", "現在はすべて予約"],
                    ["0Ch", "128.0 GT/s Status", "Equalization Complete、Phase 1〜3 Successful、Link Equalization Request、Transmitter Precoding On、Transmitter Precode Request、No Equalization Needed Received"],
                    ["10h〜", "128.0 GT/s Lane Equalization Control", "レーンごとの送信プリセット"],
                ]),
                .note("128.0 GT/s のパリティエラーは、新しいレジスタではなく既存の 16.0 GT/s Data Parity Mismatch Status レジスタ群に記録されます。速度ごとに集計したいときは、速度変更のたびにソフトウェアでクリアする必要があります。"),

                .heading("7.0 に含まれる 6.x 以降の主な機能"),
                .text("7.0 は 6.4 までの ECN をすべて含むので、6.x の間に追加された次の機能も 7.0 の一部です。"),
                .table(header: ["機能", "内容"], rows: [
                    ["UIO（Unordered I/O）", "順序規則に縛られない専用の仮想チャネル。UIO の Request はすべて Completion が必要"],
                    ["TDISP", "TEE Device Interface Security Protocol。機密計算（TEE）向けにデバイスの機能を安全に割り当てる"],
                    ["SIOV", "Scalable I/O Virtualization。SR-IOV の後継として位置付けられる仮想化の仕組み"],
                    ["Optical Aware Retimer", "光技術を部分的に含むリンクを、リタイマを使って延長する仕組み"],
                    ["Removing Prefetchable", "Prefetchable／Non-Prefetchable という用語を仕様から整理（BAR の bit 3 は定義なしに）"],
                ]),
                .text("さらに 7.1 では、CMA（Component Measurement and Authentication）に耐量子暗号（PQC）のアルゴリズムを加える ECN などが取り込まれています。"),
            ]
        ),
    ]
}
