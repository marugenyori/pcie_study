import SwiftUI

extension Level {
    var color: Color {
        switch self {
        case .beginner: return .green
        case .intermediate: return .orange
        case .advanced: return .purple
        }
    }
}

struct LevelBadge: View {
    let level: Level

    var body: some View {
        Text(level.rawValue)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(level.color.opacity(0.15), in: Capsule())
            .foregroundStyle(level.color)
    }
}

/// 進捗リング
struct ProgressRing: View {
    let value: Double   // 0...1
    var lineWidth: CGFloat = 8
    var color: Color = .accentColor

    var body: some View {
        ZStack {
            Circle().stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0, min(1, value)))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: value)
        }
    }
}

extension Text {
    /// Markdown（**太字**、`コード`）を解釈して表示する
    init(markdown: String) {
        if let attributed = try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) {
            self.init(attributed)
        } else {
            self.init(verbatim: markdown)
        }
    }
}
