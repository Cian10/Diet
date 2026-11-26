import SwiftUI
import DietCore

struct TodayMacroDashboardCard: View {
    let target: TargetResolution?
    let intake: NutritionTotals
    let assessment: NutritionAssessment?
    let onEditTarget: () -> Void
    let onTapIncomplete: () -> Void

    init(
        target: TargetResolution?,
        intake: NutritionTotals,
        assessment: NutritionAssessment?,
        onEditTarget: @escaping () -> Void,
        onTapIncomplete: @escaping () -> Void
    ) {
        self.target = target
        self.intake = intake
        self.assessment = assessment
        self.onEditTarget = onEditTarget
        self.onTapIncomplete = onTapIncomplete
    }

    private var calorieProgress: Double {
        guard let target, target.dailyTarget.calories > 0 else { return 0 }
        return intake.calories / target.dailyTarget.calories
    }

    private var unknownItemSummary: String {
        intake.unknownItemNames.isEmpty
            ? "含未知项"
            : intake.unknownItemNames.joined(separator: "、")
    }

    private var calorieAccessibilityLabel: String {
        if let target {
            let remaining = target.dailyTarget.calories - intake.calories
            if remaining >= 0 {
                return "剩余可摄入 \(DietFormat.calories(remaining))"
            }
            return "已超出目标 \(DietFormat.calories(abs(remaining)))"
        }
        return "今日已摄入 \(DietFormat.calories(intake.calories))"
    }

    private var calorieAccessibilityValue: String {
        if let target {
            let statusText = target.dailyTarget.isSingleDayOverride ? "单日修改" : "已生效"
            return "已摄入 \(DietFormat.calories(intake.calories))，目标 \(DietFormat.calories(target.dailyTarget.calories))，\(statusText)"
        }
        return "尚未设置今日目标"
    }

