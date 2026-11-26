import SwiftUI
import DietCore

struct DietCard<Content: View>: View {
    var padding: CGFloat = DietTheme.Metrics.cardPadding
    @ViewBuilder let content: Content

    init(padding: CGFloat = DietTheme.Metrics.cardPadding, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: DietTheme.Metrics.cardRadius, style: .continuous)
                    .fill(DietTheme.Palette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: DietTheme.Metrics.cardRadius, style: .continuous)
                            .stroke(DietTheme.Palette.border, lineWidth: 1)
                    }
                    .shadow(color: DietTheme.Palette.ink.opacity(0.02), radius: 2, x: 0, y: 1)
            }
    }
}

struct DietHairline: View {
    var body: some View {
        Rectangle()
            .fill(DietTheme.Palette.hairline)
            .frame(maxWidth: .infinity)
            .frame(height: 0.5)
            .accessibilityHidden(true)
    }
}

struct DietGroupHeader<Trailing: View>: View {
    let title: String
    private let detail: String?
    @ViewBuilder private let trailing: Trailing

    init(_ title: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.detail = nil
        self.trailing = trailing()
    }

    private init(title: String, detail: String?, trailing: Trailing) {
        self.title = title
        self.detail = detail
        self.trailing = trailing
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(title)
                    .font(DietTheme.Typography.groupEyebrow)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 8)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                } else {
                    trailing
                }
            }
            DietHairline()
        }
    }
}

extension DietGroupHeader where Trailing == EmptyView {
    init(_ title: String, detail: String? = nil) {
        self.init(title: title, detail: detail, trailing: EmptyView())
    }
}

struct DietHeroSurface<Content: View>: View {
    var padding: CGFloat = DietTheme.Metrics.focusPadding
    @ViewBuilder let content: Content

    init(padding: CGFloat = 22, @ViewBuilder content: () -> Content) {
        self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: DietTheme.Metrics.focusRadius, style: .continuous)
                    .fill(DietTheme.Palette.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: DietTheme.Metrics.focusRadius, style: .continuous)
                            .stroke(DietTheme.Palette.border, lineWidth: 1)
                    }
                    .shadow(color: DietTheme.Palette.ink.opacity(0.025), radius: 4, x: 0, y: 2)
            }
    }
}

struct DietFuelBar: View {
    let progress: Double
    let tint: Color
    var height: CGFloat = 8
    var hasUncertainTail: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var clampedProgress: Double {
        progress.isFinite ? min(max(progress, 0), 1) : 0
    }

    var body: some View {
        GeometryReader { proxy in
            let totalWidth = max(proxy.size.width, 0)
            let filledWidth = totalWidth * clampedProgress
            let tailWidth = hasUncertainTail ? min(max(totalWidth * 0.14, 18), totalWidth) : 0
            let solidWidth = hasUncertainTail
                ? min(filledWidth, max(totalWidth - tailWidth, 0))
                : filledWidth

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(DietTheme.Palette.surfaceMuted)
                HStack(spacing: 0) {
                    if solidWidth > 0 {
                        Rectangle()
                            .fill(tint)
                            .frame(width: solidWidth)
                    }
                    if hasUncertainTail && tailWidth > 0 {
                        UncertainHatchSegment(height: height)
                            .frame(width: tailWidth)
                    }
                }
            }
            .clipShape(Capsule())
            .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: clampedProgress)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }
}

private struct UncertainHatchSegment: View {
    let height: CGFloat

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(DietTheme.Palette.warningSoft))
            let stripeStep = max(5, height * 0.7)
            let lineWidth = max(1.5, height * 0.22)
            var path = Path()
            var x = -size.height
            while x < size.width + size.height {
                path.move(to: CGPoint(x: x, y: size.height))
                path.addLine(to: CGPoint(x: x + size.height, y: 0))
                x += stripeStep
            }
            context.stroke(path, with: .color(DietTheme.Palette.warning), lineWidth: lineWidth)
        }
    }
}

struct DietSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(DietTheme.Typography.sectionTitle)
                .foregroundStyle(DietTheme.Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
            }
        }
    }
}

struct DietStatusBadge: View {
    enum Status {
        case confirmed
        case pending
        case estimated
        case failed
        case neutral
    }

    let status: Status
    var title: String? = nil

    private var text: String {
        if let title { return title }
        switch status {
        case .confirmed: return "已确认"
        case .pending: return "待确认"
        case .estimated: return "估算"
        case .failed: return "分析失败"
        case .neutral: return "未记录"
        }
    }

    private var foreground: Color {
        switch status {
        case .confirmed: DietTheme.Palette.primaryText
        case .pending, .estimated: DietTheme.Palette.ink
        case .failed: DietTheme.Palette.danger
        case .neutral: DietTheme.Palette.inkSecondary
        }
    }

