import SwiftUI
import DietCore

@MainActor
public final class NutritionHomeViewModel: ObservableObject {
    @Published public private(set) var target: TargetResolution?
    @Published public private(set) var intake = NutritionTotals()
    @Published public private(set) var entries: [MealEntry] = []
    @Published public private(set) var weeklyTargetDays: Int?
    @Published public private(set) var weeklyEligibleDays = 0
    @Published public var errorMessage: String?

    private let profileStore: ProfileStoring
    private let targetService: DailyTargetService
    private let mealStore: MealEntryStoring
    private let trendsService: TrendsService
    private let calculator = NutritionCalculator()

    public init(
        profileStore: ProfileStoring,
        phaseStore: PhasePlanStoring,
        targetStore: DailyTargetStoring,
        mealStore: MealEntryStoring
    ) {
        self.profileStore = profileStore
        self.targetService = DailyTargetService(targetStore: targetStore, phaseStore: phaseStore)
        self.mealStore = mealStore
        self.trendsService = TrendsService(
            mealStore: mealStore,
            targetStore: targetStore,
            phaseStore: phaseStore,
            profileStore: profileStore
        )
    }

    public func load() {
        do {
            guard let profile = try profileStore.fetchProfile() else {
                target = nil
                entries = []
                intake = NutritionTotals()
                weeklyTargetDays = nil
                weeklyEligibleDays = 0
                return
            }
            target = try targetService.target(on: Date(), profile: profile)
            entries = try mealStore.allEntries()
            intake = calculator.dailyNutrition(entries: entries, on: Date())
            let days = try trendsService.dailyTrends()
            let eligible = days.filter(\.isEligibleForTargetCompletion)
            weeklyEligibleDays = eligible.count
            weeklyTargetDays = eligible.isEmpty ? nil : eligible.filter(\.meetsCalorieTarget).count
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public var todayEntries: [MealEntry] {
        entries
            .filter { Calendar.current.isDate($0.consumedAt, inSameDayAs: Date()) }
            .sorted { $0.consumedAt > $1.consumedAt }
    }

    public var assessment: NutritionAssessment? {
        guard let target, !target.requiresConfirmation else { return nil }
        return calculator.assess(
            intake: intake,
            target: target.dailyTarget,
            estimatedExpenditure: target.estimatedMaintenanceCalories
        )
    }

    public func acceptTarget() throws {
        guard let target else { return }
        try targetService.accept(target)
        load()
    }

    @discardableResult
    public func delete(_ entry: MealEntry, deletingImage: Bool, imageStore: ImageStoring) -> Bool {
        do {
            let path = entry.localImagePath
            try mealStore.deleteEntry(entry)
            if deletingImage, let path { try? imageStore.delete(relativePath: path) }
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

public struct NutritionHomeView: View {
    @StateObject private var viewModel: NutritionHomeViewModel
    @StateObject private var recommendationViewModel: RecommendationViewModel
    @State private var loggingRoute: DietLoggingRoute?
    @State private var focusedEntry: MealEntry?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let mealStore: MealEntryStoring
    private let llmProvider: LLMClientProviding
    private let imageStore: ImageStoring

    public init(
        profileStore: ProfileStoring,
        phaseStore: PhasePlanStoring,
        targetStore: DailyTargetStoring,
        mealStore: MealEntryStoring,
        llmProvider: LLMClientProviding,
        imageStore: ImageStoring
    ) {
        self.mealStore = mealStore
        self.llmProvider = llmProvider
        self.imageStore = imageStore
        _viewModel = StateObject(wrappedValue: NutritionHomeViewModel(
            profileStore: profileStore,
            phaseStore: phaseStore,
            targetStore: targetStore,
            mealStore: mealStore
        ))
        _recommendationViewModel = StateObject(wrappedValue: RecommendationViewModel(
            profileStore: profileStore,
            phaseStore: phaseStore,
            targetStore: targetStore,
            mealStore: mealStore
        ))
    }

    private var focus: TodayFocusPresentation {
        let todayEntries = viewModel.todayEntries
        let goalMet: Bool
        if let target = viewModel.target, !target.requiresConfirmation {
            let tolerance = max(target.dailyTarget.calories * 0.1, 1)
            goalMet = abs(target.dailyTarget.calories - viewModel.intake.calories) <= tolerance
                && viewModel.intake.isComplete
                && todayEntries.contains(where: \.isConfirmed)
        } else {
            goalMet = false
        }
        return TodayFocusPresentation(
            hasTarget: viewModel.target != nil,
            targetRequiresConfirmation: viewModel.target?.requiresConfirmation == true,
            hasPendingOrFailedMeal: todayEntries.contains { $0.status == .draft || $0.status == .failed },
            hasDinner: todayEntries.contains { $0.mealType == .dinner },
            isGoalMet: goalMet
        )
    }

    private var calorieProgress: Double? {
        guard let target = viewModel.target,
              !target.requiresConfirmation,
              target.dailyTarget.calories > 0 else { return nil }
        return viewModel.intake.calories / target.dailyTarget.calories
    }

    public var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                DietPage {
                    DietPageHeader(title: "今天", subtitle: "先完成最重要的一步，再查看今天的饮食概况。") {
                        HStack(spacing: 10) {
                            DietDateCapsule(date: Date())
                            DietLoggingMenu(
                                onText: { loggingRoute = .text },
                                onPhoto: { loggingRoute = .photo }
                            )
                        }
                    }

                    if let error = viewModel.errorMessage {
                        DietInlineNotice(.error, title: "需要处理", message: error)
                    }

                    DietFocusCard(
                        title: focus.title,
                        message: focus.message,
                        actionTitle: focus.actionTitle,
                        progress: calorieProgress,
                        progressCaption: calorieProgress == nil ? nil : "今日热量进度",
                        tone: focus.needsAttention ? .attention : .normal
                    ) {
                        performFocusAction(proxy: proxy)
                    }

                    if let target = viewModel.target, target.requiresConfirmation {
                        targetConfirmation(target)
                    }

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 180, maximum: .infinity), spacing: 12)],
                        spacing: 12
                    ) {
                        DietMetricCard(
                            label: "已摄入热量",
                            value: DietFormat.number(viewModel.intake.calories, maximumFractionDigits: 0),
                            unit: "kcal",
                            systemImage: "flame",
                            footnote: viewModel.target.map { "目标 \(DietFormat.calories($0.dailyTarget.calories))" }
                        )
                        DietMetricCard(
                            label: "蛋白质",
                            value: DietFormat.number(viewModel.intake.proteinGrams),
                            unit: "g",
                            systemImage: "bolt.heart",
                            footnote: viewModel.target.map { "目标 \(DietFormat.grams($0.dailyTarget.proteinGrams))" }
                        )
                        DietMetricCard(
                            label: "本周达标天数",
                            value: viewModel.weeklyTargetDays.map(String.init) ?? "—",
                            unit: viewModel.weeklyTargetDays == nil ? "暂无完整数据" : "/ \(viewModel.weeklyEligibleDays) 天",
                            systemImage: "checkmark.seal",
                            footnote: "按热量目标 ±10% 计算"
                        )
                    }

                    if !viewModel.intake.isComplete {
                        let names = viewModel.intake.unknownItemNames.joined(separator: "、")
                        DietInlineNotice(
                            .warning,
                            title: "当前为部分合计",
                            message: names.isEmpty
                                ? "仍有食物缺少可计算信息，未知项目没有按零摄入处理。"
                                : "无法计算：\(names)。这些项目没有按零摄入处理。"
                        )
                    }

                    if let assessment = viewModel.assessment {
                        DietCard {
                            VStack(spacing: 12) {
                                DietSectionHeader(title: "目标参考", subtitle: "仅基于已确认记录")
                                DietKeyValueRow(
                                    title: "目标热量差额",
                                    value: DietFormat.calories(assessment.targetCalorieDifference)
                                )
                                DietKeyValueRow(
                                    title: "蛋白质剩余",
                                    value: DietFormat.grams(assessment.remainingProteinGrams)
                                )
                                if let deficit = assessment.actualCalorieDeficit {
                                    DietKeyValueRow(
                                        title: "实际热量缺口（估算）",
                                        value: DietFormat.calories(deficit)
                                    )
                                }
                            }
                        }
                    }

                    RecommendationSectionView(viewModel: recommendationViewModel)

                    VStack(alignment: .leading, spacing: 12) {
                        DietSectionHeader(
                            title: "今天吃过",
                            subtitle: viewModel.todayEntries.isEmpty ? nil : "\(viewModel.todayEntries.count) 条记录"
                        )
                        DietCard(padding: 12) {
                            if viewModel.todayEntries.isEmpty {
                                DietEmptyState(
                                    title: "今天还没有记录",
                                    message: "从下一餐开始，确认后的食物会显示在这里。"
                                ) {
                                    Button("记录第一餐") { loggingRoute = .text }
                                        .buttonStyle(.dietSecondary)
                                }
                            } else {
                                ForEach(Array(viewModel.todayEntries.prefix(8).enumerated()), id: \.element.id) { index, entry in
                                    NavigationLink {
                                        MealDetailView(
                                            entry: entry,
                                            service: foodService,
                                            imageStore: imageStore,
                                            onChanged: { reload() },
                                            onDelete: { deletingImage in
                                                viewModel.delete(entry, deletingImage: deletingImage, imageStore: imageStore)
                                            }
                                        )
                                    } label: {
                                        DietMealRow(entry: entry)
                                    }
                                    .buttonStyle(.plain)
                                    if index < min(viewModel.todayEntries.count, 8) - 1 {
                                        Divider().overlay(DietTheme.Palette.border)
                                    }
                                }
                            }
                        }
                    }
                    .id("today-records")
                }
            }
            .navigationTitle("今天")
            .onAppear { reload() }
            .navigationDestination(isPresented: Binding(
                get: { focusedEntry != nil },
                set: { if !$0 { focusedEntry = nil } }
            )) {
                if let focusedEntry {
                    MealConfirmationView(entry: focusedEntry, service: foodService, imageStore: imageStore) {
                        self.focusedEntry = nil
                        reload()
                    }
                }
            }
            .sheet(item: $loggingRoute) { route in
                NavigationStack {
                    loggingDestination(route)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") { loggingRoute = nil }
                            }
                        }
                }
                .frame(minWidth: 620, idealWidth: 680, minHeight: 640, idealHeight: 700)
            }
        }
    }

    @ViewBuilder
    private func targetConfirmation(_ target: TargetResolution) -> some View {
        DietCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    DietSectionHeader(title: "待确认的今日目标")
                    DietStatusBadge(status: .pending)
                }
                DietKeyValueRow(title: "目标热量", value: DietFormat.calories(target.dailyTarget.calories))
                DietKeyValueRow(
                    title: "蛋白质／碳水／脂肪",
                    value: "\(DietFormat.number(target.dailyTarget.proteinGrams))／\(DietFormat.number(target.dailyTarget.carbohydrateGrams))／\(DietFormat.number(target.dailyTarget.fatGrams)) g"
                )
                if let bmr = target.basalMetabolicRate {
                    DietKeyValueRow(title: "估算基础代谢", value: DietFormat.calories(bmr))
                }
                ForEach(target.warnings, id: \.self) { warning in
                    DietInlineNotice(.warning, message: warning.displayName)
                }
                if !target.assumptions.isEmpty {
                    Text(target.assumptions.joined(separator: "；"))
                        .font(.footnote)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func performFocusAction(proxy: ScrollViewProxy) {
        switch focus.kind {
        case .confirmTarget:
            do {
                try viewModel.acceptTarget()
                reload()
            } catch {
                viewModel.errorMessage = error.localizedDescription
            }
        case .reviewMeal:
            focusedEntry = viewModel.todayEntries.first { $0.status == .draft || $0.status == .failed }
        case .startLogging, .recordDinner:
            loggingRoute = .text
        case .completed, .maintain:
            if reduceMotion {
                proxy.scrollTo("today-records", anchor: .top)
            } else {
                withAnimation(.easeOut(duration: 0.18)) {
                    proxy.scrollTo("today-records", anchor: .top)
                }
            }
        }
    }

    @ViewBuilder
    private func loggingDestination(_ route: DietLoggingRoute) -> some View {
        switch route {
        case .text:
            TextLoggingView(service: foodService, onSwitchToPhoto: { loggingRoute = .photo }) {
                loggingRoute = nil
                reload()
            }
        case .photo:
            PhotoLoggingView(
                photoService: PhotoLoggingService(imageStore: imageStore, foodLogging: foodService),
                foodService: foodService,
                imageStore: imageStore,
                onSwitchToText: { loggingRoute = .text }
            ) {
                loggingRoute = nil
                reload()
            }
        }
    }

    private var foodService: FoodLoggingService {
        FoodLoggingService(store: mealStore, clientProvider: llmProvider)
    }

    private func reload() {
        viewModel.load()
        recommendationViewModel.load()
    }
}

public extension MealEntryStatus {
    var displayName: String {
        switch self {
        case .draft: "待确认"
        case .confirmed: "已确认"
        case .failed: "分析失败"
        }
    }
}
