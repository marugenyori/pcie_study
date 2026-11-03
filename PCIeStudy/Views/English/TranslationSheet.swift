import SwiftUI
import Translation

/// iPhone の翻訳機能で日本語訳を表示する（iOS 17.4 以上）
struct TranslationSheet: ViewModifier {
    @Binding var isPresented: Bool
    let text: String

    static var isSupported: Bool {
        if #available(iOS 17.4, *) { return true }
        return false
    }

    func body(content: Content) -> some View {
        if #available(iOS 17.4, *) {
            content.translationPresentation(isPresented: $isPresented, text: text)
        } else {
            content
        }
    }
}

/// 文字起こしの全文を、iPhone の翻訳機能でまとめて日本語に訳す（iOS 18 以上）
///
/// まだ訳していない文だけを訳す。初回は英語・日本語の翻訳データのダウンロードを iPhone が尋ねる。
struct TranscriptTranslation: ViewModifier {
    let isActive: Bool
    let lines: [TranscriptLine]
    let onTranslated: ([UUID: String]) -> Void
    let onError: (String) -> Void

    static var isSupported: Bool {
        if #available(iOS 18.0, *) { return true }
        return false
    }

    func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.modifier(TranscriptTranslator(isActive: isActive, lines: lines,
                                                  onTranslated: onTranslated, onError: onError))
        } else {
            content
        }
    }
}

@available(iOS 18.0, *)
private struct TranscriptTranslator: ViewModifier {
    let isActive: Bool
    let lines: [TranscriptLine]
    let onTranslated: ([UUID: String]) -> Void
    let onError: (String) -> Void

    @State private var configuration: TranslationSession.Configuration?

    private var pendingCount: Int {
        lines.filter { $0.japanese == nil }.count
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: isActive, initial: true) { start() }
            .onChange(of: pendingCount) { start() }
            .translationTask(configuration) { session in
                let requests = lines.filter { $0.japanese == nil }.map {
                    TranslationSession.Request(sourceText: $0.text, clientIdentifier: $0.id.uuidString)
                }
                guard !requests.isEmpty else { return }
                do {
                    let responses = try await session.translations(from: requests)
                    var result: [UUID: String] = [:]
                    for response in responses {
                        if let id = response.clientIdentifier.flatMap(UUID.init(uuidString:)) {
                            result[id] = response.targetText
                        }
                    }
                    await MainActor.run { onTranslated(result) }
                } catch {
                    await MainActor.run { onError(error.localizedDescription) }
                }
            }
    }

    private func start() {
        guard isActive, pendingCount > 0 else { return }
        if configuration == nil {
            configuration = TranslationSession.Configuration(source: Locale.Language(identifier: "en"),
                                                             target: Locale.Language(identifier: "ja"))
        } else {
            configuration?.invalidate()
        }
    }
}
