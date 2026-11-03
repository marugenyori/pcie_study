import AVFoundation
import Foundation
import Observation

/// 文字起こしの1文（秒は動画の先頭から）
struct TranscriptLine: Codable, Identifiable, Hashable {
    var id = UUID()
    var start: Double
    var end: Double
    var text: String
    /// 日本語訳（訳したあとに入る）
    var japanese: String?
}

/// 取り込んだ動画（ファイルはアプリの中にコピーして持つ）
struct EnglishClip: Codable, Identifiable, Hashable {
    var id = UUID()
    var title: String
    var fileName: String
    var addedAt: Date
    var duration: Double
    /// まだ文字起こししていないときは nil
    var lines: [TranscriptLine]?
    /// 流れていた曲（まだ調べていないときは nil）
    var songs: [SongMatch]?
    /// PC で保存した YouTube の動画 ID（PC の youtube_library にある）
    var youtubeID: String?
    /// 最後に変えた日時（同期で新しいほうを使う）
    var updatedAt: Date?

    /// 動画ファイルがこの iPhone にあるか（ブラウザ版から同期した動画は、スクリプトだけのことがある）
    var hasVideo: Bool {
        !fileName.isEmpty && FileManager.default.fileExists(atPath: EnglishStore.fileURL(for: self).path)
    }

    var lastChange: Date { updatedAt ?? addedAt }
}

/// ShazamKit で見つけた曲
struct SongMatch: Codable, Hashable, Identifiable {
    var id = UUID()
    /// 動画の中で曲が見つかった時刻（秒）
    var start: Double
    var title: String
    var artist: String
    var artworkURL: URL?
    var appleMusicURL: URL?
    var webURL: URL?
}

/// フレーズ帳の1件
struct SavedPhrase: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var memo: String
    var clipID: UUID?
    var start: Double
    var savedAt: Date
    var updatedAt: Date?

    var lastChange: Date { updatedAt ?? savedAt }
}

