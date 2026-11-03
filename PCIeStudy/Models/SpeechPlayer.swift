import AVFoundation
import Observation

/// 英文の読み上げ。速さと発音（アメリカ・イギリスなど）を選べる
///
/// PC のサーバに AI の音声合成（Kokoro、docs/PC_TTS.md）があり、同じ Wi‑Fi にいるときは PC の自然な声で読む。
/// PC につながらないときや、PC にない発音（インド・オーストラリア）のときは、iPhone の声（AVSpeechSynthesizer）で読む。
@Observable
final class SpeechPlayer {
    enum Speed: String, CaseIterable, Identifiable {
        case slow, normal, fast

        var id: String { rawValue }

        var label: String {
            switch self {
            case .slow: return "ゆっくり"
            case .normal: return "ふつう"
            case .fast: return "はやめ"
            }
        }

        /// AVSpeechUtterance の rate（標準は 0.5）
        var rate: Float {
            switch self {
            case .slow: return 0.38
            case .normal: return 0.47
            case .fast: return 0.54
            }
        }

        /// PC の音声合成の速さ（1 が標準）
        var pcSpeed: Double {
            switch self {
            case .slow: return 0.8
            case .normal: return 1.0
            case .fast: return 1.15
            }
        }
    }

    enum Accent: String, CaseIterable, Identifiable {
        case us = "en-US", uk = "en-GB", india = "en-IN", australia = "en-AU"

        var id: String { rawValue }

        var label: String {
            switch self {
            case .us: return "アメリカ"
            case .uk: return "イギリス"
            case .india: return "インド"
            case .australia: return "オーストラリア"
            }
        }

        /// PC の音声合成（Kokoro）の声。PC にない発音は nil
        var pcVoice: String? {
            switch self {
            case .us: return "af_heart"
            case .uk: return "bf_emma"
            case .india, .australia: return nil
            }
        }
    }

    private(set) var speed: Speed
    private(set) var accent: Accent
    private(set) var isSpeaking = false
    /// 読み上げ中の文が、どのまとまり（source）の何番目か
    private(set) var source: String?
    private(set) var currentIndex: Int?
    /// PC の AI の声を使う（設定）
    private(set) var usesPCVoice: Bool
    /// 最後に PC の声を使えたか（nil はまだ試していない）
    private(set) var pcVoiceWorked: Bool?

    /// 止めるたびに作り直す（止めた直後に読ませると、それ以降読まなくなることがあるため）
    @ObservationIgnored private var synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let delegate = Delegate()
    @ObservationIgnored private var indexByUtterance: [ObjectIdentifier: Int] = [:]
    @ObservationIgnored private var lastUtterance: AVSpeechUtterance?
    @ObservationIgnored private let defaults: UserDefaults
    /// 言語ごとの声（声の一覧の取得は重いので覚えておく。声をダウンロードしたら作り直す）
    @ObservationIgnored private var voiceCache: [Accent: AVSpeechSynthesisVoice?] = [:]
    @ObservationIgnored private var voicesObserver: NSObjectProtocol?
    /// PC の声で読んでいるときの処理と、再生中の音声
    @ObservationIgnored private var pcTask: Task<Void, Never>?
    @ObservationIgnored private var audioPlayer: AVAudioPlayer?
    @ObservationIgnored private let audioDelegate = AudioDelegate()
    /// PC の声が使えなかった日時（しばらくは試さずに iPhone の声で読む）
    @ObservationIgnored private var pcFailedAt: Date?

    private enum Keys {
        static let speed = "englishSpeed"
        static let accent = "englishAccent"
        static let usesPCVoice = "englishUsesPCVoice"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        speed = defaults.string(forKey: Keys.speed).flatMap(Speed.init(rawValue:)) ?? .normal
        accent = defaults.string(forKey: Keys.accent).flatMap(Accent.init(rawValue:)) ?? .us
        usesPCVoice = defaults.object(forKey: Keys.usesPCVoice) as? Bool ?? true
        synthesizer.delegate = delegate
        delegate.onStart = { [weak self] utterance in
            DispatchQueue.main.async { self?.didStart(utterance) }
        }
        delegate.onFinish = { [weak self] utterance in
            DispatchQueue.main.async { self?.didFinish(utterance) }
        }
        voicesObserver = NotificationCenter.default.addObserver(
            forName: AVSpeechSynthesizer.availableVoicesDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.voiceCache = [:]
        }
    }

    deinit {
        if let voicesObserver { NotificationCenter.default.removeObserver(voicesObserver) }
    }

    func setSpeed(_ speed: Speed) {
        self.speed = speed
        defaults.set(speed.rawValue, forKey: Keys.speed)
    }

