import SwiftUI

struct AckNakSimulatorView: View {
    @State private var sim = AckNakSimulator()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("送信側（TX）が TLP を送り、受信側（RX）がまとめて処理して ACK/NAK を返します。エラーを注入して再送の動きを観察しましょう。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .top, spacing: 12) {
                    txPanel
                    rxPanel
                }

                linkPanel
                controls
                logPanel
            }
            .padding()
            .animation(.easeInOut(duration: 0.2), value: sim.log.count)
        }
        .screenBackground()
        .navigationTitle("ACK/NAK シミュレータ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var txPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("送信側 TX", systemImage: "arrow.up.circle").font(.headline)
            infoRow("NEXT_TRANSMIT_SEQ", "\(sim.nextTransmitSeq)")
            infoRow("REPLAY_NUM", "\(sim.replayNum) / \(AckNakSimulator.replayNumLimit)")
            if sim.retrainCount > 0 {
                infoRow("再トレーニング", "\(sim.retrainCount)回")
            }
            Text("リプレイバッファ").font(.caption.bold())
            chips(sim.replayBuffer, color: .blue, empty: "（空）")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var rxPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("受信側 RX", systemImage: "arrow.down.circle").font(.headline)
            infoRow("NEXT_RCV_SEQ", "\(sim.nextRcvSeq)")
            Text("受理したTLP").font(.caption.bold())
            chips(Array(sim.received.suffix(12)), color: .green, empty: "（なし）")
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }

    private var linkPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("リンク上のTLP（未処理）").font(.caption.bold())
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if sim.link.isEmpty {
                        Text("—").foregroundStyle(.secondary)
                    }
                    ForEach(sim.link) { p in
                        HStack(spacing: 2) {
                            Text("#\(p.seq)")
                            if p.corrupted { Image(systemName: "bolt.fill") }
                            if p.isReplay { Image(systemName: "arrow.uturn.left") }
                        }
                        .font(.caption.monospaced().bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background((p.corrupted ? Color.red : Color.orange).opacity(0.2), in: Capsule())
                    }
                    Image(systemName: "arrow.right").foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle(cornerRadius: 12)
    }

    private var controls: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Button {
                    sim.sendTLP(corrupt: false)
                } label: {
                    Label("TLP送信", systemImage: "paperplane").frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.primary))

                Button {
                    sim.sendTLP(corrupt: true)
                } label: {
                    Label("エラー付き送信", systemImage: "bolt").frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.secondary))
                .tint(.red)
            }
            HStack(spacing: 10) {
                Button {
                    sim.receiverProcess()
                } label: {
                    Label("RXが処理", systemImage: "tray.and.arrow.down").frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.primary))
                .tint(.green)

                Button {
                    sim.replayTimerExpired()
                } label: {
                    Label("タイマ満了", systemImage: "timer").frame(maxWidth: .infinity)
                }
                .buttonStyle(AppButtonStyle(.secondary))
                .tint(.orange)
            }
            Toggle(isOn: $sim.dropNextDLLP) {
                Label("次のACK/NAKを失わせる", systemImage: "exclamationmark.triangle")
                    .font(.subheadline)
            }
            Button("リセット", role: .destructive) { sim = AckNakSimulator() }
                .font(.subheadline)
        }
    }

    private var logPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ログ").font(.headline)
            if sim.log.isEmpty {
                Text("「TLP送信」を何回か押してから「RXが処理」を押してみましょう。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(sim.log.reversed()) { entry in
                HStack(alignment: .top, spacing: 8) {
                    Circle().fill(color(entry.kind)).frame(width: 8, height: 8).padding(.top, 5)
                    Text(entry.text)
                        .font(.caption.monospaced())
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func color(_ kind: AckNakSimulator.LogEntry.Kind) -> Color {
        switch kind {
        case .tx: return .blue
        case .rx: return .green
        case .ack: return .teal
        case .nak: return .red
        case .warn: return .orange
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.system(size: 10, design: .monospaced)).foregroundStyle(.secondary)
                .lineLimit(1).minimumScaleFactor(0.7)
            Spacer()
            Text(value).font(.caption.monospaced().bold())
        }
    }

    private func chips(_ values: [Int], color: Color, empty: String) -> some View {
        let columns = [GridItem(.adaptive(minimum: 40), spacing: 4)]
        return Group {
            if values.isEmpty {
                Text(empty).font(.caption).foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                    ForEach(values, id: \.self) { v in
                        Text("#\(v)")
                            .font(.caption2.monospaced().bold())
                            .padding(.vertical, 4)
                            .frame(maxWidth: .infinity)
                            .background(color.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack { AckNakSimulatorView() }
}
