import SwiftUI
import Observation

/// 画面ごとのゲーム演出（XPの表示・紙吹雪・レベルアップ）
@MainActor
@Observable
final class GameFX {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let detail: String?
    }

    var toast: Toast?
    var levelUp: Int?
    /// 増やすと紙吹雪が出る
    var confetti = 0

    func show(_ gain: XPGain, combo: Int = 0) {
        var details: [String] = []
        if combo >= 2 { details.append("🔥 \(combo)連続！") }
        details += gain.completedQuests.map { "クエスト達成：\($0.title)" }
        if gain.total > 0 || !details.isEmpty {
            let toast = Toast(title: gain.total > 0 ? "+\(gain.total) XP" : "クエスト達成",
                              detail: details.isEmpty ? nil : details.joined(separator: "\n"))
            self.toast = toast
            Task {
                try? await Task.sleep(for: .seconds(gain.completedQuests.isEmpty ? 1.3 : 2.4))
                if self.toast?.id == toast.id { self.toast = nil }
            }
        }
        if let level = gain.leveledUpTo {
            levelUp = level
            confetti += 1
        }
    }

    func celebrate() {
        confetti += 1
    }
}

private struct GameEffectsModifier: ViewModifier {
    let fx: GameFX

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = fx.toast {
                    XPToastView(toast: toast)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .allowsHitTesting(false)
                }
            }
            .overlay {
                ConfettiView(trigger: fx.confetti)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .overlay {
                if let level = fx.levelUp {
                    LevelUpOverlay(level: level) { fx.levelUp = nil }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }
            .animation(.spring(duration: 0.35), value: fx.toast)
            .animation(.spring(duration: 0.4), value: fx.levelUp)
    }
}

extension View {
    func gameEffects(_ fx: GameFX) -> some View {
        modifier(GameEffectsModifier(fx: fx))
    }
}

// MARK: - XPの表示

private struct XPToastView: View {
    let toast: GameFX.Toast

    var body: some View {
        VStack(spacing: 2) {
            Text(toast.title)
                .font(.title3.weight(.heavy))
                .foregroundStyle(.white)
            if let detail = toast.detail {
                Text(detail)
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.95))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Capsule().fill(Color.orange.gradient))
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
    }
}

// MARK: - 紙吹雪

struct ConfettiView: View {
    let trigger: Int

    private struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let drift: Double
        let spin: Double
        let size: CGSize
        let color: Color
    }

    @State private var start: Date?
    @State private var pieces: [Piece] = []
    private static let duration = 3.0
    private static let colors: [Color] = [.orange, .green, .blue, .pink, .yellow, .purple, .teal]

    var body: some View {
        TimelineView(.animation(paused: start == nil)) { timeline in
            Canvas { context, size in
                guard let start else { return }
                let t = timeline.date.timeIntervalSince(start)
                for p in pieces {
                    let lt = t - p.delay
                    guard lt > 0 else { continue }
                    let x = p.x * size.width + sin(lt * 3 + p.drift) * 24
                    let y = -20 + p.speed * lt + 260 * lt * lt
                    guard y < size.height + 20 else { continue }
                    var ctx = context
                    ctx.opacity = max(0, 1 - lt / Self.duration)
                    ctx.translateBy(x: x, y: y)
                    ctx.rotate(by: .radians(p.spin * lt))
                    ctx.fill(Path(CGRect(origin: CGPoint(x: -p.size.width / 2, y: -p.size.height / 2), size: p.size)),
                             with: .color(p.color))
                }
            }
        }
        .onChange(of: trigger) {
            pieces = (0..<90).map { _ in
                Piece(x: .random(in: 0...1), delay: .random(in: 0...0.4), speed: .random(in: 60...220),
                      drift: .random(in: 0...6), spin: .random(in: -8...8),
                      size: CGSize(width: .random(in: 6...10), height: .random(in: 10...16)),
                      color: Self.colors.randomElement() ?? .orange)
            }
            let started = Date.now
            start = started
            Task {
                try? await Task.sleep(for: .seconds(Self.duration + 0.5))
                if start == started { start = nil }
            }
        }
    }
}

// MARK: - レベルアップ

private struct LevelUpOverlay: View {
    let level: Int
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture(perform: onClose)
            VStack(spacing: 14) {
                Text("LEVEL UP!")
                    .font(.title2.weight(.black))
                    .foregroundStyle(.orange)
                XPLevelBadge(level: level, size: 96)
                Text(GameRules.title(forLevel: level))
                    .font(.headline)
                Text("レベル\(level)になりました")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("やったね！", action: onClose)
                    .buttonStyle(AppButtonStyle(.primary))
                    .frame(maxWidth: 220)
            }
            .padding(28)
            .cardStyle(cornerRadius: 24)
            .padding(40)
        }
    }
}

/// レベルの丸いバッジ
struct XPLevelBadge: View {
    let level: Int
    var size: CGFloat = 44

    var body: some View {
        ZStack {
            Circle().fill(Color.orange.gradient)
            Circle().strokeBorder(.white.opacity(0.6), lineWidth: size * 0.05)
            VStack(spacing: -2) {
                Text("Lv")
                    .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                Text("\(level)")
                    .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .accessibilityLabel("レベル\(level)")
    }
}

// MARK: - レベルとクエストのカード

struct LevelCard: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        let info = GameRules.levelProgress(xp: progress.xp)
        HStack(spacing: 14) {
            XPLevelBadge(level: info.level, size: 56)
            VStack(alignment: .leading, spacing: 6) {
                Text(GameRules.title(forLevel: info.level))
                    .font(.headline)
                ProgressView(value: info.ratio)
                    .tint(.orange)
                Text("次のレベルまで \(info.needed - info.current) XP（累計 \(progress.xp) XP）")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .cardStyle(cornerRadius: 20)
    }
}

struct QuestsCard: View {
    @Environment(ProgressStore.self) private var progress

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("デイリークエスト", systemImage: "scroll.fill")
                    .font(.headline)
                Spacer()
                Text("各 +\(GameRules.questXP) XP")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
            }
            ForEach(DailyQuest.allCases) { quest in
                let done = progress.isQuestDone(quest)
                let value = min(progress.questProgress(quest), quest.goal)
                HStack(spacing: 12) {
                    Image(systemName: done ? "checkmark.seal.fill" : quest.symbol)
                        .font(.title3)
                        .foregroundStyle(done ? Color.green : Color.orange)
                        .frame(width: 30)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(quest.title)
                            .font(.subheadline.bold())
                            .strikethrough(done)
                        ProgressView(value: Double(value), total: Double(quest.goal))
                            .tint(done ? .green : .orange)
                    }
                    Text("\(value)/\(quest.goal)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .cardStyle(cornerRadius: 20)
    }
}
