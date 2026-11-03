import SwiftUI

/// 下のタブ
enum AppTab: Hashable {
    case today, learn, quiz, diagrams, tools
}

/// タブのいちばん上の画面に戻る（同じタブをもう一度押したときと同じ）。どの画面からでも呼べる
private struct GoToTabRootKey: EnvironmentKey {
    static let defaultValue: (AppTab) -> Void = { _ in }
}

extension EnvironmentValues {
    var goToTabRoot: (AppTab) -> Void {
        get { self[GoToTabRootKey.self] }
        set { self[GoToTabRootKey.self] = newValue }
    }
}
