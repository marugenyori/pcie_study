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
    /// 間違えたあと、まだ正解していない問題のID（苦手リスト）
    private(set) var weakQuestionIDs: Set<String>

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let completed = "completedChapters"
        static let quizBest = "quizBest"
        static let answered = "answeredTotal"
        static let correct = "correctTotal"
        static let weak = "weakQuestionIDs"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        completedChapters = Set(defaults.stringArray(forKey: Keys.completed) ?? [])
        quizBest = (defaults.dictionary(forKey: Keys.quizBest) as? [String: Int]) ?? [:]
        answeredTotal = defaults.integer(forKey: Keys.answered)
        correctTotal = defaults.integer(forKey: Keys.correct)
        weakQuestionIDs = Set(defaults.stringArray(forKey: Keys.weak) ?? [])
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
        weakQuestionIDs = []
        [Keys.completed, Keys.quizBest, Keys.answered, Keys.correct, Keys.weak].forEach {
            defaults.removeObject(forKey: $0)
        }
    }
}
