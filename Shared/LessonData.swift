import Foundation

enum LessonData {
    static let all: [Chapter] = beginner + intermediate + advanced

    static func chapter(id: String) -> Chapter? {
        all.first { $0.id == id }
    }

    static func next(after chapter: Chapter) -> Chapter? {
        guard let i = all.firstIndex(of: chapter), i + 1 < all.count else { return nil }
        return all[i + 1]
    }

    // MARK: - 入門

    static let beginner: [Chapter] = [
        Chapter(
            id: "intro",
            number: 1,
            title: "PCIeとは",
            summary: "シリアル・ポイントツーポイントの高速インターフェース",
            level: .beginner,
            symbol: "cpu",
            blocks: [
                .text("**PCI Express（PCIe）** は、CPU と GPU・SSD・NIC などの周辺デバイスをつなぐ高速シリアルインターフェースです。業界団体 **PCI-SIG** が仕様を策定しており、2002年に最初の仕様（1.0）が公開されて以来、世代ごとに1レーンあたりの転送速度をおおむね倍にしてきました。"),
                .heading("旧来のPCIとの違い"),
                .table(header: ["項目", "PCI", "PCIe"], rows: [
                    ["伝送方式", "パラレル", "シリアル（差動信号）"],
                    ["接続形態", "共有バス", "ポイントツーポイント"],
                    ["方向", "半二重", "全二重（送受信が独立）"],
                    ["クロック", "専用のクロック線", "データに埋め込み"],
                    ["通信単位", "バスサイクル", "パケット"],
                ]),
                .text("パラレルバスは周波数を上げると信号線間のタイミングずれ（スキュー）が問題になります。PCIe は少数の差動ペアを高速に動かし、受信側でデータからクロックを復元（CDR）することでこの限界を超えました。"),
                .heading("レーンとリンク"),
                .text("**レーン** は「送信用の差動ペア＋受信用の差動ペア」の計4本の信号線です。複数のレーンを束ねたものを **リンク** と呼び、レーン数を x1, x2, x4, x8, x16 のように表記します。"),
                .figure("""
                 Device A                  Device B
                +--------+   TX+/TX-    +--------+
                |        | -----------> |        |
                |        |   RX+/RX-    |        |
                |        | <----------- |        |
                +--------+              +--------+
                 1 lane = 2 differential pairs
                """),
                .bullets([
                    "x16 はグラフィックスカード、x4 は NVMe SSD、x1 は小型の拡張カードでよく使われます",
                    "送信と受信は独立しているため、上り・下りを同時にフル帯域で使えます",
                    "リンク幅と速度は、両端がサポートする範囲で起動時に自動的に決まります",
                ]),
                .heading("PCIeの主な特徴"),
                .bullets([
                    "**ソフトウェア互換**：PCI のコンフィグレーション空間モデルを継承しているため、OS やドライバの仕組みをそのまま使えます",
                    "**パケット通信**：データはヘッダ付きのパケット（TLP）としてやり取りします",
                    "**高信頼**：CRC によるエラー検出と、ハードウェアによる自動再送を備えています",
                    "**拡張性**：ホットプラグ、電源管理、仮想化支援（SR-IOV）などを標準で定義しています",
                ]),
                .note("**GT/s（ギガトランスファ毎秒）** は1レーンが1秒間に何ギガ回ビットを送るかという生の速度です。符号化のオーバーヘッドを含むため、実際のデータ速度（GB/s）とは異なります。"),
            ]
        ),
        Chapter(
            id: "topology",
            number: 2,
            title: "トポロジとデバイス",
            summary: "Root Complex・スイッチ・エンドポイントとBDF",
            level: .beginner,
            symbol: "point.3.connected.trianglepath.dotted",
            blocks: [
                .text("PCIe のシステムは、CPU 側を根とする **ツリー構造** になっています。ツリーを構成する部品は主に次の3種類です。"),
                .heading("構成要素"),
                .bullets([
                    "**Root Complex（RC）**：CPU・メモリと PCIe 階層をつなぐ根。1つ以上の **ルートポート** を持ちます",
                    "**Switch（スイッチ）**：1つのアップストリームポートと複数のダウンストリームポートを持ち、パケットを中継します。ソフトウェアからは複数の仮想 PCI-PCI ブリッジに見えます",
                    "**Endpoint（EP）**：GPU、NVMe SSD、NIC などツリーの末端にあるデバイス",
                ]),
                .figure("""
                          CPU
                           |
                  +-----------------+
                  |  Root Complex   |--- Memory
                  +-----------------+
                   | RP1         | RP2
               [Endpoint]   +--------+
                 (GPU)      | Switch |
                            +--------+
                             |      |
                        [Endpoint] [Endpoint]
                          (NVMe)     (NIC)
               """),
                .text("CPU に近い方向を **アップストリーム**、遠い方向を **ダウンストリーム** と呼びます。PCIe はポイントツーポイント接続なので、1本のリンクには必ず2つのポートしかつながりません。"),
                .heading("BDF（Bus / Device / Function）"),
                .text("各デバイスの機能（Function）は、16ビットの **BDF** で一意に識別されます。この値はパケットの送信元（Requester ID）や応答元（Completer ID）としても使われます。"),
                .table(header: ["フィールド", "ビット数", "範囲"], rows: [
                    ["Bus", "8", "0–255"],
                    ["Device", "5", "0–31"],
                    ["Function", "3", "0–7"],
                ]),
                .bullets([
                    "表記例：`01:00.0` は Bus 1, Device 0, Function 0",
                    "1つのデバイスが複数の Function を持つものを **マルチファンクションデバイス** と呼びます（例：デュアルポートNIC）",
                    "リンクの先には1デバイスしかいないため、通常 Device 番号は 0 です。**ARI** を使うと Device 番号の5ビットも Function 番号に回し、最大256 Function を扱えます",
                ]),
                .heading("Endpointの種類"),
                .bullets([
                    "**PCI Express Endpoint**：一般的な PCIe デバイス",
                    "**Legacy Endpoint**：I/O 空間やロック付きアクセスなど旧来の機能を使うもの",
                    "**RCiEP（Root Complex Integrated Endpoint）**：チップセットやSoC内部に統合され、リンクを持たないEP",
                ]),
                .note("Linux では `lspci -tv` でツリー構造を、`lspci -s 01:00.0 -vv` で個別デバイスの詳細を確認できます。"),
            ],
            diagram: .topology
        ),
        Chapter(
            id: "generations",
            number: 3,
            title: "世代と転送速度",
            summary: "Gen1〜Gen7の速度と符号化方式",
            level: .beginner,
            symbol: "speedometer",
            blocks: [
                .text("PCIe は世代（Generation）ごとに1レーンあたりの転送速度がおおむね倍になってきました。"),
                .table(header: ["世代", "仕様公開", "速度", "符号化", "x16 片方向"], rows: [
                    ["1.0", "2002", "2.5 GT/s", "8b/10b", "4 GB/s"],
                    ["2.0", "2006", "5.0 GT/s", "8b/10b", "8 GB/s"],
                    ["3.0", "2010", "8.0 GT/s", "128b/130b", "約15.8 GB/s"],
                    ["4.0", "2017", "16 GT/s", "128b/130b", "約31.5 GB/s"],
                    ["5.0", "2019", "32 GT/s", "128b/130b", "約63 GB/s"],
                    ["6.0", "2021", "64 GT/s", "PAM4 + FLIT", "128 GB/s ※"],
                    ["7.0", "2025", "128 GT/s", "PAM4 + FLIT", "256 GB/s ※"],
                ]),
                .note("※ Gen6 以降は符号化オーバーヘッドがない（1b/1b）ため生の値を示しています。実際には固定長 FLIT 内の CRC・FEC などの分だけ実効帯域は下がります（詳細は「Gen6以降と最新動向」の章）。"),
                .heading("符号化方式"),
                .bullets([
                    "**8b/10b**（Gen1/2）：8ビットを10ビットのシンボルに変換。DCバランスとクロック復元のための遷移を確保できる反面、効率は **80%**",
                    "**128b/130b**（Gen3〜5）：128ビットごとに2ビットの **Sync Header** を付けるだけ。効率は **約98.5%**。遷移の確保はスクランブルで行います",
                    "**PAM4 + FLIT**（Gen6〜）：1シンボルで2ビットを送る4値変調と、固定長パケット（FLIT）＋FECの組み合わせ",
                ]),
                .heading("帯域幅の計算"),
                .figure("""
                BW (GB/s, one direction)
                  = GT/s x efficiency x lanes / 8

                ex) Gen4 x4
                  = 16 x (128/130) x 4 / 8
                  = 7.88 GB/s
                """),
                .text("Gen3 で速度の伸びが 5→8 GT/s と2倍未満なのは、符号化効率の改善（80%→98.5%）と合わせて実効帯域をほぼ倍にしたためです。"),
                .heading("後方互換性"),
                .bullets([
                    "リンクは、両端がサポートする **最も高い世代** と **最も広い幅** で動作します",
                    "Gen5 対応カードを Gen3 スロットに挿すと Gen3 速度で動作します",
                    "x16 スロットに x4 カードを挿すことも、x16 形状で配線が x4 のスロットもあります",
                ]),
                .note("「ツール」タブの帯域幅計算機で、世代とレーン数を変えて試してみましょう。"),
            ]
        ),
        Chapter(
            id: "layers",
            number: 4,
            title: "3つのレイヤ",
            summary: "トランザクション層・データリンク層・物理層",
            level: .beginner,
            symbol: "square.stack.3d.up",
            blocks: [
                .text("PCIe の通信機能は、ネットワークプロトコルのように **3つの層** に分かれています。上位層が作ったパケットを、下位層が情報を付け足して包んでいきます（カプセル化）。"),
                .heading("各層の役割"),
                .table(header: ["層", "主な役割"], rows: [
                    ["トランザクション層", "TLPの生成と解釈、フロー制御、順序規則、QoS（TC/VC）、ECRC（任意）"],
                    ["データリンク層", "シーケンス番号とLCRCの付加、ACK/NAKによる再送、DLLPの送受信"],
                    ["物理層", "フレーミング、符号化、スクランブル、リンク初期化（LTSSM）、電気信号"],
                ]),
                .heading("カプセル化のイメージ（Gen1/2）"),
                .figure("""
                TL :            [Hdr | Data | ECRC]
                DLL:     [Seq# | Hdr | Data | ECRC | LCRC]
                PHY: [STP| Seq# | Hdr | Data | ECRC | LCRC |END]
                """),
                .text("受信側では逆に、物理層がフレームを取り出し、データリンク層が LCRC とシーケンス番号を確認し、正しければトランザクション層に TLP を渡します。"),
                .heading("3種類のパケット"),
                .bullets([
                    "**TLP（Transaction Layer Packet）**：読み書きなど実際の仕事を運ぶ。送信元から宛先まで **スイッチを越えて** 届く",
                    "**DLLP（Data Link Layer Packet）**：ACK/NAK、フロー制御クレジット、電源管理など。**隣り合う2ポート間のみ**",
                    "**Ordered Set**：物理層が生成するリンク制御用の符号列（TS1/TS2、SKP など）。こちらも1リンク内のみ",
                ]),
                .heading("物理層の2つのサブブロック"),
                .bullets([
                    "**論理サブブロック**：フレーミング、符号化、スクランブル、レーン間デスキュー、LTSSM",
                    "**電気サブブロック**：差動ドライバ／レシーバ、イコライゼーション、クロック復元",
                ]),
                .note("エラー検出は二段構えです。LCRC はリンクごとに付け直され1リンク区間を守り、ECRC は送信元から宛先まで変わらず end-to-end でデータを守ります。"),
            ],
            diagram: .layers
        ),
    ]

