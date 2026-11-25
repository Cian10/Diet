import Testing
import Foundation
@testable import DietCore

@Suite("NutritionCalculator")
struct NutritionCalculatorTests {
    private let calculator = NutritionCalculator()

    @Test("Gram, serving and milliliter quantities scale independently")
    func quantityScaling() throws {
        let per100g = NutritionSnapshot(
            basisQuantity: 100,
            basisUnit: .grams,
            calories: 200,
            proteinGrams: 10,
            carbohydrateGrams: 20,
            fatGrams: 8,
            fiberGrams: 2,
            source: .userLabel
        )
        let grams = EntryComponent(
            displayName: "食物",
            originalQuantity: 1,
            originalUnit: "份",
            estimatedGrams: 150,
            nutritionSnapshot: per100g
        )
        let result = try calculator.componentNutrition(grams)
        #expect(result.calories == 300)
        #expect(result.proteinGrams == 15)
        #expect(result.fiberGrams == 3)

        let perServing = NutritionSnapshot(
            basisQuantity: 1,
            basisUnit: .serving,
            calories: 500,
            proteinGrams: 25,
            carbohydrateGrams: 50,
            fatGrams: 20,
            source: .modelEstimate
        )
        let halfServing = EntryComponent(
            displayName: "汉堡",
            originalQuantity: 0.5,
            originalUnit: "个",
            nutritionSnapshot: perServing
        )
        #expect(try calculator.componentNutrition(halfServing).calories == 250)

        let per100ml = NutritionSnapshot(
            basisQuantity: 100,
            basisUnit: .milliliters,
            calories: 40,
            proteinGrams: 0,
            carbohydrateGrams: 10,
            fatGrams: 0,
            source: .userLabel
        )
        let drink = EntryComponent(
            displayName: "饮料",
            originalQuantity: 250,
            originalUnit: "毫升",
            nutritionSnapshot: per100ml
        )
        #expect(try calculator.componentNutrition(drink).calories == 100)
    }

    @Test("Unknown components remain visible and drafts are excluded")
    func unknownAndDraftHandling() {
        let known = EntryComponent(
            displayName: "已知食物",
            originalQuantity: 1,
            originalUnit: "份",
            nutritionSnapshot: NutritionSnapshot(
                basisUnit: .serving,
                calories: 300,
                proteinGrams: 20,
                carbohydrateGrams: 30,
                fatGrams: 10,
                source: .userLabel
            )
        )
        let unknown = EntryComponent(displayName: "未知食物", originalQuantity: 1, originalUnit: "份")
        let date = Date()
        let confirmed = MealEntry(consumedAt: date, status: .confirmed, components: [known, unknown])
        let draft = MealEntry(consumedAt: date, status: .draft, components: [known])

        let result = calculator.dailyNutrition(entries: [confirmed, draft], on: date)
        #expect(result.calories == 300)
        #expect(!result.isComplete)
        #expect(result.unknownItemNames == ["未知食物"])
    }

    @Test("Target difference and actual deficit are distinct")
    func assessmentSeparatesMetrics() {
        let target = DailyTarget(date: Date(), calories: 2200, proteinGrams: 150, carbohydrateGrams: 200, fatGrams: 70)
        let intake = NutritionTotals(calories: 1800, proteinGrams: 120, carbohydrateGrams: 180, fatGrams: 60)
        let assessment = calculator.assess(intake: intake, target: target, estimatedExpenditure: 2500)
        #expect(assessment.targetCalorieDifference == 400)
        #expect(assessment.actualCalorieDeficit == 700)
        #expect(assessment.remainingProteinGrams == 30)
    }

    @Test("Label energy is preserved instead of overwritten by macro energy")
    func labelEnergyPreserved() throws {
        let snapshot = NutritionSnapshot(
            basisUnit: .serving,
            calories: 200,
            proteinGrams: 10,
            carbohydrateGrams: 10,
            fatGrams: 10,
            source: .userLabel
        )
        let component = EntryComponent(displayName: "标签食品", originalQuantity: 1, originalUnit: "份", nutritionSnapshot: snapshot)
        let result = try calculator.componentNutrition(component)
        #expect(result.calories == 200)
        #expect(calculator.energyFromMacros(protein: 10, carbohydrate: 10, fat: 10) == 170)
    }

    @Test("Invalid quantities fail explicitly")
    func invalidQuantity() {
        let snapshot = NutritionSnapshot(
            basisQuantity: 0,
            basisUnit: .grams,
            calories: 100,
            proteinGrams: 10,
            carbohydrateGrams: 10,
            fatGrams: 5,
            source: .modelEstimate
        )
        let component = EntryComponent(
            displayName: "异常食物",
            originalQuantity: 100,
            originalUnit: "克",
            nutritionSnapshot: snapshot
        )
        #expect(throws: NutritionCalculationError.invalidBasisQuantity) {
            try calculator.componentNutrition(component)
        }
    }
}
