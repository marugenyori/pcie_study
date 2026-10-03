import SwiftUI

struct DiagramsHomeView: View {
    var body: some View {
        NavigationStack {
            List {
                ForEach(DiagramKind.allCases) { kind in
                    NavigationLink {
                        DiagramDestination(kind: kind)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: kind.symbol)
                                .font(.title2)
                                .foregroundStyle(.tint)
                                .frame(width: 36)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(kind.title).font(.body.weight(.medium))
                                Text(kind.subtitle).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .screenBackground()
            .navigationTitle("図解")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { DisplaySettingsButton() }
            }
        }
    }
}

struct DiagramDestination: View {
    let kind: DiagramKind

    var body: some View {
        switch kind {
        case .topology: TopologyDiagramView()
        case .layers: LayerEncapsulationView()
        case .tlpHeader: TLPHeaderDiagramView()
        case .ackNak: AckNakSimulatorView()
        case .ltssm: LTSSMDiagramView()
        }
    }
}
