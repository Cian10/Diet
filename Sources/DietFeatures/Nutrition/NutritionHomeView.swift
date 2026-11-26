import SwiftUI
import DietCore

public enum NutritionHomeTargetUpdateError: LocalizedError, Equatable {
    case missingProfile

    public var errorDescription: String? {
        switch self {
        case .missingProfile: "尚未创建个人档案，暂时无法保存今日目标。"
        }
    }
}

@MainActor
public final class NutritionHomeViewModel: ObservableObject {
    @Published public private(set) var target: TargetResolution?
    @Published public private(set) var intake = NutritionTotals()
    @Published public private(set) var entries: [MealEntry] = []
    @Published public private(set) var weeklyDays: [DailyTrend] = []
    @Published public private(set) var weeklyTargetDays: Int?
    @Published public private(set) var weeklyEligibleDays = 0
    @Published public private(set) var latestWeight: WeightRecord?
    @Published public private(set) var weightDeltaText: String?
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
                weeklyDays = []
                weeklyTargetDays = nil
                weeklyEligibleDays = 0
                latestWeight = nil
                weightDeltaText = nil
                errorMessage = nil
                return
            }
            target = try targetService.reconcile(on: Date(), profile: profile).today
            try refreshHomeData()
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
        guard let target else { return nil }
        return calculator.assess(
            intake: intake,
            target: target.dailyTarget,
            estimatedExpenditure: target.estimatedMaintenanceCalories
        )
    }

    public func updateTodayTarget(_ manualTarget: ManualNutritionTarget) throws {
        do {
            guard let profile = try profileStore.fetchProfile() else {
                throw NutritionHomeTargetUpdateError.missingProfile
            }
            target = try targetService.updateTodayTarget(manualTarget, profile: profile)
            try refreshHomeData()
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
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

    private func refreshHomeData() throws {
        entries = try mealStore.allEntries()
        intake = calculator.dailyNutrition(entries: entries, on: Date())
        let review = try trendsService.weeklyReview()
        let days = review.days
        weeklyDays = days
        let eligible = days.filter(\.isEligibleForTargetCompletion)
        weeklyEligibleDays = eligible.count
        weeklyTargetDays = eligible.isEmpty ? nil : eligible.filter(\.meetsCalorieTarget).count
        if let delta = review.overview.weightChangeKilograms {
            let prefix = delta >= 0 ? "+" : ""
            weightDeltaText = "\(prefix)\(DietFormat.number(delta)) kg / \(review.overview.weightSpanDays) 天"
        } else {
            weightDeltaText = nil
        }
        latestWeight = try profileStore.allWeightRecords().max {
            if $0.date != $1.date {
                return $0.date < $1.date
            }
            return $0.createdAt < $1.createdAt
        }
    }
}

private enum HomeLoggingSheet: Identifiable {
    case text(initialText: String = "", mealType: MealType? = nil, autoAnalyze: Bool = false)
    case photo
    case manual(MealEntry)

    var id: String {
        switch self {
        case .text(let initialText, let mealType, let autoAnalyze):
            return "text-\(initialText)-\(mealType?.rawValue ?? "auto")-\(autoAnalyze)"
        case .photo:
            return "photo"
        case .manual(let entry):
            return "manual-\(entry.id.uuidString)"
        }
    }
}

public struct NutritionHomeView: View {
    @StateObject private var viewModel: NutritionHomeViewModel
    @StateObject private var recommendationViewModel: RecommendationViewModel
    @State private var activeSheet: HomeLoggingSheet?
    @State private var focusedEntry: MealEntry?
    @State private var isEditingTarget = false
    @State private var quickInputText = ""

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
        if let target = viewModel.target {
            let tolerance = max(target.dailyTarget.calories * 0.1, 1)
            goalMet = abs(target.dailyTarget.calories - viewModel.intake.calories) <= tolerance
                && viewModel.intake.isComplete
                && todayEntries.contains(where: \.isConfirmed)
        } else {
            goalMet = false
        }
        let hour = Calendar.current.component(.hour, from: Date())
        return TodayFocusPresentation(
            hasTarget: viewModel.target != nil,
            hasPendingOrFailedMeal: todayEntries.contains { $0.status == .draft || $0.status == .failed },
            recordedMealTypes: Set(todayEntries.map(\.mealType)),
            hour: hour,
            isGoalMet: goalMet
        )
    }

    private var suggestedMealType: MealType {
        let hour = Calendar.current.component(.hour, from: Date())
        return TodayFocusPresentation.suggestedMealType(
            for: hour,
            recorded: Set(viewModel.todayEntries.map(\.mealType))
        )
    }

    private var firstPendingEntry: MealEntry? {
        viewModel.todayEntries.first { $0.status == .draft || $0.status == .failed }
    }

    public var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                DietWorkbenchPage {
                    if proxy.size.width >= DietTheme.Metrics.twoColumnBreakpoint {
                        wideWorkbench
                    } else {
                        narrowWorkbench
                    }
                }
            }
            .navigationTitle("今天")
            .toolbar {
                #if os(macOS)
                ToolbarItemGroup(placement: .primaryAction) {
                    Text(DietFormat.day(Date()))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .padding(.horizontal, 6)
                        .accessibilityLabel("日期：\(DietFormat.day(Date()))")
                    addMealMenu
                }
                #else
                ToolbarItem(placement: .topBarLeading) {
                    Text(DietFormat.day(Date()))
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .accessibilityLabel("日期：\(DietFormat.day(Date()))")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    addMealMenu
                }
                #endif
            }
            .background {
                Button("记一餐") {
                    activeSheet = .text()
                }
                .keyboardShortcut("n", modifiers: .command)
                .frame(width: 0, height: 0)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
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
            .sheet(item: $activeSheet, onDismiss: { reload() }) { sheet in
                NavigationStack {
                    loggingDestination(sheet)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") { activeSheet = nil }
                            }
                        }
                }
                #if os(macOS)
                .frame(minWidth: 620, idealWidth: 680, minHeight: 640, idealHeight: 700)
                #endif
            }
            .sheet(isPresented: $isEditingTarget) {
                if let target = viewModel.target {
                    TodayTargetEditView(initialTarget: target.dailyTarget) { manualTarget in
                        try viewModel.updateTodayTarget(manualTarget)
                        recommendationViewModel.load()
                    }
                }
            }
        }
    }

    private var wideWorkbench: some View {
        HStack(alignment: .top, spacing: DietTheme.Metrics.sectionSpacing) {
            VStack(alignment: .leading, spacing: DietTheme.Metrics.sectionSpacing) {
                if let error = viewModel.errorMessage {
                    errorBanner(error)
                }

                macroDashboardCard
                mealTimelineSection
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: DietTheme.Metrics.sectionSpacing) {
                if focus.needsAttention {
                    attentionBanner
                }

                RecommendationSectionView(viewModel: recommendationViewModel)
                weeklyRhythmPanel
            }
            .frame(
                minWidth: DietTheme.Metrics.railMinWidth,
                idealWidth: 320,
                maxWidth: DietTheme.Metrics.railMaxWidth,
                alignment: .leading
            )
        }
    }

    private var narrowWorkbench: some View {
        VStack(alignment: .leading, spacing: DietTheme.Metrics.sectionSpacing) {
            if let error = viewModel.errorMessage {
                errorBanner(error)
            }

            macroDashboardCard

            if focus.needsAttention {
                attentionBanner
            }

            mealTimelineSection
            RecommendationSectionView(viewModel: recommendationViewModel)
            weeklyRhythmPanel
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var macroDashboardCard: some View {
        TodayMacroDashboardCard(
            target: viewModel.target,
            intake: viewModel.intake,
            assessment: viewModel.assessment,
            onEditTarget: { isEditingTarget = true },
            onTapIncomplete: { openIncompleteEntry() }
        )
    }

    private var mealTimelineSection: some View {
        TodayMealTimelineSection(
            entries: viewModel.todayEntries,
            suggestedMealType: suggestedMealType,
            quickInputText: $quickInputText,
            onQuickAnalyze: { text, mealType in
                activeSheet = .text(initialText: text, mealType: mealType, autoAnalyze: true)
            },
            onOpenPhoto: {
                activeSheet = .photo
            },
            onOpenManual: { mealType in
                openManualLogging(mealType: mealType)
            }
        ) { entry in
            MealDetailView(
                entry: entry,
                service: foodService,
                imageStore: imageStore,
                onChanged: { reload() },
                onDelete: { deletingImage in
                    let deleted = viewModel.delete(entry, deletingImage: deletingImage, imageStore: imageStore)
                    if deleted {
                        recommendationViewModel.load()
                    }
                    return deleted
                }
            )
        }
    }

    private var weeklyRhythmPanel: some View {
        TodayWeeklyRhythmPanel(
            days: viewModel.weeklyDays,
            eligibleDays: viewModel.weeklyEligibleDays,
            metDays: viewModel.weeklyTargetDays,
            latestWeight: viewModel.latestWeight,
            weightDeltaText: viewModel.weightDeltaText,
            onJumpToTrends: nil
        )
    }

    private var addMealMenu: some View {
        Menu {
            Button {
                activeSheet = .text()
            } label: {
                Label("文字记录", systemImage: "text.quote")
            }

            Button {
                activeSheet = .photo
            } label: {
                Label("图片识别", systemImage: "photo")
            }

            Button {
                openManualLogging(mealType: suggestedMealType)
            } label: {
                Label("手动记录", systemImage: "square.and.pencil")
            }
        } label: {
            Label("记一餐", systemImage: "plus")
                .labelStyle(.titleAndIcon)
        }
        .accessibilityLabel("记一餐")
        .accessibilityHint("选择文字记录、图片识别或手动记录，快捷键 Command 加 N")
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundStyle(DietTheme.Palette.danger)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("需要处理")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DietTheme.Palette.ink)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(DietTheme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DietTheme.Metrics.cardRadius, style: .continuous)
                .fill(DietTheme.Palette.dangerSoft)
                .overlay {
                    RoundedRectangle(cornerRadius: DietTheme.Metrics.cardRadius, style: .continuous)
                        .stroke(DietTheme.Palette.danger.opacity(0.35), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
    }

    private var attentionBanner: some View {
        Button {
            if let pending = firstPendingEntry {
                focusedEntry = pending
            }
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checklist")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DietTheme.Palette.warning)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(focus.title)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(DietTheme.Palette.ink)
                    Text(focus.message)
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(focus.actionTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(DietTheme.Palette.primaryText)
                    .fixedSize()
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: DietTheme.Metrics.cardRadius, style: .continuous)
                    .fill(DietTheme.Palette.warningSoft)
                    .overlay {
                        RoundedRectangle(cornerRadius: DietTheme.Metrics.cardRadius, style: .continuous)
                            .stroke(DietTheme.Palette.warning.opacity(0.3), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(focus.title)，\(focus.message)")
        .accessibilityHint("点击\(focus.actionTitle)")
    }

    private func openIncompleteEntry() {
        let calculator = NutritionCalculator()
        let candidate = viewModel.todayEntries.first {
            $0.isConfirmed && !calculator.mealNutrition($0).isComplete
        } ?? viewModel.todayEntries.first {
            !calculator.mealNutrition($0).isComplete
        } ?? firstPendingEntry
        if let candidate {
            focusedEntry = candidate
        } else {
            activeSheet = .text(mealType: suggestedMealType)
        }
    }

    private func openManualLogging(mealType: MealType) {
        do {
            let entry = try foodService.createManualEntry(consumedAt: Date(), mealType: mealType)
            activeSheet = .manual(entry)
        } catch {
            viewModel.errorMessage = error.localizedDescription
        }
    }

    @ViewBuilder
    private func loggingDestination(_ sheet: HomeLoggingSheet) -> some View {
        switch sheet {
        case .text(let initialText, let mealType, let autoAnalyze):
            TextLoggingView(
                service: foodService,
                initialText: initialText,
                initialMealType: mealType,
                initialDate: Date(),
                autoAnalyzeOnAppear: autoAnalyze,
                onSwitchToPhoto: { activeSheet = .photo }
            ) {
                if autoAnalyze {
                    quickInputText = ""
                }
                activeSheet = nil
                reload()
            }
        case .photo:
            PhotoLoggingView(
                photoService: PhotoLoggingService(imageStore: imageStore, foodLogging: foodService),
                foodService: foodService,
                imageStore: imageStore,
                onSwitchToText: { activeSheet = .text() }
            ) {
                activeSheet = nil
                reload()
            }
        case .manual(let entry):
            MealConfirmationView(entry: entry, service: foodService, imageStore: imageStore) {
                activeSheet = nil
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
