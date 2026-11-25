import SwiftUI
import Charts
import DietCore

@MainActor
public final class TrendsViewModel: ObservableObject {
    @Published public private(set) var days: [DailyTrend] = []
    @Published public private(set) var overview = TrendsOverview(
        recordedDays: 0,
        averageCalories: nil,
        targetCompletionRate: nil,
        weightChangeKilograms: nil,
        weightSpanDays: 0,
        hasSufficientData: false
    )
    @Published public private(set) var weights: [WeightRecord] = []
    @Published public var errorMessage: String?

    public let service: TrendsService
    private let profileStore: ProfileStoring

    public init(service: TrendsService, profileStore: ProfileStoring) {
        self.service = service
        self.profileStore = profileStore
    }

    public func load() {
        do {
            let review = try service.weeklyReview()
            days = review.days
            overview = review.overview
            if let start = days.first?.date, let end = days.last?.date {
                weights = try profileStore.allWeightRecords().filter {
                    Calendar.current.startOfDay(for: $0.date) >= start && Calendar.current.startOfDay(for: $0.date) <= end
                }
            } else {
                weights = []
            }
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

public struct TrendsView: View {
    @StateObject private var viewModel: TrendsViewModel
    @StateObject private var reviewViewModel: WeeklyReviewViewModel
    private let onReviewChanged: () -> Void

    public init(
        service: TrendsService,
        profileStore: ProfileStoring,
        phaseStore: PhasePlanStoring,
        proposalStore: AdjustmentProposalStoring,
        onReviewChanged: @escaping () -> Void = {}
    ) {
        self.onReviewChanged = onReviewChanged
        _viewModel = StateObject(wrappedValue: TrendsViewModel(service: service, profileStore: profileStore))
        _reviewViewModel = StateObject(wrappedValue: WeeklyReviewViewModel(
            trendsService: service,
            phaseStore: phaseStore,
            proposalStore: proposalStore
        ))
    }

    private var dateRange: String {
        guard let start = viewModel.days.first?.date, let end = viewModel.days.last?.date else { return "最近七日" }
        return "\(start.formatted(.dateTime.month(.abbreviated).day())) – \(end.formatted(.dateTime.month(.abbreviated).day()))"
    }

    private var chartSummary: String {
        viewModel.days.map { day in
            let intake = DietFormat.calories(day.intake.calories)
            let completeness = day.intake.isComplete ? "营养完整" : "部分营养未知"
            let target = day.target.map { "，目标 \(DietFormat.calories($0.calories))" } ?? "，无目标"
            return "\(day.date.formatted(.dateTime.month(.abbreviated).day().weekday(.abbreviated)))：\(intake)，\(completeness)\(target)"
        }.joined(separator: "；")
    }

    private var visibleChartSummary: String {
        let today = viewModel.days.first(where: { Calendar.current.isDateInToday($0.date) })
        let todayText = today.map {
            "今天已确认 \(DietFormat.calories($0.intake.calories))（\($0.intake.isComplete ? "营养完整" : "部分未知"))"
        } ?? "今天尚无记录"
        return "本周共 \(viewModel.overview.recordedDays) / 7 个已确认记录日；\(todayText)。每日数值可通过 VoiceOver 逐项读取。"
    }

    public var body: some View {
        NavigationStack {
            DietPage {
                DietPageHeader(title: "趋势", subtitle: "先看七日事实，再决定是否需要调整。") {
                    DietDateCapsule(date: Date())
                }

                if let error = viewModel.errorMessage {
                    DietInlineNotice(.error, title: "需要处理", message: error)
                }

                if !viewModel.overview.hasSufficientData {
                    DietInlineNotice(
                        .info,
                        title: "数据不足",
                        message: "至少需要 3 个有记录日才展示趋势性描述；当前仅列出原始数据，不生成趋势结论。"
                    )
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 16) {
                        energyChart
                        overviewCard
                            .frame(width: 278)
                    }
                    VStack(spacing: 16) {
                        energyChart
                        overviewCard
                    }
                }

                insightCard

                WeeklyReviewSectionView(viewModel: reviewViewModel, onChanged: onReviewChanged)

                if viewModel.weights.count >= 2 {
                    weightChart
                }

                dailyData
            }
            .navigationTitle("趋势")
            .onAppear { viewModel.load(); reviewViewModel.load() }
        }
    }

    private var energyChart: some View {
        DietCard {
            VStack(alignment: .leading, spacing: 14) {
                DietSectionHeader(title: "每日摄入与目标", subtitle: dateRange)
                Chart {
                    ForEach(viewModel.days) { day in
                        BarMark(
                            x: .value("日期", day.date, unit: .day),
                            y: .value("摄入", day.intake.calories)
                        )
                        .foregroundStyle(barColor(for: day))
                        .cornerRadius(5)
                        .annotation(position: .top) {
                            if Calendar.current.isDateInToday(day.date) {
                                Text("今")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(DietTheme.Palette.primaryText)
                            }
                        }
                        .accessibilityLabel(day.date.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue("\(DietFormat.calories(day.intake.calories))，\(day.intake.isComplete ? "营养完整" : "部分未知")")

                        if let target = day.target {
                            LineMark(
                                x: .value("日期", day.date, unit: .day),
                                y: .value("目标", target.calories)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                            PointMark(
                                x: .value("日期", day.date, unit: .day),
                                y: .value("目标", target.calories)
                            )
                            .symbol(.diamond)
                            .symbolSize(42)
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                            .accessibilityLabel("\(day.date.formatted(date: .abbreviated, time: .omitted))目标")
                            .accessibilityValue(DietFormat.calories(target.calories))
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(DietTheme.Palette.border)
                        AxisValueLabel(format: .dateTime.weekday(.narrow).locale(Locale(identifier: "zh_CN")))
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                            .foregroundStyle(DietTheme.Palette.border)
                        AxisValueLabel()
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                    }
                }
                .frame(height: 230)
                .accessibilityLabel("七日热量摄入与目标图")
                .accessibilityHint(chartSummary)

                VStack(alignment: .leading, spacing: 5) {
                    Label("柱形为已确认摄入；菱形与虚线表示当天目标。", systemImage: "diamond")
                    Label("浅色柱为其他日期，深绿柱为今天；橙色表示部分营养未知。", systemImage: "info.circle")
                }
                .font(.caption)
                .foregroundStyle(DietTheme.Palette.inkSecondary)
                Text(visibleChartSummary)
                    .font(.caption)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func barColor(for day: DailyTrend) -> Color {
        if !day.intake.isComplete {
            return Calendar.current.isDateInToday(day.date) ? DietTheme.Palette.warning : DietTheme.Palette.warningSoft
        }
        return Calendar.current.isDateInToday(day.date) ? DietTheme.Palette.primary : DietTheme.Palette.primarySoft
    }

    private var overviewCard: some View {
        DietCard {
            VStack(alignment: .leading, spacing: 14) {
                DietSectionHeader(title: "七日概况")
                DietKeyValueRow(title: "记录天数", value: "\(viewModel.overview.recordedDays) / 7 天")
                DietKeyValueRow(
                    title: "平均热量",
                    value: viewModel.overview.averageCalories.map(DietFormat.calories) ?? "数据不足"
                )
                DietKeyValueRow(
                    title: "目标完成率",
                    value: viewModel.overview.targetCompletionRate?.formatted(.percent.precision(.fractionLength(0))) ?? "数据不足"
                )
                DietKeyValueRow(
                    title: "体重变化",
                    value: viewModel.overview.weightChangeKilograms.map {
                        "\($0 >= 0 ? "+" : "")\(DietFormat.number($0)) kg / \(viewModel.overview.weightSpanDays) 天"
                    } ?? "数据不足"
                )
                Text("完成率只统计营养完整、有目标且热量在目标 ±10% 内的已确认记录日。")
                    .font(.caption)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var insightCard: some View {
        DietCard {
            VStack(alignment: .leading, spacing: 11) {
                DietSectionHeader(title: "本周观察", subtitle: "基于现有数据")
                if viewModel.overview.hasSufficientData {
                    Label("本周共有 \(viewModel.overview.recordedDays) 个已确认记录日，记录完整度会直接影响可比性。", systemImage: "checklist")
                    if let average = viewModel.overview.averageCalories {
                        Label("有记录日的平均已确认摄入为 \(DietFormat.calories(average))；这不代表完整每日消耗。", systemImage: "chart.bar")
                    }
                    if let rate = viewModel.overview.targetCompletionRate {
                        Label("符合统计条件的记录日中，热量目标完成率为 \(rate.formatted(.percent.precision(.fractionLength(0))))。", systemImage: "target")
                    }
                } else {
                    Label("继续记录后再观察节奏；目前不对体重或摄入变化作因果解释。", systemImage: "calendar")
                }
            }
            .font(.footnote)
            .foregroundStyle(DietTheme.Palette.inkSecondary)
        }
    }

    private var weightChart: some View {
        DietCard {
            VStack(alignment: .leading, spacing: 12) {
                DietSectionHeader(title: "体重记录", subtitle: "仅展示已保存数据")
                Chart(viewModel.weights, id: \.id) { weight in
                    LineMark(x: .value("日期", weight.date), y: .value("体重", weight.weightKilograms))
                        .foregroundStyle(DietTheme.Palette.primary)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                    PointMark(x: .value("日期", weight.date), y: .value("体重", weight.weightKilograms))
                        .foregroundStyle(DietTheme.Palette.primary)
                        .accessibilityLabel(weight.date.formatted(date: .abbreviated, time: .omitted))
                        .accessibilityValue("\(DietFormat.number(weight.weightKilograms)) kg")
                }
                .frame(height: 180)
                .accessibilityLabel("七日体重记录图")
            }
        }
    }

    private var dailyData: some View {
        DietCard(padding: 12) {
            VStack(alignment: .leading, spacing: 4) {
                DietSectionHeader(title: "每日数据与阶段", subtitle: "最近七日")
                    .padding(.horizontal, 6)
                    .padding(.vertical, 6)
                ForEach(viewModel.days) { day in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(day.date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.body.weight(.medium))
                                if Calendar.current.isDateInToday(day.date) {
                                    DietStatusBadge(status: .confirmed, title: "今天")
                                }
                            }
                            Text(day.phaseType?.displayName ?? "无阶段")
                                .font(.caption)
                                .foregroundStyle(DietTheme.Palette.inkSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(DietFormat.calories(day.intake.calories))
                                .font(.body.weight(.medium))
                                .monospacedDigit()
                            Text(day.target.map { "目标 \(DietFormat.calories($0.calories))" } ?? "无目标")
                                .font(.caption)
                                .foregroundStyle(DietTheme.Palette.inkSecondary)
                        }
                        DietStatusBadge(
                            status: day.intake.isComplete ? .confirmed : .estimated,
                            title: day.hasConfirmedEntries ? (day.intake.isComplete ? "完整" : "部分未知") : "无确认记录"
                        )
                    }
                    .foregroundStyle(DietTheme.Palette.ink)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 9)
                    if day.id != viewModel.days.last?.id {
                        Divider().overlay(DietTheme.Palette.border)
                    }
                }
            }
        }
    }
}
