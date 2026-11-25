import SwiftUI
import DietCore

@MainActor
public final class RecommendationViewModel: ObservableObject {
    @Published public private(set) var recommendations: [Recommendation] = []
    @Published public var hasUpcomingWorkout = false
    @Published public private(set) var dismissed: Set<String> = []

    private let profileStore: ProfileStoring
    private let phaseStore: PhasePlanStoring
    private let targetStore: DailyTargetStoring
    private let mealStore: MealEntryStoring
    private let engine = RecommendationEngine()

    public init(profileStore: ProfileStoring, phaseStore: PhasePlanStoring, targetStore: DailyTargetStoring, mealStore: MealEntryStoring) {
        self.profileStore = profileStore
        self.phaseStore = phaseStore
        self.targetStore = targetStore
        self.mealStore = mealStore
    }

    public func load() {
        do {
            guard let profile = try profileStore.fetchProfile(),
                  let target = try targetStore.target(on: Date()),
                  let phase = try phaseStore.allPlans().first(where: { $0.contains(Date()) }) else {
                recommendations = []
                return
            }
            let entries = try mealStore.allEntries()
            let intake = NutritionCalculator().dailyNutrition(entries: entries, on: Date())
            let context = RecommendationContext(
                intake: intake,
                target: target,
                phaseType: phase.phaseType,
                profile: profile,
                hasUpcomingWorkout: hasUpcomingWorkout
            )
            recommendations = engine.recommendations(for: context).filter { !dismissed.contains($0.id) }
        } catch {
            recommendations = []
        }
    }

    public func dismiss(_ recommendation: Recommendation) {
        dismissed.insert(recommendation.id)
        recommendations.removeAll { $0.id == recommendation.id }
    }
}

public struct RecommendationSectionView: View {
    @ObservedObject var viewModel: RecommendationViewModel

    public var body: some View {
        Section("今日建议") {
            Toggle("接下来有训练", isOn: $viewModel.hasUpcomingWorkout)
                .onChange(of: viewModel.hasUpcomingWorkout) { _, _ in viewModel.load() }
            if viewModel.recommendations.isEmpty {
                Text("确认今日目标后，这里会显示本地规则建议。").foregroundStyle(.secondary)
            }
            ForEach(viewModel.recommendations) { recommendation in
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(recommendation.title).font(.headline)
                        Spacer()
                        Button("忽略") { viewModel.dismiss(recommendation) }
                            .font(.caption)
                    }
                    Text(recommendation.reason).font(.subheadline).foregroundStyle(.secondary)
                    ForEach(recommendation.suggestions) { suggestion in
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(suggestion.name) · \(suggestion.portionDescription)")
                            Text("预计 \(suggestion.expectedNutrition.calories.formatted()) kcal，蛋白质 \(suggestion.expectedNutrition.proteinGrams.formatted()) g，碳水 \(suggestion.expectedNutrition.carbohydrateGrams.formatted()) g")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Text("食物营养使用 App 内置通用参考值；建议不会替代医疗意见。")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }
}
