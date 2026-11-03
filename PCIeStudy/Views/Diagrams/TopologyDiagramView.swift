import SwiftUI

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
