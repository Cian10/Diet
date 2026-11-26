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
        static let canvas = Color.dietAdaptive(light: 0xF1F1EC, dark: 0x101110)
        static let paper = Color.dietAdaptive(light: 0xF6F6F3, dark: 0x131413)
        static let sidebar = Color.dietAdaptive(light: 0xEFEFE9, dark: 0x181918)
        static let surface = Color.dietAdaptive(light: 0xFFFFFF, dark: 0x1C1E1C)
        static let surfaceMuted = Color.dietAdaptive(light: 0xECECE7, dark: 0x252825)
        static let ink = Color.dietAdaptive(light: 0x181A18, dark: 0xF2F2EE)
        static let inkSecondary = Color.dietAdaptive(light: 0x5B605C, dark: 0xA2A8A3)
        static let inkTertiary = Color.dietAdaptive(light: 0x6E7470, dark: 0x868D88)
        static let border = Color.dietAdaptive(light: 0xE2E2DC, dark: 0x2D302D)
        static let hairline = Color.dietAdaptive(light: 0xE2E2DC, dark: 0x2D302D)
        static let primary = Color.dietAdaptive(light: 0x1F5E43, dark: 0x5CC192)
        static let primaryDeep = Color.dietAdaptive(light: 0x174833, dark: 0x8ADBB3)
        static let primaryText = Color.dietAdaptive(light: 0x1D573E, dark: 0x7AD4A8)
        static let onPrimary = Color.dietAdaptive(light: 0xFFFFFF, dark: 0x0D1F17)
        static let onPrimaryDeep = Color.dietAdaptive(light: 0xFFFFFF, dark: 0x0F241B)
        static let primarySoft = Color.dietAdaptive(light: 0xE4EFE9, dark: 0x1E3329)
        static let primaryLine = Color.dietAdaptive(light: 0xC7DDD1, dark: 0x2E4B3D)
        static let warning = Color.dietAdaptive(light: 0xB86B1A, dark: 0xF0B25F)
        static let warningSoft = Color.dietAdaptive(light: 0xFBF1E3, dark: 0x362A1B)
        static let danger = Color.dietAdaptive(light: 0xB33A32, dark: 0xF08078)
        static let dangerSoft = Color.dietAdaptive(light: 0xFAE7E5, dark: 0x38201E)
        static let macroProtein = Color.dietAdaptive(light: 0x2A6F97, dark: 0x64B5E5)
        static let macroProteinSoft = Color.dietAdaptive(light: 0xE6F0F6, dark: 0x1B2F3B)
        static let macroCarbs = Color.dietAdaptive(light: 0xC47D2B, dark: 0xE5A952)
        static let macroCarbsSoft = Color.dietAdaptive(light: 0xF8EFE3, dark: 0x352919)
        static let macroFat = Color.dietAdaptive(light: 0x8A5A7E, dark: 0xC68FB8)
        static let macroFatSoft = Color.dietAdaptive(light: 0xF2EBF0, dark: 0x31232E)
    }

    enum Metrics {
        static let pagePadding: CGFloat = 28
        static let compactPagePadding: CGFloat = 20
        static let sectionSpacing: CGFloat = 24
        static let itemSpacing: CGFloat = 12
        static let cardPadding: CGFloat = 18
        static let focusPadding: CGFloat = 22
        static let controlHeight: CGFloat = 32
        static let cardRadius: CGFloat = 12
        static let focusRadius: CGFloat = 16
        static let controlRadius: CGFloat = 8
        static let sheetRadius: CGFloat = 18
        static let contentWidth: CGFloat = 1180
        static let workbenchMaxWidth: CGFloat = 1220
        static let railMinWidth: CGFloat = 290
        static let railMaxWidth: CGFloat = 350
        static let twoColumnBreakpoint: CGFloat = 840
    }

    enum Typography {
        static let pageTitle = Font.largeTitle.weight(.semibold)
        static let sectionTitle = Font.title3.weight(.semibold)
        static let cardTitle = Font.headline.weight(.semibold)
        static let body = Font.body
        static let supporting = Font.footnote
        static let metric = Font.title2.weight(.semibold)
        static let micro = Font.caption.weight(.medium)
        static let heroMetric = Font.system(size: 36, weight: .bold, design: .rounded)
        static let subMetric = Font.system(size: 18, weight: .semibold, design: .rounded)
        static let groupEyebrow = Font.caption.weight(.semibold)
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
