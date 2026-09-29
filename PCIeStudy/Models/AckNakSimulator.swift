import Foundation

/// データリンク層の ACK/NAK と再送を簡略化したシミュレータ
struct AckNakSimulator {
    struct Packet: Identifiable, Hashable {
        let id = UUID()
        let seq: Int
        var corrupted: Bool
        let isReplay: Bool
    }

    struct LogEntry: Identifiable, Hashable {
        enum Kind { case tx, rx, ack, nak, warn }
        let id = UUID()
        let kind: Kind
        let text: String
    }

    static let seqModulo = 4096
    static let replayNumLimit = 4

    private(set) var nextTransmitSeq = 0           // NEXT_TRANSMIT_SEQ
    private(set) var ackdSeq = seqModulo - 1       // 最後にACKされた番号
    private(set) var replayBuffer: [Int] = []      // 保持中のシーケンス番号
    private(set) var link: [Packet] = []           // 送信中（まだ受信側が処理していない）
    private(set) var nextRcvSeq = 0                // NEXT_RCV_SEQ
    private(set) var received: [Int] = []          // 受信側がトランザクション層へ渡したTLP
    private(set) var replayNum = 0
    private(set) var log: [LogEntry] = []
    private(set) var retrainCount = 0

    /// true のとき、受信側が返す次の ACK/NAK DLLP が壊れて届かない
    var dropNextDLLP = false

    // MARK: 送信側

    mutating func sendTLP(corrupt: Bool) {
        let seq = nextTransmitSeq
        replayBuffer.append(seq)
        link.append(Packet(seq: seq, corrupted: corrupt, isReplay: false))
        nextTransmitSeq = (nextTransmitSeq + 1) % Self.seqModulo
        add(.tx, "TX: TLP #\(seq) を送信" + (corrupt ? "（途中でビット化け）" : ""))
    }

    /// REPLAY_TIMER 満了
    mutating func replayTimerExpired() {
        guard !replayBuffer.isEmpty else {
            add(.warn, "リプレイバッファが空なのでタイマは動いていません")
            return
        }
        add(.warn, "TX: REPLAY_TIMER 満了 → バッファ内のTLPを再送")
        replay()
    }

    private mutating func replay() {
        replayNum += 1
        if replayNum >= Self.replayNumLimit {
            retrainCount += 1
            add(.warn, "REPLAY_NUM が \(Self.replayNumLimit) に到達 → 物理層がRecoveryでリンクを再トレーニング")
            replayNum = 0
        }
        for seq in replayBuffer {
            link.append(Packet(seq: seq, corrupted: false, isReplay: true))
            add(.tx, "TX: TLP #\(seq) を再送")
        }
    }

    // MARK: 受信側

    /// リンク上のTLPを受信側が処理し、ACK/NAKを返す
    mutating func receiverProcess() {
        guard !link.isEmpty else {
            add(.warn, "リンク上に処理するTLPがありません")
            return
        }
        var sendNak = false
        var sendAck = false

        for p in link {
            if p.corrupted {
                add(.rx, "RX: TLP #\(p.seq) のLCRCエラー → 破棄")
                sendNak = true
                continue
            }
            if p.seq == nextRcvSeq {
                if sendNak {
                    // NAKを出した後は、再送されたTLPが来るまで後続を捨てる
                    add(.rx, "RX: TLP #\(p.seq) はNAK後の後続TLP扱いで破棄")
                    continue
                }
                received.append(p.seq)
                nextRcvSeq = (nextRcvSeq + 1) % Self.seqModulo
                add(.rx, "RX: TLP #\(p.seq) を受理" + (p.isReplay ? "（再送分）" : ""))
                sendAck = true
            } else if isBefore(p.seq, nextRcvSeq) {
                add(.rx, "RX: TLP #\(p.seq) は受信済み（重複）→ 破棄してACK")
                sendAck = true
            } else {
                add(.rx, "RX: TLP #\(p.seq) は期待値 #\(nextRcvSeq) より先 → 欠落を検出、破棄")
                sendNak = true
            }
        }
        link.removeAll()

        let lastGood = (nextRcvSeq - 1 + Self.seqModulo) % Self.seqModulo
        if sendNak {
            deliverDLLP(isAck: false, seq: lastGood)
        } else if sendAck {
            deliverDLLP(isAck: true, seq: lastGood)
        }
    }

    private mutating func deliverDLLP(isAck: Bool, seq: Int) {
        let name = isAck ? "ACK" : "NAK"
        add(isAck ? .ack : .nak, "RX → TX: \(name) \(seq) を送信")
        if dropNextDLLP {
            dropNextDLLP = false
            add(.warn, "\(name) DLLP がCRCエラーで失われた！送信側は何も受け取れない")
            return
        }
        // 送信側：seq までをリプレイバッファから解放
        let before = replayBuffer.count
        replayBuffer.removeAll { !isAfter($0, seq) }
        let freed = before - replayBuffer.count
        if freed > 0 {
            ackdSeq = seq
            replayNum = 0
            add(isAck ? .ack : .nak, "TX: #\(seq) までの \(freed) 個をバッファから解放")
        }
        if !isAck {
            if replayBuffer.isEmpty {
                add(.nak, "TX: 再送対象なし")
            } else {
                add(.nak, "TX: NAK受信 → #\(replayBuffer.first!) 以降を再送")
                replay()
            }
        }
    }

    // MARK: ユーティリティ

    /// a が b より「前」の番号か（シーケンス番号の循環を考慮）
    private func isBefore(_ a: Int, _ b: Int) -> Bool {
        let d = (b - a + Self.seqModulo) % Self.seqModulo
        return d != 0 && d < Self.seqModulo / 2
    }

    private func isAfter(_ a: Int, _ b: Int) -> Bool {
        isBefore(b, a)
    }

    private mutating func add(_ kind: LogEntry.Kind, _ text: String) {
        log.append(LogEntry(kind: kind, text: text))
    }
}
