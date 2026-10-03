import SwiftUI

struct TopoNode: Identifiable, Hashable {
    enum Kind: String {
        case cpu = "CPU"
        case rootComplex = "Root Complex"
        case rootPort = "Root Port"
        case switchUp = "Switch (Upstream)"
        case switchDown = "Switch (Downstream)"
        case endpoint = "Endpoint"
    }

    let id: String
    let name: String
    let kind: Kind
    let bdf: String?
    let header: String?
    let detail: String
    var children: [TopoNode] = []
}

enum TopologySample {
    static let root = TopoNode(
        id: "cpu", name: "CPU", kind: .cpu, bdf: nil, header: nil,
        detail: "CPUコアとメモリコントローラ。PCIeデバイスへのアクセスはRoot Complexを通じて行われます。",
        children: [
            TopoNode(
                id: "rc", name: "Root Complex", kind: .rootComplex, bdf: "Bus 0", header: nil,
                detail: "PCIe階層の根。Bus 0 にホストブリッジ（例：00:00.0）、内蔵デバイス、ルートポートが並びます。CPUからのメモリアクセスをTLPに変換し、デバイスからのDMAをメモリに届けます。",
                children: [
                    TopoNode(
                        id: "rp1", name: "Root Port 1", kind: .rootPort, bdf: "00:01.0", header: "Type 1",
                        detail: "ルートポートは仮想PCI-PCIブリッジ（Type 1ヘッダ）です。Secondary Bus=1, Subordinate Bus=1 に設定され、Bus 1あてのTLPを下流へ送ります。",
                        children: [
                            TopoNode(id: "gpu", name: "GPU", kind: .endpoint, bdf: "01:00.0", header: "Type 0",
                                     detail: "x16で接続されたグラフィックスカード。大きなBAR（VRAMのウィンドウ）を持ち、MSI-Xで割り込みを通知します。同じデバイスのHDMIオーディオが 01:00.1 として見えることもあります。")
                        ]),
                    TopoNode(
                        id: "rp2", name: "Root Port 2", kind: .rootPort, bdf: "00:1c.0", header: "Type 1",
                        detail: "Secondary Bus=2, Subordinate Bus=5。配下のスイッチ全体（Bus 2〜5）をカバーします。",
                        children: [
                            TopoNode(
                                id: "usp", name: "Switch USP", kind: .switchUp, bdf: "02:00.0", header: "Type 1",
                                detail: "スイッチのアップストリームポート。Secondary Bus=3（スイッチ内部の仮想バス）、Subordinate=5。",
                                children: [
                                    TopoNode(
                                        id: "dsp1", name: "DSP 1", kind: .switchDown, bdf: "03:00.0", header: "Type 1",
                                        detail: "スイッチのダウンストリームポート。スイッチ内部の仮想バス（Bus 3）上にDevice 0として並びます。Secondary=4。",
                                        children: [
                                            TopoNode(id: "nvme", name: "NVMe SSD", kind: .endpoint, bdf: "04:00.0", header: "Type 0",
                                                     detail: "x4接続のNVMe SSD。BAR0にコントローラのレジスタがあり、MSI-Xでキューごとに割り込みを出します。")
                                        ]),
                                    TopoNode(
                                        id: "dsp2", name: "DSP 2", kind: .switchDown, bdf: "03:01.0", header: "Type 1",
                                        detail: "2つ目のダウンストリームポート。Bus 3上のDevice 1です。Secondary=5。",
                                        children: [
                                            TopoNode(id: "nic0", name: "NIC Port0", kind: .endpoint, bdf: "05:00.0", header: "Type 0",
                                                     detail: "デュアルポートNICのFunction 0。マルチファンクションデバイスで、Header Typeのbit7が1になっています。"),
                                            TopoNode(id: "nic1", name: "NIC Port1", kind: .endpoint, bdf: "05:00.1", header: "Type 0",
                                                     detail: "同じNICのFunction 1。物理的なリンクは1本で、Function番号だけが異なります。"),
                                        ]),
                                ]),
                        ]),
                ]),
        ])
}

struct TopologyDiagramView: View {
    @State private var selected: TopoNode? = TopologySample.root.children.first

    var body: some View {
        VStack(spacing: 0) {
            ScrollView([.horizontal, .vertical]) {
                TopoNodeView(node: TopologySample.root, selected: $selected)
                    .padding()
            }
            .frame(maxHeight: .infinity)

            if let node = selected {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(node.name).font(.headline)
                        Spacer()
                        if let bdf = node.bdf {
                            Text(bdf).font(.subheadline.monospaced().bold())
                        }
                    }
                    HStack(spacing: 8) {
                        Text(node.kind.rawValue)
                        if let h = node.header { Text("· \(h) ヘッダ") }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    Text(node.detail)
                        .font(.callout)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
            }
        }
        .screenBackground()
        .navigationTitle("トポロジとBDF")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct TopoNodeView: View {
    let node: TopoNode
    @Binding var selected: TopoNode?

    private let lineColor = Color.secondary.opacity(0.5)

    var body: some View {
        VStack(spacing: 0) {
            card
            if !node.children.isEmpty {
                Rectangle().fill(lineColor).frame(width: 2, height: 14)
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(node.children.enumerated()), id: \.element.id) { index, child in
                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                Rectangle().fill(index == 0 ? Color.clear : lineColor).frame(height: 2)
                                Rectangle().fill(index == node.children.count - 1 ? Color.clear : lineColor).frame(height: 2)
                            }
                            Rectangle().fill(lineColor).frame(width: 2, height: 12)
                            TopoNodeView(node: child, selected: $selected)
                        }
                    }
                }
            }
        }
    }

    private var card: some View {
        let isSelected = selected?.id == node.id
        return Button {
            selected = node
        } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol)
                    .font(.system(size: 16))
                Text(node.name)
                    .font(.caption.bold())
                    .lineLimit(1)
                if let bdf = node.bdf {
                    Text(bdf).font(.system(size: 10, design: .monospaced))
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .frame(minWidth: 84)
            .background(color.opacity(isSelected ? 0.45 : 0.15), in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? color : .clear, lineWidth: 2))
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 4)
    }

    private var color: Color {
        switch node.kind {
        case .cpu: return .gray
        case .rootComplex: return .red
        case .rootPort: return .orange
        case .switchUp, .switchDown: return .purple
        case .endpoint: return .blue
        }
    }

    private var symbol: String {
        switch node.kind {
        case .cpu: return "cpu"
        case .rootComplex: return "circle.hexagongrid"
        case .rootPort: return "arrow.down.to.line"
        case .switchUp, .switchDown: return "arrow.triangle.branch"
        case .endpoint: return "memorychip"
        }
    }
}

#Preview {
    NavigationStack { TopologyDiagramView() }
}
