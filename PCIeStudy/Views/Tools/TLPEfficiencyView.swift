import SwiftUI

struct TLPEfficiencyView: View {
    @State private var payload = 256
    @State private var use4DW = false
    @State private var ecrc = false
    @State private var gen: PCIeGen = .gen4
    @State private var lanes = 16

    private let payloadOptions = [0, 4, 32, 64, 128, 256, 512, 1024, 2048, 4096]
    private let nonFlitGens: [PCIeGen] = [.gen1, .gen2, .gen3, .gen4, .gen5]

    private var header: Int { use4DW ? 16 : 12 }
    private var efficiency: Double { PCIeCalc.tlpEfficiency(payload: payload, headerBytes: header, ecrc: ecrc) }
    private var total: Int { payload + header + (ecrc ? 4 : 0) + PCIeCalc.tlpFramingOverhead }

    var body: some View {
        Form {
            Section {
                Picker("ペイロード", selection: $payload) {
                    ForEach(payloadOptions, id: \.self) { Text("\($0) B").tag($0) }
                }
                Toggle("64ビットアドレス（4DWヘッダ）", isOn: $use4DW)
                Toggle("ECRC付き", isOn: $ecrc)
                Picker("世代", selection: $gen) {
                    ForEach(nonFlitGens) { Text($0.name).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("レーン数", selection: $lanes) {
                    ForEach([1, 2, 4, 8, 16], id: \.self) { Text("x\($0)").tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("条件（Gen1〜5・非FLIT）")
            }

            Section("1 TLP の内訳") {
                breakdownBar
                LabeledContent("フレーミング + Seq# + LCRC", value: "\(PCIeCalc.tlpFramingOverhead) B")
                LabeledContent("ヘッダ", value: "\(header) B")
                if ecrc { LabeledContent("ECRC", value: "4 B") }
                LabeledContent("ペイロード", value: "\(payload) B")
                LabeledContent("合計", value: "\(total) B")
            }

            Section("結果") {
                VStack(spacing: 10) {
                    ResultCard(title: "TLP転送効率", value: String(format: "%.1f%%", efficiency * 100),
                               color: efficiency > 0.9 ? .green : (efficiency > 0.7 ? .orange : .red))
                    ResultCard(title: "\(gen.name) x\(lanes) での実効データ帯域（目安）",
                               value: PCIeCalc.formatGBps(PCIeCalc.bandwidthGBps(gen: gen, lanes: lanes) * efficiency),
                               caption: "DLLP（ACK・UpdateFC）やSKPの分は含みません")
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
            }

            Section("ポイント") {
                Text("ペイロードが小さいほどヘッダの割合が増え、効率が下がります。MPS（Max Payload Size）を大きくするとDMAの効率が上がりますが、経路上の全デバイスが対応する値に揃える必要があります。")
                    .font(.callout)
            }
        }
        .navigationTitle("TLP転送効率")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var breakdownBar: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let t = CGFloat(max(total, 1))
            HStack(spacing: 0) {
                Rectangle().fill(Color.orange.opacity(0.6))
                    .frame(width: w * CGFloat(PCIeCalc.tlpFramingOverhead) / t)
                Rectangle().fill(Color.blue.opacity(0.6))
                    .frame(width: w * CGFloat(header) / t)
                if ecrc {
                    Rectangle().fill(Color.indigo.opacity(0.6)).frame(width: w * 4 / t)
                }
                Rectangle().fill(Color.green.opacity(0.6))
                    .frame(width: w * CGFloat(payload) / t)
            }
        }
        .frame(height: 20)
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

#Preview {
    NavigationStack { TLPEfficiencyView() }
}
