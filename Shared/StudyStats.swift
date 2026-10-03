import Foundation

/// アプリとウィジェットで共有する保存先（App Group）
enum AppGroup {
    /// "group." + アプリ本体の Bundle ID（ウィジェットからは ".widget" を外して求める）
    static var id: String {
        var bundleID = Bundle.main.bundleIdentifier ?? "com.yourname.PCIeStudy"
        if bundleID.hasSuffix(".widget") {
            bundleID = String(bundleID.dropLast(".widget".count))
        }
        return "group." + bundleID
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }
}

/// 日ごとの学習量と連続日数（アプリとウィジェットで共有）
struct StudyStats: Equatable {
    /// 日付キー（yyyy-MM-dd）→ その日に解いた問題数
    var dailyCounts: [String: Int] = [:]
    /// 1日の目標を達成した日
    var goalMetDays: Set<String> = []
    var dailyGoal: Int = 5
    var bestStreak: Int = 0

    static let goalChoices = [3, 5, 10, 20]

    private enum Keys {
        static let counts = "dailyCounts"
        static let met = "goalMetDays"
        static let goal = "dailyGoal"
        static let best = "bestStreak"
    }

    // MARK: 保存と読み込み

    static func load(from defaults: UserDefaults = AppGroup.defaults) -> StudyStats {
        var s = StudyStats()
        s.dailyCounts = (defaults.dictionary(forKey: Keys.counts) as? [String: Int]) ?? [:]
        s.goalMetDays = Set(defaults.stringArray(forKey: Keys.met) ?? [])
        let goal = defaults.integer(forKey: Keys.goal)
        s.dailyGoal = goal > 0 ? goal : 5
        s.bestStreak = defaults.integer(forKey: Keys.best)
        return s
    }

    func save(to defaults: UserDefaults = AppGroup.defaults) {
        defaults.set(dailyCounts, forKey: Keys.counts)
        defaults.set(Array(goalMetDays), forKey: Keys.met)
        defaults.set(dailyGoal, forKey: Keys.goal)
        defaults.set(bestStreak, forKey: Keys.best)
    }

    // MARK: 記録

    /// 1問解いたときに呼ぶ。今日の目標を新しく達成したら true
    @discardableResult
    mutating func recordAnswer(on date: Date = .now) -> Bool {
        let key = Self.key(for: date)
        dailyCounts[key, default: 0] += 1
        pruneOldDays(today: date)
        guard !goalMetDays.contains(key), dailyCounts[key, default: 0] >= dailyGoal else { return false }
        goalMetDays.insert(key)
        bestStreak = max(bestStreak, currentStreak(today: date))
        return true
    }

    mutating func setGoal(_ goal: Int, today: Date = .now) {
        dailyGoal = goal
        let key = Self.key(for: today)
        if count(on: today) >= goal {
            goalMetDays.insert(key)
            bestStreak = max(bestStreak, currentStreak(today: today))
        }
    }

    /// 1年より前の日ごとの回数は消す（達成日は連続日数の計算に使うので残す）
    private mutating func pruneOldDays(today: Date) {
        guard dailyCounts.count > 400 else { return }
        let limit = Self.key(for: Calendar.current.date(byAdding: .day, value: -366, to: today) ?? today)
        dailyCounts = dailyCounts.filter { $0.key >= limit }
    }

    // MARK: 集計

    func count(on date: Date) -> Int {
        dailyCounts[Self.key(for: date), default: 0]
    }

    func isGoalMet(on date: Date) -> Bool {
        goalMetDays.contains(Self.key(for: date))
    }

    /// 今日まで（今日が未達成なら昨日まで）の連続達成日数
    func currentStreak(today: Date = .now) -> Int {
        let cal = Calendar.current
        var day = cal.startOfDay(for: today)
        if !isGoalMet(on: day) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var streak = 0
        while isGoalMet(on: day) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return streak
    }

    func remainingToday(today: Date = .now) -> Int {
        max(0, dailyGoal - count(on: today))
    }

    // MARK: 日付キー

    static func key(for date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

/// 日付から決まる「今日の1問」（アプリ・ウィジェット・通知で同じ問題になる）
enum DailyPick {
    static func question(for date: Date = .now) -> QuizQuestion {
        let all = QuizData.all
        return all[index(for: date, count: all.count, salt: 7919)]
    }

    /// 日付から決まる 0..<count の番号
    static func index(for date: Date, count: Int, salt: Int) -> Int {
        guard count > 0 else { return 0 }
        let start = Calendar.current.startOfDay(for: date)
        let days = Int(start.timeIntervalSince1970 / 86_400)
        return ((days * salt) % count + count) % count
    }
}
