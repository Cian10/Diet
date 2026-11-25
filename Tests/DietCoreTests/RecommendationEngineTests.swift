import Testing
import Foundation
@testable import DietCore

@Suite("RecommendationEngine")
struct RecommendationEngineTests {
    @Test("Allergies and vegetarian preference are hard filters")
    func preferenceFiltering() {
        let chicken = ReferenceFood(
            name: "鸡胸肉",
            isPlantBased: false,
            tags: [.highProtein],
            component: component(name: "鸡胸肉", calories: 165, protein: 31)
        )
        let peanut = ReferenceFood(
            name: "花生酱",
            allergens: ["花生"],
            isPlantBased: true,
            tags: [.highProtein],
            component: component(name: "花生酱", calories: 200, protein: 8)
        )
        let tofu = ReferenceFood(
            name: "豆腐",
            isPlantBased: true,
            tags: [.highProtein],
            component: component(name: "豆腐", calories: 120, protein: 12)
        )
        let profile = UserProfile(dietaryPreferences: ["素食"], allergies: ["花生"])
        let engine = RecommendationEngine(foods: [chicken, peanut, tofu])
        let result = engine.recommendations(for: context(profile: profile))
        let names = result.flatMap(\.suggestions).map(\.name)
        #expect(names == ["豆腐"])
    }

    @Test("Suggested nutrition is computed locally and repeated calls do not shrink portions")
    func nutritionAndRepeatability() {
        let engine = RecommendationEngine()
        let first = engine.recommendations(for: context())
        let second = engine.recommendations(for: context())
        let firstSuggestion = first.flatMap(\.suggestions).first
        let secondSuggestion = second.flatMap(\.suggestions).first
        #expect(firstSuggestion?.portionDescription == secondSuggestion?.portionDescription)
        #expect(firstSuggestion?.expectedNutrition.calories == secondSuggestion?.expectedNutrition.calories)
        #expect((firstSuggestion?.expectedNutrition.calories ?? 0) > 0)
        #expect((firstSuggestion?.expectedNutrition.proteinGrams ?? 0) > 0)
    }

    @Test("Exceeded calories produce neutral guidance without food suggestions")
    func exceededCalories() {
        let target = DailyTarget(date: Date(), calories: 1800, proteinGrams: 100, carbohydrateGrams: 150, fatGrams: 60)
        let intake = NutritionTotals(calories: 2000, proteinGrams: 80, carbohydrateGrams: 150, fatGrams: 60)
        let result = RecommendationEngine().recommendations(for: RecommendationContext(
            intake: intake,
            target: target,
            phaseType: .cutting,
            profile: UserProfile(),
            hasUpcomingWorkout: false
        ))
        #expect(result.first?.kind == .neutral)
        #expect(result.first?.suggestions.isEmpty == true)
        #expect(result.first?.reason.contains("无需禁食") == true)
    }

    @Test("Incomplete records are resolved before food recommendations")
    func incompleteRecord() {
        let intake = NutritionTotals(calories: 500, isComplete: false, unknownItemNames: ["未知菜"])
        var input = context()
        input = RecommendationContext(
            intake: intake,
            target: input.target,
            phaseType: input.phaseType,
            profile: input.profile,
            hasUpcomingWorkout: false
        )
        let result = RecommendationEngine().recommendations(for: input)
        #expect(result.first?.kind == .incompleteRecord)
        #expect(result.first?.suggestions.isEmpty == true)
    }

    @Test("Upcoming workout enables carbohydrate recommendation")
    func workoutCarbohydrate() {
        let target = DailyTarget(date: Date(), calories: 2000, proteinGrams: 100, carbohydrateGrams: 300, fatGrams: 50)
        let intake = NutritionTotals(calories: 1500, proteinGrams: 100, carbohydrateGrams: 100, fatGrams: 50)
        let result = RecommendationEngine().recommendations(for: RecommendationContext(
            intake: intake,
            target: target,
            phaseType: .maintenance,
            profile: UserProfile(),
            hasUpcomingWorkout: true
        ))
        #expect(result.contains { $0.kind == .carbohydrate })
    }

    private func context(profile: UserProfile = UserProfile()) -> RecommendationContext {
        RecommendationContext(
            intake: NutritionTotals(calories: 1000, proteinGrams: 50, carbohydrateGrams: 100, fatGrams: 40),
            target: DailyTarget(date: Date(), calories: 2000, proteinGrams: 150, carbohydrateGrams: 200, fatGrams: 60),
            phaseType: .maintenance,
            profile: profile,
            hasUpcomingWorkout: false
        )
    }

    private func component(name: String, calories: Double, protein: Double) -> EntryComponent {
        EntryComponent(
            displayName: name,
            originalQuantity: 100,
            originalUnit: "克",
            estimatedGrams: 100,
            nutritionSnapshot: NutritionSnapshot(
                basisQuantity: 100,
                basisUnit: .grams,
                calories: calories,
                proteinGrams: protein,
                carbohydrateGrams: 5,
                fatGrams: 3,
                source: .genericReference
            )
        )
    }
}
