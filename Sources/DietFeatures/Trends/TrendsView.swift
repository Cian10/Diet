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

    public var body: some View {
        NavigationStack {
            List {
                WeeklyReviewSectionView(viewModel: reviewViewModel, onChanged: onReviewChanged)
                Section("七日概览") {
                    LabeledContent("有记录天数", value: "\(viewModel.overview.recordedDays) / 7")
                    LabeledContent("平均热量", value: viewModel.overview.averageCalories.map { "\($0.formatted()) kcal" } ?? "数据不足")
                    LabeledContent("热量目标完成率", value: viewModel.overview.targetCompletionRate.map { "\($0.formatted(.percent.precision(.fractionLength(0))))" } ?? "数据不足")
                    if let change = viewModel.overview.weightChangeKilograms {
                        LabeledContent("体重变化", value: "\(change >= 0 ? "+" : "")\(change.formatted()) kg / \(viewModel.overview.weightSpanDays) 天")
                    }
                    if !viewModel.overview.hasSufficientData {
                        Text("至少需要 3 个有记录日才展示趋势性描述；当前仅列出原始数据。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Section("热量与目标") {
                    Chart {
                        ForEach(viewModel.days) { day in
                            BarMark(
                                x: .value("日期", day.date),
                                y: .value("摄入", day.intake.calories)
                            )
                            .foregroundStyle(day.intake.isComplete ? Color.accentColor : Color.orange)
                            if let target = day.target {
                                PointMark(
                                    x: .value("日期", day.date),
                                    y: .value("目标", target.calories)
                                )
                                .symbol(.diamond)
                                .foregroundStyle(.green)
                            }
                        }
                    }
                    .frame(height: 220)
                    Text("柱形为已确认摄入，菱形为当天目标；橙色表示部分营养未知。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if viewModel.weights.count >= 2 {
                    Section("体重") {
                        Chart(viewModel.weights, id: \.id) { weight in
                            LineMark(x: .value("日期", weight.date), y: .value("体重", weight.weightKilograms))
                            PointMark(x: .value("日期", weight.date), y: .value("体重", weight.weightKilograms))
                        }
                        .frame(height: 180)
                    }
                }
                Section("每日数据与阶段") {
                    ForEach(viewModel.days) { day in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(day.date.formatted(date: .abbreviated, time: .omitted))
                            Text("\(day.intake.calories.formatted()) kcal · \(day.phaseType?.displayName ?? "无阶段")")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("完成率按热量在目标 ±10% 内计算，且只统计营养完整、有目标的已确认记录日。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("趋势")
            .onAppear { viewModel.load(); reviewViewModel.load() }
        }
    }
}
