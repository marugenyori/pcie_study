import SwiftUI

struct ToolsHomeView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink {
                    BandwidthCalculatorView()
                } label: {
                    ToolRow(symbol: "speedometer", title: "帯域幅計算", detail: "世代とレーン数から実効帯域を計算")
                }
                NavigationLink {
                    TLPEfficiencyView()
                } label: {
                    ToolRow(symbol: "chart.bar.xaxis", title: "TLP転送効率", detail: "ペイロードサイズとヘッダのオーバーヘッド")
                }
                NavigationLink {
                    ECAMCalculatorView()
                } label: {
                    ToolRow(symbol: "number", title: "ECAMアドレス計算", detail: "BDF ⇄ コンフィグ空間アドレス")
                }
                NavigationLink {
                    BARSizeView()
                } label: {
                    ToolRow(symbol: "memorychip", title: "BARサイズ判定", detail: "全1書き込み後の読み戻し値から計算")
                }
            }
            .navigationTitle("ツール")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { DisplaySettingsButton() }
            }
        }
    }
}

struct ToolRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 36)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.body.weight(.medium))
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

/// 結果表示用の大きな数値カード
struct ResultCard: View {
    let title: String
    let value: String
    var caption: String? = nil
    var color: Color = .accentColor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold().monospacedDigit())
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let caption {
                Text(caption).font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
    }
}
