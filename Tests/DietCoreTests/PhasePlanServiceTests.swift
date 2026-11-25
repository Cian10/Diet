import Testing
import Foundation
@testable import DietCore

@Suite("PhasePlanService")
@MainActor
final class PhasePlanServiceTests {
    private let store = InMemoryPhasePlanStore()
    private let service: PhasePlanService

    init() {
        service = PhasePlanService(store: store)
    }

    @Test("Manual target is required and validated")
    func manualTargetIsRequiredAndValidated() throws {
        let input = PhasePlanInput(energyStrategy: .manual, manualTarget: nil)
        #expect(throws: PhasePlanValidationError.missingManualCalories) {
            try self.service.startNewPhase(input)
        }

        let negative = PhasePlanInput(
            energyStrategy: .manual,
            manualTarget: ManualNutritionTarget(calories: 2000, proteinGrams: -1, carbohydrateGrams: 200, fatGrams: 60)
        )
        #expect(throws: PhasePlanValidationError.negativeMacroTarget) {
            try self.service.startNewPhase(negative)
        }
    }

    @Test("New phase preserves historical target")
    func startingNewPhaseEndsPreviousPlanAndPreservesHistoricalTarget() throws {
        let old = try service.startNewPhase(PhasePlanInput(
            phaseType: .maintenance,
            startDate: day(2026, 1, 1),
            energyStrategy: .manual,
            manualTarget: target(calories: 2300)
        ))
        let historicalTarget = DailyTarget(
            date: day(2026, 1, 15),
            calories: 2300,
            proteinGrams: 140,
            carbohydrateGrams: 230,
            fatGrams: 70,
            phasePlanVersion: old.version
        )

        let new = try service.startNewPhase(PhasePlanInput(
            phaseType: .cutting,
            startDate: day(2026, 2, 1),
            energyStrategy: .manual,
            manualTarget: target(calories: 2000)
        ))

        #expect(old.endDate == Calendar.current.startOfDay(for: day(2026, 1, 31)))
        #expect(new.version == old.version + 1)
        let oldCurrent = try service.currentPlan(on: day(2026, 1, 15))
        let newCurrent = try service.currentPlan(on: day(2026, 2, 1))
        #expect(oldCurrent?.id == old.id)
        #expect(newCurrent?.id == new.id)
        #expect(historicalTarget.calories == 2300)
        #expect(historicalTarget.phasePlanVersion == old.version)
    }

    @Test("Rejected overlap does not partially mutate schedule")
    func overlapValidationDoesNotPartiallyMutateSchedule() throws {
        _ = try service.startNewPhase(PhasePlanInput(
            startDate: day(2026, 3, 1),
            endDate: day(2026, 3, 31),
            energyStrategy: .manual,
            manualTarget: target()
        ))

        let sameDay = PhasePlanInput(
            startDate: day(2026, 3, 1),
            energyStrategy: .manual,
            manualTarget: target()
        )
        #expect(throws: PhasePlanValidationError.overlappingPhase) {
            try self.service.startNewPhase(sameDay)
        }

        let current = try service.startNewPhase(PhasePlanInput(
            startDate: day(2026, 3, 15),
            energyStrategy: .manual,
            manualTarget: target()
        ))
        #expect(current.endDate == nil)
        let afterReplacement = try service.allPlans()
        #expect(afterReplacement.count == 2)

        _ = try service.startNewPhase(PhasePlanInput(
            startDate: day(2026, 5, 1),
            endDate: day(2026, 5, 31),
            energyStrategy: .manual,
            manualTarget: target()
        ))

        let overlapsFuture = PhasePlanInput(
            startDate: day(2026, 4, 15),
            endDate: day(2026, 6, 15),
            energyStrategy: .manual,
            manualTarget: target()
        )
        let endDateBeforeRejectedProposal = current.endDate
        #expect(throws: PhasePlanValidationError.overlappingPhase) {
            try self.service.startNewPhase(overlapsFuture)
        }
        #expect(current.endDate == endDateBeforeRejectedProposal)
        let afterRejection = try service.allPlans()
        #expect(afterRejection.count == 3)
    }

    @Test("End date includes whole day and recovery is separate from rest-day setting")
    func endDateAndRecoverySemantics() throws {
        let plan = try service.startNewPhase(PhasePlanInput(
            phaseType: .recovery,
            startDate: day(2026, 4, 1),
            endDate: day(2026, 4, 7),
            energyStrategy: .manual,
            manualTarget: target(),
            usesTrainingDayTargets: true
        ))

        let endDayEvening = try #require(Calendar.current.date(
            bySettingHour: 20,
            minute: 0,
            second: 0,
            of: day(2026, 4, 7)
        ))
        #expect(plan.contains(endDayEvening))
        #expect(plan.status(on: day(2026, 4, 8)) == .ended)
        #expect(plan.phaseType == .recovery)
        #expect(plan.usesTrainingDayTargets)
    }

    @Test("Automatic strategy stores rule without calculating target")
    func automaticStrategyStoresRule() throws {
        let plan = try service.startNewPhase(PhasePlanInput(
            phaseType: .bulking,
            startDate: day(2026, 5, 1),
            energyStrategy: .automatic,
            energyAdjustmentPercent: 8
        ))
        #expect(plan.energyAdjustmentPercent == 8)
        #expect(plan.manualTarget == nil)
    }

    private func target(calories: Double = 2200) -> ManualNutritionTarget {
        ManualNutritionTarget(calories: calories, proteinGrams: 140, carbohydrateGrams: 220, fatGrams: 70)
    }

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }
}
