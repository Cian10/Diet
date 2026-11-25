import SwiftUI

struct DietPrimaryButtonStyle: ButtonStyle {
    var isOnFocus = false

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(isEnabled ? (isOnFocus ? DietTheme.Palette.onPrimaryDeep : DietTheme.Palette.onPrimary) : DietTheme.Palette.inkSecondary)
            .padding(.horizontal, 15)
            .frame(minHeight: DietTheme.Metrics.controlHeight)
            .background {
                RoundedRectangle(cornerRadius: DietTheme.Metrics.controlRadius, style: .continuous)
                    .fill(isEnabled ? (isOnFocus ? DietTheme.Palette.primaryDeep : DietTheme.Palette.primary) : DietTheme.Palette.surfaceMuted)
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct DietSecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(isEnabled ? DietTheme.Palette.ink : DietTheme.Palette.inkSecondary)
            .padding(.horizontal, 14)
            .frame(minHeight: DietTheme.Metrics.controlHeight)
            .background {
                RoundedRectangle(cornerRadius: DietTheme.Metrics.controlRadius, style: .continuous)
                    .fill(DietTheme.Palette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: DietTheme.Metrics.controlRadius, style: .continuous)
                            .stroke(DietTheme.Palette.border, lineWidth: 1)
                    }
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct DietTextButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(isEnabled ? DietTheme.Palette.primaryText : DietTheme.Palette.inkSecondary)
            .padding(.horizontal, 4)
            .padding(.vertical, 6)
            .opacity(configuration.isPressed ? 0.65 : 1)
    }
}

extension ButtonStyle where Self == DietPrimaryButtonStyle {
    static var dietPrimary: DietPrimaryButtonStyle { DietPrimaryButtonStyle() }
}

extension ButtonStyle where Self == DietSecondaryButtonStyle {
    static var dietSecondary: DietSecondaryButtonStyle { DietSecondaryButtonStyle() }
}

extension ButtonStyle where Self == DietTextButtonStyle {
    static var dietText: DietTextButtonStyle { DietTextButtonStyle() }
}
