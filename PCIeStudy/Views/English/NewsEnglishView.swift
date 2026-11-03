import SwiftUI
import Translation

/// PCIe ニュースを英語で聞く・読む
///
/// news.json に英語（titleEn・summaryEn）があればそれを使い、なければ iPhone の翻訳機能（iOS 18 以上）で
/// 日本語から英語に訳す。訳したものはこの iPhone に保存して、次からはすぐ出す。
struct NewsEnglishView: View {
    let item: NewsItem

    @State private var player = SpeechPlayer()
    @State private var sentences: [String] = []
    @State private var translating = false
    @State private var errorMessage: String?
    @State private var showsEnglish = true
    @State private var showsJapanese = false

    private var source: String { "news-\(item.id)" }
    private static func cacheKey(_ id: String) -> String { "newsEnglish.\(id)" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.dateLabel).font(.caption).foregroundStyle(.secondary)
                    Text(item.title).font(.headline)
                }

                if sentences.isEmpty {
                    if translating {
                        ProgressView("英語にしています…")
                    } else if let errorMessage {
                        Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.orange)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            if player.isPlaying(source) { player.stop() } else { player.play(sentences, source: source) }
                        } label: {
                            Label(player.isPlaying(source) ? "止める" : "最初から聞く",
                                  systemImage: player.isPlaying(source) ? "stop.fill" : "play.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(AppButtonStyle(.primary))
                        Toggle("英文を表示", isOn: $showsEnglish)
                        Toggle("日本語を表示", isOn: $showsJapanese)
                    }
                    .font(.subheadline)
                    .padding()
                    .cardStyle()

                    ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                        let current = player.isPlaying(source) && player.currentIndex == index
                        Button {
                            player.play(sentences, from: index, source: source)
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                SpeakerIcon(playing: current, size: 36)
                                Text(sentence)
                                    .font(.body)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .blur(radius: showsEnglish ? 0 : 6)
                            }
                            .padding()
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .choiceTile(current ? .correct : .normal)
                    }

                    if showsJapanese {
                        Text(item.summary)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .padding()
                            .cardStyle()
                    }

                    Text(item.summaryEn == nil
                         ? "英文は iPhone の翻訳機能で作ったものです。固有名詞や数値は、元の記事で確かめてください。"
                         : "英文は news.json に入っている英語版です。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .screenBackground()
        .navigationTitle("英語で聞く")
        .navigationBarTitleDisplayMode(.inline)
        .modifier(NewsTranslator(item: item, needed: sentences.isEmpty && !hasEnglish) { english in
            UserDefaults.standard.set(english, forKey: Self.cacheKey(item.id))
            sentences = Self.split(english)
            translating = false
        } onError: { message in
            errorMessage = message
            translating = false
        })
        .onAppear(perform: prepare)
        .onDisappear { player.stop() }
    }

    private var hasEnglish: Bool {
        item.summaryEn != nil || UserDefaults.standard.string(forKey: Self.cacheKey(item.id)) != nil
    }

    private func prepare() {
        guard sentences.isEmpty else { return }
        if let summaryEn = item.summaryEn {
            sentences = Self.split([item.titleEn.map(Self.sentence), summaryEn].compactMap { $0 }.joined(separator: " "))
        } else if let cached = UserDefaults.standard.string(forKey: Self.cacheKey(item.id)) {
            sentences = Self.split(cached)
        } else if NewsTranslator.isSupported {
            translating = true
        } else {
            errorMessage = "英語にするには iOS 18 以上が必要です。"
        }
    }

    /// 題名のように句点のない文に、文の終わりの記号を付ける（題名と要約の1文目がつながらないように）
    static func sentence(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = trimmed.last, !".!?".contains(last) else { return trimmed }
        return trimmed + "."
    }

    /// 英文を1文ずつに分ける
    static func split(_ text: String) -> [String] {
        var result: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: .bySentences) { sentence, _, _, _ in
            if let sentence = sentence?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty {
                result.append(sentence)
            }
        }
        return result.isEmpty ? [text] : result
    }
}

/// ニュースの題名と要約を、iPhone の翻訳機能で日本語から英語にする（iOS 18 以上）
private struct NewsTranslator: ViewModifier {
    let item: NewsItem
    let needed: Bool
    let onTranslated: (String) -> Void
    let onError: (String) -> Void

    static var isSupported: Bool {
        if #available(iOS 18.0, *) { return true }
        return false
    }

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.modifier(Translator(item: item, needed: needed, onTranslated: onTranslated, onError: onError))
        } else {
            content
        }
    }

    @available(iOS 18.0, *)
    private struct Translator: ViewModifier {
        let item: NewsItem
        let needed: Bool
        let onTranslated: (String) -> Void
        let onError: (String) -> Void
        @State private var configuration: TranslationSession.Configuration?

        func body(content: Content) -> some View {
            content
                .onAppear {
                    if needed {
                        configuration = TranslationSession.Configuration(source: Locale.Language(identifier: "ja"),
                                                                         target: Locale.Language(identifier: "en"))
                    }
                }
                .translationTask(configuration) { session in
                    do {
                        let responses = try await session.translations(from: [
                            TranslationSession.Request(sourceText: item.title),
                            TranslationSession.Request(sourceText: item.summary),
                        ])
                        let english = responses.map { NewsEnglishView.sentence($0.targetText) }.joined(separator: " ")
                        await MainActor.run { onTranslated(english) }
                    } catch {
                        await MainActor.run { onError("英語にできませんでした：\(error.localizedDescription)") }
                    }
                }
        }
    }
}
