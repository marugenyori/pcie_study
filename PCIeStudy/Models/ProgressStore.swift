import Foundation
import Observation

/// 学習進捗（読了した章・クイズ成績・毎日の記録）を保存する
@Observable
final class ProgressStore {
    private(set) var completedChapters: Set<String>
    /// クイズのキー（章IDや "random" など）→ 最高正答率(0–100)
    private(set) var quizBest: [String: Int]
    private(set) var answeredTotal: Int
    private(set) var correctTotal: Int
    /// 間違えたあと、まだ正解していない問題のID（苦手リスト）
    private(set) var weakQuestionIDs: Set<String>
    /// 日ごとの学習量と連続日数（ウィジェットと共有）
    private(set) var stats: StudyStats
    /// 日付キー → 「今日の1問」で選んだ選択肢の番号
    private(set) var dailyAnswers: [String: Int]
    /// 累計XP
    private(set) var xp: Int
    /// ゲームモードの自己ベスト（"survival" → 正解数）
    private(set) var gameBest: [String: Int]
    /// デイリークエストの進み具合（questDay の日のもの）
    private var questDay: String
    private var questBestCombo: Int
    private var questWeakCleared: Int
    private var questsDone: Set<String>

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let sharedDefaults: UserDefaults

    private enum Keys {
        static let completed = "completedChapters"
        static let quizBest = "quizBest"
        static let answered = "answeredTotal"
        static let correct = "correctTotal"
        static let weak = "weakQuestionIDs"
        static let dailyAnswers = "dailyAnswers"
        static let xp = "xp"
        static let gameBest = "gameBest"
        static let questDay = "questDay"
        static let questBestCombo = "questBestCombo"
        static let questWeakCleared = "questWeakCleared"
        static let questsDone = "questsDone"
    }

    init(defaults: UserDefaults = .standard, sharedDefaults: UserDefaults = AppGroup.defaults) {
        self.defaults = defaults
        self.sharedDefaults = sharedDefaults
        completedChapters = Set(defaults.stringArray(forKey: Keys.completed) ?? [])
        quizBest = (defaults.dictionary(forKey: Keys.quizBest) as? [String: Int]) ?? [:]
        answeredTotal = defaults.integer(forKey: Keys.answered)
        correctTotal = defaults.integer(forKey: Keys.correct)
        weakQuestionIDs = Set(defaults.stringArray(forKey: Keys.weak) ?? [])
        dailyAnswers = (defaults.dictionary(forKey: Keys.dailyAnswers) as? [String: Int]) ?? [:]
        stats = StudyStats.load(from: sharedDefaults)
        xp = defaults.integer(forKey: Keys.xp)
        gameBest = (defaults.dictionary(forKey: Keys.gameBest) as? [String: Int]) ?? [:]
        questDay = defaults.string(forKey: Keys.questDay) ?? ""
        questBestCombo = defaults.integer(forKey: Keys.questBestCombo)
        questWeakCleared = defaults.integer(forKey: Keys.questWeakCleared)
        questsDone = Set(defaults.stringArray(forKey: Keys.questsDone) ?? [])
    }

    func isCompleted(_ chapterID: String) -> Bool {
        completedChapters.contains(chapterID)
    }

    func toggleCompleted(_ chapterID: String) {
        if completedChapters.contains(chapterID) {
            completedChapters.remove(chapterID)
        } else {
            completedChapters.insert(chapterID)
        }
        defaults.set(Array(completedChapters), forKey: Keys.completed)
    }

    func markCompleted(_ chapterID: String) {
        guard !completedChapters.contains(chapterID) else { return }
        completedChapters.insert(chapterID)
        defaults.set(Array(completedChapters), forKey: Keys.completed)
    }

    /// 1問回答ごとに呼ぶ。間違えた問題は苦手リストに入り、正解すると外れる。
    /// combo はこの回答を含む連続正解数。得たXPとクエストの達成を返す
    @discardableResult
    func recordAnswer(questionID: String, correct: Bool, combo: Int = 0,
                      xpPerCorrect: Int = GameRules.correctXP) -> XPGain {
        rollQuestDayIfNeeded()
        let wasWeak = weakQuestionIDs.contains(questionID)
        answeredTotal += 1
        if correct {
            correctTotal += 1
            weakQuestionIDs.remove(questionID)
        } else {
            weakQuestionIDs.insert(questionID)
        }
        defaults.set(answeredTotal, forKey: Keys.answered)
        defaults.set(correctTotal, forKey: Keys.correct)
        defaults.set(Array(weakQuestionIDs), forKey: Keys.weak)

        stats.recordAnswer()
        stats.save(to: sharedDefaults)

        var gain = XPGain()
        if correct {
            gain.base = xpPerCorrect
            gain.bonus = GameRules.comboBonus(combo)
            if wasWeak { questWeakCleared += 1 }
        }
        questBestCombo = max(questBestCombo, combo)
        gain.completedQuests = checkQuests()
        gain.bonus += gain.completedQuests.count * GameRules.questXP
        addXP(gain.total, into: &gain)
        saveQuests()
        return gain
    }

