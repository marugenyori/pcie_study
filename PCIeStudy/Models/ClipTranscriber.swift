import AVFoundation
import Foundation
import Speech

/// 動画の英語音声を、iPhone の音声認識で文字起こしする
///
/// 音声認識は1回に約1分までしか扱えないので、50秒ずつに区切って順に認識する。
/// 区切りで単語が切れないよう、各区間の最後の単語は捨てて、次の区間をその単語の頭から始める。
enum ClipTranscriber {
    enum Failure: LocalizedError {
        case notAuthorized
        case unavailable
        case noAudio
        case exportFailed
        case nothingRecognized

        var errorDescription: String? {
            switch self {
            case .notAuthorized:
                return "音声認識が許可されていません。設定 → PCIe学習 →「音声認識」をオンにしてください。"
            case .unavailable:
                return "英語の音声認識が使えません。ネットにつながっているか確認してください。"
            case .noAudio:
                return "この動画には音声が入っていません。"
            case .exportFailed:
                return "動画から音声を取り出せませんでした。"
            case .nothingRecognized:
                return "英語を聞き取れませんでした。"
            }
        }
    }

    private struct Word {
        let text: String
        let start: Double
        let end: Double
    }

    private static let chunkLength = 50.0

    static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    /// 文字起こしして、1文ずつに分けて返す。progress には 0〜1 の進み具合が届く
    static func transcribe(fileURL: URL, progress: @escaping @MainActor (Double) -> Void) async throws -> [TranscriptLine] {
        guard await requestAuthorization() else { throw Failure.notAuthorized }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
            throw Failure.unavailable
        }

        let asset = AVURLAsset(url: fileURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else { throw Failure.noAudio }
        let duration = try await asset.load(.duration).seconds

        let workFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workFolder) }

        var words: [Word] = []
        var lastError: Error?
        var start = 0.0
        while start < duration - 0.5 {
            try Task.checkCancellation()
            let length = min(chunkLength, duration - start)
            let isLast = start + length >= duration - 0.5
            let audioURL = workFolder.appendingPathComponent("\(Int(start)).m4a")
            try await exportAudio(from: asset, start: start, length: length, to: audioURL)

            var segments: [SFTranscriptionSegment] = []
            do {
                segments = try await recognize(audioURL, with: recognizer)
            } catch {
                // 無音の区間でもエラーになるので、ここでは止めずに次へ進む
                lastError = error
            }

            var next = start + length
            if !isLast, segments.count > 1, let tail = segments.last, tail.timestamp > 10 {
                segments.removeLast()
                next = start + tail.timestamp
            }
            words += segments.map {
                Word(text: $0.substring, start: start + $0.timestamp, end: start + $0.timestamp + $0.duration)
            }
            start = next
            let done = min(start / max(duration, 1), 1)
            await progress(done)
        }

        if words.isEmpty {
            throw lastError ?? Failure.nothingRecognized
        }
        return makeLines(words)
    }

    // MARK: - 音声の取り出し

    private static func exportAudio(from asset: AVAsset, start: Double, length: Double, to url: URL) async throws {
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw Failure.exportFailed
        }
        session.outputURL = url
        session.outputFileType = .m4a
        session.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                                        duration: CMTime(seconds: length, preferredTimescale: 600))
        await session.export()
        guard session.status == .completed else { throw session.error ?? Failure.exportFailed }
    }

    // MARK: - 認識

    private static func recognize(_ url: URL, with recognizer: SFSpeechRecognizer) async throws -> [SFTranscriptionSegment] {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.addsPunctuation = true
        request.taskHint = .dictation
        // 英語のモデルが iPhone に入っていれば、音声を外に送らずに認識する
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let result, result.isFinal {
                    finished = true
                    continuation.resume(returning: result.bestTranscription.segments)
                } else if let error {
                    finished = true
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - 文に分ける

    /// 文末の記号、0.8秒以上の間、18語のどれかで区切る
    private static func makeLines(_ words: [Word]) -> [TranscriptLine] {
        var lines: [TranscriptLine] = []
        var current: [Word] = []

        func flush() {
            guard let first = current.first, let last = current.last else { return }
            let text = current.map(\.text).joined(separator: " ")
            lines.append(TranscriptLine(start: first.start, end: last.end, text: text))
            current = []
        }

        for (index, word) in words.enumerated() {
            current.append(word)
            let endsSentence = word.text.hasSuffix(".") || word.text.hasSuffix("?") || word.text.hasSuffix("!")
            let gap = index + 1 < words.count ? words[index + 1].start - word.end : 0
            if endsSentence || gap >= 0.8 || current.count >= 18 {
                flush()
            }
        }
        flush()
        return lines
    }
}