    private var background: Color {
        switch status {
        case .confirmed: DietTheme.Palette.primarySoft
        case .pending, .estimated: DietTheme.Palette.warningSoft
        case .failed: DietTheme.Palette.dangerSoft
        case .neutral: DietTheme.Palette.surfaceMuted
        }
    }

    private var showsWarningDot: Bool {
        status == .pending || status == .estimated
    }

    var body: some View {
        HStack(spacing: 5) {
            if showsWarningDot {
                Circle()
                    .fill(DietTheme.Palette.warning)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
            }
            Text(text)
                .font(.caption.weight(.medium))
                .foregroundStyle(foreground)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background { Capsule().fill(background) }
        .fixedSize()
    }
}

struct DietMealIcon: View {
    let mealType: MealType

    private var icon: String {
        switch mealType {
        case .breakfast: "sun.horizon"
        case .lunch: "sun.max"
        case .dinner: "moon.stars"
        case .snack: "cup.and.saucer"
        case .other: "fork.knife"
        }
    }

    var body: some View {
        Image(systemName: icon)
            .font(.body.weight(.medium))
            .foregroundStyle(DietTheme.Palette.primaryText)
            .frame(width: 34, height: 34)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(DietTheme.Palette.primarySoft)
            }
            .accessibilityHidden(true)
    }
}

struct DietMealRow: View {
    let entry: MealEntry
    var showsDate = false
    var showsMealIcon = true
    var showsMealTypeInSubtitle = true

    private var title: String {
        entry.components.isEmpty ? "尚未添加食物" : entry.components.map(\.displayName).joined(separator: "、")
    }

    private var nutrition: String {
        guard entry.isConfirmed else { return entry.status.displayName }
        if entry.components.isEmpty { return "等待补充食物" }
        let totals = NutritionCalculator().mealNutrition(entry)
        let caloriesText = DietFormat.calories(totals.calories)
        let proteinText = "蛋白 \(DietFormat.number(totals.proteinGrams, maximumFractionDigits: 0))g"
        let base = "\(caloriesText) · \(proteinText)"
        return totals.isComplete ? base : "\(base) · 部分未知"
    }

    private var subtitleItems: [String] {
        var items: [String] = []
        if showsDate {
            items.append(entry.consumedAt.formatted(date: .abbreviated, time: .omitted))
        }
        if showsMealTypeInSubtitle {
            items.append(entry.mealType.displayName)
        }
        items.append(DietFormat.time(entry.consumedAt))
        items.append(nutrition)
        return items
    }

    private var statusDotColor: Color {
        switch entry.status {
        case .confirmed: DietTheme.Palette.primary
        case .draft: DietTheme.Palette.warning
        case .failed: DietTheme.Palette.danger
        }
    }

    private var statusTextColor: Color {
        switch entry.status {
        case .confirmed: DietTheme.Palette.inkSecondary
        case .draft: DietTheme.Palette.ink
        case .failed: DietTheme.Palette.danger
        }
    }

    private var statusText: String {
        switch entry.status {
        case .confirmed: "已确认"
        case .draft: "待确认"
        case .failed: "分析失败"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if showsMealIcon {
                DietMealIcon(mealType: entry.mealType)
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(DietTheme.Palette.ink)
                    .lineLimit(2)
                Text(subtitleItems.joined(separator: " · "))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .lineLimit(1)
                if let note = entry.note, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            HStack(spacing: 5) {
                Circle()
                    .fill(statusDotColor)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(statusText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(statusTextColor)
            }
            .fixedSize()
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(DietTheme.Palette.inkSecondary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 7)
        .contentShape(Rectangle())
    }
}

struct DietKeyValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 16) {
            Text(title)
                .font(.body)
                .foregroundStyle(DietTheme.Palette.inkSecondary)
            Spacer(minLength: 12)
            Text(value)
                .font(.body)
                .foregroundStyle(DietTheme.Palette.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}

enum DietLoggingRoute: Identifiable {
    case text
    case photo

    var id: Self { self }
}

struct DietLoggingMenu: View {
    let onText: () -> Void
    let onPhoto: () -> Void

    var body: some View {
        Menu {
            Button {
                onText()
            } label: {
                Label("文字描述", systemImage: "text.quote")
            }
            Button {
                onPhoto()
            } label: {
                Label("图片识别", systemImage: "photo")
            }
        } label: {
            Label("记一餐", systemImage: "plus")
        }
        .buttonStyle(.dietPrimary)
        .menuIndicator(.hidden)
        .accessibilityLabel("记一餐")
        .accessibilityHint("选择文字描述或图片识别")
    }
}
