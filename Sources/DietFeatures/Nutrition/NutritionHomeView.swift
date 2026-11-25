import SwiftUI
import DietCore

@MainActor
public final class NutritionHomeViewModel: ObservableObject {
    @Published public private(set) var target: TargetResolution?
    @Published public private(set) var intake = NutritionTotals()
    @Published public private(set) var entries: [MealEntry] = []
    @Published public var errorMessage: String?

    private let profileStore: ProfileStoring
    private let targetService: DailyTargetService
    private let mealStore: MealEntryStoring
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
    }

    public func load() {
        do {
            guard let profile = try profileStore.fetchProfile() else {
                target = nil
                return
            }
            target = try targetService.target(on: Date(), profile: profile)
            entries = try mealStore.allEntries()
            intake = calculator.dailyNutrition(entries: entries, on: Date())
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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
}

public struct NutritionHomeView: View {
    @StateObject private var viewModel: NutritionHomeViewModel
    @StateObject private var recommendationViewModel: RecommendationViewModel

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

    public var body: some View {
        NavigationStack {
            List {
                if let error = viewModel.errorMessage {
                    Section("需要处理") { Text(error).foregroundStyle(.red) }
                }
                if let target = viewModel.target {
                    Section(target.requiresConfirmation ? "待确认的今日目标" : "今日目标") {
                        LabeledContent("目标热量", value: "\(target.dailyTarget.calories.formatted()) kcal")
                        LabeledContent("蛋白质／碳水／脂肪", value: "\(target.dailyTarget.proteinGrams.formatted())／\(target.dailyTarget.carbohydrateGrams.formatted())／\(target.dailyTarget.fatGrams.formatted()) g")
                        if let bmr = target.basalMetabolicRate {
                            LabeledContent("估算基础代谢", value: "\(bmr.formatted()) kcal")
                        }
                        ForEach(target.warnings, id: \.self) { warning in
                            Text(warning.displayName).font(.footnote).foregroundStyle(.orange)
                        }
                        if target.requiresConfirmation {
                            ForEach(target.assumptions, id: \.self) { assumption in
                                Text(assumption).font(.footnote).foregroundStyle(.secondary)
                            }
                            Button("确认采用此目标") {
                                do { try viewModel.acceptTarget(); reload() } catch { viewModel.errorMessage = error.localizedDescription }
                            }
                        }
                    }
                }
                if let assessment = viewModel.assessment {
                    Section("今日已确认摄入") {
                        LabeledContent("已知热量", value: "\(viewModel.intake.calories.formatted()) kcal")
                        LabeledContent("目标差额", value: "\(assessment.targetCalorieDifference.formatted()) kcal")
                        if let deficit = assessment.actualCalorieDeficit {
                            LabeledContent("实际热量缺口（估算）", value: "\(deficit.formatted()) kcal")
                        }
                        LabeledContent("蛋白质剩余", value: "\(assessment.remainingProteinGrams.formatted()) g")
                        if !viewModel.intake.isComplete {
                            Text("仍有食物缺少可计算信息，当前为部分合计而非完整摄入。")
                                .foregroundStyle(.orange)
                        }
                    }
                }
                RecommendationSectionView(viewModel: recommendationViewModel)
                Section("记录饮食") {
                    NavigationLink("文本分析") {
                        TextLoggingView(service: foodService) { reload() }
                    }
                    NavigationLink("图片识别") {
                        PhotoLoggingView(
                            photoService: PhotoLoggingService(imageStore: imageStore, foodLogging: foodService),
                            foodService: foodService
                        ) { reload() }
                    }
                }
                Section("最近记录") {
                    if viewModel.entries.isEmpty {
                        Text("尚无饮食记录。").foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.entries.prefix(8), id: \.id) { entry in
                        NavigationLink {
                            MealConfirmationView(entry: entry, service: foodService) { reload() }
                        } label: {
                            VStack(alignment: .leading) {
                                Text(entry.components.isEmpty ? "尚未添加食物" : entry.components.map(\.displayName).joined(separator: "、"))
                                Text("\(entry.consumedAt.formatted(date: .abbreviated, time: .shortened)) · \(entry.status.displayName)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("今日饮食")
            .onAppear { reload() }
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
