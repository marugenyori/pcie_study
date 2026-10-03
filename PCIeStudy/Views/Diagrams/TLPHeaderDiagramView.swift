import SwiftUI

struct TLPHeaderDiagramView: View {
    @State private var format: TLPHeaderFormat = .memory3DW
    @State private var selected: TLPField?
    @State private var byte0: UInt8 = 0b0100_0000   // Fmt=010, Type=00000 → MWr 3DW

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Picker("形式", selection: $format) {
                    ForEach(TLPHeaderFormat.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: format) { selected = nil }

                Text("フィールドをタップすると説明が表示されます。横向きにすると見やすくなります。")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                headerGrid

                if let selected {
                    fieldDetail(selected)
                        .transition(.opacity)
                }

                Divider()
                decoder
            }
            .padding()
            .animation(.easeInOut(duration: 0.2), value: selected)
        }
        .screenBackground()
        .navigationTitle("TLPヘッダ構造")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - ヘッダの図

    private var headerGrid: some View {
        VStack(spacing: 4) {
            // ビット番号
            HStack(spacing: 0) {
                Text("").frame(width: 36)
                GeometryReader { geo in
                    let w = geo.size.width / 32
                    ZStack(alignment: .topLeading) {
                        ForEach([31, 24, 23, 16, 15, 8, 7, 0], id: \.self) { bit in
                            Text("\(bit)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: w * 2)
                                .offset(x: CGFloat(31 - bit) * w - w / 2)
                        }
                    }
                }
                .frame(height: 12)
            }

            ForEach(0..<format.dwCount, id: \.self) { dw in
                HStack(spacing: 0) {
                    Text("DW\(dw)")
                        .font(.caption2.monospaced().bold())
                        .frame(width: 36, alignment: .leading)
                    GeometryReader { geo in
                        let unit = geo.size.width / 32
                        HStack(spacing: 0) {
                            ForEach(format.fields.filter { $0.dw == dw }) { field in
                                fieldCell(field)
                                    .frame(width: unit * CGFloat(field.width))
                            }
                        }
                    }
                    .frame(height: 44)
                }
            }

            HStack(spacing: 0) {
                Text("").frame(width: 36)
                HStack(spacing: 0) {
                    ForEach(0..<4, id: \.self) { b in
                        Text("Byte \(b)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
    }

    private func fieldCell(_ field: TLPField) -> some View {
        let isSelected = selected == field
        return Button {
            selected = isSelected ? nil : field
        } label: {
            Text(field.name)
                .font(.system(size: field.width <= 2 ? 8 : 11, weight: .semibold))
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(color(for: field).opacity(isSelected ? 0.6 : 0.22))
                .overlay(Rectangle().stroke(Color(.systemBackground), lineWidth: 1))
                .overlay(Rectangle().stroke(isSelected ? Color.primary : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func color(for field: TLPField) -> Color {
        switch field.name {
        case "Fmt", "Type": return .blue
        case "TC", "Attr", "A2", "TH", "LN", "AT": return .purple
        case "TD", "EP": return .red
        case "Length", "Byte Count": return .orange
        case "Requester ID", "Completer ID", "Tag", "T8", "T9": return .green
        case "Last BE", "1st BE", "Status", "BCM": return .teal
        default: return .gray
        }
    }

    private func fieldDetail(_ field: TLPField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(field.fullName).font(.headline)
                Spacer()
                Text("DW\(field.dw) \(field.bitRange)（\(field.width)bit）")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
            Text(field.detail)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color(for: field).opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Fmt/Type デコーダ

    private var decoder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fmt / Type デコーダ").font(.title3.bold())
            Text("ヘッダの先頭バイト（Byte 0）のビットをタップして切り替えてみましょう。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach((0..<8).reversed(), id: \.self) { bit in
                    let on = (byte0 >> UInt8(bit)) & 1 == 1
                    Button {
                        byte0 ^= (1 << UInt8(bit))
                    } label: {
                        VStack(spacing: 2) {
                            Text(on ? "1" : "0")
                                .font(.title3.monospaced().bold())
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background((bit >= 5 ? Color.blue : Color.indigo).opacity(on ? 0.5 : 0.12),
                                            in: RoundedRectangle(cornerRadius: 6))
                            Text("\(bit)").font(.system(size: 9)).foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 16) {
                Label("Fmt（bit 7:5）", systemImage: "square.fill").foregroundStyle(.blue)
                Label("Type（bit 4:0）", systemImage: "square.fill").foregroundStyle(.indigo)
            }
            .font(.caption)

            HStack {
                Text(String(format: "0x%02X", byte0)).font(.body.monospaced())
                Spacer()
                Text(TLPTypeDecoder.decode(byte0: byte0))
                    .font(.headline)
                    .multilineTextAlignment(.trailing)
            }
            .padding()
            .cardStyle(cornerRadius: 12)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(presets.indices, id: \.self) { i in
                        Button(presets[i].0) { byte0 = presets[i].1 }
                            .buttonStyle(AppButtonStyle(.secondary))
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private var presets: [(String, UInt8)] {
        [("MRd32", 0x00), ("MRd64", 0x20), ("MWr32", 0x40), ("MWr64", 0x60),
         ("CfgRd0", 0x04), ("CfgWr0", 0x44), ("Cpl", 0x0A), ("CplD", 0x4A),
         ("Msg", 0x30), ("MsgD", 0x70)]
    }
}

#Preview {
    NavigationStack { TLPHeaderDiagramView() }
}
