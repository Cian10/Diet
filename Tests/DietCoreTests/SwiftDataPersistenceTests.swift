#if DIETAPP_SWIFTDATA
import Testing
import Foundation
import SwiftData
@testable import DietCore

@Suite("SwiftData persistence")
@MainActor
struct SwiftDataPersistenceTests {
    @Test("Complete schema creates an in-memory container")
    func completeSchemaCanCreateInMemoryContainer() throws {
        _ = try DietPersistence.makeContainer(isStoredInMemoryOnly: true)
    }

    @Test("SwiftData stores persist profile and phase")
    func storesPersistProfileAndPhase() throws {
        let container = try DietPersistence.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let profileStore = SwiftDataProfileStore(modelContext: context)
        let phaseStore = SwiftDataPhasePlanStore(modelContext: context)
        let targetStore = SwiftDataDailyTargetStore(modelContext: context)
        let mealStore = SwiftDataMealEntryStore(modelContext: context)

        _ = try ProfileService(store: profileStore).saveProfile(ProfileInput(currentWeightKilograms: 70))
        _ = try PhasePlanService(store: phaseStore).startNewPhase(PhasePlanInput(
            energyStrategy: .manual,
            manualTarget: ManualNutritionTarget(calories: 2200, proteinGrams: 140, carbohydrateGrams: 220, fatGrams: 70)
        ))

        let profileCount = try context.fetchCount(FetchDescriptor<UserProfile>())
        let weightCount = try context.fetchCount(FetchDescriptor<WeightRecord>())
        let phaseCount = try context.fetchCount(FetchDescriptor<PhasePlan>())
        try targetStore.saveTarget(DailyTarget(
            date: Date(),
            calories: 2200,
            proteinGrams: 140,
            carbohydrateGrams: 220,
            fatGrams: 70
        ))
        try mealStore.saveEntry(MealEntry(consumedAt: Date(), status: .draft))
        let targetCount = try context.fetchCount(FetchDescriptor<DailyTarget>())
        let mealCount = try context.fetchCount(FetchDescriptor<MealEntry>())
        #expect(profileCount == 1)
        #expect(weightCount == 1)
        #expect(phaseCount == 1)
        #expect(targetCount == 1)
        #expect(mealCount == 1)
    }

    @Test("Meal edits preserve identity and deletion preserves unrelated entries")
    func mealEditAndDeletePreserveOtherData() throws {
        let container = try DietPersistence.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let store = SwiftDataMealEntryStore(modelContext: context)
        let originalDate = Date()
        let originalSnapshot = NutritionSnapshot(
            basisQuantity: 1,
            basisUnit: .serving,
            calories: 400,
            proteinGrams: 20,
            carbohydrateGrams: 40,
            fatGrams: 15,
            source: .modelEstimate
        )
        let entry = MealEntry(
            consumedAt: originalDate,
            mealType: .lunch,
            status: .confirmed,
            originalText: "原始输入保持不变",
            components: [EntryComponent(
                displayName: "原始食物",
                originalQuantity: 1,
                originalUnit: "份",
                nutritionSnapshot: originalSnapshot
            )]
        )
        let otherEntry = MealEntry(
            consumedAt: originalDate,
            mealType: .dinner,
            status: .confirmed,
            components: [EntryComponent(
                displayName: "其他记录",
                originalQuantity: 1,
                originalUnit: "份",
                nutritionSnapshot: originalSnapshot.independentCopy()
            )]
        )
        try store.saveEntry(entry)
        try store.saveEntry(otherEntry)

        let updatedSnapshot = NutritionSnapshot(
            basisQuantity: 1,
            basisUnit: .serving,
            calories: 600,
            proteinGrams: 30,
            carbohydrateGrams: 50,
            fatGrams: 25,
            source: .userCorrection
        )
        entry.mealType = .dinner
        try store.replaceComponents(for: entry, components: [EntryComponent(
            displayName: "修改后的食物",
            originalQuantity: 2,
            originalUnit: "份",
            nutritionSnapshot: updatedSnapshot
        )])

        let verificationStore = SwiftDataMealEntryStore(modelContext: ModelContext(container))
        let afterEdit = try verificationStore.allEntries()
        let editedEntry = try #require(afterEdit.first { $0.id == entry.id })
        #expect(afterEdit.count == 2)
        #expect(editedEntry.originalText == "原始输入保持不变")
        #expect(editedEntry.mealType == .dinner)
        #expect(editedEntry.components.count == 1)
        #expect(editedEntry.components.first?.displayName == "修改后的食物")
        #expect(editedEntry.components.first?.nutritionSnapshot?.calories == 600)
        #expect(afterEdit.contains { $0.id == otherEntry.id })

        try store.deleteEntry(entry)

        let finalStore = SwiftDataMealEntryStore(modelContext: ModelContext(container))
        let afterDelete = try finalStore.allEntries()
        #expect(afterDelete.count == 1)
        #expect(afterDelete.first?.id == otherEntry.id)
        #expect(afterDelete.first?.components.first?.displayName == "其他记录")
    }
}
#endif