    func setAccent(_ accent: Accent) {
        self.accent = accent
        defaults.set(accent.rawValue, forKey: Keys.accent)
    }

    func setUsesPCVoice(_ value: Bool) {
        usesPCVoice = value
        pcFailedAt = nil
        defaults.set(value, forKey: Keys.usesPCVoice)
    }

    /// 文を順に読み上げる。pause が true のときは、1文ごとに声に出してまねる時間（シャドーイング・リピート用）を空ける
    func play(_ sentences: [String], from start: Int = 0, source: String, pause: Bool = false) {
        let items = sentences.indices.filter { $0 >= start }.map { (text: sentences[$0], index: Optional($0)) }
        speak(items, source: source, pause: pause)
    }

    /// 1つだけ読み上げる（単語や1文）
    func say(_ text: String, source: String = "", index: Int? = nil) {
        speak([(text: text, index: index)], source: source, pause: false)
    }

    private func speak(_ items: [(text: String, index: Int?)], source: String, pause: Bool) {
        stop()
        guard !items.isEmpty else { return }
        activateAudioSession()
        self.source = source
        isSpeaking = true
        // PC の声が使えなかった直後（1分以内）は、待たずに iPhone の声で読む。
        // ただし、すべての文の音声が iPhone に保存してあれば、PC につながらなくても PC の声で読む
        let recentlyFailed = pcFailedAt.map { Date().timeIntervalSince($0) < 60 } ?? false
        guard usesPCVoice, let voice = accent.pcVoice else {
            speakWithSynthesizer(items, pause: pause)
            return
        }
        let allSaved = items.allSatisfy { VoiceCache.contains(text: $0.text, voice: voice, speed: speed.pcSpeed) }
        let base = recentlyFailed ? nil : SpecRAGClient.savedBaseURL
        if allSaved || base != nil {
            speakWithPC(items, pause: pause, base: base, voice: voice)
        } else {
            speakWithSynthesizer(items, pause: pause)
        }
    }

    private func speakWithSynthesizer(_ items: [(text: String, index: Int?)], pause: Bool) {
        let voice = voice(for: accent)
        for item in items {
            let utterance = AVSpeechUtterance(string: EnglishSpeech.spoken(item.text))
            utterance.voice = voice
            utterance.rate = speed.rate
            utterance.postUtteranceDelay = pause ? Self.repeatTime(for: item.text, speed: speed) : 0.25
            if let index = item.index { indexByUtterance[ObjectIdentifier(utterance)] = index }
            lastUtterance = utterance
            synthesizer.speak(utterance)
        }
    }

    /// PC で音声を作ってもらい、順に再生する。次の文の音声は、今の文を読んでいるあいだに作っておく
    private func speakWithPC(_ items: [(text: String, index: Int?)], pause: Bool, base: URL?, voice: String) {
        let speedValue = speed.pcSpeed
        let currentSpeed = speed
        pcTask = Task { @MainActor [weak self] in
            var pending: Task<Data, Error>? = Self.fetchAudio(items[0].text, base: base, voice: voice, speed: speedValue)
            for (n, item) in items.enumerated() {
                guard let self, !Task.isCancelled, let current = pending else { return }
                let data: Data
                do {
                    data = try await current.value
                } catch {
                    guard !Task.isCancelled else { return }
                    // PC につながらない・PC に音声合成がないときは、残りを iPhone の声で読む
                    self.pcFailedAt = Date()
                    self.pcVoiceWorked = false
                    self.speakWithSynthesizer(Array(items[n...]), pause: pause)
                    return
                }
                pending = n + 1 < items.count
                    ? Self.fetchAudio(items[n + 1].text, base: base, voice: voice, speed: speedValue) : nil
                self.pcVoiceWorked = true
                if let index = item.index { self.currentIndex = index }
                await self.playAudio(data)
                guard !Task.isCancelled else { return }
                if n < items.count - 1 {
                    let delay = pause ? Self.repeatTime(for: item.text, speed: currentSpeed) : 0.25
                    try? await Task.sleep(for: .seconds(delay))
                }
            }
            guard let self, !Task.isCancelled else { return }
            self.stop()
        }
    }

    private static func fetchAudio(_ text: String, base: URL?, voice: String, speed: Double) -> Task<Data, Error> {
        Task { try await audio(for: text, base: base, voice: voice, speed: speed) }
    }

