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
}
#endif
