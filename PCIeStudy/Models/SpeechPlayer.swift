import AVFoundation
import Observation

/// 英文の読み上げ（AVSpeechSynthesizer）。速さと発音（アメリカ・イギリスなど）を選べる
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
    }

    private(set) var speed: Speed
    private(set) var accent: Accent
    private(set) var isSpeaking = false
    /// 読み上げ中の文が、どのまとまり（source）の何番目か
    private(set) var source: String?
    private(set) var currentIndex: Int?

    /// 止めるたびに作り直す（止めた直後に読ませると、それ以降読まなくなることがあるため）
    @ObservationIgnored private var synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let delegate = Delegate()
    @ObservationIgnored private var indexByUtterance: [ObjectIdentifier: Int] = [:]
    @ObservationIgnored private var lastUtterance: AVSpeechUtterance?
    @ObservationIgnored private let defaults: UserDefaults
    /// 言語ごとの声（声の一覧の取得は重いので覚えておく。声をダウンロードしたら作り直す）
    @ObservationIgnored private var voiceCache: [Accent: AVSpeechSynthesisVoice?] = [:]
    @ObservationIgnored private var voicesObserver: NSObjectProtocol?

    private enum Keys {
        static let speed = "englishSpeed"
        static let accent = "englishAccent"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        speed = defaults.string(forKey: Keys.speed).flatMap(Speed.init(rawValue:)) ?? .normal
        accent = defaults.string(forKey: Keys.accent).flatMap(Accent.init(rawValue:)) ?? .us
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

    /// 文を順に読み上げる。pause が true のときは、1文ごとに声に出してまねる時間（シャドーイング・リピート用）を空ける
    func play(_ sentences: [String], from start: Int = 0, source: String, pause: Bool = false) {
        stop()
        activateAudioSession()
        let voice = voice(for: accent)
        self.source = source
        for index in sentences.indices where index >= start {
            let utterance = AVSpeechUtterance(string: EnglishSpeech.spoken(sentences[index]))
            utterance.voice = voice
            utterance.rate = speed.rate
            utterance.postUtteranceDelay = pause ? Self.repeatTime(for: sentences[index], speed: speed) : 0.25
            indexByUtterance[ObjectIdentifier(utterance)] = index
            lastUtterance = utterance
            synthesizer.speak(utterance)
        }
        isSpeaking = lastUtterance != nil
    }

    /// 1つだけ読み上げる（単語や1文）
    func say(_ text: String, source: String = "", index: Int? = nil) {
        stop()
        activateAudioSession()
        let utterance = AVSpeechUtterance(string: EnglishSpeech.spoken(text))
        utterance.voice = voice(for: accent)
        utterance.rate = speed.rate
        self.source = source
        if let index { indexByUtterance[ObjectIdentifier(utterance)] = index }
        lastUtterance = utterance
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    func stop() {
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
