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
    func makeBody(configuration: Configuration) -> some View {
        DietSecondaryButtonBody(configuration: configuration)
    }
}

struct DietTextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        DietTextButtonBody(configuration: configuration)
    }
}

private struct DietSecondaryButtonBody: View {
    let configuration: ButtonStyleConfiguration

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var fillColor: Color {
        if !isEnabled || isHovered {
            return DietTheme.Palette.surfaceMuted
        }
        return DietTheme.Palette.surface
    }

    var body: some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(isEnabled ? DietTheme.Palette.ink : DietTheme.Palette.inkSecondary)
            .padding(.horizontal, 14)
            .frame(minHeight: DietTheme.Metrics.controlHeight)
            .background {
                RoundedRectangle(cornerRadius: DietTheme.Metrics.controlRadius, style: .continuous)
                    .fill(fillColor)
                    .overlay {
                        RoundedRectangle(cornerRadius: DietTheme.Metrics.controlRadius, style: .continuous)
                            .stroke(DietTheme.Palette.border, lineWidth: 1)
                    }
            }
            .contentShape(RoundedRectangle(cornerRadius: DietTheme.Metrics.controlRadius, style: .continuous))
            .onHover { hovering in
                isHovered = hovering
            }
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: configuration.isPressed)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered)
    }
}

private struct DietTextButtonBody: View {
    let configuration: ButtonStyleConfiguration

    @State private var isHovered = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(isEnabled ? DietTheme.Palette.primaryText : DietTheme.Palette.inkSecondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 5)
            .background {
                RoundedRectangle(cornerRadius: DietTheme.Metrics.controlRadius, style: .continuous)
                    .fill(isEnabled && isHovered ? DietTheme.Palette.surfaceMuted : Color.clear)
            }
            .contentShape(RoundedRectangle(cornerRadius: DietTheme.Metrics.controlRadius, style: .continuous))
            .opacity(configuration.isPressed ? 0.65 : 1)
            .onHover { hovering in
                isHovered = hovering
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.15), value: isHovered)
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
