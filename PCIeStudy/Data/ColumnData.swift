import Foundation

/// 気軽に読めるコラム
struct ReadingColumn: Identifiable, Hashable {
    let id: String
    let title: String
    let lead: String
    let symbol: String
    let minutes: Int
    /// 関連する章（章の解説へのリンクに使う）
    let chapterID: String?
    let blocks: [ContentBlock]
}

enum ColumnData {
    /// 日付から決まる「今日のコラム」
    static func today(_ date: Date = .now) -> ReadingColumn {
        all[DailyPick.index(for: date, count: all.count, salt: 3)]
    }

    static let all: [ReadingColumn] = [
        ReadingColumn(
            id: "gts-vs-gbs",
            title: "「GT/s」と「GB/s」、どっちが本当の速さ？",
            lead: "カタログの数字にだまされないための、帯域の読み方",
            symbol: "speedometer",
            minutes: 3,
            chapterID: "generations",
            blocks: [
                .text("PCIe のカタログには「32 GT/s」と「64 GB/s」のような2種類の数字が並びます。似ているようで、意味はまったく違います。"),
                .heading("GT/s は「1レーンが1秒に何回送るか」"),
                .text("**GT/s（ギガトランスファ毎秒）** は、1本のレーンが1秒間に何十億回信号を送るかという生の値です。符号化のオーバーヘッドも含んでいるので、そのままでは「使えるデータ量」になりません。"),
                .heading("GB/s は「使えるデータ量」"),
                .figure("""
                GB/s = GT/s x (符号化効率) x レーン数 / 8

                Gen4 x16 = 16 x 128/130 x 16 / 8 ≒ 31.5 GB/s
                """),
                .bullets([
                    "最後に8で割るのは、ビットをバイトに直すため",
                    "これは **片方向** の値。PCIe は全二重なので、双方向の合計はこの2倍になります",
                    "ニュースで「PCIe 7.0 は x16 で 512 GB/s」と書かれていたら、それは双方向の合計（片方向は 256 GB/s）です",
                ]),
                .note("実際にアプリが使える速度は、TLP ヘッダや DLLP、フロー制御などの分だけさらに下がります。大きな Max_Payload_Size を使うほど、ヘッダの割合が小さくなって効率が上がります。"),
            ]
        ),
        ReadingColumn(
            id: "encoding-journey",
            title: "符号化の旅：8b/10b から 1b/1b へ",
            lead: "20% のムダを 1.5% に、そして 0% に",
            symbol: "arrow.triangle.swap",
            minutes: 4,
            chapterID: "physical",
            blocks: [
                .text("PCIe の歴史は、ある意味「符号化のムダとの戦い」でもあります。"),
                .table(header: ["世代", "符号化", "効率"], rows: [
                    ["Gen1 / Gen2", "8b/10b", "80%"],
                    ["Gen3〜Gen5", "128b/130b", "約98.5%"],
                    ["Gen6 以降", "1b/1b（Flit Mode）", "符号化のムダはなし"],
                ]),
                .heading("8b/10b：安全だけど20%が消える"),
                .text("8ビットを10ビットの記号に置き換えることで、0と1が長く続かないようにし、受信側がクロックを取り出しやすくしていました。その代わり、送ったビットの20%はデータではありません。"),
                .heading("128b/130b：スクランブルに任せる"),
                .text("Gen3 では、128ビットごとに2ビットの **Sync Header** を付けるだけにしました。0と1の偏りは、LFSR を使ったスクランブルでならします。これで 5 GT/s → 8 GT/s という控えめな速度アップでも、実効帯域はほぼ2倍になりました。"),
                .heading("1b/1b と Flit：ムダの場所が変わった"),
                .text("Gen6 の PAM4 では、符号化そのもののオーバーヘッドはなくなりました。ただし 256バイトの Flit のうち TLP を入れられるのは 236バイトで、残りは DLP（6バイト）、CRC（8バイト）、FEC（6バイト）に使われます。ムダが「符号化」から「誤り対策」に移ったと言えます。"),
                .note("その代わり Flit Mode では、TLP ごとの LCRC やシーケンス番号、フレーミングのトークンが不要になったため、小さな TLP が多い場面では Non-Flit Mode より効率が良くなることもあります。"),
            ]
        ),
        ReadingColumn(
            id: "why-2-5",
            title: "最新の PCIe も、最初は 2.5 GT/s で話し始める",
            lead: "128 GT/s のリンクが、まず一番遅い速度で握手する理由",
            symbol: "hand.wave",
            minutes: 3,
            chapterID: "ltssm",
            blocks: [
                .text("Gen7 どうしをつないでも、電源を入れた直後のリンクは **2.5 GT/s（Gen1 の速度）** で L0 にたどり着きます。仕様書の LTSSM の章にも、両側がもっと速い速度に対応していても、まず 2.5 GT/s で L0 まで進むと書かれています。"),
                .heading("なぜわざわざ遅い速度から？"),
                .bullets([
                    "相手がどの世代かは、話してみるまで分からない。全世代が必ず話せる共通語が 2.5 GT/s",
                    "高い速度で正しく通信するには **イコライゼーション** で波形を整える必要があるが、その相談自体を安全な速度で行う必要がある",
                    "対応速度は TS1/TS2 の中で伝え合い、そのあと **Recovery** を通って速度を切り替える",
                ]),
                .figure("""
                2.5 GT/s で L0
                  -> Recovery で速度変更
                  -> 8 / 16 / 32 GT/s でイコライゼーション
                  -> 64 GT/s -> 128 GT/s
                """),
                .note("最近は、8.0 / 16.0 GT/s のイコライゼーションを飛ばして 32.0 GT/s から始める「Equalization Bypass to Highest NRZ Rate」も定義されています。握手の手順もどんどん効率化されています。"),
            ]
        ),
        ReadingColumn(
            id: "ack-registered-mail",
            title: "ACK/NAK は「書留郵便」",
            lead: "届いたかどうかを必ず確かめる、データリンク層の仕事",
            symbol: "envelope.badge",
            minutes: 3,
            chapterID: "datalink",
            blocks: [
                .text("データリンク層の ACK/NAK は、書留郵便にたとえると分かりやすくなります。"),
                .table(header: ["郵便", "PCIe（Non-Flit Mode）"], rows: [
                    ["荷物の追跡番号", "12ビットのシーケンス番号"],
                    ["控えを手元に残す", "Retry Buffer（リプレイバッファ）に保存"],
                    ["受け取りのハンコ", "ACK（その番号までまとめて受け取ったという意味）"],
                    ["「破れていた」と連絡", "NAK（その番号の次から送り直して）"],
                    ["いつまでも連絡がない", "REPLAY_TIMER が満了して自動で再送"],
                ]),
                .heading("同じ荷物が2回届いたら？"),
                .text("ACK が途中で失われると、送信側はタイマで再送します。受信側から見ると同じ番号の TLP が2回届くことになりますが、受信側は重複として捨て、もう一度 ACK を返します。こうして、ソフトウェアからはエラーが起きなかったように見えます。"),
                .heading("それでもダメなときは"),
                .text("再送が何度も続くと（Non-Flit Mode では4回目の再送で REPLAY_NUM がロールオーバー）、データリンク層は物理層にリンクの再トレーニングを頼みます。配送ルートそのものを点検し直すイメージです。"),
                .note("「図解」タブの ACK/NAK シミュレータで、ビット化けや ACK の喪失を起こしてみましょう。"),
            ]
        ),
        ReadingColumn(
            id: "credit-reservation",
            title: "フロー制御は「座席の予約」",
            lead: "受け取れる分しか送らないから、あふれない",
            symbol: "ticket",
            minutes: 3,
            chapterID: "flowcontrol",
            blocks: [
                .text("PCIe のフロー制御は、レストランの予約に似ています。受信側（お店）が「いま何席空いているか」を先に伝え、送信側（お客）は空いている分だけ送ります。"),
                .bullets([
                    "**ヘッダクレジット**＝テーブルの数（TLP 1個につき1つ）",
                    "**データクレジット**＝椅子の数（16バイトごとに1つ）",
                    "Posted / Non-Posted / Completion の3種類 × ヘッダ・データで、合計6種類の「予約枠」がある",
                ]),
                .heading("席が空いたら連絡が来る"),
                .text("受信側は TLP を処理してバッファを空けると、**UpdateFC** で「また席が空いた」と知らせます。だから、受信側のバッファがあふれて TLP が捨てられることは起きません。"),
                .heading("「いくらでもどうぞ」もある"),
                .text("初期化のときにクレジットを 0 と伝えると「無限」の意味になります。たとえば Endpoint は Completion について無限クレジットを通知します。自分が出した読み出しの返事は、必ず受け取れるように準備しておく決まりだからです。"),
                .note("遠くまで伸ばしたリンク（リタイマ経由など）では、「席が空いた」という連絡が届くまで時間がかかります。そのぶん多めのクレジット（大きなバッファ）がないと、帯域を使い切れません。"),
            ]
        ),
        ReadingColumn(
            id: "bar-sizing",
            title: "BAR に「全部1」を書くと、なぜサイズが分かる？",
            lead: "ビット演算ひとつで分かる、列挙のちょっとした魔法",
            symbol: "function",
            minutes: 4,
            chapterID: "config",
            blocks: [
                .text("OS がデバイスにアドレスを割り当てるとき、まず「このデバイスは何バイトの領域が欲しいのか」を知る必要があります。その方法がとてもユニークです。"),
                .heading("手順"),
                .bullets([
                    "BAR に `FFFFFFFFh`（全部1）を書く",
                    "読み戻すと、デバイスが **書き換えられないビットは0のまま** 返ってくる",
                    "下位の属性ビットを除いて反転し、1を足すとサイズになる",
                ]),
                .figure("""
                読み戻し : FFF0000Ch
                属性を除く: FFF00000h
                反転      : 000FFFFFh
                +1        : 00100000h = 1 MB
                """),
                .heading("なぜうまくいくのか"),
                .text("1MB の領域は、必ず 1MB 境界に置く決まりです。すると下位20ビットはアドレスとして意味がないので、デバイスはそのビットを常に0にしておけばよい。つまり「0に固定されたビットの数」が、そのままサイズを表しているのです。"),
                .note("64ビットの BAR は隣の BAR と2つで1組です。上位側にも全部1を書いて、64ビット全体で同じ計算をします。「ツール」タブの BAR サイズ計算機で試せます。"),
            ]
        ),
        ReadingColumn(
            id: "pam4-eye",
            title: "PAM4 の「3つの目」",
            lead: "1回で2ビット送る代わりに失ったもの",
            symbol: "eye",
            minutes: 4,
            chapterID: "gen6",
            blocks: [
                .text("高速信号の品質は、波形を重ね書きした **アイダイアグラム**（目のような形）で確かめます。目が大きく開いているほど、0と1を見分けやすい信号です。"),
                .heading("NRZ は目が1つ、PAM4 は3つ"),
                .figure("""
                NRZ (2 levels)     PAM4 (4 levels)
                 1 -------          3 -------
                    (eye)              (eye)
                 0 -------          2 -------
                                       (eye)
                                    1 -------
                                       (eye)
                                    0 -------
                """),
                .text("PAM4 は4つの電圧レベルで2ビットを表すので、同じ電圧の幅を3つの目で分け合うことになります。1つの目の高さはおよそ1/3になり、ノイズに弱くなります。Gen6 で FEC が必須になったのはこのためです。"),
                .heading("被害を小さくする工夫"),
                .bullets([
                    "**グレイ符号化**：隣り合う電圧レベルが1ビットしか違わないように割り当てる。読み違えても、壊れるのは1ビットで済む",
                    "**プリコーディング**：受信側の DFE が1回間違えたときに、誤りが続けて広がるのを抑える（32.0 GT/s 以上で受信側が要求できる）",
                    "**軽い FEC ＋ 再送**：遅延を増やさないよう FEC はあえて軽くし、直しきれないものは CRC で見つけて Flit ごと再送する",
                ]),
                .note("Gen6 では、FEC をかける前のビット誤り率（FBER）として 10⁻⁶ という、NRZ 時代（10⁻¹²）よりずっと悪い値を前提に設計されています。"),
            ]
        ),
        ReadingColumn(
            id: "lspci",
            title: "自分の PC の PCIe をのぞいてみよう",
            lead: "lspci で、リンク速度と幅を確かめる",
            symbol: "terminal",
            minutes: 3,
            chapterID: "topology",
            blocks: [
                .text("学んだことを、実際のマシンで確かめてみましょう。Linux なら `lspci` コマンドで PCIe のツリーやリンクの状態が見られます。"),
                .heading("ツリーを見る"),
                .figure("""
                $ lspci -tv
                -[0000:00]-+-00.0  Host bridge
                           +-01.0-[01]----00.0  VGA controller
                           \\-1d.0-[02]----00.0  NVMe controller
                """),
                .text("`[01]` のような番号はバス番号です。Root Port（`01.0`）の先にバス1があり、そこに GPU がつながっていることが分かります。"),
                .heading("リンク速度と幅を見る"),
                .figure("""
                $ sudo lspci -vv -s 01:00.0 | grep Lnk
                LnkCap: Port #0, Speed 16GT/s, Width x16
                LnkSta: Speed 16GT/s, Width x16
                """),
                .bullets([
                    "**LnkCap**：そのデバイスが対応している最高の速度と幅",
                    "**LnkSta**：いま実際に動いている速度と幅",
                    "LnkSta に「(downgraded)」と出ていたら、相手や配線の都合で本来より遅く・狭く動いている",
                ]),
                .note("GPU は省電力のため、アイドル中は速度を落としていることがあります。負荷をかけながら確認すると、本来の速度が見えます。"),
            ]
        ),
        ReadingColumn(
            id: "nvme-cxl",
            title: "NVMe と CXL：PCIe の上に乗る仲間たち",
            lead: "PCIe は「道路」、その上を走る「車」はいろいろ",
            symbol: "car.side",
            minutes: 3,
            chapterID: "gen6",
            blocks: [
                .text("PCIe はデータを運ぶ「道路」です。その上で、用途に合わせた「車」（プロトコル）が走っています。"),
                .heading("NVMe：SSD のための車"),
                .text("**NVMe** は SSD を PCIe で使うためのプロトコルです。メモリ上にコマンドの待ち行列（キュー）を作り、デバイスの BAR にある「ドアベル」レジスタに書き込んで知らせます。データの読み書きは、SSD がメモリに直接アクセスする DMA（MRd / MWr の TLP）で行われます。完了の通知には MSI-X がよく使われます。"),
                .heading("CXL：メモリを共有するための車"),
                .text("**CXL** は PCIe の物理層を使いながら、CPU とデバイスがキャッシュの内容を矛盾なく共有できるようにしたプロトコルです。PCIe と同じスロットを使い、リンクトレーニングのときに CXL で動くかどうかを決めます。"),
                .table(header: ["プロトコル", "たとえると"], rows: [
                    ["CXL.io", "PCIe そのもの（列挙・設定・DMA）"],
                    ["CXL.cache", "デバイスが CPU のメモリをキャッシュする"],
                    ["CXL.mem", "CPU がデバイスのメモリを自分のメモリのように使う"],
                ]),
                .note("どちらも土台は PCIe なので、この章で学んだ TLP やフロー制御、リンクトレーニングの知識がそのまま役に立ちます。"),
            ]
        ),
    ]
}
