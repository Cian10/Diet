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

    public init(viewModel: RecommendationViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            DietGroupHeader("今日情境") {
                Toggle("接下来有训练", isOn: $viewModel.hasUpcomingWorkout)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
                    .tint(DietTheme.Palette.primary)
                    .font(.caption)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .fixedSize()
                    .onChange(of: viewModel.hasUpcomingWorkout) { _, _ in viewModel.load() }
            }

            if viewModel.recommendations.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.primaryText)
                        .accessibilityHidden(true)
                    Text("确认今日目标后将显示当前情境建议。")
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(viewModel.recommendations.enumerated()), id: \.element.id) { index, recommendation in
                        if index > 0 {
                            DietHairline()
                        }
                        recommendationBlock(recommendation)
                    }
                }
            }

            Text("内置通用参考值，不替代医疗意见。")
                .font(.caption)
                .foregroundStyle(DietTheme.Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func recommendationBlock(_ recommendation: Recommendation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(recommendation.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(DietTheme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                Button {
                    viewModel.dismiss(recommendation)
                } label: {
                    Text("忽略")
                        .font(.caption.weight(.medium))
                }
                .buttonStyle(.dietText)
                .accessibilityLabel("忽略建议：\(recommendation.title)")
            }

            Text(recommendation.reason)
                .font(.caption)
                .foregroundStyle(DietTheme.Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !recommendation.suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(recommendation.suggestions.enumerated()), id: \.element.id) { suggestionIndex, suggestion in
                        if suggestionIndex > 0 {
                            DietHairline()
                        }
                        suggestionRow(suggestion)
                    }
                }
            }
        }
    }

    private func suggestionRow(_ suggestion: FoodSuggestion) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.name)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(DietTheme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text(suggestion.portionDescription)
                    .font(.caption)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(macroSummary(for: suggestion))
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(DietTheme.Palette.inkSecondary)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(suggestionAccessibilityLabel(for: suggestion))
    }

    private func macroSummary(for suggestion: FoodSuggestion) -> String {
        let kcal = DietFormat.number(suggestion.expectedNutrition.calories, maximumFractionDigits: 0)
        let protein = DietFormat.number(suggestion.expectedNutrition.proteinGrams, maximumFractionDigits: 0)
        return "\(kcal) kcal / P \(protein)g"
    }

    private func suggestionAccessibilityLabel(for suggestion: FoodSuggestion) -> String {
        "\(suggestion.name)，\(suggestion.portionDescription)，约 \(DietFormat.calories(suggestion.expectedNutrition.calories))，蛋白质 \(DietFormat.grams(suggestion.expectedNutrition.proteinGrams))"
    }
}