    // MARK: XP・レベル・クエスト

    var level: Int { GameRules.level(forXP: xp) }

    /// 全問正解などのボーナス
    @discardableResult
    func awardBonus(_ amount: Int) -> XPGain {
        var gain = XPGain(bonus: amount)
        addXP(amount, into: &gain)
        return gain
    }

    private func addXP(_ amount: Int, into gain: inout XPGain) {
        guard amount > 0 else { return }
        let before = level
        xp += amount
        defaults.set(xp, forKey: Keys.xp)
        if level > before { gain.leveledUpTo = level }
    }

    func questProgress(_ quest: DailyQuest) -> Int {
        let today = StudyStats.key(for: .now)
        switch quest {
        case .answer10: return stats.count(on: .now)
        case .combo5: return questDay == today ? questBestCombo : 0
        case .conquerWeak: return questDay == today ? questWeakCleared : 0
        }
    }

    func isQuestDone(_ quest: DailyQuest) -> Bool {
        questDay == StudyStats.key(for: .now) && questsDone.contains(quest.rawValue)
    }

    private func checkQuests() -> [DailyQuest] {
        var completed: [DailyQuest] = []
        for quest in DailyQuest.allCases where !questsDone.contains(quest.rawValue) {
            if questProgress(quest) >= quest.goal {
                questsDone.insert(quest.rawValue)
                completed.append(quest)
            }
        }
        return completed
    }

    private func rollQuestDayIfNeeded() {
        let today = StudyStats.key(for: .now)
        guard questDay != today else { return }
        questDay = today
        questBestCombo = 0
        questWeakCleared = 0
        questsDone = []
    }

    private func saveQuests() {
        defaults.set(questDay, forKey: Keys.questDay)
        defaults.set(questBestCombo, forKey: Keys.questBestCombo)
        defaults.set(questWeakCleared, forKey: Keys.questWeakCleared)
        defaults.set(Array(questsDone), forKey: Keys.questsDone)
    }

    /// ゲームモードの結果。自己ベストを更新したら true
    @discardableResult
    func recordGameScore(mode: String, score: Int) -> Bool {
        guard score > (gameBest[mode] ?? 0) else { return false }
        gameBest[mode] = score
        defaults.set(gameBest, forKey: Keys.gameBest)
        return true
    }

    /// クイズ終了時に呼ぶ
    func recordQuizResult(key: String, correct: Int, total: Int) {
        guard total > 0 else { return }
        let percent = Int((Double(correct) / Double(total) * 100).rounded())
        if percent > (quizBest[key] ?? -1) {
            quizBest[key] = percent
            defaults.set(quizBest, forKey: Keys.quizBest)
        }
    }

    func bestScore(for key: String) -> Int? {
        quizBest[key]
    }

    var overallAccuracy: Double {
        answeredTotal == 0 ? 0 : Double(correctTotal) / Double(answeredTotal)
    }

    // MARK: 毎日の学習

    func setDailyGoal(_ goal: Int) {
        stats.setGoal(goal)
        stats.save(to: sharedDefaults)
    }

    /// 「今日の1問」の回答（その日に1回だけ記録する）
    @discardableResult
    func answerDaily(_ question: QuizQuestion, choice: Int, on date: Date = .now) -> XPGain {
        let key = StudyStats.key(for: date)
        guard dailyAnswers[key] == nil else { return XPGain() }
        dailyAnswers[key] = choice
        // 古い記録は60日分だけ残す
        if dailyAnswers.count > 60 {
            let keep = dailyAnswers.keys.sorted().suffix(60)
            dailyAnswers = dailyAnswers.filter { keep.contains($0.key) }
        }
        defaults.set(dailyAnswers, forKey: Keys.dailyAnswers)
        return recordAnswer(questionID: question.id, correct: choice == question.answer,
                            xpPerCorrect: GameRules.dailyQuestionXP)
    }

    func dailyAnswer(on date: Date = .now) -> Int? {
        dailyAnswers[StudyStats.key(for: date)]
    }

    /// ウィジェットなど、ほかのプロセスが書いた値を読み直す
    func reloadShared() {
        let latest = StudyStats.load(from: sharedDefaults)
        if latest != stats { stats = latest }
    }

    func resetAll() {
        completedChapters = []
        quizBest = [:]
        answeredTotal = 0
        correctTotal = 0
        weakQuestionIDs = []
        dailyAnswers = [:]
        xp = 0
        gameBest = [:]
        questDay = ""
        questBestCombo = 0
        questWeakCleared = 0
        questsDone = []
        [Keys.completed, Keys.quizBest, Keys.answered, Keys.correct, Keys.weak, Keys.dailyAnswers,
         Keys.xp, Keys.gameBest, Keys.questDay, Keys.questBestCombo, Keys.questWeakCleared, Keys.questsDone].forEach {
            defaults.removeObject(forKey: $0)
        }
        let goal = stats.dailyGoal
        stats = StudyStats()
        stats.dailyGoal = goal
        stats.save(to: sharedDefaults)
    }
}
