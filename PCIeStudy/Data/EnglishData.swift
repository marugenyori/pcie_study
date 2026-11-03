import Foundation

// MARK: - 型

/// 英語で聞くレッスン（PCIe の説明を英語で聞き、聞き取り問題・書き取り・単語で耳を慣らす）
struct EnglishLesson: Identifiable, Hashable {
    let id: String
    let title: String
    let titleJa: String
    /// 関連する章（LessonData の ID）
    let chapterID: String
    let sentences: [EnglishSentence]
    let words: [EnglishWord]
    let questions: [ListeningQuestion]

    var level: Level { LessonData.chapter(id: chapterID)?.level ?? .beginner }

    /// 書き取りに使う文（key がある文）
    var dictationItems: [EnglishSentence] { sentences.filter { $0.key != nil } }
}

struct EnglishSentence: Hashable {
    let en: String
    let ja: String
    /// 書き取りで空欄にする語（en の中にそのまま含まれていること）
    let key: String?
}

struct EnglishWord: Hashable {
    let word: String
    let ja: String
    /// 聞き取りのコツ（どう聞こえるか、どこを強く言うか）
    let tip: String
}

struct ListeningQuestion: Hashable {
    let question: String
    let choices: [String]
    let answer: Int
    /// 解説（日本語）
    let note: String
}

/// PCIe の言葉の、英語での読み方
struct SpokenTerm: Identifiable, Hashable {
    var id: String { written }
    let written: String
    let reading: String
    /// 読み上げに渡す文
    let speech: String
    let tip: String
}

// MARK: - 読み上げ用の書き換え

enum EnglishSpeech {
    /// 画面の表記を、読み上げで正しく聞こえる形に変える（x16 → by 16 など）
    static func spoken(_ text: String) -> String {
        var result = text
        for (from, to) in replacements {
            result = result.replacingOccurrences(of: from, with: to)
        }
        return result.replacingOccurrences(of: #"\bx(\d+)\b"#, with: "by $1", options: .regularExpression)
    }

    private static let replacements: [(String, String)] = [
        ("REPLAY_NUM", "replay num"),
        ("REPLAY_TIMER", "replay timer"),
        ("128b/130b", "128 b, 130 b"),
        ("8b/10b", "8 b, 10 b"),
        ("GT/s", "gigatransfers per second"),
        ("PCIe", "P C I E"),
        ("PAM4", "pam four"),
        ("UpdateFC", "update F C"),
        ("L0", "L zero"),
        ("ECAM", "E cam"),
        ("BAR", "bar"),
        ("ACK", "ack"),
        ("NAK", "nak"),
        (" ID", " I D"),
    ]
}

// MARK: - データ

enum EnglishData {
    static func lesson(id: String) -> EnglishLesson? {
        all.first { $0.id == id }
    }

    static let terms: [SpokenTerm] = [
        SpokenTerm(written: "PCIe", reading: "P-C-I-E / PCI Express", speech: "P C I E. P C I Express.",
                   tip: "「ピー・シー・アイ・イー」。正式名の PCI Express と言う人も多い"),
        SpokenTerm(written: "x16", reading: "by sixteen", speech: "by sixteen. by four. by one.",
                   tip: "レーン数は「by」で読む。x4 は by four、x1 は by one"),
        SpokenTerm(written: "64 GT/s", reading: "sixty-four gigatransfers per second", speech: "sixty-four gigatransfers per second",
                   tip: "GT/s は「ギガトランスファーズ・パー・セカンド」。会話では「sixty-four gig」と略すこともある"),
        SpokenTerm(written: "Gen5", reading: "gen five", speech: "gen five. gen six.",
                   tip: "世代は「ジェン」。generation の略"),
        SpokenTerm(written: "TLP / DLLP", reading: "T-L-P / D-L-L-P", speech: "T L P. D L L P.",
                   tip: "略語は1文字ずつ読む。D-L-L-P は「ダブル L」と言う人もいる"),
        SpokenTerm(written: "ACK / NAK", reading: "ack / nak", speech: "ack. nak.",
                   tip: "1文字ずつではなく、単語として「アック」「ナック」と読む"),
        SpokenTerm(written: "REPLAY_NUM", reading: "replay num", speech: "replay num. replay timer.",
                   tip: "下線は読まない。replay（リプレイ）と reply（リプライ）は最後の母音が違うので注意"),
        SpokenTerm(written: "LTSSM", reading: "L-T-S-S-M", speech: "L T S S M",
                   tip: "1文字ずつ。S が2つ続くところは「エス・エス」とはっきり区切って読まれる"),
        SpokenTerm(written: "L0 / L0s / L1", reading: "L zero / L zero S / L one", speech: "L zero. L zero S. L one.",
                   tip: "0 は「オー」ではなく zero と読むのが普通"),
        SpokenTerm(written: "BAR", reading: "bar", speech: "bar. BAR zero.",
                   tip: "B-A-R ではなく、単語として「バー」と読む。BAR0 は「バー・ゼロ」"),
        SpokenTerm(written: "ECAM", reading: "E-cam", speech: "E cam",
                   tip: "「イー・キャム」"),
        SpokenTerm(written: "MSI-X", reading: "M-S-I-X", speech: "M S I X",
                   tip: "最後の X も1文字として「エックス」と読む"),
        SpokenTerm(written: "PAM4", reading: "pam four", speech: "pam four",
                   tip: "PAM は単語として「パム」"),
        SpokenTerm(written: "FEC", reading: "F-E-C", speech: "F E C. forward error correction.",
                   tip: "ふつうは1文字ずつ。forward error correction と言い換えることも多い"),
        SpokenTerm(written: "4 KB", reading: "four kilobytes / four K", speech: "four kilobytes. four K.",
                   tip: "会話では「four K」と短く言うことが多い"),
        SpokenTerm(written: "0x10", reading: "hex ten / zero x ten", speech: "hex ten. zero x one zero.",
                   tip: "16進は「hex」を前に付けるか、「zero x」と読む。1と0を1桁ずつ読む人もいる"),
    ]

