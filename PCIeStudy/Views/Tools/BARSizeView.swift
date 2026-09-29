import SwiftUI

struct BARSizeView: View {
    @State private var lowText = "FFF0000C"
    @State private var highText = "FFFFFFFF"

    private var low: UInt32? { UInt32(lowText.trimmingCharacters(in: .whitespaces), radix: 16) }
    private var high: UInt32? { UInt32(highText.trimmingCharacters(in: .whitespaces), radix: 16) }

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("BAR 読み戻し値  0x")
                    TextField("FFF0000C", text: $lowText)
                        .font(.body.monospaced())
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                }
                if let low, low & 1 == 0, (low >> 1) & 0x3 == 0b10 {
                    HStack {
                        Text("上位BAR 読み戻し値  0x")
                        TextField("FFFFFFFF", text: $highText)
                            .font(.body.monospaced())
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled()
                    }
                }
            } header: {
                Text("全ビット1を書き込んだ後の読み戻し値")
            }

            Section("結果") {
                if let low, let info = PCIeCalc.decodeBAR(readBack: low, upper: high) {
                    ResultCard(title: "BARサイズ", value: PCIeCalc.formatBytes(info.size),
                               caption: "0x" + String(info.size, radix: 16, uppercase: true) + " バイト")
                        .listRowInsets(EdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8))
                    LabeledContent("空間", value: info.isIO ? "I/O" : "メモリ")
                    if !info.isIO {
                        LabeledContent("アドレス幅", value: info.is64Bit ? "64ビット（次のBARと対）" : "32ビット")
                        LabeledContent("bit 3（旧Prefetchable）", value: info.prefetchable ? "1" : "0")
                    }
                } else {
                    Text("有効な値を16進数で入力してください（0 は未実装のBARを意味します）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if let low {
                Section("下位4ビットの意味") {
                    bitRow("bit 0", low & 1 == 1 ? "1 = I/O空間" : "0 = メモリ空間")
                    if low & 1 == 0 {
                        bitRow("bit 2:1", typeText((low >> 1) & 0x3))
                        bitRow("bit 3", "定義なし（旧Prefetchable）。64ビットBARは1、32ビットBARは0が推奨。現在の値：\((low >> 3) & 1)")
                    }
                }
            }

            Section("手順") {
                Text("1. BARの元の値を保存\n2. FFFFFFFFh を書き込む\n3. 読み戻す（固定0のビットがサイズを表す）\n4. 属性ビットをマスクし、ビット反転して +1\n5. 元の値を書き戻す")
                    .font(.callout)
            }
        }
        .navigationTitle("BARサイズ判定")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func bitRow(_ bit: String, _ text: String) -> some View {
        HStack {
            Text(bit).font(.caption.monospaced()).frame(width: 60, alignment: .leading)
            Text(text).font(.callout)
        }
    }

    private func typeText(_ t: UInt32) -> String {
        switch t {
        case 0b00: return "00 = 32ビットアドレス"
        case 0b10: return "10 = 64ビットアドレス"
        default: return "\(t == 1 ? "01" : "11") = 予約"
        }
    }
}

#Preview {
    NavigationStack { BARSizeView() }
}
