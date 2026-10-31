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
