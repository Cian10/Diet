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
                    .shadow(color: DietTheme.Palette.ink.opacity(0.035), radius: 5, x: 0, y: 2)
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

struct DietFocusCard: View {
    enum Tone {
        case normal
        case attention
    }

    let title: String
    let message: String
    let actionTitle: String
    var progress: Double? = nil
    var progressCaption: String? = nil
    var tone: Tone = .normal
    let action: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Label("今日重点", systemImage: tone == .attention ? "checklist" : "sparkles")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(tone == .attention ? DietTheme.Palette.warning : DietTheme.Palette.primaryText)
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(DietTheme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(message)
                    .font(.body)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button(actionTitle, action: action)
                    .buttonStyle(DietPrimaryButtonStyle(isOnFocus: true))
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let progress {
                VStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .stroke(DietTheme.Palette.primaryLine, lineWidth: 7)
                        Circle()
                            .trim(from: 0, to: min(max(progress, 0), 1))
                            .stroke(DietTheme.Palette.primary, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Text(progress.formatted(.percent.precision(.fractionLength(0))))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(DietTheme.Palette.primaryText)
                    }
                    .frame(width: 78, height: 78)
                    Text(progressCaption ?? "今日热量进度")
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(width: 100)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(progressCaption ?? "今日热量进度") \(progress.formatted(.percent.precision(.fractionLength(0))))")
            }
        }
        .padding(DietTheme.Metrics.focusPadding)
        .frame(maxWidth: .infinity)
        .background {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: DietTheme.Metrics.focusRadius, style: .continuous)
                    .fill(LinearGradient(
                        colors: tone == .attention
                            ? [DietTheme.Palette.warningSoft, DietTheme.Palette.surface]
                            : [DietTheme.Palette.primarySoft, DietTheme.Palette.surface],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                Circle()
                    .stroke(tone == .attention ? DietTheme.Palette.warning.opacity(0.12) : DietTheme.Palette.primaryLine.opacity(0.65), lineWidth: 18)
                    .frame(width: 150, height: 150)
                    .offset(x: 56, y: -86)
                    .accessibilityHidden(true)
            }
            .clipShape(RoundedRectangle(cornerRadius: DietTheme.Metrics.focusRadius, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: DietTheme.Metrics.focusRadius, style: .continuous)
                .stroke(tone == .attention ? DietTheme.Palette.warning.opacity(0.25) : DietTheme.Palette.primaryLine, lineWidth: 1)
        }
    }
}

struct DietMetricCard: View {
    let label: String
    let value: String
    let unit: String
    let systemImage: String
    var footnote: String? = nil

    var body: some View {
        DietCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 7) {
                    Image(systemName: systemImage)
                        .foregroundStyle(DietTheme.Palette.primaryText)
                        .accessibilityHidden(true)
                    Text(label)
                        .font(.footnote)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Text(value)
                        .font(DietTheme.Typography.metric)
                        .monospacedDigit()
                        .foregroundStyle(DietTheme.Palette.ink)
                        .minimumScaleFactor(0.8)
                    Text(unit)
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                }
                if let footnote {
                    Text(footnote)
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .lineLimit(2)
                }
            }
        }
        .accessibilityElement(children: .combine)
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
        case .pending, .estimated: DietTheme.Palette.warning
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

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(foreground)
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

    private var title: String {
        entry.components.isEmpty ? "尚未添加食物" : entry.components.map(\.displayName).joined(separator: "、")
    }

    private var status: DietStatusBadge.Status {
        switch entry.status {
        case .confirmed: .confirmed
        case .draft: .pending
        case .failed: .failed
        }
    }

    private var nutrition: String {
        guard entry.isConfirmed else { return entry.status.displayName }
        let totals = NutritionCalculator().mealNutrition(entry)
        if entry.components.isEmpty { return "等待补充食物" }
        let known = DietFormat.calories(totals.calories)
        return totals.isComplete ? known : "\(known) · 部分未知"
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            DietMealIcon(mealType: entry.mealType)
            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(DietTheme.Palette.ink)
                    .lineLimit(2)
                HStack(spacing: 5) {
                    if showsDate {
                        Text(entry.consumedAt.formatted(date: .abbreviated, time: .omitted))
                        Text("·")
                    }
                    Text(entry.mealType.displayName)
                    Text("·")
                    Text(DietFormat.time(entry.consumedAt))
                    Text("·")
                    Text(nutrition)
                }
                .font(.caption)
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
            DietStatusBadge(status: status)
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