    // MARK: - 中級

    static let intermediate: [Chapter] = [
        Chapter(
            id: "tlp",
            number: 5,
            title: "TLP（トランザクション層パケット）",
            summary: "リクエストの種類、ヘッダ、Posted/Non-Posted",
            level: .intermediate,
            symbol: "shippingbox",
            blocks: [
                .text("TLP はトランザクション層が作るパケットで、メモリの読み書きや設定アクセスなど、PCIe 上の「仕事」はすべて TLP で表現されます。"),
                .heading("TLPの種類"),
                .table(header: ["種類", "略称", "区分"], rows: [
                    ["メモリリード", "MRd", "Non-Posted"],
                    ["メモリライト", "MWr", "Posted"],
                    ["I/Oリード／ライト", "IORd / IOWr", "Non-Posted"],
                    ["コンフィグリード／ライト", "CfgRd0/1, CfgWr0/1", "Non-Posted"],
                    ["メッセージ", "Msg / MsgD", "Posted"],
                    ["AtomicOp", "FetchAdd / Swap / CAS", "Non-Posted"],
                    ["遅延可能メモリライト", "DMWr", "Non-Posted"],
                    ["コンプリーション", "Cpl / CplD", "（応答）"],
                ]),
                .heading("Posted と Non-Posted"),
                .bullets([
                    "**Posted**：送ったら終わり。応答（Completion）を返さない。MWr と Message が該当（UIO の Request は例外で、すべて Completion を必要とします）",
                    "**Non-Posted**：必ず Completion が返る。読み出しはデータ付きの **CplD** で、IOWr・CfgWr は完了通知だけの **Cpl** で応答されます",
                    "MWr が Posted なのは性能のため。書き込みのたびに応答を待つと遅くなるからです",
                ]),
                .heading("ヘッダ形式"),
                .text("ヘッダは **3DW（12バイト）** または **4DW（16バイト）** です（1DW = 4バイト）。32ビットアドレスなら3DW、64ビットアドレスなら4DWを使います。先頭の **Fmt** フィールドが形式を示します。"),
                .table(header: ["Fmt", "意味"], rows: [
                    ["000", "3DWヘッダ、データなし"],
                    ["001", "4DWヘッダ、データなし"],
                    ["010", "3DWヘッダ、データあり"],
                    ["011", "4DWヘッダ、データあり"],
                    ["100", "TLP Prefix"],
                ]),
                .heading("主なヘッダフィールド"),
                .bullets([
                    "**Type**：Fmt と組み合わせて TLP の種類を決める（例：Fmt=010, Type=00000 → 32bit MWr）",
                    "**TC（Traffic Class）**：0–7 の優先度クラス",
                    "**Attr**：Relaxed Ordering、No Snoop、ID-Based Ordering の各属性",
                    "**TD**：ECRC（TLP Digest）が付いているか",
                    "**EP**：Poisoned（データが壊れていることを示す）",
                    "**Length**：ペイロード長（DW 単位、10ビット。0 は 1024DW = 4KB を意味する）",
                    "**Requester ID / Tag**：誰のどのリクエストかを識別。Completion はこの2つ（Transaction ID）で対応付けられます。Tag は8ビットが基本で、10ビット、Flit Mode では14ビットまで拡張できます",
                    "**First / Last DW BE**：最初と最後のDWのうち有効なバイトを示すバイトイネーブル",
                ]),
                .heading("サイズに関するルール"),
                .bullets([
                    "**MPS（Max Payload Size）**：1つの TLP に載せられる最大データ量。128〜4096バイトで、経路上のすべてのデバイスで共通の値に設定します",
                    "**MRRS（Max Read Request Size）**：1回の読み出し要求の最大サイズ",
                    "読み出しの応答は **RCB（Read Completion Boundary：64 または 128バイト）** 境界で複数の CplD に分割されることがあります",
                    "リクエストは **4KB のアドレス境界** をまたいではいけません",
                ]),
                .heading("Completionステータス"),
                .table(header: ["値", "意味"], rows: [
                    ["SC", "Successful Completion（成功）"],
                    ["UR", "Unsupported Request（未サポート）"],
                    ["CA", "Completer Abort（応答側で中止）"],
                    ["RRS", "Request Retry Status（準備中なので再試行して）。以前の版では CRS（Configuration Request Retry Status）と呼ばれていた"],
                ]),
                .note("「図解」タブの TLP ヘッダ構造で、各フィールドのビット位置を確認できます。"),
            ],
            diagram: .tlpHeader
        ),
        Chapter(
            id: "datalink",
            number: 6,
            title: "データリンク層とACK/NAK",
            summary: "シーケンス番号、LCRC、リプレイバッファ、DLLP",
            level: .intermediate,
            symbol: "arrow.triangle.2.circlepath",
            blocks: [
                .text("データリンク層の最大の仕事は、**1本のリンク上で TLP を確実に届けること** です。エラーが起きてもハードウェアが自動的に再送するため、ソフトウェアはビット誤りを意識せずに済みます。"),
                .heading("送信側の動き"),
                .bullets([
                    "TLP に **12ビットのシーケンス番号** と **32ビットの LCRC** を付けて送信",
                    "送った TLP は ACK が返るまで **リプレイバッファ** に保持",
                    "ACK を受けたら、その番号までの TLP をバッファから解放",
                    "NAK を受けたら、その番号より後の TLP を **すべて順に再送**（Go-Back-N 方式）",
                ]),
                .heading("受信側の動き"),
                .bullets([
                    "LCRC とシーケンス番号をチェック",
                    "正しく、期待した番号なら受け取り、**ACK** を返す（複数TLP分をまとめて返せる）",
                    "LCRC エラーなら TLP を捨てて **NAK** を返す。NAK には「最後に正しく受けた番号」が入る",
                    "すでに受け取った番号（重複）が来たら捨てて ACK を返す",
                ]),
                .figure("""
                 TX                          RX
                  |--- TLP #10 ------------>|  OK
                  |--- TLP #11 ------------>|  OK
                  |<-- ACK 11 --------------|  free #10,#11
                  |--- TLP #12 ----X        |  LCRC error
                  |--- TLP #13 ------------>|  discard
                  |<-- NAK 11 --------------|
                  |--- TLP #12 (replay) --->|  OK
                  |--- TLP #13 (replay) --->|  OK
                  |<-- ACK 13 --------------|
                """),
                .heading("タイマとカウンタ"),
                .bullets([
                    "**REPLAY_TIMER**：ACK/NAK が一定時間返らないと、リプレイバッファの内容を再送します（ACK 自体が壊れた場合の保険）",
                    "**REPLAY_NUM**：再送の回数を数えるカウンタ（Non-Flit Mode では3ビットで、再送のたびに2ずつ増える）。4回目の再送でロールオーバーすると、物理層にリンクの **再トレーニング（Recovery）** を要求し、それが終わってから再送を続けます",
                    "**AckNak_Latency_Timer**：受信側が ACK を返すまでの最大待ち時間。ACK をまとめる（coalescing）ことで帯域を節約します",
                ]),
                .heading("DLLP（データリンク層パケット）"),
                .text("DLLP は4バイトの内容（8ビットのタイプ＋24ビットの情報）と16ビットの CRC からなる短いパケットで、隣接ポート間でのみやり取りされます。Flit Mode では Flit 内の DLP バイトで運ばれ、DLLP 自体の CRC はありません。"),
                .table(header: ["DLLP", "用途"], rows: [
                    ["Ack / Nak", "TLPの受信確認・再送要求"],
                    ["InitFC1 / InitFC2", "フロー制御クレジットの初期化"],
                    ["UpdateFC", "解放したクレジットの通知"],
                    ["PM_Enter_L1 など", "電源管理のハンドシェイク"],
                    ["Vendor Specific", "ベンダ独自"],
                ]),
                .heading("データリンク層の状態"),
                .figure("""
                DL_Inactive --> (DL_Feature) --> DL_Init --> DL_Active
                 (link down)   (FC init)   (TLP OK)
                """),
                .text("物理層のリンクアップ後、（対応していれば）DL_Feature で Scaled Flow Control などの機能を交換し、DL_Init でフロー制御の初期化を済ませて **DL_Active** になると、TLP の送受信が可能になります。"),
                .note("ここで説明した TLP ごとのシーケンス番号・LCRC・ACK/NAK は **Non-Flit Mode** の仕組みです。Flit Mode（64 GT/s 以上では必須）では、再送は Flit 単位で行われます（第14章）。"),
                .note("「図解」タブの ACK/NAK シミュレータで、エラー注入や ACK 喪失を試してみましょう。"),
            ],
            diagram: .ackNak
        ),
        Chapter(
            id: "flowcontrol",
            number: 7,
            title: "フロー制御",
            summary: "クレジット方式による受信バッファ管理",
            level: .intermediate,
            symbol: "gauge.with.dots.needle.33percent",
            blocks: [
                .text("PCIe は **クレジットベースのフロー制御** を使います。受信側が「バッファにこれだけ空きがある」とあらかじめ通知し、送信側はクレジットが足りるときだけ TLP を送ります。これにより、受信バッファのあふれによる TLP の破棄が **原理的に起きません**。"),
                .heading("6種類のクレジット"),
                .table(header: ["種類", "ヘッダ", "データ"], rows: [
                    ["Posted（MWr, Msg）", "PH", "PD"],
                    ["Non-Posted（MRd, Cfg, IO）", "NPH", "NPD"],
                    ["Completion", "CplH", "CplD"],
                ]),
                .bullets([
                    "ヘッダクレジット 1 = TLP ヘッダ 1個分",
                    "データクレジット 1 = **16バイト（4DW）**",
                    "クレジットは **VC（仮想チャネル）ごと** に独立して管理されます",
                ]),
                .figure("""
                ex) MWr with 256-byte payload
                    PH : 1
                    PD : 256 / 16 = 16
                """),
                .heading("初期化と更新"),
                .bullets([
                    "リンクアップ直後、データリンク層が **InitFC1 → InitFC2** DLLP で初期クレジットを交換します",
                    "受信側は TLP を処理してバッファを空けるたびに **UpdateFC** DLLP で送信側に通知します",
                    "初期値 0 は **無限クレジット** を意味します。エンドポイントは Completion に対して無限クレジットを通知します（自分が出した読み出しの応答は必ず受け取れるように準備する）",
                ]),
                .heading("送信側と受信側のカウンタ"),
                .table(header: ["側", "カウンタ", "意味"], rows: [
                    ["送信", "CREDITS_CONSUMED", "これまでに消費したクレジット"],
                    ["送信", "CREDIT_LIMIT", "受信側から通知された上限"],
                    ["受信", "CREDITS_ALLOCATED", "送信側に許可した総量"],
                    ["受信", "CREDITS_RECEIVED", "実際に受け取った量"],
                ]),
                .text("カウンタは固定ビット幅で循環（ラップアラウンド）するため、送信可否は差分を剰余演算で比較して判定します。Gen4 以降では **Scaled Flow Control** により大きなクレジット値を扱えるようになりました。"),
                .note("クレジット不足はスループット低下の典型的な原因です。特に長距離リンクやリタイマ経由では往復遅延が増えるため、十分なクレジット（バッファ）が必要です。"),
            ]
        ),
        Chapter(
            id: "physical",
            number: 8,
            title: "物理層",
            summary: "差動信号、符号化、Ordered Set、イコライゼーション",
            level: .intermediate,
            symbol: "waveform.path",
            blocks: [
                .heading("電気的な仕組み"),
                .bullets([
                    "**差動信号**：2本の信号線の電位差で0/1を表すため、ノイズに強い",
                    "**AC結合**：送信側にコンデンサを入れ、直流成分を切る",
                    "**埋め込みクロック**：受信側は **CDR（Clock Data Recovery）** でデータの変化点からクロックを復元",
                    "**リファレンスクロック**：100 MHz。両端で共通クロックを使う方式と、独立クロック（SRIS/SRNS）方式があります",
                ]),
                .heading("スクランブル"),
                .text("同じビットが長く続くと CDR がロックを失ったり、特定周波数に電磁ノイズが集中します。そこで **LFSR（線形帰還シフトレジスタ）** の出力とデータを XOR してランダム化します。Gen1/2 は16ビット、Gen3 以降はレーンごとに23ビットの LFSR を使います。"),
                .heading("128b/130b のブロック"),
                .figure("""
                | Sync(2b) |        Payload (128 bit)        |
                   10b  -> Data Block
                   01b  -> Ordered Set Block
                """),
                .heading("フレーミング"),
                .bullets([
                    "Gen1/2：TLP は **STP〜END**、DLLP は **SDP〜END** の特殊シンボル（K文字）で囲む",
                    "Gen3〜5：**STP トークン**（長さ・シーケンス番号を含む4バイト）、SDP トークン、IDL、EDB、EDS などのトークンで区切る。END はなく、長さで終端を判断",
                ]),
                .heading("Ordered Set"),
                .table(header: ["名称", "用途"], rows: [
                    ["TS1 / TS2", "リンクトレーニング（速度・幅・レーン番号の交渉）"],
                    ["SKP", "両端のクロック周波数差の吸収（独立クロック・SSCなしのSRNSで最大600ppm。SRISではさらに大きい）"],
                    ["EIOS", "Electrical Idle（低消費電力の無信号状態）に入る合図"],
                    ["EIEOS", "Electrical Idle から抜ける合図（Gen2以降）"],
                    ["FTS", "L0s からの高速復帰で受信側を再同期（Non-Flit Modeのみ）"],
                    ["SDS", "データストリーム開始（Gen3以降）"],
                ]),
                .heading("レーンまわりの機能"),
                .bullets([
                    "**レーン間デスキュー**：配線長の違いによるレーン間の到着時間差を受信側で補正",
                    "**レーン反転（Lane Reversal）**：レーン番号の並びを逆に接続しても動作",
                    "**極性反転（Polarity Inversion）**：差動ペアの＋／−を逆に配線しても受信側で補正",
                ]),
                .heading("イコライゼーション（Gen3以降）"),
                .text("高速になるほど基板配線での信号減衰が大きくなるため、送信側で波形を強調（**FFE：プリカーソル／ポストカーソル**）し、受信側で補償（**CTLE、DFE**）します。Gen3 以降はリンクトレーニング中に **Phase 0〜3** の手順で最適な係数を両端で探索します。送信側には **プリセット P0〜P10** が定義されています。"),
                .note("ボード設計で「Gen4では動くがGen5でリンクが落ちる」といった問題の多くは、損失とイコライゼーションの不足が原因です。"),
            ]
        ),
    ]
}
