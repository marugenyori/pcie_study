import SwiftUI

struct LayerEncapsulationView: View {
    enum PhyMode: String, CaseIterable, Identifiable {
        case gen12 = "Gen1/2"
        case gen35 = "Gen3〜5"
        var id: String { rawValue }
    }

    struct Segment: Identifiable {
        let id: String
        let label: String
        let bytes: Int
        let color: Color
        let layer: Int  // 0=TL, 1=DLL, 2=PHY
    }

    @State private var step = 0
    @State private var mode: PhyMode = .gen35
    @State private var payload = 64
    @State private var use4DW = false
    @State private var useECRC = false

    private let layerNames = ["トランザクション層", "データリンク層", "物理層"]
    private let layerColors: [Color] = [.blue, .green, .orange]

    private var segments: [Segment] {
        var s: [Segment] = []
        // 物理層（Gen1/2）
        if step >= 2 && mode == .gen12 {
            s.append(Segment(id: "stp", label: "STP", bytes: 1, color: .orange, layer: 2))
        }
        if step >= 2 && mode == .gen35 {
            s.append(Segment(id: "stptoken", label: "STPトークン\n(Seq#含む)", bytes: 4, color: .orange, layer: 2))
        } else if step >= 1 {
            s.append(Segment(id: "seq", label: "Seq#", bytes: 2, color: .green, layer: 1))
        }
        s.append(Segment(id: "hdr", label: "Header", bytes: use4DW ? 16 : 12, color: .blue, layer: 0))
        if payload > 0 {
            s.append(Segment(id: "data", label: "Data", bytes: payload, color: .cyan, layer: 0))
        }
        if useECRC {
            s.append(Segment(id: "ecrc", label: "ECRC", bytes: 4, color: .indigo, layer: 0))
        }
        if step >= 1 {
            s.append(Segment(id: "lcrc", label: "LCRC", bytes: 4, color: .green, layer: 1))
        }
        if step >= 2 && mode == .gen12 {
            s.append(Segment(id: "end", label: "END", bytes: 1, color: .orange, layer: 2))
        }
        return s
    }

    private var totalBytes: Int { segments.reduce(0) { $0 + $1.bytes } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("ステップ", selection: $step) {
                    ForEach(0..<3) { i in Text(layerNames[i]).tag(i) }
                }
                .pickerStyle(.segmented)

                Text(stepDescription)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(layerColors[step].opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

                packetBar

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(segments) { seg in
                        HStack {
                            RoundedRectangle(cornerRadius: 3).fill(seg.color.opacity(0.7)).frame(width: 14, height: 14)
                            Text(seg.label.replacingOccurrences(of: "\n", with: " "))
                            Spacer()
                            Text("\(seg.bytes) B").monospacedDigit()
                            Text(layerNames[seg.layer]).font(.caption2).foregroundStyle(.secondary)
                                .frame(width: 96, alignment: .trailing)
                        }
                        .font(.subheadline)
                    }
                    Divider()
                    HStack {
                        Text("合計").bold()
                        Spacer()
                        Text("\(totalBytes) B").bold().monospacedDigit()
                        Text("効率 \(efficiencyText)").font(.caption).foregroundStyle(.secondary)
                            .frame(width: 96, alignment: .trailing)
                    }
                }

                GroupBox("条件") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("物理層", selection: $mode) {
                            ForEach(PhyMode.allCases) { Text($0.rawValue).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        Stepper("ペイロード：\(payload) バイト", value: $payload, in: 0...512, step: 16)
                        Toggle("64ビットアドレス（4DWヘッダ）", isOn: $use4DW)
                        Toggle("ECRCを付ける（TD=1）", isOn: $useECRC)
                    }
                }
            }
            .padding()
            .animation(.spring(duration: 0.35), value: step)
            .animation(.easeInOut, value: mode)
        }
        .screenBackground()
        .navigationTitle("レイヤとカプセル化")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var efficiencyText: String {
        guard totalBytes > 0 else { return "-" }
        return String(format: "%.1f%%", Double(payload) / Double(totalBytes) * 100)
    }

    private var stepDescription: String {
        switch step {
        case 0:
            return "トランザクション層がヘッダとデータからTLPを作ります。必要ならend-to-endのECRCを付けます。"
        case 1:
            return "データリンク層が12ビットのシーケンス番号と32ビットのLCRCを付けます。このTLPは再送に備えてリプレイバッファに保持されます。"
        default:
            return mode == .gen12
                ? "物理層がSTPとENDの特殊シンボルで囲み、8b/10b符号化してレーンに振り分けます。"
                : "物理層がSTPトークン（長さとシーケンス番号を含む4バイト）を先頭に付けます。ENDはなく、長さで終端を判断します。128b/130bのブロックに詰めてレーンに振り分けます。"
        }
    }

    private var packetBar: some View {
        GeometryReader { geo in
            // データ部は見やすさのため圧縮して表示
            let displayWidths = segments.map { seg -> CGFloat in
                seg.id == "data" ? max(40, min(CGFloat(seg.bytes), 120)) : CGFloat(max(seg.bytes, 2)) * 5
            }
            let total = displayWidths.reduce(0, +)
            let scale = geo.size.width / max(total, 1)
            HStack(spacing: 1) {
                ForEach(Array(segments.enumerated()), id: \.element.id) { i, seg in
                    Text(seg.label)
                        .font(.system(size: 9, weight: .bold))
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .frame(width: max(displayWidths[i] * scale - 1, 1), height: 56)
                        .background(seg.color.opacity(0.35))
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .frame(height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    NavigationStack { LayerEncapsulationView() }
}
