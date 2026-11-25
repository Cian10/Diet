import Testing
import Foundation
@testable import DietCore

@Suite("Model invariants")
struct ModelInvariantTests {
    @Test("Entry uses independent nutrition snapshot")
    func entryUsesIndependentNutritionSnapshot() {
        let source = NutritionSnapshot(
            calories: 250,
            proteinGrams: 20,
            carbohydrateGrams: 20,
            fatGrams: 8,
            fiberGrams: nil,
            source: .verified
        )
        let entrySnapshot = source.independentCopy()
        let component = EntryComponent(
            displayName: "示例食物",
            originalQuantity: 1,
            originalUnit: "份",
            nutritionSnapshot: entrySnapshot
        )

        source.calories = 999
        source.proteinGrams = 1

        #expect(component.nutritionSnapshot?.calories == 250)
        #expect(component.nutritionSnapshot?.proteinGrams == 20)
        #expect(component.nutritionSnapshot?.fiberGrams == nil)
        #expect(source.id != entrySnapshot.id)
    }

    @Test("Only confirmed meal is confirmed")
    func onlyConfirmedMealIsConfirmed() {
        let meal = MealEntry(consumedAt: Date())
        #expect(!meal.isConfirmed)
        meal.status = .failed
        #expect(!meal.isConfirmed)
        meal.status = .confirmed
        #expect(meal.isConfirmed)
    }

    @Test("Single-day target is distinct from phase")
    func singleDayTargetIsDistinctFromPhase() {
        let target = DailyTarget(
            date: Date(),
            calories: 2100,
            proteinGrams: 130,
            carbohydrateGrams: 200,
            fatGrams: 70,
            phasePlanVersion: 3,
            isSingleDayOverride: true
        )
        #expect(target.isSingleDayOverride)
        #expect(target.phasePlanVersion == 3)
    }
}