    static let all: [EnglishLesson] = [
        EnglishLesson(
            id: "en-layers", title: "The Three Layers", titleJa: "3つの層", chapterID: "layers",
            sentences: [
                EnglishSentence(en: "PCIe is built from three layers: the Transaction Layer, the Data Link Layer, and the Physical Layer.",
                                ja: "PCIe は3つの層でできています。トランザクション層、データリンク層、物理層です。", key: "layers"),
                EnglishSentence(en: "The Transaction Layer turns read and write requests into packets called TLPs.",
                                ja: "トランザクション層は、読み書きの要求を TLP というパケットにします。", key: "packets"),
                EnglishSentence(en: "The Data Link Layer adds a sequence number and an LCRC to each TLP, so that errors on the link can be detected.",
                                ja: "データリンク層は各 TLP にシーケンス番号と LCRC を付け、リンク上の誤りを見つけられるようにします。", key: "detected"),
                EnglishSentence(en: "If a TLP is damaged, the Data Link Layer sends it again automatically.",
                                ja: "TLP が壊れたら、データリンク層が自動で送り直します。", key: "damaged"),
                EnglishSentence(en: "The Physical Layer converts the packets into electrical signals and sends them over the lanes.",
                                ja: "物理層はパケットを電気信号に変えて、レーンで送ります。", key: "signals"),
                EnglishSentence(en: "On the receiving side, the same three layers work in reverse order.",
                                ja: "受け取る側では、同じ3つの層が逆の順番で働きます。", key: "reverse"),
            ],
            words: [
                EnglishWord(word: "layer", ja: "層", tip: "「レイヤー」より「レイア」に近い。最後の r は弱く、ほとんど聞こえない"),
                EnglishWord(word: "packet", ja: "パケット", tip: "最初の pa を強く「パキット」。後ろの t は軽い"),
                EnglishWord(word: "automatically", ja: "自動で", tip: "「オートマティカリー」の ma を強く。-cally は「クリ」と短くなる"),
                EnglishWord(word: "lane", ja: "レーン（信号線の組）", tip: "rain（雨）と混同しやすい。L は舌先を上の歯ぐきに付ける"),
                EnglishWord(word: "reverse", ja: "逆の", tip: "後ろの ver を強く「リヴァース」"),
            ],
            questions: [
                ListeningQuestion(question: "Which layer adds the sequence number to a TLP?",
                                  choices: ["The Transaction Layer", "The Data Link Layer", "The Physical Layer"], answer: 1,
                                  note: "シーケンス番号と LCRC を付けるのはデータリンク層（Data Link Layer）です。"),
                ListeningQuestion(question: "What happens when a TLP is damaged on the link?",
                                  choices: ["It is sent again automatically.", "The link is turned off.", "Software must send it again."], answer: 0,
                                  note: "「sends it again automatically」＝データリンク層が自動で再送します。ソフトウェアは関わりません。"),
            ]
        ),
        EnglishLesson(
            id: "en-topology", title: "The PCIe Tree", titleJa: "PCIe の木構造", chapterID: "topology",
            sentences: [
                EnglishSentence(en: "A PCIe system is shaped like a tree.",
                                ja: "PCIe のシステムは木のような形をしています。", key: "tree"),
                EnglishSentence(en: "At the top is the Root Complex, which connects the CPU and memory to the PCIe fabric.",
                                ja: "いちばん上にあるのが Root Complex で、CPU とメモリを PCIe のつながり全体（ファブリック）に結びます。", key: "connects"),
                EnglishSentence(en: "Devices such as SSDs and network cards are called Endpoints.",
                                ja: "SSD やネットワークカードのような機器は Endpoint と呼ばれます。", key: "Endpoints"),
                EnglishSentence(en: "A Switch has one upstream port and several downstream ports, so it can connect more devices.",
                                ja: "Switch は上流ポートを1つ、下流ポートを複数持つので、より多くの機器をつなげます。", key: "upstream"),
                EnglishSentence(en: "Each link connects exactly two ports, one on each end.",
                                ja: "1本のリンクは、ちょうど2つのポートを両端でつなぎます。", key: "exactly"),
                EnglishSentence(en: "Unlike the old PCI bus, devices do not share the same wires.",
                                ja: "昔の PCI バスと違い、機器どうしが同じ配線を共有することはありません。", key: "share"),
            ],
            words: [
                EnglishWord(word: "Root Complex", ja: "ルートコンプレックス", tip: "root は「ルート」と伸ばす。会話では RC（アール・シー）と略すことも多い"),
                EnglishWord(word: "upstream", ja: "上流（CPU に近い側）", tip: "str は間に母音を入れず一気に「アップストリーム」"),
                EnglishWord(word: "Endpoint", ja: "エンドポイント（末端の機器）", tip: "d がほとんど聞こえず「エンポイント」のように聞こえる"),
                EnglishWord(word: "fabric", ja: "ファブリック（つながり全体）", tip: "最初の fa を強く「ファブリク」"),
                EnglishWord(word: "exactly", ja: "ちょうど", tip: "t が落ちて「イグザクリー」と聞こえる"),
            ],
            questions: [
                ListeningQuestion(question: "What is a device like an SSD called?",
                                  choices: ["A Root Complex", "A Switch", "An Endpoint"], answer: 2,
                                  note: "SSD やネットワークカードは Endpoint です。"),
                ListeningQuestion(question: "How many ports does one link connect?",
                                  choices: ["Two", "Three", "As many as needed"], answer: 0,
                                  note: "「exactly two ports」＝ちょうど2つ。PCIe は1対1のつながりです。"),
            ]
        ),
        EnglishLesson(
            id: "en-tlp", title: "Inside a TLP", titleJa: "TLP のなかみ", chapterID: "tlp",
            sentences: [
                EnglishSentence(en: "A TLP has a header, an optional data payload, and an optional digest called the ECRC.",
                                ja: "TLP は、ヘッダと、あってもなくてもよいデータ（ペイロード）と、ECRC というダイジェスト（これも省略可）でできています。", key: "header"),
                EnglishSentence(en: "In Non-Flit Mode, the header is three or four doublewords long, and one doubleword is four bytes.",
                                ja: "Non-Flit Mode では、ヘッダは3または4ダブルワードで、1ダブルワードは4バイトです。", key: "doublewords"),
                EnglishSentence(en: "Memory writes are posted, which means the requester does not wait for a reply.",
                                ja: "メモリ書き込みは Posted で、要求した側は返事を待ちません。", key: "posted"),
                EnglishSentence(en: "Memory reads are non-posted, so the completer must send back a Completion with the data.",
                                ja: "メモリ読み出しは Non-Posted なので、受けた側はデータ付きの Completion を返す必要があります。", key: "Completion"),
                EnglishSentence(en: "If a read request is never answered, the requester eventually reports a Completion Timeout.",
                                ja: "読み出し要求に返事がないと、要求した側はやがて Completion Timeout を報告します。", key: "eventually"),
                EnglishSentence(en: "Every request carries a Requester ID and a Tag, so the Completion can be matched to the right request.",
                                ja: "要求には Requester ID と Tag が入っているので、Completion を正しい要求と結び付けられます。", key: "matched"),
            ],
            words: [
                EnglishWord(word: "header", ja: "ヘッダ", tip: "ea は「エ」。「ヘダー」と短く聞こえる"),
                EnglishWord(word: "payload", ja: "ペイロード（運ぶデータ）", tip: "「ペイロウド」。load は「ロード」より「ロウド」"),
                EnglishWord(word: "posted", ja: "ポステッド（返事を待たない）", tip: "post は「ポスト」ではなく「ポウスト」。-ed は「ティド」"),
                EnglishWord(word: "completion", ja: "完了の返事", tip: "最初の com は弱く「カンプリーション」。ple を強く"),
                EnglishWord(word: "eventually", ja: "最終的に、やがて", tip: "ven を強く「イヴェンチュアリー」。t は「チュ」に変わる"),
            ],
            questions: [
                ListeningQuestion(question: "Does the requester wait for a reply after a memory write?",
                                  choices: ["Yes, it waits for a Completion.", "No, memory writes are posted.", "Only for 64-bit addresses."], answer: 1,
                                  note: "メモリ書き込みは posted（返事を待たない）です。"),
                ListeningQuestion(question: "What helps match a Completion to its request?",
                                  choices: ["The LCRC", "The Requester ID and the Tag", "The lane number"], answer: 1,
                                  note: "Requester ID（誰が出したか）と Tag（何番目の要求か）で対応を付けます。"),
            ]
        ),
        EnglishLesson(
            id: "en-replay", title: "ACK, NAK, and Replay", titleJa: "ACK・NAK と再送", chapterID: "datalink",
            sentences: [
                EnglishSentence(en: "The transmitter keeps a copy of every TLP it sends in a replay buffer.",
                                ja: "送信側は、送った TLP のコピーをすべてリプレイバッファに残しておきます。", key: "copy"),
                EnglishSentence(en: "When the receiver gets a good TLP, it returns an ACK, and the transmitter can free that space in the buffer.",
                                ja: "受信側が正しい TLP を受け取ると ACK を返し、送信側はバッファのその場所を空けられます。", key: "free"),
                EnglishSentence(en: "When the receiver finds a bad TLP, it returns a NAK, and the transmitter replays the TLPs still in the buffer.",
                                ja: "受信側が壊れた TLP を見つけると NAK を返し、送信側はバッファに残っている TLP を送り直します。", key: "replays"),
                EnglishSentence(en: "If no ACK or NAK arrives in time, the REPLAY_TIMER expires and causes a replay as well.",
                                ja: "ACK も NAK も時間内に来なければ、REPLAY_TIMER が切れて、同じように再送が起きます。", key: "expires"),
                EnglishSentence(en: "The REPLAY_NUM counter counts how many times in a row the same TLPs have been replayed.",
                                ja: "REPLAY_NUM カウンタは、同じ TLP が何回続けて再送されたかを数えます。", key: "row"),
                EnglishSentence(en: "When it rolls over, the link is retrained, because repeated errors suggest a problem with the signal itself.",
                                ja: "これがロールオーバーするとリンクを再トレーニングします。誤りが続くのは、信号そのものに問題がありそうだからです。", key: "retrained"),
            ],
            words: [
                EnglishWord(word: "replay", ja: "再送", tip: "「リプレイ」。reply（リプライ、返事）と混同しやすい。最後が「レイ」か「ライ」かを聞き分ける"),
                EnglishWord(word: "acknowledge", ja: "受け取りを知らせる（ACK の元の語）", tip: "k は読まず「アクナリッジ」。nowl を強く"),
                EnglishWord(word: "expire", ja: "（時間が）切れる", tip: "「イクスパイア」。pire を強く、最後の r は弱い"),
                EnglishWord(word: "in a row", ja: "続けて、連続で", tip: "つながって「イナロウ」と1語のように聞こえる"),
                EnglishWord(word: "roll over", ja: "一周して0に戻る", tip: "つながって「ロウロウヴァ」。名詞の rollover も同じ音"),
                EnglishWord(word: "retrain", ja: "再トレーニングする", tip: "「リートレイン」。train の tr は「チュ」に近く聞こえる"),
            ],
            questions: [
                ListeningQuestion(question: "What does the receiver send when it finds a bad TLP?",
                                  choices: ["An ACK", "A NAK", "A new header"], answer: 1,
                                  note: "壊れた TLP を見つけたら NAK を返します。"),
                ListeningQuestion(question: "Besides a NAK, what else causes a replay?",
                                  choices: ["The REPLAY_TIMER expiring", "A Completion", "A configuration write"], answer: 0,
                                  note: "「the REPLAY_TIMER expires and causes a replay as well」＝タイマ切れでも再送します。"),
                ListeningQuestion(question: "Why is the link retrained when REPLAY_NUM rolls over?",
                                  choices: ["Repeated errors suggest a problem with the signal.", "The buffer is full of new data.", "Software asked for a faster speed."], answer: 0,
                                  note: "同じ再送が何度も続くのは、信号の質そのものが悪いサインだからです。"),
            ]
        ),
        EnglishLesson(
            id: "en-credits", title: "Flow Control Credits", titleJa: "フロー制御のクレジット", chapterID: "flowcontrol",
            sentences: [
                EnglishSentence(en: "PCIe uses credit-based flow control, so a transmitter never sends more than the receiver can hold.",
                                ja: "PCIe はクレジット方式のフロー制御を使うので、送信側は受信側が受け取れる量を超えて送ることはありません。", key: "hold"),
                EnglishSentence(en: "The receiver advertises how much buffer space it has, counted in credits.",
                                ja: "受信側は、バッファの空きがどれだけあるかをクレジット単位で知らせます。", key: "advertises"),
                EnglishSentence(en: "There are separate credits for headers and for data, and for posted, non-posted, and completion traffic.",
                                ja: "クレジットは、ヘッダ用とデータ用、さらに Posted・Non-Posted・Completion ごとに分かれています。", key: "separate"),
                EnglishSentence(en: "One data credit is sixteen bytes, which is four doublewords.",
                                ja: "データクレジット1つは16バイト、つまり4ダブルワードです。", key: "sixteen"),
                EnglishSentence(en: "As the receiver frees its buffers, it sends UpdateFC DLLPs to give credits back.",
                                ja: "受信側はバッファが空くと、UpdateFC という DLLP を送ってクレジットを返します。", key: "frees"),
                EnglishSentence(en: "Advertising zero credits during initialization means the credits are infinite.",
                                ja: "初期化のときに0クレジットを知らせると、「無限」という意味になります。", key: "infinite"),
            ],
            words: [
                EnglishWord(word: "credit", ja: "クレジット（受け取れる量の単位）", tip: "「クレディット」。最後の t は軽く、ほとんど聞こえないこともある"),
                EnglishWord(word: "advertise", ja: "知らせる、通知する", tip: "最初の ad を強く「アドヴァタイズ」"),
                EnglishWord(word: "separate", ja: "別々の", tip: "形容詞は「セパレット」、動詞は「セパレイト」と音が変わる"),
                EnglishWord(word: "infinite", ja: "無限の", tip: "最初の in を強く「インフィニット」。「インフィナイト」ではない"),
                EnglishWord(word: "buffer", ja: "バッファ", tip: "「バファー」。u は口を軽く開けた「ア」"),
            ],
            questions: [
                ListeningQuestion(question: "How big is one data credit?",
                                  choices: ["Four bytes", "Sixteen bytes", "Sixty-four bytes"], answer: 1,
                                  note: "sixteen（16）と sixty（60）は聞き分けにくい数です。sixTEEN は後ろを強く、SIXty は前を強く言います。"),
                ListeningQuestion(question: "What does advertising zero credits at initialization mean?",
                                  choices: ["No traffic is allowed.", "The credits are infinite.", "The link is broken."], answer: 1,
                                  note: "初期化で0を知らせると「無限（infinite）」の意味になります。"),
            ]
        ),
        EnglishLesson(
            id: "en-lanes", title: "Lanes and Encoding", titleJa: "レーンと符号化", chapterID: "physical",
            sentences: [
                EnglishSentence(en: "A lane is made of two differential pairs, one for sending and one for receiving.",
                                ja: "レーンは2組の差動ペアでできています。1組は送信用、もう1組は受信用です。", key: "differential"),
                EnglishSentence(en: "A link can be one, two, four, eight, or sixteen lanes wide, written as x1 to x16.",
                                ja: "リンクの幅は1・2・4・8・16レーンにでき、x1〜x16 と書きます。", key: "wide"),
                EnglishSentence(en: "When you hear by sixteen, it means a link with sixteen lanes.",
                                ja: "「by sixteen」と聞こえたら、16レーンのリンクのことです。", key: "hear"),
                EnglishSentence(en: "The first two generations used 8b/10b encoding, which wastes twenty percent of the bandwidth.",
                                ja: "最初の2世代は 8b/10b 符号化を使っていて、帯域の20%がむだになります。", key: "wastes"),
                EnglishSentence(en: "From 8 GT/s, PCIe switched to 128b/130b encoding, so the overhead dropped to about one and a half percent.",
                                ja: "8 GT/s からは 128b/130b 符号化に変わり、オーバーヘッドは約1.5%に下がりました。", key: "overhead"),
                EnglishSentence(en: "The receiver recovers the clock from the data stream itself.",
                                ja: "受信側は、データの流れそのものからクロックを取り出します。", key: "recovers"),
            ],
            words: [
                EnglishWord(word: "differential", ja: "差動の", tip: "ren を強く「ディファレンシャル」"),
                EnglishWord(word: "encoding", ja: "符号化", tip: "co を強く「エンコウディング」"),
                EnglishWord(word: "overhead", ja: "オーバーヘッド（むだになる分）", tip: "「オウヴァヘッド」。over は「オーバー」より「オウヴァ」"),
                EnglishWord(word: "bandwidth", ja: "帯域", tip: "d がほぼ消えて「バンウィドス」。最後は th（舌を歯に当てる）"),
                EnglishWord(word: "by sixteen", ja: "x16（16レーン）", tip: "x は「バイ」と読む。x8 は by eight"),
            ],
            questions: [
                ListeningQuestion(question: "What is a lane made of?",
                                  choices: ["One wire", "Two differential pairs", "Sixteen wires"], answer: 1,
                                  note: "送信用と受信用の、2組の差動ペアです。"),
                ListeningQuestion(question: "What is the overhead of 128b/130b encoding?",
                                  choices: ["About one and a half percent", "Twenty percent", "Zero"], answer: 0,
                                  note: "130ビットのうち2ビットが余分なので、約1.5%です。twenty percent は 8b/10b のほうです。"),
            ]
        ),
        EnglishLesson(
            id: "en-ltssm", title: "Bringing the Link Up", titleJa: "リンクが立ち上がるまで", chapterID: "ltssm",
            sentences: [
                EnglishSentence(en: "The LTSSM is the state machine that brings a link up and keeps it running.",
                                ja: "LTSSM は、リンクを立ち上げて動かし続けるための状態機械です。", key: "state"),
                EnglishSentence(en: "First, in Detect, each side checks whether a receiver is connected at the other end.",
                                ja: "まず Detect で、それぞれの側が相手の端に受信器がつながっているかを調べます。", key: "connected"),
                EnglishSentence(en: "In Polling, the two sides exchange training sets and lock onto each other's bits and symbols.",
                                ja: "Polling では、両側がトレーニングセットを送り合い、相手のビットとシンボルに同期します。", key: "lock"),
                EnglishSentence(en: "In Configuration, they agree on the link width and the lane numbers.",
                                ja: "Configuration では、リンク幅とレーン番号を決めます。", key: "agree"),
                EnglishSentence(en: "L0 is the normal state where TLPs and DLLPs flow.",
                                ja: "L0 は、TLP と DLLP が流れるふつうの状態です。", key: "normal"),
                EnglishSentence(en: "If something goes wrong, or the speed has to change, the link goes through Recovery and comes back to L0.",
                                ja: "何か問題が起きたときや速度を変えるときは、リンクは Recovery を通って L0 に戻ります。", key: "Recovery"),
            ],
            words: [
                EnglishWord(word: "state machine", ja: "状態機械", tip: "「ステイト・マシーン」。state の t は弱く「ステイ_マシーン」と聞こえる"),
                EnglishWord(word: "training set", ja: "トレーニングセット（TS1/TS2）", tip: "set の t が落ちて「トレイニング・セッ」"),
                EnglishWord(word: "symbol", ja: "シンボル", tip: "最後の l は「ウ」に近く「シンボゥ」"),
                EnglishWord(word: "width", ja: "幅", tip: "d と th が続いて「ウィドス」。with と似て聞こえる"),
                EnglishWord(word: "recovery", ja: "回復", tip: "co を強く「リカヴァリー」"),
            ],
            questions: [
                ListeningQuestion(question: "In which state do the two sides agree on the link width?",
                                  choices: ["Detect", "Configuration", "L0"], answer: 1,
                                  note: "リンク幅とレーン番号は Configuration で決めます。"),
                ListeningQuestion(question: "Which state is used when the speed has to change?",
                                  choices: ["Recovery", "Detect", "Polling"], answer: 0,
                                  note: "速度の変更や、問題が起きたときの立て直しは Recovery で行います。"),
            ]
        ),
        EnglishLesson(
            id: "en-config", title: "Configuration Space", titleJa: "コンフィグ空間", chapterID: "config",
            sentences: [
                EnglishSentence(en: "Every function has a configuration space of four kilobytes.",
                                ja: "それぞれのファンクションは、4キロバイトのコンフィグ空間を持っています。", key: "kilobytes"),
                EnglishSentence(en: "The first two hundred fifty-six bytes are compatible with the old PCI configuration space.",
                                ja: "先頭の256バイトは、昔の PCI のコンフィグ空間と互換です。", key: "compatible"),
                EnglishSentence(en: "Software finds devices by reading the Vendor ID at each bus, device, and function number; this is called enumeration.",
                                ja: "ソフトウェアは、バス・デバイス・ファンクション番号ごとに Vendor ID を読んで機器を見つけます。これをエニュメレーションといいます。", key: "enumeration"),
                EnglishSentence(en: "A Base Address Register, or BAR, tells software how much memory space a device needs.",
                                ja: "Base Address Register（BAR）は、機器が必要とするメモリ空間の大きさをソフトウェアに伝えます。", key: "memory"),
                EnglishSentence(en: "To find the size, software writes all ones to the BAR and reads the value back.",
                                ja: "大きさを調べるには、ソフトウェアが BAR にすべて1を書いて、値を読み返します。", key: "ones"),
                EnglishSentence(en: "With ECAM, configuration space can be accessed with ordinary memory reads and writes.",
                                ja: "ECAM を使うと、コンフィグ空間にふつうのメモリ読み書きでアクセスできます。", key: "ordinary"),
            ],
            words: [
                EnglishWord(word: "enumeration", ja: "列挙（機器を見つけて番号を割り当てること）", tip: "「イニューメレイション」。ra を強く、mer は弱い"),
                EnglishWord(word: "register", ja: "レジスタ", tip: "最初の re を強く「レジスター」"),
                EnglishWord(word: "compatible", ja: "互換の", tip: "pat を強く「カンパタブル」"),
                EnglishWord(word: "kilobyte", ja: "キロバイト", tip: "最初の ki を強く「キロバイト」。会話では four K とも言う"),
                EnglishWord(word: "vendor", ja: "メーカー", tip: "v は下くちびるに歯を当てる「ヴェンダー」"),
            ],
            questions: [
                ListeningQuestion(question: "What is enumeration?",
                                  choices: ["Finding devices by reading their Vendor IDs", "Changing the link speed", "Replaying damaged TLPs"], answer: 0,
                                  note: "Vendor ID を読んで、機器がいるかどうかを順に調べることです。"),
                ListeningQuestion(question: "How does software find the size of a BAR?",
                                  choices: ["It asks the driver.", "It writes all ones and reads the value back.", "It counts the lanes."], answer: 1,
                                  note: "すべて1（all ones）を書いて読み返すと、変わらないビットから大きさがわかります。"),
            ]
        ),
        EnglishLesson(
            id: "en-msi", title: "Interrupts as Writes", titleJa: "書き込みとしての割り込み", chapterID: "interrupts",
            sentences: [
                EnglishSentence(en: "Old PCI devices signaled interrupts with dedicated wires.",
                                ja: "昔の PCI の機器は、専用の配線で割り込みを知らせていました。", key: "dedicated"),
                EnglishSentence(en: "PCIe has no such wires, so legacy interrupts are sent as special messages instead.",
                                ja: "PCIe にはそうした配線がないので、従来型の割り込みは代わりに特別なメッセージで送ります。", key: "messages"),
                EnglishSentence(en: "With MSI, a device raises an interrupt by doing a memory write to a special address.",
                                ja: "MSI では、機器は決められたアドレスへのメモリ書き込みで割り込みを起こします。", key: "address"),
                EnglishSentence(en: "Because it is just a memory write, it follows the same ordering rules as the data written before it.",
                                ja: "ただのメモリ書き込みなので、その前に書いたデータと同じ順序のルールに従います。", key: "ordering"),
                EnglishSentence(en: "MSI-X allows up to two thousand forty-eight vectors, each with its own address and data.",
                                ja: "MSI-X では最大2048個のベクタを使え、それぞれが自分のアドレスとデータを持ちます。", key: "vectors"),
                EnglishSentence(en: "This lets each CPU core handle its own queue, which is important for fast SSDs and network cards.",
                                ja: "これにより CPU のコアごとに自分のキューを処理でき、速い SSD やネットワークカードで重要になります。", key: "queue"),
            ],
            words: [
                EnglishWord(word: "interrupt", ja: "割り込み", tip: "rupt を強く「インタラプト」"),
                EnglishWord(word: "legacy", ja: "従来の、昔からの", tip: "最初の le を強く「レガシー」"),
                EnglishWord(word: "dedicated", ja: "専用の", tip: "「デディケイティッド」。t は d に近い音になる"),
                EnglishWord(word: "vector", ja: "ベクタ（割り込みの番号）", tip: "v の音で「ヴェクター」"),
                EnglishWord(word: "queue", ja: "キュー（待ち行列）", tip: "つづりは長いが、音は「キュー」の1音だけ"),
            ],
            questions: [
                ListeningQuestion(question: "How does a device raise an MSI?",
                                  choices: ["By pulling a wire low", "By doing a memory write", "By sending a NAK"], answer: 1,
                                  note: "MSI は決められたアドレスへのメモリ書き込みです。"),
                ListeningQuestion(question: "How many vectors can MSI-X support?",
                                  choices: ["Thirty-two", "Two hundred fifty-six", "Two thousand forty-eight"], answer: 2,
                                  note: "MSI-X は最大2048個です（MSI は最大32個）。"),
            ]
        ),
        EnglishLesson(
            id: "en-gen6", title: "PAM4 and Flits", titleJa: "PAM4 とフリット", chapterID: "gen6",
            sentences: [
                EnglishSentence(en: "PCIe 6.0 doubles the data rate to 64 GT/s.",
                                ja: "PCIe 6.0 は、データレートを 64 GT/s に倍増させます。", key: "doubles"),
                EnglishSentence(en: "Instead of making the signal faster, it uses PAM4, which sends two bits in each unit interval using four voltage levels.",
                                ja: "信号を速くするのではなく PAM4 を使い、4つの電圧レベルで1単位時間（UI）あたり2ビットを送ります。", key: "levels"),
                EnglishSentence(en: "PAM4 is more sensitive to noise, so errors happen more often than before.",
                                ja: "PAM4 はノイズの影響を受けやすいので、以前より誤りが起きやすくなります。", key: "noise"),
                EnglishSentence(en: "To deal with this, PCIe 6.0 adds a lightweight forward error correction, called FEC.",
                                ja: "その対策として、PCIe 6.0 では FEC という軽い前方誤り訂正を加えました。", key: "lightweight"),
                EnglishSentence(en: "Data is sent in fixed-size units called flits, which are two hundred fifty-six bytes long.",
                                ja: "データは、フリットという256バイトの決まった大きさの単位で送ります。", key: "flits"),
                EnglishSentence(en: "FEC fixes most errors, and the rare ones it cannot fix are caught by a CRC and replayed.",
                                ja: "FEC がほとんどの誤りを直し、直せないまれな誤りは CRC で見つけて再送します。", key: "rare"),
            ],
            words: [
                EnglishWord(word: "PAM4", ja: "4値パルス振幅変調", tip: "「パム・フォー」。PAM は1文字ずつではなく単語として読む"),
                EnglishWord(word: "unit interval", ja: "1ビット（1シンボル）分の時間（UI）", tip: "「ユーニット・インタヴァル」。in を強く"),
                EnglishWord(word: "sensitive", ja: "影響を受けやすい", tip: "最初の sen を強く「センシティヴ」"),
                EnglishWord(word: "lightweight", ja: "軽い", tip: "light の t が止まって「ライッウェイト」"),
                EnglishWord(word: "flit", ja: "フリット（転送の単位）", tip: "i は短い「イ」。flight（フライト）と聞き分ける"),
            ],
            questions: [
                ListeningQuestion(question: "How many bits does PAM4 send in each unit interval?",
                                  choices: ["One", "Two", "Four"], answer: 1,
                                  note: "4つの電圧レベルで2ビットを表します。four は電圧レベルの数です。"),
                ListeningQuestion(question: "How long is a flit?",
                                  choices: ["Sixty-four bytes", "One hundred twenty-eight bytes", "Two hundred fifty-six bytes"], answer: 2,
                                  note: "フリットは256バイトです。"),
            ]
        ),
    ]
}
