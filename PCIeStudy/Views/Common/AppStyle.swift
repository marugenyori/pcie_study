import SwiftUI

/// 画面の背景・カード・ボタンの色
struct AppPalette {
    let background: Color
    /// 背景に重ねるテーマ色（「テーマ色」の背景のとき）
    let backgroundTint: Double
    let surface: Color
    let border: Color
    /// カードやボタンの下に付ける厚み（ポップのとき）
    let edge: CGFloat

    static func make(_ settings: AppSettings, scheme: ColorScheme) -> AppPalette {
        switch (settings.style, scheme) {
        case (.simple, _):
            return AppPalette(background: Color(.systemGroupedBackground), backgroundTint: 0,
                              surface: Color(.secondarySystemGroupedBackground), border: .clear, edge: 0)
        case (.pop, .dark):
            return AppPalette(background: Color(red: 0.075, green: 0.122, blue: 0.141), backgroundTint: 0,
                              surface: Color(red: 0.090, green: 0.145, blue: 0.169),
                              border: Color(red: 0.216, green: 0.275, blue: 0.310), edge: 4)
        case (.pop, _):
            let background: Color
            var tint = 0.0
            switch settings.backgroundTone {
            case .white: background = .white
            case .cream: background = Color(red: 1.0, green: 0.976, blue: 0.925)
            case .tinted:
                background = .white
                tint = 0.10
            }
            return AppPalette(background: background, backgroundTint: tint,
                              surface: .white, border: Color(red: 0.898, green: 0.898, blue: 0.898), edge: 4)
        }
    }
}

// MARK: - 背景

private struct ScreenBackground: ViewModifier {
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let palette = AppPalette.make(settings, scheme: scheme)
        return content
            .scrollContentBackground(.hidden)
            .background {
                ZStack {
                    palette.background
                    if palette.backgroundTint > 0 {
                        settings.theme.color.opacity(palette.backgroundTint)
                    }
                }
                .ignoresSafeArea()
            }
    }
}

// MARK: - カード

private struct CardStyle: ViewModifier {
    let cornerRadius: CGFloat
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let palette = AppPalette.make(settings, scheme: scheme)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        return content
            .background {
                shape.fill(palette.surface)
                    .overlay(shape.strokeBorder(palette.border, lineWidth: 2))
            }
            .background {
                shape.fill(palette.border).offset(y: palette.edge)
            }
            .padding(.bottom, palette.edge)
    }
}

// MARK: - クイズの選択肢

enum ChoiceState {
    case normal, correct, wrong, dimmed
}

private struct ChoiceTile: ViewModifier {
    let state: ChoiceState
    let cornerRadius: CGFloat
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        let palette = AppPalette.make(settings, scheme: scheme)
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let (fill, border): (Color, Color) = {
            switch state {
            case .normal, .dimmed:
                return (settings.style == .pop ? palette.surface : Color(.systemBackground),
                        settings.style == .pop ? palette.border : Color(.separator))
            case .correct: return (.green.opacity(0.18), .green)
            case .wrong: return (.red.opacity(0.15), .red)
            }
        }()
        let pop = settings.style == .pop
        return content
            .background {
                shape.fill(fill)
                    .overlay(shape.strokeBorder(border, lineWidth: pop ? 2 : 1))
            }
            .background {
                shape.fill(border).offset(y: pop ? 4 : 0)
            }
            .padding(.bottom, pop ? 4 : 0)
            .opacity(state == .dimmed ? 0.6 : 1)
    }
}

extension View {
    /// 画面全体の背景（List / Form / ScrollView の標準の背景を置き換える）
    func screenBackground() -> some View {
        modifier(ScreenBackground())
    }

    /// カード（ポップのときは縁取りと厚みを付ける）
    func cardStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(CardStyle(cornerRadius: cornerRadius))
    }

    /// クイズの選択肢
    func choiceTile(_ state: ChoiceState, cornerRadius: CGFloat = 14) -> some View {
        modifier(ChoiceTile(state: state, cornerRadius: cornerRadius))
    }
}

// MARK: - ボタン

/// ポップのときは厚みのある立体ボタン、シンプルのときは iOS 標準に近いボタン
struct AppButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary }
    let kind: Kind

    init(_ kind: Kind) {
        self.kind = kind
    }

    func makeBody(configuration: Configuration) -> some View {
        AppButtonBody(label: configuration.label, isPressed: configuration.isPressed, kind: kind)
    }
}

private struct AppButtonBody<Label: View>: View {
    let label: Label
    let isPressed: Bool
    let kind: AppButtonStyle.Kind

    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var scheme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.controlSize) private var controlSize

    var body: some View {
        let palette = AppPalette.make(settings, scheme: scheme)
        let small = controlSize == .small || controlSize == .mini
        let base = label
            .font(small ? .subheadline.weight(.bold) : .body.weight(.bold))
            .padding(.vertical, small ? 6 : 13)
            .padding(.horizontal, small ? 12 : 16)

        if settings.style == .pop {
            let shape = RoundedRectangle(cornerRadius: small ? 12 : 16, style: .continuous)
            let edge: CGFloat = small ? 3 : 4
            switch kind {
            case .primary:
                base
                    .foregroundStyle(isEnabled ? Color.white : Color.secondary)
                    .background {
                        shape.fill(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(palette.border))
                    }
                    .background {
                        shape.fill(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(palette.border))
                            .overlay(shape.fill(Color.black.opacity(0.22)))
                            .offset(y: isPressed ? 0 : edge)
                    }
                    .offset(y: isPressed ? edge : 0)
                    .padding(.bottom, edge)
            case .secondary:
                base
                    .foregroundStyle(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary))
                    .background {
                        shape.fill(palette.surface)
                            .overlay(shape.strokeBorder(palette.border, lineWidth: 2))
                    }
                    .background {
                        shape.fill(palette.border).offset(y: isPressed ? 0 : edge)
                    }
                    .offset(y: isPressed ? edge : 0)
                    .padding(.bottom, edge)
            }
        } else {
            let shape = RoundedRectangle(cornerRadius: small ? 8 : 12, style: .continuous)
            switch kind {
            case .primary:
                base
                    .foregroundStyle(isEnabled ? Color.white : Color.secondary)
                    .background(shape.fill(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.tertiarySystemFill))))
                    .opacity(isPressed ? 0.75 : 1)
            case .secondary:
                base
                    .foregroundStyle(isEnabled ? AnyShapeStyle(.tint) : AnyShapeStyle(Color.secondary))
                    .background(shape.fill(isEnabled ? AnyShapeStyle(.tint.opacity(0.15)) : AnyShapeStyle(Color(.tertiarySystemFill))))
                    .opacity(isPressed ? 0.6 : 1)
            }
        }
    }
}
