import SwiftUI

struct BandwidthCalculatorView: View {
    @State private var gen: PCIeGen = .gen4
    @State private var lanes = 4

    private let laneOptions = [1, 2, 4, 8, 16]

    private var perDirection: Double { PCIeCalc.bandwidthGBps(gen: gen, lanes: lanes) }
    private var raw: Double { gen.rate * Double(lanes) / 8 }

    var body: some View {
        Form {
            Section("条件") {
                Picker("世代", selection: $gen) {
                    ForEach(PCIeGen.allCases) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("レーン数", selection: $lanes) {
                    ForEach(laneOptions, id: \.self) { Text("x\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
                LabeledContent("転送速度", value: "\(gen.rate.formatted()) GT/s / レーン")
                LabeledContent("符号化", value: gen.encoding)
                LabeledContent("符号化効率", value: String(format: "%.2f%%", gen.encodingEfficiency * 100))
            }

            Section("結果") {
                VStack(spacing: 10) {
                    ResultCard(title: "片方向の帯域（符号化後）", value: PCIeCalc.formatGBps(perDirection))
                    ResultCard(title: "双方向の合計", value: PCIeCalc.formatGBps(perDirection * 2), color: .purple)
                    if gen.isFlit {
                        ResultCard(title: "FLITのTLP領域（236/256）を考慮した片方向",
                                   value: PCIeCalc.formatGBps(PCIeCalc.flitTLPBandwidthGBps(gen: gen, lanes: lanes)),
                                   caption: "さらにTLPヘッダ等のオーバーヘッドがかかります",
                                   color: .orange)
                    }
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            Section("計算式") {
                Text(verbatim: "\(gen.rate.formatted()) GT/s × \(formatEff) × \(lanes) ÷ 8 = \(String(format: "%.3f", perDirection)) GB/s")
                    .font(.callout.monospaced())
                Text("生の値（符号化前）: \(String(format: "%.2f", raw)) GB/s")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("全世代の比較（x\(lanes)・片方向）") {
                ForEach(PCIeGen.allCases) { g in
                    let v = PCIeCalc.bandwidthGBps(gen: g, lanes: lanes)
                    let maxV = PCIeCalc.bandwidthGBps(gen: .gen7, lanes: lanes)
                    HStack {
                        Text(g.name).font(.caption.monospaced()).frame(width: 40, alignment: .leading)
                        GeometryReader { geo in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(g == gen ? Color.accentColor : Color.secondary.opacity(0.3))
                                .frame(width: max(2, geo.size.width * v / maxV))
                        }
                        .frame(height: 14)
                        Text(PCIeCalc.formatGBps(v))
                            .font(.caption.monospacedDigit())
                            .frame(width: 84, alignment: .trailing)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { gen = g }
                }
            }
        }
        .navigationTitle("帯域幅計算")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var formatEff: String {
        switch gen {
        case .gen1, .gen2: return "0.8"
        case .gen3, .gen4, .gen5: return "(128/130)"
        case .gen6, .gen7: return "1"
        }
    }
}

#Preview {
    NavigationStack { BandwidthCalculatorView() }
}