    var body: some View {
        DietHeroSurface {
            VStack(alignment: .leading, spacing: 18) {
                headerRow

                DietFuelBar(
                    progress: calorieProgress,
                    tint: DietTheme.Palette.primary,
                    height: 10,
                    hasUncertainTail: !intake.isComplete
                )

                if !intake.isComplete {
                    incompleteRow
                }

                macroGrid

                if let deficit = assessment?.actualCalorieDeficit {
                    VStack(alignment: .leading, spacing: 8) {
                        DietHairline()
                        Text(deficit >= 0
                            ? "估算实际热量缺口 \(DietFormat.calories(deficit))"
                            : "估算实际热量盈余 \(DietFormat.calories(abs(deficit)))")
                            .font(.caption)
                            .monospacedDigit()
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var headerRow: some View {
        HStack(alignment: .top, spacing: 16) {
            calorieSummaryBlock
                .frame(maxWidth: .infinity, alignment: .leading)

            if let target {
                HStack(spacing: 8) {
                    DietStatusBadge(
                        status: .confirmed,
                        title: target.dailyTarget.isSingleDayOverride ? "单日修改" : "已生效"
                    )
                    Button("修改", action: onEditTarget)
                        .buttonStyle(.dietText)
                        .accessibilityLabel("修改今日目标")
                }
            }
        }
    }

    private var calorieSummaryBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let target {
                let remaining = target.dailyTarget.calories - intake.calories
                Text(remaining >= 0 ? "剩余可摄入" : "已超出目标")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(DietTheme.Palette.inkSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(DietFormat.number(abs(remaining), maximumFractionDigits: 0))
                        .font(DietTheme.Typography.heroMetric)
                        .monospacedDigit()
                        .foregroundStyle(DietTheme.Palette.ink)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text("kcal")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                }

                Text("已摄入 \(DietFormat.number(intake.calories, maximumFractionDigits: 0)) / 目标 \(DietFormat.calories(target.dailyTarget.calories))")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
            } else {
                Text("今日摄入")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(DietTheme.Palette.inkSecondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(DietFormat.number(intake.calories, maximumFractionDigits: 0))
                        .font(DietTheme.Typography.heroMetric)
                        .monospacedDigit()
                        .foregroundStyle(DietTheme.Palette.ink)
                        .minimumScaleFactor(0.75)
                        .lineLimit(1)
                    Text("kcal")
                        .font(.callout.weight(.medium))
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                }

                Text("已摄入 \(DietFormat.calories(intake.calories)) · 尚未设置今日目标")
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(calorieAccessibilityLabel)
        .accessibilityValue(calorieAccessibilityValue)
    }

    private var incompleteRow: some View {
        Button(action: onTapIncomplete) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(DietTheme.Palette.warning)
                    .accessibilityHidden(true)

                Text("部分合计：\(unknownItemSummary)（未按 0 处理）")
                    .font(.footnote)
                    .foregroundStyle(DietTheme.Palette.ink)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Text("去补全")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DietTheme.Palette.primaryText)
                    .fixedSize()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: DietTheme.Metrics.controlRadius, style: .continuous)
                    .fill(DietTheme.Palette.warningSoft)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("部分合计：\(unknownItemSummary)，未按 0 处理")
        .accessibilityHint("点击去补全餐食营养信息")
    }

    private var macroGrid: some View {
        HStack(alignment: .top, spacing: 14) {
            MacroColumnView(
                title: "蛋白质",
                consumed: intake.proteinGrams,
                goal: target?.dailyTarget.proteinGrams,
                tint: DietTheme.Palette.macroProtein
            )
            MacroColumnView(
                title: "碳水",
                consumed: intake.carbohydrateGrams,
                goal: target?.dailyTarget.carbohydrateGrams,
                tint: DietTheme.Palette.macroCarbs
            )
            MacroColumnView(
                title: "脂肪",
                consumed: intake.fatGrams,
                goal: target?.dailyTarget.fatGrams,
                tint: DietTheme.Palette.macroFat
            )
        }
    }
}

private struct MacroColumnView: View {
    let title: String
    let consumed: Double
    let goal: Double?
    let tint: Color

    private var progress: Double {
        guard let goal, goal > 0 else { return 0 }
        return consumed / goal
    }

    private var consumedText: String {
        DietFormat.number(consumed, maximumFractionDigits: 0)
    }

    private var goalText: String? {
        goal.map { DietFormat.number($0, maximumFractionDigits: 0) }
    }

    private var ratioLine: String {
        if let goalText {
            return "\(title) \(consumedText) / \(goalText) g"
        }
        return "\(title) \(consumedText) g"
    }

    private var remainingLine: String {
        guard let goal else { return "未设目标" }
        let remaining = goal - consumed
        if remaining >= 0 {
            return "剩 \(DietFormat.number(remaining, maximumFractionDigits: 0)) g"
        }
        return "超 \(DietFormat.number(abs(remaining), maximumFractionDigits: 0)) g"
    }

    private var accessibilityValueText: String {
        if let goal, let goalText {
            let remaining = goal - consumed
            let remainingDesc = remaining >= 0
                ? "剩余 \(DietFormat.number(remaining, maximumFractionDigits: 0)) 克"
                : "超出 \(DietFormat.number(abs(remaining), maximumFractionDigits: 0)) 克"
            return "已摄入 \(consumedText) 克，目标 \(goalText) 克，\(remainingDesc)"
        }
        return "已摄入 \(consumedText) 克，尚未设置目标"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(tint)
                    .frame(width: 6, height: 6)
                    .accessibilityHidden(true)
                Text(ratioLine)
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(DietTheme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            DietFuelBar(
                progress: progress,
                tint: tint,
                height: 5,
                hasUncertainTail: false
            )

            Text(remainingLine)
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(DietTheme.Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValueText)
    }
}

struct TodayMealTimelineSection<RowDestination: View>: View {
    let entries: [MealEntry]
    let suggestedMealType: MealType
    @Binding var quickInputText: String
    let onQuickAnalyze: (String, MealType) -> Void
    let onOpenPhoto: () -> Void
    let onOpenManual: (MealType) -> Void
    @ViewBuilder let destination: (MealEntry) -> RowDestination

    @State private var overrideMealType: MealType?

    init(
        entries: [MealEntry],
        suggestedMealType: MealType,
        quickInputText: Binding<String>,
        onQuickAnalyze: @escaping (String, MealType) -> Void,
        onOpenPhoto: @escaping () -> Void,
        onOpenManual: @escaping (MealType) -> Void,
        @ViewBuilder destination: @escaping (MealEntry) -> RowDestination
    ) {
        self.entries = entries
        self.suggestedMealType = suggestedMealType
        self._quickInputText = quickInputText
        self.onQuickAnalyze = onQuickAnalyze
        self.onOpenPhoto = onOpenPhoto
        self.onOpenManual = onOpenManual
        self.destination = destination
    }

    private var sortedEntries: [MealEntry] {
        entries.sorted { $0.consumedAt < $1.consumedAt }
    }

    private var activeMealType: MealType {
        overrideMealType ?? suggestedMealType
    }

    private var trimmedQuickInput: String {
        quickInputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            DietGroupHeader("今日餐食", detail: "\(entries.count) 条记录")

            if sortedEntries.isEmpty {
                Text("今天还没有餐食记录，可以在下方快速输入一句开始。")
                    .font(.footnote)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(sortedEntries.enumerated()), id: \.element.id) { index, entry in
                        NavigationLink {
                            destination(entry)
                        } label: {
                            TodayMealTimelineRow(entry: entry)
                        }
                        .buttonStyle(.plain)

                        if index < sortedEntries.count - 1 {
                            DietHairline()
                        }
                    }
                }
            }

            quickInputSlot
        }
    }

    private var quickInputSlot: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 10) {
                mealTypeMenu

                TextField("记下\(activeMealType.displayName)，按 ⌘↩ 分析…", text: $quickInputText)
                    .textFieldStyle(.plain)
                    .font(.body)
                    .foregroundStyle(DietTheme.Palette.ink)
                    .onSubmit {
                        submitQuickAnalyze()
                    }
                    .accessibilityLabel("快速记录\(activeMealType.displayName)内容")

                Button(action: onOpenPhoto) {
                    Image(systemName: "camera")
                        .frame(minWidth: 18, minHeight: 18)
                }
                .buttonStyle(.dietSecondary)
                .accessibilityLabel("图片识别记一餐")

                Button("分析") {
                    submitQuickAnalyze()
                }
                .buttonStyle(.dietPrimary)
                .disabled(trimmedQuickInput.isEmpty)
                .keyboardShortcut(.return, modifiers: .command)
                .accessibilityLabel("分析这一餐")
            }

