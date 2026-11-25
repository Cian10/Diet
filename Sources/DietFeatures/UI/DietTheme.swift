import SwiftUI
#if os(macOS)
import AppKit
#elseif os(iOS)
import UIKit
#endif

/// The single visual source of truth for the macOS app.
/// Business modules deliberately do not depend on this palette.
enum DietTheme {
    enum Palette {
        static let canvas = Color.dietAdaptive(light: 0xEFF2ED, dark: 0x101713)
        static let paper = Color.dietAdaptive(light: 0xFCFDFB, dark: 0x131B17)
        static let sidebar = Color.dietAdaptive(light: 0xF7F9F5, dark: 0x19211D)
        static let surface = Color.dietAdaptive(light: 0xFFFFFF, dark: 0x1A2420)
        static let surfaceMuted = Color.dietAdaptive(light: 0xF1F4EF, dark: 0x222D27)
        static let ink = Color.dietAdaptive(light: 0x203128, dark: 0xEDF3EE)
        static let inkSecondary = Color.dietAdaptive(light: 0x5F6E65, dark: 0xA8B7AE)
        static let inkTertiary = Color.dietAdaptive(light: 0x6A786F, dark: 0x8B9A91)
        static let border = Color.dietAdaptive(light: 0xE3E9E1, dark: 0x303D35)
        static let primary = Color.dietAdaptive(light: 0x2F7D59, dark: 0x64AD83)
        static let primaryDeep = Color.dietAdaptive(light: 0x285F46, dark: 0xA7D7B8)
        static let primaryText = Color.dietAdaptive(light: 0x285F46, dark: 0x9FD2B2)
        static let onPrimary = Color.dietAdaptive(light: 0xFFFFFF, dark: 0x10231A)
        static let onPrimaryDeep = Color.dietAdaptive(light: 0xFFFFFF, dark: 0x173124)
        static let primarySoft = Color.dietAdaptive(light: 0xE5EFE6, dark: 0x263B30)
        static let primaryLine = Color.dietAdaptive(light: 0xD2E1D3, dark: 0x3C5646)
        static let warning = Color.dietAdaptive(light: 0x96601B, dark: 0xF2B869)
        static let warningSoft = Color.dietAdaptive(light: 0xFBF0DD, dark: 0x3A2D1C)
        static let danger = Color.dietAdaptive(light: 0x9F3E35, dark: 0xF08B80)
        static let dangerSoft = Color.dietAdaptive(light: 0xF8E5E2, dark: 0x3A2320)
    }

    enum Metrics {
        static let pagePadding: CGFloat = 28
        static let compactPagePadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
        static let itemSpacing: CGFloat = 12
        static let cardPadding: CGFloat = 18
        static let focusPadding: CGFloat = 22
        static let controlHeight: CGFloat = 34
        static let cardRadius: CGFloat = 14
        static let focusRadius: CGFloat = 16
        static let controlRadius: CGFloat = 9
        static let sheetRadius: CGFloat = 18
        static let contentWidth: CGFloat = 1180
    }

    enum Typography {
        static let pageTitle = Font.largeTitle.weight(.semibold)
        static let sectionTitle = Font.title3.weight(.semibold)
        static let cardTitle = Font.headline.weight(.semibold)
        static let body = Font.body
        static let supporting = Font.footnote
        static let metric = Font.title2.weight(.semibold)
        static let micro = Font.caption.weight(.medium)
    }
}

private extension Color {
    static func dietAdaptive(light: UInt32, dark: UInt32) -> Color {
        #if os(macOS)
        return Color(NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(dietHex: isDark ? dark : light)
        })
        #elseif os(iOS)
        return Color(UIColor { traits in
            UIColor(dietHex: traits.userInterfaceStyle == .dark ? dark : light)
        })
        #else
        return Color.primary
        #endif
    }
}

#if os(macOS)
private extension NSColor {
    convenience init(dietHex hex: UInt32) {
        self.init(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#elseif os(iOS)
private extension UIColor {
    convenience init(dietHex hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
#endif

enum DietFormat {
    static func number(_ value: Double, maximumFractionDigits: Int = 1) -> String {
        value.formatted(.number.precision(.fractionLength(0...maximumFractionDigits)))
    }

    static func calories(_ value: Double) -> String {
        "\(number(value, maximumFractionDigits: 0)) kcal"
    }

    static func grams(_ value: Double) -> String {
        "\(number(value)) g"
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func day(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day().weekday(.wide).locale(Locale(identifier: "zh_CN")))
    }
}
