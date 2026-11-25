import Testing
import Foundation
@testable import DietFeatures
import DietCore

@Suite("Meal confirmation editing")
@MainActor
final class MealConfirmationViewModelTests {
    private let store = InMemoryMealEntryStore()
    private let service: FoodLoggingService

    init() {
        service = FoodLoggingService(store: store, clientProvider: UnusedLLMProvider())
    }

    @Test("Quantity edits recalculate without changing model nutrition source")
    func quantityEdit() throws {
        let entry = try makeEntry()
        let original = try #require(entry.components.first)
        let viewModel = MealConfirmationViewModel(entry: entry, service: service)
        viewModel.components[0].quantityText = "0.5"

        try viewModel.confirm()

        #expect(entry.status == .confirmed)
        #expect(NutritionCalculator().mealNutrition(entry).calories == 250)
        #expect(entry.components.first?.nutritionSnapshot?.source == .modelEstimate)
        #expect(original.nutritionSnapshot?.calories == 500)
        #expect(entry.components.first?.nutritionSnapshot?.id != original.nutritionSnapshot?.id)
    }

    @Test("Changed nutrition creates a user-correction snapshot")
    func nutritionCorrection() throws {
        let entry = try makeEntry()
        let viewModel = MealConfirmationViewModel(entry: entry, service: service)
        viewModel.components[0].caloriesText = "600"
        try viewModel.confirm()
        #expect(entry.components.first?.nutritionSnapshot?.calories == 600)
        #expect(entry.components.first?.nutritionSnapshot?.source == .userCorrection)
    }

    @Test("Invalid edit does not replace a confirmed entry")
    func invalidConfirmedEditIsAtomic() throws {
        let entry = try makeEntry()
        try service.confirm(entry)
        let viewModel = MealConfirmationViewModel(entry: entry, service: service)
        viewModel.components[0].caloriesText = ""

        #expect(throws: FoodLoggingError.incompleteComponent("汉堡", "该食物缺少营养数据，不能按零摄入处理。")) {
            try viewModel.confirm()
        }
        #expect(entry.components.first?.nutritionSnapshot?.calories == 500)
        #expect(entry.status == .confirmed)
    }

    private func makeEntry() throws -> MealEntry {
        let entry = try service.createManualEntry(consumedAt: Date(), mealType: .lunch)
        let snapshot = NutritionSnapshot(
            basisQuantity: 1,
            basisUnit: .serving,
            calories: 500,
            proteinGrams: 25,
            carbohydrateGrams: 50,
            fatGrams: 20,
            source: .modelEstimate
        )
        let component = EntryComponent(
            displayName: "汉堡",
            originalQuantity: 1,
            originalUnit: "个",
            nutritionSnapshot: snapshot
        )
        try service.update(entry, components: [component], consumedAt: entry.consumedAt, mealType: entry.mealType)
        return entry
    }
}

@MainActor
private final class UnusedLLMProvider: LLMClientProviding {
    func client() throws -> any LLMClient { throw LLMError.notConfigured }
}
