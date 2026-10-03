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

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let sharedDefaults: UserDefaults

    private enum Keys {
        static let completed = "completedChapters"
        static let quizBest = "quizBest"
        static let answered = "answeredTotal"
        static let correct = "correctTotal"
        static let weak = "weakQuestionIDs"
        static let dailyAnswers = "dailyAnswers"
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

    /// 1問回答ごとに呼ぶ。間違えた問題は苦手リストに入り、正解すると外れる
    func recordAnswer(questionID: String, correct: Bool) {
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
    func answerDaily(_ question: QuizQuestion, choice: Int, on date: Date = .now) {
        let key = StudyStats.key(for: date)
        guard dailyAnswers[key] == nil else { return }
        dailyAnswers[key] = choice
        // 古い記録は60日分だけ残す
        if dailyAnswers.count > 60 {
            let keep = dailyAnswers.keys.sorted().suffix(60)
            dailyAnswers = dailyAnswers.filter { keep.contains($0.key) }
        }
        defaults.set(dailyAnswers, forKey: Keys.dailyAnswers)
        recordAnswer(questionID: question.id, correct: choice == question.answer)
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
        [Keys.completed, Keys.quizBest, Keys.answered, Keys.correct, Keys.weak, Keys.dailyAnswers].forEach {
            defaults.removeObject(forKey: $0)
        }
        let goal = stats.dailyGoal
        stats = StudyStats()
        stats.dailyGoal = goal
        stats.save(to: sharedDefaults)
    }
}
