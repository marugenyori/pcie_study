import SwiftUI
import Observation

/// 見た目の設定（文字の大きさ・テーマ色・外観・行間）
@Observable
final class AppSettings {
    enum TextSize: String, CaseIterable, Identifiable {
        case system, small, standard, large, xLarge, xxLarge, max

        var id: String { rawValue }

        var label: String {
            switch self {
            case .system: return "iPhoneの設定に合わせる"
            case .small: return "小さめ"
            case .standard: return "標準"
            case .large: return "大きめ"
            case .xLarge: return "とても大きい"
            case .xxLarge: return "特大"
            case .max: return "最大"
            }
        }

        /// nil のときは iPhone の設定（Dynamic Type）に従う
        var dynamicType: DynamicTypeSize? {
            switch self {
            case .system: return nil
            case .small: return .medium
            case .standard: return .large
            case .large: return .xLarge
            case .xLarge: return .xxLarge
            case .xxLarge: return .xxxLarge
            case .max: return .accessibility1
            }
        }
    }

    enum Style: String, CaseIterable, Identifiable {
        case pop, simple

        var id: String { rawValue }

        var label: String {
            switch self {
            case .pop: return "ポップ"
            case .simple: return "シンプル"
            }
        }
    }

    enum BackgroundTone: String, CaseIterable, Identifiable {
        case white, cream, tinted

        var id: String { rawValue }

        var label: String {
            switch self {
            case .white: return "ホワイト"
            case .cream: return "クリーム"
            case .tinted: return "テーマ色"
            }
        }
    }

    enum Theme: String, CaseIterable, Identifiable {
        case lime, blue, indigo, teal, green, orange, pink, purple

        var id: String { rawValue }

        var label: String {
            switch self {
            case .lime: return "ライム"
            case .blue: return "ブルー"
            case .indigo: return "インディゴ"
            case .teal: return "ティール"
            case .green: return "グリーン"
            case .orange: return "オレンジ"
            case .pink: return "ピンク"
            case .purple: return "パープル"
            }
        }

        var color: Color {
            switch self {
            case .lime: return Color(red: 0.345, green: 0.800, blue: 0.008)
            case .blue: return .blue
            case .indigo: return .indigo
            case .teal: return .teal
            case .green: return .green
            case .orange: return .orange
            case .pink: return .pink
            case .purple: return .purple
            }
        }
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark

        var id: String { rawValue }

        var label: String {
            switch self {
            case .system: return "自動"
            case .light: return "ライト"
            case .dark: return "ダーク"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    private var storedStyle: Style
    private var storedBackgroundTone: BackgroundTone
    private var storedTextSize: TextSize
    private var storedTheme: Theme
    private var storedAppearance: Appearance
    private var storedWideLineSpacing: Bool

    var style: Style {
        get { storedStyle }
        set { storedStyle = newValue; save() }
    }
    var backgroundTone: BackgroundTone {
        get { storedBackgroundTone }
        set { storedBackgroundTone = newValue; save() }
    }
    var textSize: TextSize {
        get { storedTextSize }
        set { storedTextSize = newValue; save() }
    }
    var theme: Theme {
        get { storedTheme }
        set { storedTheme = newValue; save() }
    }
    var appearance: Appearance {
        get { storedAppearance }
        set { storedAppearance = newValue; save() }
    }
    /// 解説やコラムの行間を広くする
    var wideLineSpacing: Bool {
        get { storedWideLineSpacing }
        set { storedWideLineSpacing = newValue; save() }
    }

    @ObservationIgnored private let defaults: UserDefaults

    private enum Keys {
        static let style = "settingsStyle"
        static let backgroundTone = "settingsBackgroundTone"
        static let textSize = "settingsTextSize"
        static let theme = "settingsTheme"
        static let appearance = "settingsAppearance"
        static let wideLineSpacing = "settingsWideLineSpacing"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        storedStyle = Style(rawValue: defaults.string(forKey: Keys.style) ?? "") ?? .pop
        storedBackgroundTone = BackgroundTone(rawValue: defaults.string(forKey: Keys.backgroundTone) ?? "") ?? .white
        storedTextSize = TextSize(rawValue: defaults.string(forKey: Keys.textSize) ?? "") ?? .system
        storedTheme = Theme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .lime
        storedAppearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        storedWideLineSpacing = defaults.bool(forKey: Keys.wideLineSpacing)
    }

    /// 本文の行間
    var lineSpacing: CGFloat { wideLineSpacing ? 9 : 4 }

    private func save() {
        defaults.set(style.rawValue, forKey: Keys.style)
        defaults.set(backgroundTone.rawValue, forKey: Keys.backgroundTone)
        defaults.set(textSize.rawValue, forKey: Keys.textSize)
        defaults.set(theme.rawValue, forKey: Keys.theme)
        defaults.set(appearance.rawValue, forKey: Keys.appearance)
        defaults.set(wideLineSpacing, forKey: Keys.wideLineSpacing)
    }
}

extension View {
    /// 表示設定をアプリ全体に反映する
    func applyAppSettings(_ settings: AppSettings) -> some View {
        self
            .dynamicTypeSize(settings.textSize.dynamicType.map { $0...$0 } ?? (.xSmall ... .accessibility5))
            .tint(settings.theme.color)
            .preferredColorScheme(settings.appearance.colorScheme)
            .fontDesign(settings.style == .pop ? .rounded : .default)
    }
}