/// 英語学習用の動画とフレーズ帳を保存する
@Observable
final class EnglishStore {
    private(set) var clips: [EnglishClip]
    private(set) var phrases: [SavedPhrase]
    /// 消した動画・フレーズの ID と消した日時（同期でほかの端末にも消したことを伝える）
    private var deletedClips: [UUID: Date]
    private var deletedPhrases: [UUID: Date]

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let clips = "englishClips"
        static let phrases = "englishPhrases"
        static let deletedClips = "englishDeletedClips"
        static let deletedPhrases = "englishDeletedPhrases"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        clips = Self.decode([EnglishClip].self, defaults.data(forKey: Keys.clips)) ?? []
        phrases = Self.decode([SavedPhrase].self, defaults.data(forKey: Keys.phrases)) ?? []
        deletedClips = Self.decode([UUID: Date].self, defaults.data(forKey: Keys.deletedClips)) ?? [:]
        deletedPhrases = Self.decode([UUID: Date].self, defaults.data(forKey: Keys.deletedPhrases)) ?? [:]
    }

    // MARK: - ファイルの置き場所

    /// 動画をコピーしておくフォルダ（Application Support/EnglishClips）
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("EnglishClips", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    static func fileURL(for clip: EnglishClip) -> URL {
        folder.appendingPathComponent(clip.fileName)
    }

    /// 取り込む動画のコピー先（名前が重ならないように UUID を使う）
    static func newFileURL(pathExtension: String) -> URL {
        let ext = pathExtension.isEmpty ? "mov" : pathExtension
        return folder.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)
    }

    // MARK: - 動画

    func clip(id: UUID) -> EnglishClip? {
        clips.first { $0.id == id }
    }

    /// フォルダにコピー済みのファイルを一覧に加える
    @MainActor
    func addClip(copiedFile url: URL, title: String? = nil, lines: [TranscriptLine]? = nil,
                 youtubeID: String? = nil) async -> EnglishClip {
        let duration = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        let clip = EnglishClip(title: title ?? "\(formatter.string(from: Date())) の動画",
                               fileName: url.lastPathComponent,
                               addedAt: Date(),
                               duration: duration.isFinite ? duration : 0,
                               lines: lines,
                               youtubeID: youtubeID,
                               updatedAt: Date())
        clips.insert(clip, at: 0)
        saveClips()
        return clip
    }

    func rename(_ id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].title = trimmed
        clips[index].updatedAt = Date()
        saveClips()
    }

    func setLines(_ lines: [TranscriptLine], for id: UUID) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].lines = lines
        clips[index].updatedAt = Date()
        saveClips()
    }

    func setSongs(_ songs: [SongMatch], for id: UUID) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].songs = songs
        clips[index].updatedAt = Date()
        saveClips()
    }

    /// 文の ID → 日本語訳 を書き込む
    func setTranslations(_ translations: [UUID: String], for id: UUID) {
        guard let index = clips.firstIndex(where: { $0.id == id }), var lines = clips[index].lines else { return }
        for i in lines.indices {
            if let japanese = translations[lines[i].id] { lines[i].japanese = japanese }
        }
        clips[index].lines = lines
        clips[index].updatedAt = Date()
        saveClips()
    }

    /// PC から受け取った動画ファイルを、スクリプトだけの動画に付ける（動画の中身は変わらないので updatedAt は変えない）
    func attachVideo(copiedFile url: URL, to id: UUID) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].fileName = url.lastPathComponent
        saveClips()
    }

    /// 動画を消す（フレーズ帳の項目は残す）
    func delete(_ id: UUID) {
        guard let clip = clip(id: id) else { return }
        if !clip.fileName.isEmpty {
            try? FileManager.default.removeItem(at: Self.fileURL(for: clip))
        }
        clips.removeAll { $0.id == id }
        deletedClips[id] = Date()
        saveClips()
    }

    // MARK: - フレーズ帳

    func addPhrase(text: String, memo: String, clipID: UUID?, start: Double) {
        let phrase = SavedPhrase(text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                                 memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
                                 clipID: clipID, start: start, savedAt: Date(), updatedAt: Date())
        phrases.insert(phrase, at: 0)
        savePhrases()
    }

    func updateMemo(_ id: UUID, memo: String) {
        guard let index = phrases.firstIndex(where: { $0.id == id }) else { return }
        phrases[index].memo = memo
        phrases[index].updatedAt = Date()
        savePhrases()
    }

    func deletePhrase(_ id: UUID) {
        phrases.removeAll { $0.id == id }
        deletedPhrases[id] = Date()
        savePhrases()
    }

    // MARK: - 同期（docs/SYNC.md）

    /// PC に送る動画（ファイル以外）とフレーズ帳。消したものは deleted で伝える
    func syncSnapshot() -> SyncEnglish {
        var syncClips: [String: SyncClip] = [:]
        for clip in clips {
            syncClips[clip.id.uuidString] = SyncClip(title: clip.title, addedAt: clip.addedAt, duration: clip.duration,
                                                     youtubeID: clip.youtubeID, lines: clip.lines, songs: clip.songs,
                                                     updatedAt: clip.lastChange)
        }
        for (id, date) in deletedClips {
            syncClips[id.uuidString] = SyncClip(updatedAt: date, deleted: true)
        }
        var syncPhrases: [String: SyncPhrase] = [:]
        for phrase in phrases {
            syncPhrases[phrase.id.uuidString] = SyncPhrase(text: phrase.text, memo: phrase.memo, clipID: phrase.clipID,
                                                           start: phrase.start, savedAt: phrase.savedAt,
                                                           updatedAt: phrase.lastChange)
        }
        for (id, date) in deletedPhrases {
            syncPhrases[id.uuidString] = SyncPhrase(updatedAt: date, deleted: true)
        }
        return SyncEnglish(clips: syncClips, phrases: syncPhrases)
    }

    /// PC から読んだものを混ぜる（ID ごとに新しいほうを使う）
    func merge(_ remote: SyncEnglish) {
        for (key, item) in remote.clips ?? [:] {
            guard let id = UUID(uuidString: key) else { continue }
            let index = clips.firstIndex { $0.id == id }
            if item.deleted == true {
                if let index, clips[index].lastChange <= item.updatedAt {
                    if !clips[index].fileName.isEmpty {
                        try? FileManager.default.removeItem(at: Self.fileURL(for: clips[index]))
                    }
                    clips.remove(at: index)
                }
                deletedClips[id] = max(deletedClips[id] ?? item.updatedAt, item.updatedAt)
                continue
            }
            if let deleted = deletedClips[id], deleted >= item.updatedAt { continue }
            if let index {
                guard item.updatedAt > clips[index].lastChange else { continue }
                clips[index].title = item.title ?? clips[index].title
                clips[index].duration = item.duration ?? clips[index].duration
                clips[index].youtubeID = item.youtubeID ?? clips[index].youtubeID
                clips[index].lines = item.lines
                clips[index].songs = item.songs
                clips[index].updatedAt = item.updatedAt
            } else {
                // ほかの端末で取り込んだ動画：スクリプトなどだけ入れる（動画は PC から受け取れる）
                clips.append(EnglishClip(id: id, title: item.title ?? "動画", fileName: "",
                                         addedAt: item.addedAt ?? item.updatedAt, duration: item.duration ?? 0,
                                         lines: item.lines, songs: item.songs, youtubeID: item.youtubeID,
                                         updatedAt: item.updatedAt))
            }
        }
        clips.sort { $0.addedAt > $1.addedAt }

        for (key, item) in remote.phrases ?? [:] {
            guard let id = UUID(uuidString: key) else { continue }
            let index = phrases.firstIndex { $0.id == id }
            if item.deleted == true {
                if let index, phrases[index].lastChange <= item.updatedAt {
                    phrases.remove(at: index)
                }
                deletedPhrases[id] = max(deletedPhrases[id] ?? item.updatedAt, item.updatedAt)
                continue
            }
            if let deleted = deletedPhrases[id], deleted >= item.updatedAt { continue }
            if let index {
                guard item.updatedAt > phrases[index].lastChange else { continue }
                phrases[index].text = item.text ?? phrases[index].text
                phrases[index].memo = item.memo ?? phrases[index].memo
                phrases[index].updatedAt = item.updatedAt
            } else if let text = item.text {
                phrases.append(SavedPhrase(id: id, text: text, memo: item.memo ?? "", clipID: item.clipID,
                                           start: item.start ?? 0, savedAt: item.savedAt ?? item.updatedAt,
                                           updatedAt: item.updatedAt))
            }
        }
        phrases.sort { $0.savedAt > $1.savedAt }
        saveClips()
        savePhrases()
    }

    // MARK: - 保存

    private func saveClips() {
        defaults.set(try? JSONEncoder().encode(clips), forKey: Keys.clips)
        defaults.set(try? JSONEncoder().encode(deletedClips), forKey: Keys.deletedClips)
    }

    private func savePhrases() {
        defaults.set(try? JSONEncoder().encode(phrases), forKey: Keys.phrases)
        defaults.set(try? JSONEncoder().encode(deletedPhrases), forKey: Keys.deletedPhrases)
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
