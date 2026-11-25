import Testing
import Foundation
@testable import DietCore

@Suite("TrendsService")
@MainActor
final class TrendsServiceTests {
    private let calendar = Calendar.current
    private let mealStore = InMemoryMealEntryStore()
    private let targetStore = InMemoryDailyTargetStore()
    private let phaseStore = InMemoryPhasePlanStore()
    private let profileStore = InMemoryProfileStore()

    @Test("Seven-day overview uses recorded days and preserves phase history")
    func weeklyOverview() throws {
        let day1 = day(2026, 6, 1)
        let day2 = day(2026, 6, 2)
        let day3 = day(2026, 6, 3)
        let day7 = day(2026, 6, 7)
        _ = try PhasePlanService(store: phaseStore).startNewPhase(PhasePlanInput(
            phaseType: .maintenance,
            startDate: day1,
            energyStrategy: .manual,
            manualTarget: ManualNutritionTarget(calories: 600, proteinGrams: 100, carbohydrateGrams: 50, fatGrams: 20)
        ))
        _ = try PhasePlanService(store: phaseStore).startNewPhase(PhasePlanInput(
            phaseType: .cutting,
            startDate: day3,
            energyStrategy: .manual,
            manualTarget: ManualNutritionTarget(calories: 800, proteinGrams: 100, carbohydrateGrams: 50, fatGrams: 20)
        ))

        try mealStore.saveEntry(meal(date: day1, calories: 500, status: .confirmed))
        try mealStore.saveEntry(meal(date: day2, calories: 1000, status: .confirmed))
        try mealStore.saveEntry(meal(date: day3, calories: 2000, status: .draft))
        try targetStore.saveTarget(target(day1, calories: 500))
        try targetStore.saveTarget(target(day2, calories: 800))
        try targetStore.saveTarget(target(day3, calories: 100))

        let profileService = ProfileService(store: profileStore)
        _ = try profileService.saveProfile(ProfileInput(currentWeightKilograms: 70), now: day1)
        _ = try profileService.saveProfile(ProfileInput(currentWeightKilograms: 69), now: day7)
        let service = TrendsService(
            mealStore: mealStore,
            targetStore: targetStore,
            phaseStore: phaseStore,
            profileStore: profileStore,
            calendar: calendar
        )
        let review = try service.weeklyReview(endingOn: day7)

        #expect(review.days.count == 7)
        #expect(review.overview.recordedDays == 2)
        #expect(review.overview.averageCalories == 750)
        #expect(review.overview.targetCompletionRate == 0.5)
        #expect(review.overview.weightChangeKilograms == -1)
        #expect(review.overview.weightSpanDays == 6)
        #expect(!review.overview.hasSufficientData)
        #expect(review.days[0].phaseType == .maintenance)
        #expect(review.days[2].phaseType == .cutting)
        #expect(review.days[2].intake.calories == 0)
    }

    @Test("One weight record does not create a trend")
    func singleWeightRecord() throws {
        let profileService = ProfileService(store: profileStore)
        _ = try profileService.saveProfile(ProfileInput(currentWeightKilograms: 70))
        let service = TrendsService(
            mealStore: mealStore,
            targetStore: targetStore,
            phaseStore: phaseStore,
            profileStore: profileStore
        )
        let result = try service.weeklyReview()
        #expect(result.overview.weightChangeKilograms == nil)
        #expect(result.overview.weightSpanDays == 0)
    }

    private func meal(date: Date, calories: Double, status: MealEntryStatus) -> MealEntry {
        let snapshot = NutritionSnapshot(
            basisUnit: .serving,
            calories: calories,
            proteinGrams: 10,
            carbohydrateGrams: 10,
            fatGrams: 5,
            source: .userLabel
        )
        return MealEntry(
            consumedAt: date,
            status: status,
            components: [EntryComponent(
                displayName: "测试餐",
                originalQuantity: 1,
                originalUnit: "份",
                nutritionSnapshot: snapshot
            )]
        )
    }

    private func target(_ date: Date, calories: Double) -> DailyTarget {
        DailyTarget(date: date, calories: calories, proteinGrams: 100, carbohydrateGrams: 100, fatGrams: 50)
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
