import Foundation

/// 学習記録から計算する実績バッジ
struct Achievement: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let unlocked: Bool

    static func all(for progress: ProgressStore) -> [Achievement] {
        let best = progress.stats.bestStreak
        let answered = progress.answeredTotal
        let chapters = LessonData.all.filter { progress.isCompleted($0.id) }.count
        let perfect = progress.quizBest.values.contains(100)
        return [
            Achievement(id: "first", title: "はじめの一歩", detail: "1問解く", symbol: "figure.walk", unlocked: answered >= 1),
            Achievement(id: "streak3", title: "三日坊主卒業", detail: "3日連続で目標達成", symbol: "flame", unlocked: best >= 3),
            Achievement(id: "streak7", title: "1週間連続", detail: "7日連続で目標達成", symbol: "flame.fill", unlocked: best >= 7),
            Achievement(id: "streak30", title: "習慣マスター", detail: "30日連続で目標達成", symbol: "crown.fill", unlocked: best >= 30),
            Achievement(id: "q100", title: "100問突破", detail: "通算100問解く", symbol: "100.circle", unlocked: answered >= 100),
            Achievement(id: "q500", title: "500問突破", detail: "通算500問解く", symbol: "star.circle.fill", unlocked: answered >= 500),
            Achievement(id: "perfect", title: "パーフェクト", detail: "クイズで全問正解", symbol: "checkmark.seal.fill", unlocked: perfect),
            Achievement(id: "chapters", title: "全章読破", detail: "\(LessonData.all.count)章すべて読了", symbol: "books.vertical.fill", unlocked: chapters == LessonData.all.count),
            Achievement(id: "level5", title: "リンクトレーナー", detail: "レベル5になる", symbol: "arrow.up.circle.fill", unlocked: progress.level >= 5),
            Achievement(id: "level10", title: "パケットマスター", detail: "レベル10になる", symbol: "star.square.fill", unlocked: progress.level >= 10),
            Achievement(id: "timeattack20", title: "スピードスター", detail: "タイムアタックで20問正解", symbol: "stopwatch.fill", unlocked: (progress.gameBest[GameMode.timeAttack.rawValue] ?? 0) >= 20),
            Achievement(id: "survival15", title: "不死身", detail: "サバイバルで15問正解", symbol: "heart.circle.fill", unlocked: (progress.gameBest[GameMode.survival.rawValue] ?? 0) >= 15),
        ]
    }
}
