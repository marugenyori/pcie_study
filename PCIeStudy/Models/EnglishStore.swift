import AVFoundation
import Foundation
import Observation

/// 文字起こしの1文（秒は動画の先頭から）
struct TranscriptLine: Codable, Identifiable, Hashable {
    var id = UUID()
    var start: Double
    var end: Double
    var text: String
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
}

/// フレーズ帳の1件
struct SavedPhrase: Codable, Identifiable, Hashable {
    var id = UUID()
    var text: String
    var memo: String
    var clipID: UUID?
    var start: Double
    var savedAt: Date
}

/// 英語学習用の動画とフレーズ帳を保存する
@Observable
final class EnglishStore {
    private(set) var clips: [EnglishClip]
    private(set) var phrases: [SavedPhrase]

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let clips = "englishClips"
        static let phrases = "englishPhrases"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        clips = Self.decode([EnglishClip].self, defaults.data(forKey: Keys.clips)) ?? []
        phrases = Self.decode([SavedPhrase].self, defaults.data(forKey: Keys.phrases)) ?? []
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
    func addClip(copiedFile url: URL, title: String? = nil) async -> EnglishClip {
        let duration = (try? await AVURLAsset(url: url).load(.duration).seconds) ?? 0
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d HH:mm"
        let clip = EnglishClip(title: title ?? "\(formatter.string(from: Date())) の動画",
                               fileName: url.lastPathComponent,
                               addedAt: Date(),
                               duration: duration.isFinite ? duration : 0)
        clips.insert(clip, at: 0)
        saveClips()
        return clip
    }

    func rename(_ id: UUID, to title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].title = trimmed
        saveClips()
    }

    func setLines(_ lines: [TranscriptLine], for id: UUID) {
        guard let index = clips.firstIndex(where: { $0.id == id }) else { return }
        clips[index].lines = lines
        saveClips()
    }

    /// 動画を消す（フレーズ帳の項目は残す）
    func delete(_ id: UUID) {
        guard let clip = clip(id: id) else { return }
        try? FileManager.default.removeItem(at: Self.fileURL(for: clip))
        clips.removeAll { $0.id == id }
        saveClips()
    }

    // MARK: - フレーズ帳

    func addPhrase(text: String, memo: String, clipID: UUID?, start: Double) {
        let phrase = SavedPhrase(text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                                 memo: memo.trimmingCharacters(in: .whitespacesAndNewlines),
                                 clipID: clipID, start: start, savedAt: Date())
        phrases.insert(phrase, at: 0)
        savePhrases()
    }

    func updateMemo(_ id: UUID, memo: String) {
        guard let index = phrases.firstIndex(where: { $0.id == id }) else { return }
        phrases[index].memo = memo
        savePhrases()
    }

    func deletePhrase(_ id: UUID) {
        phrases.removeAll { $0.id == id }
        savePhrases()
    }

    // MARK: - 保存

    private func saveClips() {
        defaults.set(try? JSONEncoder().encode(clips), forKey: Keys.clips)
    }

    private func savePhrases() {
        defaults.set(try? JSONEncoder().encode(phrases), forKey: Keys.phrases)
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
