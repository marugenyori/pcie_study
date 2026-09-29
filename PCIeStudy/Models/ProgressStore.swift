import Foundation
import Observation

/// 学習進捗（読了した章・クイズ成績）を UserDefaults に保存する
@Observable
final class ProgressStore {
    private(set) var completedChapters: Set<String>
    /// クイズのキー（章IDや "random" など）→ 最高正答率(0–100)
    private(set) var quizBest: [String: Int]
    private(set) var answeredTotal: Int
    private(set) var correctTotal: Int

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let completed = "completedChapters"
        static let quizBest = "quizBest"
        static let answered = "answeredTotal"
        static let correct = "correctTotal"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        completedChapters = Set(defaults.stringArray(forKey: Keys.completed) ?? [])
        quizBest = (defaults.dictionary(forKey: Keys.quizBest) as? [String: Int]) ?? [:]
        answeredTotal = defaults.integer(forKey: Keys.answered)
        correctTotal = defaults.integer(forKey: Keys.correct)
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

    /// 1問回答ごとに呼ぶ
    func recordAnswer(correct: Bool) {
        answeredTotal += 1
        if correct { correctTotal += 1 }
        defaults.set(answeredTotal, forKey: Keys.answered)
        defaults.set(correctTotal, forKey: Keys.correct)
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

    func resetAll() {
        completedChapters = []
        quizBest = [:]
        answeredTotal = 0
        correctTotal = 0
        [Keys.completed, Keys.quizBest, Keys.answered, Keys.correct].forEach {
            defaults.removeObject(forKey: $0)
        }
    }
}