            HStack(spacing: 8) {
                Text("描述食材与大致份量，确认后计入今日摄入。")
                    .font(.caption)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                Spacer(minLength: 8)
                Button {
                    let mealType = activeMealType
                    overrideMealType = nil
                    onOpenManual(mealType)
                } label: {
                    Text("手动记录")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.dietText)
            }
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: DietTheme.Metrics.cardRadius, style: .continuous)
                .fill(DietTheme.Palette.surface)
                .overlay {
                    RoundedRectangle(cornerRadius: DietTheme.Metrics.cardRadius, style: .continuous)
                        .stroke(DietTheme.Palette.hairline, lineWidth: 1)
                }
        }
    }

    private var mealTypeMenu: some View {
        Menu {
            ForEach(MealType.allCases, id: \.self) { mealType in
                Button {
                    overrideMealType = mealType
                } label: {
                    if activeMealType == mealType {
                        Label(mealType.displayName, systemImage: "checkmark")
                    } else {
                        Text(mealType.displayName)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(activeMealType.displayName)
                    .font(.footnote.weight(.medium))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(DietTheme.Palette.ink)
            .padding(.horizontal, 10)
            .frame(minHeight: DietTheme.Metrics.controlHeight)
            .background {
                RoundedRectangle(cornerRadius: DietTheme.Metrics.controlRadius, style: .continuous)
                    .fill(DietTheme.Palette.surfaceMuted)
            }
        }
        #if os(macOS)
        .menuStyle(.borderlessButton)
        .fixedSize()
        #endif
        .accessibilityLabel("餐别：\(activeMealType.displayName)")
        .accessibilityHint("选择快速记录的餐别")
    }

    private func submitQuickAnalyze() {
        let trimmed = trimmedQuickInput
        guard !trimmed.isEmpty else { return }
        let mealType = activeMealType
        overrideMealType = nil
        onQuickAnalyze(trimmed, mealType)
    }
}

private struct TodayMealTimelineRow: View {
    let entry: MealEntry

    @State private var isHovered = false

    private var foodTitle: String {
        if !entry.components.isEmpty {
            return entry.components.map(\.displayName).joined(separator: "、")
        }
        if let originalText = entry.originalText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !originalText.isEmpty {
            return originalText
        }
        return "\(entry.mealType.displayName)（尚未添加食物）"
    }

    private var totals: NutritionTotals? {
        guard entry.isConfirmed, !entry.components.isEmpty else { return nil }
        return NutritionCalculator().mealNutrition(entry)
    }

    private var statusDotColor: Color {
        switch entry.status {
        case .confirmed:
            if let totals, !totals.isComplete {
                return DietTheme.Palette.warning
            }
            return DietTheme.Palette.primary
        case .draft:
            return DietTheme.Palette.warning
        case .failed:
            return DietTheme.Palette.danger
        }
    }

    private var statusText: String {
        switch entry.status {
        case .confirmed:
            if let totals, !totals.isComplete {
                return "部分未知"
            }
            return "已确认"
        case .draft:
            return "待确认"
        case .failed:
            return "分析失败"
        }
    }

    private var statusTextColor: Color {
        switch entry.status {
        case .confirmed:
            if let totals, !totals.isComplete {
                return DietTheme.Palette.ink
            }
            return DietTheme.Palette.inkSecondary
        case .draft:
            return DietTheme.Palette.ink
        case .failed:
            return DietTheme.Palette.danger
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(DietFormat.time(entry.consumedAt))
                .font(.footnote.monospacedDigit())
                .foregroundStyle(DietTheme.Palette.inkSecondary)
                .frame(minWidth: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(foodTitle)
                    .font(.body.weight(.medium))
                    .foregroundStyle(DietTheme.Palette.ink)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(entry.mealType.displayName)
                    if let note = entry.note, !note.isEmpty {
                        Text("· \(note)")
                            .lineLimit(1)
                    }
                }
                .font(.caption)
                .foregroundStyle(DietTheme.Palette.inkSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 10) {
                if let totals {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("\(DietFormat.calories(totals.calories)) · 蛋白 \(DietFormat.number(totals.proteinGrams, maximumFractionDigits: 0))g")
                            .font(.footnote.monospacedDigit())
                            .foregroundStyle(DietTheme.Palette.ink)
                        if !totals.isComplete {
                            HStack(spacing: 4) {
                                Circle()
                                    .fill(statusDotColor)
                                    .frame(width: 6, height: 6)
                                    .accessibilityHidden(true)
                                Text(statusText)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(statusTextColor)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(statusDotColor)
                            .frame(width: 6, height: 6)
                            .accessibilityHidden(true)
                        Text(statusText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(statusTextColor)
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .accessibilityHidden(true)
            }
            .fixedSize()
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .background {
            RoundedRectangle(cornerRadius: DietTheme.Metrics.controlRadius, style: .continuous)
                .fill(isHovered ? DietTheme.Palette.surfaceMuted.opacity(0.65) : Color.clear)
        }
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityElement(children: .combine)
    }
}

struct TodayWeeklyRhythmPanel: View {
    let days: [DailyTrend]
    let eligibleDays: Int
    let metDays: Int?
    let latestWeight: WeightRecord?
    let weightDeltaText: String?
    let onJumpToTrends: (() -> Void)?

    init(
        days: [DailyTrend],
        eligibleDays: Int,
        metDays: Int?,
        latestWeight: WeightRecord?,
        weightDeltaText: String?,
        onJumpToTrends: (() -> Void)? = nil
    ) {
        self.days = days
        self.eligibleDays = eligibleDays
        self.metDays = metDays
        self.latestWeight = latestWeight
        self.weightDeltaText = weightDeltaText
        self.onJumpToTrends = onJumpToTrends
    }

    private var displayDays: [DailyTrend] {
        Array(days.suffix(7))
    }

    private var recordedDaysCount: Int {
        displayDays.filter(\.hasConfirmedEntries).count
    }

    private var incompleteDaysCount: Int {
        displayDays.filter { $0.hasConfirmedEntries && !$0.intake.isComplete }.count
    }

    private var maxCalorieReference: Double {
        let maxValue = displayDays
            .map { max($0.intake.calories, $0.target?.calories ?? 0) }
            .max() ?? 0
        return max(maxValue, 1)
    }

    private var rhythmAccessibilityValue: String {
        let metSummary: String
        if let metDays {
            metSummary = "热量达标 \(metDays) 天，共 \(eligibleDays) 天符合统计"
        } else {
            metSummary = "暂无可统计达标天数"
        }

        let incompleteSummary = incompleteDaysCount > 0
            ? "，其中 \(incompleteDaysCount) 天含未知营养项"
            : ""

        let weightSummary: String
        if let latestWeight {
            let weightText = "\(DietFormat.number(latestWeight.weightKilograms)) 公斤"
            if let weightDeltaText, !weightDeltaText.isEmpty {
                weightSummary = "，最新体重 \(weightText)，变化 \(weightDeltaText)"
            } else {
                weightSummary = "，最新体重 \(weightText)"
            }
        } else {
            weightSummary = "，暂无体重记录"
        }

        return "最近 7 日已记录 \(recordedDaysCount) 天；\(metSummary)\(incompleteSummary)\(weightSummary)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let onJumpToTrends {
                DietGroupHeader("近 7 日节奏") {
                    Button(action: onJumpToTrends) {
                        Text("查看趋势")
                            .font(.caption.weight(.medium))
                    }
                    .buttonStyle(.dietText)
                }
            } else {
                DietGroupHeader("近 7 日节奏")
            }

            VStack(alignment: .leading, spacing: 14) {
                barsRow

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("记录")
                            .font(.caption)
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                        Text("\(recordedDaysCount)/7 天")
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(DietTheme.Palette.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("达标")
                            .font(.caption)
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                        Text(metDays.map { "\($0)/\(eligibleDays) 天" } ?? "暂无")
                            .font(.footnote.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(DietTheme.Palette.ink)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                DietHairline()

                weightRow
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("近 7 日节奏")
            .accessibilityValue(rhythmAccessibilityValue)
        }
    }

    @ViewBuilder
    private var barsRow: some View {
        if displayDays.isEmpty {
            HStack(spacing: 8) {
                ForEach(["一", "二", "三", "四", "五", "六", "日"], id: \.self) { label in
                    VStack(spacing: 6) {
                        ZStack(alignment: .bottom) {
                            Capsule()
                                .fill(DietTheme.Palette.surfaceMuted)
                        }
                        .frame(width: 14, height: 52)
                        .clipShape(Capsule())
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        } else {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(displayDays) { day in
                    dayBar(day)
                }
            }
        }
    }

    private func dayBar(_ day: DailyTrend) -> some View {
        let isToday = Calendar.current.isDateInToday(day.date)
        let isIncomplete = day.hasConfirmedEntries && !day.intake.isComplete
        let barMaxHeight: CGFloat = 52
        let barWidth: CGFloat = 14

        let ratio: Double = {
            guard day.hasConfirmedEntries else { return 0 }
            if let target = day.target, target.calories > 0 {
                return min(max(day.intake.calories / target.calories, 0), 1)
            }
            return min(max(day.intake.calories / maxCalorieReference, 0), 1)
        }()

        let fillHeight: CGFloat = day.hasConfirmedEntries
            ? max(10, barMaxHeight * ratio)
            : 4

        let fillColor: Color = {
            if !day.hasConfirmedEntries {
                return DietTheme.Palette.surfaceMuted
            }
            if isIncomplete {
                return DietTheme.Palette.warningSoft
            }
            return isToday ? DietTheme.Palette.primary : DietTheme.Palette.primaryLine
        }()

        let weekdayLabel = day.date.formatted(
            .dateTime.weekday(.narrow).locale(Locale(identifier: "zh_CN"))
        )

        return VStack(spacing: 6) {
            ZStack(alignment: .bottom) {
                Capsule()
                    .fill(DietTheme.Palette.surfaceMuted.opacity(0.55))
                    .frame(width: barWidth, height: barMaxHeight)

                Capsule()
                    .fill(fillColor)
                    .overlay {
                        if isIncomplete {
                            Capsule()
                                .strokeBorder(
                                    DietTheme.Palette.warning,
                                    style: StrokeStyle(lineWidth: 1.5, dash: [3, 2])
                                )
                        }
                    }
                    .frame(width: barWidth, height: fillHeight)
            }
            .frame(width: barWidth, height: barMaxHeight)
            .clipShape(Capsule())

            Text(weekdayLabel)
                .font(.caption2.weight(isToday ? .semibold : .regular))
                .foregroundStyle(isToday ? DietTheme.Palette.primaryText : DietTheme.Palette.inkSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var weightRow: some View {
        if let latestWeight {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("最新体重")
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                    Text("\(DietFormat.number(latestWeight.weightKilograms)) kg")
                        .font(DietTheme.Typography.subMetric)
                        .monospacedDigit()
                        .foregroundStyle(DietTheme.Palette.ink)
                }

                Spacer(minLength: 8)

                if let weightDeltaText, !weightDeltaText.isEmpty {
                    Text(weightDeltaText)
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                }
            }
        } else {
            Text("暂无体重记录")
                .font(.footnote)
                .foregroundStyle(DietTheme.Palette.inkSecondary)
        }
    }
}
