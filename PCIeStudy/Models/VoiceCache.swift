import CryptoKit
import Foundation
import Observation

/// PC の AI の声（Kokoro）で作った音声を、iPhone に保存しておく
///
/// 保存した音声は、PC につながらない家の外でも使える。声・速さ・読み上げる文の組ごとに1つのファイル。
enum VoiceCache {
    static var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = base.appendingPathComponent("PCVoice", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func fileURL(text: String, voice: String, speed: Double) -> URL {
        let key = "\(voice)|\(speed)|\(EnglishSpeech.spoken(text))"
        let hash = SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
        return folder.appendingPathComponent(hash).appendingPathExtension("audio")
    }

    static func audio(text: String, voice: String, speed: Double) -> Data? {
        try? Data(contentsOf: fileURL(text: text, voice: voice, speed: speed))
    }

    static func contains(text: String, voice: String, speed: Double) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(text: text, voice: voice, speed: speed).path)
    }

    static func save(_ data: Data, text: String, voice: String, speed: Double) {
        try? data.write(to: fileURL(text: text, voice: voice, speed: speed), options: .atomic)
    }

    /// 保存している音声の合計（バイト）
    static var totalBytes: Int64 {
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        return files.reduce(0) { $0 + Int64((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
    }

    static func removeAll() {
        try? FileManager.default.removeItem(at: folder)
    }

    /// 「英語で聞く」で読み上げる文（レッスンの英文・単語・問題、読み方の一覧）。skipping のレッスンは入れない
    static func texts(skipping done: Set<String> = []) -> [String] {
        var texts: [String] = []
        for lesson in EnglishData.all where !done.contains(lesson.id) {
            texts += lesson.sentences.map(\.en)
            texts += lesson.words.map(\.word)
            texts += lesson.questions.map(\.question)
        }
        texts += EnglishData.terms.map(\.speech)
        var seen = Set<String>()
        return texts.filter { seen.insert($0).inserted }
    }
}

/// 「英語で聞く」の音声を、PC でまとめて作って iPhone に保存する
@Observable
final class VoiceDownloader {
    private(set) var isRunning = false
    private(set) var done = 0
    private(set) var total = 0
    private(set) var failed = 0
    private(set) var message: String?
    /// 保存している音声の合計（表示用）
    private(set) var savedBytes: Int64 = VoiceCache.totalBytes

    @ObservationIgnored private var task: Task<Void, Never>?

    /// 今の発音・速さで、まだ保存していない音声を PC に作ってもらう。完了したレッスン（skipping）の分は作らない
    @MainActor
    func start(voice: String, speed: Double, skipping completedLessons: Set<String>) {
        guard !isRunning else { return }
        guard let base = SpecRAGClient.savedBaseURL else {
            message = "PC のサーバのアドレスが未設定です。「質問する」の右上の歯車から設定してください。"
            return
        }
        let texts = VoiceCache.texts(skipping: completedLessons).filter { !VoiceCache.contains(text: $0, voice: voice, speed: speed) }
        isRunning = true
        done = 0
        failed = 0
        total = texts.count
        message = texts.isEmpty ? "すべて保存済みです。" : nil
        task = Task { @MainActor [self] in
            for text in texts {
                if Task.isCancelled { break }
                do {
                    _ = try await SpeechPlayer.audio(for: text, base: base, voice: voice, speed: speed)
                } catch {
                    failed += 1
                    // 最初から続けて失敗するときは、PC につながっていないので止める
                    if failed >= 3 && done == 0 {
                        message = "PC の声を作れませんでした。PC と同じ Wi‑Fi か、PC 側の準備（docs/PC_TTS.md）ができているか確認してください。"
                        break
                    }
                }
                done += 1
                if done % 10 == 0 { savedBytes = VoiceCache.totalBytes }
            }
            savedBytes = VoiceCache.totalBytes
            if message == nil {
                message = failed == 0 ? "保存しました。家の外でも PC の声で聞けます。" : "保存しました（\(failed) 件は作れませんでした）。"
            }
            isRunning = false
        }
    }

    func cancel() {
        task?.cancel()
    }

    func removeAll() {
        cancel()
        VoiceCache.removeAll()
        savedBytes = 0
        message = "保存した音声を消しました。"
    }
}
