import AVFoundation
import Foundation
import Speech

/// 動画の英語音声を、iPhone の音声認識で文字起こしする
///
/// iOS 26 以上は SpeechAnalyzer で音声全体を一度に認識する。
/// それより前の iOS では、音声認識が1回に約1分までしか扱えないので、50秒ずつに区切って順に認識する。
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
        let asset = AVURLAsset(url: fileURL)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else { throw Failure.noAudio }
        let duration = try await asset.load(.duration).seconds

        let workFolder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: workFolder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workFolder) }

        // iOS 26 以上は、長い音声向けの新しい音声認識（SpeechAnalyzer）で一度に認識する。区切らないぶん速い
        if #available(iOS 26.0, *) {
            if let words = try await transcribeWithAnalyzer(asset: asset, duration: duration,
                                                            workFolder: workFolder, progress: progress) {
                guard !words.isEmpty else { throw Failure.nothingRecognized }
                return makeLines(words)
            }
        }

        guard await requestAuthorization() else { throw Failure.notAuthorized }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
            throw Failure.unavailable
        }

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

    // MARK: - iOS 26 以上の音声認識

    /// 音声全体を m4a に取り出して、SpeechTranscriber で文字起こしする。英語が使えないときは nil
    @available(iOS 26.0, *)
    private static func transcribeWithAnalyzer(asset: AVAsset, duration: Double, workFolder: URL,
                                               progress: @escaping @MainActor (Double) -> Void) async throws -> [Word]? {
        guard let locale = await SpeechTranscriber.supportedLocale(equivalentTo: Locale(identifier: "en-US")) else {
            return nil
        }
        let transcriber = SpeechTranscriber(locale: locale, transcriptionOptions: [], reportingOptions: [],
                                            attributeOptions: [.audioTimeRange])
        // 英語の認識データが入っていなければダウンロードする（初回だけ）
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }

        let audioURL = workFolder.appendingPathComponent("all.m4a")
        try await exportAudio(from: asset, start: 0, length: duration, to: audioURL)
        let audioFile = try AVAudioFile(forReading: audioURL)

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let collector = Task { () -> [Word] in
            var words: [Word] = []
            for try await result in transcriber.results {
                for run in result.text.runs {
                    let text = String(result.text[run.range].characters).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { continue }
                    if let range = run.audioTimeRange {
                        words.append(Word(text: text, start: range.start.seconds, end: range.end.seconds))
                    } else if let last = words.popLast() {
                        // 時刻の付かない句読点は、直前の単語につなげる
                        words.append(Word(text: last.text + text, start: last.start, end: last.end))
                    }
                }
                await progress(min(result.range.end.seconds / max(duration, 1), 1))
            }
            return words
        }

        if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }
        return try await collector.value
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

    /// 話の切れ目（間）ごとに届く結果をつなげて返す
    ///
    /// 最近の iOS では、間があくと認識結果がそこでリセットされ、最後の結果には最後の発話しか入らない。
    /// そのため、発話の終わり（speechRecognitionMetadata が付いた結果）ごとに単語を集めておく。
    /// 以前のように結果が積み上がる場合もあるので、すでに集めた時刻より後の単語だけを足す。
    private static func recognize(_ url: URL, with recognizer: SFSpeechRecognizer) async throws -> [SFTranscriptionSegment] {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        request.taskHint = .dictation
        // 英語のモデルが iPhone に入っていれば、音声を外に送らずに認識する
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            var finished = false
            var collected: [SFTranscriptionSegment] = []
            recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let result, result.isFinal || result.speechRecognitionMetadata != nil {
                    let lastTime = collected.last?.timestamp ?? -1
                    collected += result.bestTranscription.segments.filter { $0.timestamp > lastTime + 0.01 }
                }
                if result?.isFinal == true {
                    finished = true
                    continuation.resume(returning: collected)
                } else if let error {
                    finished = true
                    if collected.isEmpty {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: collected)
                    }
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
