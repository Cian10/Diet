import Testing
import Foundation
@testable import DietFeatures
import DietCore

@Suite("Nutrition home view model")
@MainActor
final class NutritionHomeViewModelTests {
    private let profileStore = InMemoryProfileStore()
    private let phaseStore = InMemoryPhasePlanStore()
    private let targetStore = InMemoryDailyTargetStore()
    private let mealStore = InMemoryMealEntryStore()

    @Test("Loading reconciles and saves today's automatic target")
    func loadReconcilesTodayTarget() throws {
        try profileStore.saveProfile(profile(), weightRecord: nil)
        let plan = PhasePlan(
            phaseType: .maintenance,
            startDate: today,
            version: 1,
            energyStrategy: .automatic,
            energyAdjustmentPercent: 0,
            macroRule: .default
        )
        try phaseStore.saveNewPhase(plan)
        let viewModel = makeViewModel()

        viewModel.load()

        let target = try #require(try targetStore.target(on: today))
        #expect(viewModel.target?.dailyTarget === target)
        #expect(viewModel.target?.requiresConfirmation == false)
        #expect(viewModel.assessment != nil)
        #expect(viewModel.errorMessage == nil)
    }

    @Test("Single-day update refreshes target and leaves other dates unchanged")
    func updateRefreshesTargetAssessmentAndHistory() throws {
        try profileStore.saveProfile(profile(), weightRecord: nil)
        try phaseStore.saveNewPhase(PhasePlan(
            phaseType: .maintenance,
            startDate: day(-1),
            version: 1,
            energyStrategy: .manual,
            manualTarget: ManualNutritionTarget(
                calories: 2200,
                proteinGrams: 140,
                carbohydrateGrams: 220,
                fatGrams: 70
            )
        ))
        let viewModel = makeViewModel()
        viewModel.load()
        let yesterday = try #require(try targetStore.target(on: day(-1)))

        try viewModel.updateTodayTarget(ManualNutritionTarget(
            calories: 1800,
            proteinGrams: 120,
            carbohydrateGrams: 0,
            fatGrams: 0
        ))

        let updated = try #require(viewModel.target?.dailyTarget)
        #expect(updated.calories == 1800)
        #expect(updated.proteinGrams == 120)
        #expect(updated.carbohydrateGrams == 0)
        #expect(updated.fatGrams == 0)
        #expect(updated.isSingleDayOverride)
        #expect(viewModel.assessment?.targetCalorieDifference == 1800)
        #expect(yesterday.calories == 2200)
        #expect(!yesterday.isSingleDayOverride)
        #expect(viewModel.errorMessage == nil)

        #expect(throws: PhasePlanValidationError.negativeMacroTarget) {
            try viewModel.updateTodayTarget(ManualNutritionTarget(
                calories: 1800,
                proteinGrams: -1,
                carbohydrateGrams: 0,
                fatGrams: 0
            ))
        }
        #expect(viewModel.target?.dailyTarget.calories == 1800)
        #expect(viewModel.errorMessage == PhasePlanValidationError.negativeMacroTarget.localizedDescription)
    }

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: today)!
    }

    private func profile() -> UserProfile {
        UserProfile(
            ageYears: 28,
            heightCentimeters: 175,
            currentWeightKilograms: 70,
            biologicalSex: .male,
            activityLevel: .moderate
        )
    }

    private func makeViewModel() -> NutritionHomeViewModel {
        NutritionHomeViewModel(
            profileStore: profileStore,
            phaseStore: phaseStore,
            targetStore: targetStore,
            mealStore: mealStore
        )
    }
}
