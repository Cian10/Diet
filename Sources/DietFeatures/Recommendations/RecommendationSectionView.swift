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
        DietCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    DietSectionHeader(title: "今日建议", subtitle: "由本地规则生成")
                    Toggle("接下来有训练", isOn: $viewModel.hasUpcomingWorkout)
                        .toggleStyle(.switch)
                        .tint(DietTheme.Palette.primary)
                        .font(.footnote)
                        .onChange(of: viewModel.hasUpcomingWorkout) { _, _ in viewModel.load() }
                }

                if viewModel.recommendations.isEmpty {
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle")
                            .foregroundStyle(DietTheme.Palette.primaryText)
                            .accessibilityHidden(true)
                        Text("确认今日目标后，这里会显示适合当前记录的建议。")
                            .font(.footnote)
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                    }
                    .padding(.vertical, 4)
                }

                ForEach(Array(viewModel.recommendations.enumerated()), id: \.element.id) { index, recommendation in
                    if index > 0 { Divider().overlay(DietTheme.Palette.border) }
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top) {
                            Text(recommendation.title)
                                .font(.headline)
                                .foregroundStyle(DietTheme.Palette.ink)
                            Spacer()
                            Button("忽略") { viewModel.dismiss(recommendation) }
                                .buttonStyle(.dietText)
                                .font(.caption)
                        }
                        Text(recommendation.reason)
                            .font(.footnote)
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(recommendation.suggestions) { suggestion in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(suggestion.name) · \(suggestion.portionDescription)")
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(DietTheme.Palette.ink)
                                Text("预计 \(DietFormat.calories(suggestion.expectedNutrition.calories))，蛋白质 \(DietFormat.grams(suggestion.expectedNutrition.proteinGrams))，碳水 \(DietFormat.grams(suggestion.expectedNutrition.carbohydrateGrams))")
                                    .font(.caption)
                                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(DietTheme.Palette.surfaceMuted)
                            }
                        }
                    }
                }

                Text("食物营养使用 App 内置通用参考值；建议不会替代医疗意见。")
                    .font(.caption)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
            }
        }
    }
}
