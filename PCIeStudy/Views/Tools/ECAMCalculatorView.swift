import SwiftUI

struct ECAMCalculatorView: View {
    @State private var baseText = "E0000000"
    @State private var bus = 1
    @State private var device = 0
    @State private var function = 0
    @State private var offsetText = "000"

    @State private var reverseText = "E0100000"

    private var base: UInt64? { UInt64(baseText.trimmingCharacters(in: .whitespaces), radix: 16) }
    private var offset: Int? {
        guard let v = Int(offsetText.trimmingCharacters(in: .whitespaces), radix: 16), v <= 0xFFF else { return nil }
        return v
    }

    var body: some View {
        Form {
            Section("BDF → アドレス") {
                HStack {
                    Text("ECAM Base  0x")
                    TextField("E0000000", text: $baseText)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                Stepper("Bus: \(bus)（0x\(hex(bus, 2))）", value: $bus, in: 0...255)
                Stepper("Device: \(device)（0x\(hex(device, 2))）", value: $device, in: 0...31)
                Stepper("Function: \(function)", value: $function, in: 0...7)
                HStack {
                    Text("Offset  0x")
                    TextField("000", text: $offsetText)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                if let base, let offset {
                    let addr = PCIeCalc.ecamAddress(base: base, bus: bus, device: device, function: function, offset: offset)
                    VStack(spacing: 8) {
                        ResultCard(title: "\(hex(bus, 2)):\(hex(device, 2)).\(function) + 0x\(hex(offset, 3))",
                                   value: "0x" + String(addr, radix: 16, uppercase: true))
                        Text(verbatim: "Base + (\(bus) << 20) + (\(device) << 15) + (\(function) << 12) + 0x\(hex(offset, 3))")
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                } else {
                    Text("16進数で入力してください（Offsetは 000〜FFF）").foregroundStyle(.red).font(.caption)
                }
            }

            Section("アドレス → BDF") {
                HStack {
                    Text("アドレス  0x")
                    TextField("E0100000", text: $reverseText)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                if let base, let addr = UInt64(reverseText.trimmingCharacters(in: .whitespaces), radix: 16), addr >= base {
                    let d = PCIeCalc.decodeECAM(offset: addr - base)
                    LabeledContent("Base からのオフセット", value: "0x" + String(addr - base, radix: 16, uppercase: true))
                    LabeledContent("BDF", value: "\(hex(d.bus, 2)):\(hex(d.device, 2)).\(d.function)")
                    LabeledContent("レジスタ", value: "0x\(hex(d.register, 3))" + registerName(d.register))
                    if addr - base >= (1 << 28) {
                        Text("256バス分（256MB）の範囲を超えています").font(.caption).foregroundStyle(.orange)
                    }
                } else {
                    Text("Base 以上のアドレスを16進数で入力してください").foregroundStyle(.secondary).font(.caption)
                }
            }

            Section("メモ") {
                Text("ECAMは1 Functionあたり4KB、1バスあたり 32×8×4KB = 1MB、256バスで256MBの領域を使います。Baseの値はACPIのMCFGテーブルに記載されています（Linuxでは dmesg の「MMCONFIG」や「ECAM」で確認できます）。")
                    .font(.callout)
            }
        }
        .screenBackground()
        .navigationTitle("ECAMアドレス計算")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func hex(_ v: Int, _ width: Int) -> String {
        let s = String(v, radix: 16, uppercase: true)
        return String(repeating: "0", count: max(0, width - s.count)) + s
    }

    private func registerName(_ reg: Int) -> String {
        switch reg {
        case 0x00: return "（Vendor ID）"
        case 0x02: return "（Device ID）"
        case 0x04: return "（Command）"
        case 0x06: return "（Status）"
        case 0x08: return "（Revision ID）"
        case 0x0E: return "（Header Type）"
        case 0x10...0x27: return "（BAR）"
        case 0x34: return "（Capabilities Pointer）"
        case 0x3C: return "（Interrupt Line）"
        case 0x100: return "（拡張Capabilityの先頭）"
        default: return ""
        }
    }
}

#Preview {
    NavigationStack { ECAMCalculatorView() }
}
