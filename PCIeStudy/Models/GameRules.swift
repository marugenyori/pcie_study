import Foundation

/// XP・レベル・デイリークエストの決まり
enum GameRules {
    /// 1問正解の基本XP
    static let correctXP = 10
    /// タイムアタックの1問正解のXP（たくさん解けるので少なめ）
    static let timeAttackXP = 5
    /// 「今日の1問」に正解したときのXP
    static let dailyQuestionXP = 20
    /// クイズを全問正解したときのボーナス（5問以上）
    static let perfectBonusXP = 20
    /// デイリークエスト1つの報酬
    static let questXP = 30

    /// コンボ（連続正解）のボーナス。2連続目から +2 ずつ、最大 +10
    static func comboBonus(_ combo: Int) -> Int {
        guard combo >= 2 else { return 0 }
        return min(10, (combo - 1) * 2)
    }

    // MARK: レベル

    /// レベル n に必要な累計XP（1→0, 2→50, 3→150, 4→300, ...）
    static func xpRequired(forLevel level: Int) -> Int {
        25 * level * (level - 1)
    }

    static func level(forXP xp: Int) -> Int {
        var level = 1
        while xpRequired(forLevel: level + 1) <= xp { level += 1 }
        return level
    }

    /// 今のレベルの中での進み具合（0...1）
    static func levelProgress(xp: Int) -> (level: Int, current: Int, needed: Int, ratio: Double) {
        let level = level(forXP: xp)
        let start = xpRequired(forLevel: level)
        let end = xpRequired(forLevel: level + 1)
        let current = xp - start
        let needed = end - start
        return (level, current, needed, Double(current) / Double(max(needed, 1)))
    }

    static func title(forLevel level: Int) -> String {
        switch level {
        case ..<3: return "見習いエンジニア"
        case 3..<5: return "レーン見習い"
        case 5..<8: return "リンクトレーナー"
        case 8..<11: return "パケットマスター"
        case 11..<15: return "プロトコル職人"
        case 15..<20: return "スペック探検家"
        default: return "PCIeマイスター"
        }
    }
}

/// デイリークエスト（毎日同じ3つ。日付が変わるとリセット）
enum DailyQuest: String, CaseIterable, Identifiable {
    case answer10, combo5, conquerWeak

    var id: String { rawValue }

    var title: String {
        switch self {
        case .answer10: return "10問解く"
        case .combo5: return "5問連続で正解する"
        case .conquerWeak: return "苦手な問題を1問克服する"
        }
    }

    var symbol: String {
        switch self {
        case .answer10: return "pencil.and.list.clipboard"
        case .combo5: return "bolt.fill"
        case .conquerWeak: return "target"
        }
    }

    var goal: Int {
        switch self {
        case .answer10: return 10
        case .combo5: return 5
        case .conquerWeak: return 1
        }
    }
}

/// 1問答えたときに得たもの（画面の演出に使う）
struct XPGain: Equatable {
    var base = 0
    var bonus = 0
    var leveledUpTo: Int? = nil
    var completedQuests: [DailyQuest] = []

    var total: Int { base + bonus }
}
