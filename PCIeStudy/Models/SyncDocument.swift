import Foundation

/// PC のサーバに置く記録（docs/SYNC.md）。アプリとブラウザ版で同じ形を使う
struct SyncDocument: Codable {
    var version: Int? = 1
    var progress: SyncProgress?
    var english: SyncEnglish?
}

/// 更新日時付きの値（新しいほうを使う項目）
struct Stamped<Value: Codable>: Codable {
    var value: Value
    var updatedAt: Date
}

struct SyncProgress: Codable {
    var completedChapters: [String]?
    var quizBest: [String: Int]?
    var answeredTotal: Int?
    var correctTotal: Int?
    var xp: Int?
    var weak: Stamped<[String]>?
    var englishDone: [String]?
    var dailyCounts: [String: Int]?
    var goalMetDays: [String]?
    var bestStreak: Int?
    var dailyGoal: Stamped<Int>?
    var dailyAnswers: [String: Int]?
    var gameBest: [String: Int]?
}

struct SyncEnglish: Codable {
    var clips: [String: SyncClip]?
    var phrases: [String: SyncPhrase]?
}

struct SyncClip: Codable {
    var title: String?
    var addedAt: Date?
    var duration: Double?
    var youtubeID: String?
    var lines: [TranscriptLine]?
    var songs: [SongMatch]?
    var updatedAt: Date
    var deleted: Bool?
}

struct SyncPhrase: Codable {
    var text: String?
    var memo: String?
    var clipID: UUID?
    var start: Double?
    var savedAt: Date?
    var updatedAt: Date
    var deleted: Bool?
}

enum SyncCoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    /// ブラウザの toISOString() はミリ秒付きなので、どちらの形も読めるようにする
    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        let plain = ISO8601DateFormatter()
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let text = try decoder.singleValueContainer().decode(String.self)
            if let date = plain.date(from: text) ?? fractional.date(from: text) { return date }
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "日時の形が違います：\(text)"))
        }
        return decoder
    }()
}