    /// PC の声の音声。iPhone に保存してあればそれを使い、なければ PC で作って保存する
    /// GET /api/tts?text=…&voice=…&speed=…（PC 側は docs/PC_TTS.md）
    static func audio(for text: String, base: URL?, voice: String, speed: Double) async throws -> Data {
        if let saved = VoiceCache.audio(text: text, voice: voice, speed: speed) { return saved }
        guard let base else { throw URLError(.notConnectedToInternet) }
        var components = URLComponents(url: base.appending(path: "api/tts"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "text", value: EnglishSpeech.spoken(text)),
            URLQueryItem(name: "voice", value: voice),
            URLQueryItem(name: "speed", value: String(speed)),
            // 小さく保存できるよう AAC（m4a）を頼む。PC が対応していなければ WAV のまま返ってくる
            URLQueryItem(name: "format", value: "m4a"),
        ]
        guard let url = components?.url else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200, !data.isEmpty else {
            throw URLError(.badServerResponse)
        }
        VoiceCache.save(data, text: text, voice: voice, speed: speed)
        return data
    }

    /// 音声を最後まで再生する（stop() で途中で止めたときも戻る）
    private func playAudio(_ data: Data) async {
        guard let player = try? AVAudioPlayer(data: data) else { return }
        audioPlayer = player
        await withCheckedContinuation { continuation in
            audioDelegate.onFinish = { continuation.resume() }
            player.delegate = audioDelegate
            if !player.play() { audioDelegate.finish() }
        }
    }

    func stop() {
        pcTask?.cancel()
        pcTask = nil
        audioPlayer?.stop()
        audioPlayer = nil
        audioDelegate.finish()
        let hadQueue = lastUtterance != nil
        indexByUtterance = [:]
        lastUtterance = nil
        if hadQueue || synthesizer.isSpeaking || synthesizer.isPaused {
            let old = synthesizer
            old.delegate = nil
            old.stopSpeaking(at: .immediate)
            synthesizer = AVSpeechSynthesizer()
            synthesizer.delegate = delegate
        }
        isSpeaking = false
        source = nil
        currentIndex = nil
    }

    func isPlaying(_ source: String) -> Bool {
        isSpeaking && self.source == source
    }

    // MARK: - 内部

    private func didStart(_ utterance: AVSpeechUtterance) {
        if let index = indexByUtterance[ObjectIdentifier(utterance)] {
            currentIndex = index
        }
    }

    private func didFinish(_ utterance: AVSpeechUtterance) {
        // stop() のあとに届いた古い通知は無視する
        guard let last = lastUtterance, last === utterance else { return }
        stop()
    }

    /// 消音スイッチがオンでも聞こえるようにする
    private func activateAudioSession() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try? session.setActive(true)
    }

    /// まねして言うための時間（単語数から見積もる）
    private static func repeatTime(for sentence: String, speed: Speed) -> TimeInterval {
        let words = sentence.split(whereSeparator: { $0 == " " }).count
        let perWord = speed == .slow ? 0.55 : 0.45
        return Double(words) * perWord + 1.0
    }

    /// その言語で一番品質の高い声（「拡張」「プレミアム」をダウンロードしてあればそれを使う）
    func voice(for accent: Accent) -> AVSpeechSynthesisVoice? {
        if let cached = voiceCache[accent] { return cached }
        let voice = Self.bestVoice(for: accent)
        voiceCache[accent] = voice
        return voice
    }

    /// 品質の高い声が入っているか（入っていなければダウンロード方法を案内する）
    func hasEnhancedVoice(for accent: Accent) -> Bool {
        guard let voice = voice(for: accent) else { return false }
        return voice.quality != .default
    }

    private static func bestVoice(for accent: Accent) -> AVSpeechSynthesisVoice? {
        let candidates = AVSpeechSynthesisVoice.speechVoices().filter {
            $0.language == accent.rawValue && !$0.voiceTraits.contains(.isNoveltyVoice)
        }
        if let best = candidates.max(by: { $0.quality.rawValue < $1.quality.rawValue }), best.quality != .default {
            return best
        }
        return AVSpeechSynthesisVoice(language: accent.rawValue)
    }

    /// AVAudioPlayer の再生が終わったら一度だけ知らせる
    private final class AudioDelegate: NSObject, AVAudioPlayerDelegate {
        var onFinish: (() -> Void)?

        func finish() {
            let callback = onFinish
            onFinish = nil
            callback?()
        }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            finish()
        }

        func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
            finish()
        }
    }

    private final class Delegate: NSObject, AVSpeechSynthesizerDelegate {
        var onStart: ((AVSpeechUtterance) -> Void)?
        var onFinish: ((AVSpeechUtterance) -> Void)?

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
            onStart?(utterance)
        }

        func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
            onFinish?(utterance)
        }
    }
}
