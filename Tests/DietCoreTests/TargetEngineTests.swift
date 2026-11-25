import Testing
import Foundation
@testable import DietCore

@Suite("TargetEngine")
@MainActor
final class TargetEngineTests {
    private let engine = TargetEngine()

    @Test("Mifflin-St Jeor and activity multiplier are deterministic")
    func expenditureEstimate() throws {
        let result = try engine.expenditureEstimate(profile: profile())
        #expect(abs(result.bmr - 1658.75) < 0.0001)
        #expect(abs(result.maintenance - 2571.0625) < 0.0001)
        #expect(result.assumptions.count == 3)
    }

    @Test("Automatic target uses phase adjustment and configurable macro rule")
    func automaticTarget() throws {
        let phase = PhasePlan(
            phaseType: .bulking,
            startDate: Date(),
            version: 1,
            energyStrategy: .automatic,
            energyAdjustmentPercent: 10,
            macroRule: MacroTargetRule(proteinGramsPerKilogram: 1.8, fatEnergyProportion: 0.25)
        )
        let result = try engine.resolve(profile: profile(), phase: phase, date: Date())
        let target = result.dailyTarget
        #expect(abs(target.calories - 2828.16875) < 0.0001)
        #expect(target.proteinGrams == 126)
        #expect(target.carbohydrateGrams > 0)
        #expect(target.phasePlanVersion == 1)
        let reconstructed = target.proteinGrams * 4 + target.carbohydrateGrams * 4 + target.fatGrams * 9
        #expect(abs(reconstructed - target.calories) < 0.0001)
    }

    @Test("Manual target works without body data")
    func manualTargetWithoutBodyData() throws {
        let phase = PhasePlan(
            phaseType: .maintenance,
            startDate: Date(),
            version: 2,
            energyStrategy: .manual,
            manualTarget: ManualNutritionTarget(calories: 2100, proteinGrams: 130, carbohydrateGrams: 200, fatGrams: 70)
        )
        let result = try engine.resolve(profile: UserProfile(), phase: phase, date: Date())
        #expect(result.dailyTarget.calories == 2100)
        #expect(result.basalMetabolicRate == nil)
    }

    @Test("Automatic target reports missing sex")
    func automaticMissingSex() {
        let phase = PhasePlan(
            phaseType: .cutting,
            startDate: Date(),
            version: 1,
            energyStrategy: .automatic,
            energyAdjustmentPercent: -15
        )
        #expect(throws: TargetEngineError.missingSex) {
            try self.engine.resolve(profile: self.profile(sex: nil), phase: phase, date: Date())
        }
    }

    @Test("Excessive macro rules fail instead of creating negative carbs")
    func excessiveMacros() {
        let phase = PhasePlan(
            phaseType: .cutting,
            startDate: Date(),
            version: 1,
            energyStrategy: .automatic,
            energyAdjustmentPercent: -50,
            macroRule: MacroTargetRule(proteinGramsPerKilogram: 5, fatEnergyProportion: 0.6)
        )
        #expect(throws: TargetEngineError.macroTargetsExceedCalories) {
            try self.engine.resolve(profile: self.profile(), phase: phase, date: Date())
        }
    }

    @Test("Saved daily target survives later phase changes")
    func dailyTargetHistory() throws {
        let targetStore = InMemoryDailyTargetStore()
        let phaseStore = InMemoryPhasePlanStore()
        let phaseService = PhasePlanService(store: phaseStore)
        let service = DailyTargetService(targetStore: targetStore, phaseStore: phaseStore)
        let date = Date()
        _ = try phaseService.startNewPhase(PhasePlanInput(
            startDate: date,
            energyStrategy: .manual,
            manualTarget: ManualNutritionTarget(calories: 2200, proteinGrams: 140, carbohydrateGrams: 220, fatGrams: 70)
        ))
        let first = try service.target(on: date, profile: UserProfile())
        #expect(!first.usedExistingTarget)

        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: date)!
        _ = try phaseService.startNewPhase(PhasePlanInput(
            startDate: tomorrow,
            energyStrategy: .manual,
            manualTarget: ManualNutritionTarget(calories: 1800, proteinGrams: 140, carbohydrateGrams: 150, fatGrams: 60)
        ))
        let historical = try service.target(on: date, profile: UserProfile())
        #expect(historical.usedExistingTarget)
        #expect(historical.dailyTarget.calories == 2200)
    }

    @Test("Legacy automatic target proposal remains compatible with accept")
    func legacyAutomaticTargetProposal() throws {
        let targetStore = InMemoryDailyTargetStore()
        let phaseStore = InMemoryPhasePlanStore()
        _ = try PhasePlanService(store: phaseStore).startNewPhase(PhasePlanInput(
            startDate: Date(),
            energyStrategy: .automatic,
            energyAdjustmentPercent: 0
        ))
        let service = DailyTargetService(targetStore: targetStore, phaseStore: phaseStore)
        let proposal = try service.target(on: Date(), profile: profile())
        #expect(proposal.requiresConfirmation)
        #expect(try targetStore.target(on: Date()) == nil)

        try service.accept(proposal)
        let saved = try service.target(on: Date(), profile: profile())
        #expect(saved.usedExistingTarget)
        #expect(!saved.requiresConfirmation)
    }

    @Test("Reconciliation saves an automatic target immediately")
    func reconciliationSavesAutomaticTodayTarget() throws {
        let targetStore = InMemoryDailyTargetStore()
        let phaseStore = InMemoryPhasePlanStore()
        try savePlan(
            to: phaseStore,
            startOffset: 0,
            strategy: .automatic,
            version: 1
        )
        let service = DailyTargetService(targetStore: targetStore, phaseStore: phaseStore)

        let result = try service.reconcile(on: today, profile: profile())

        #expect(!result.today.usedExistingTarget)
        #expect(!result.today.requiresConfirmation)
        #expect(result.backfilledDates.isEmpty)
        let saved = try #require(try targetStore.target(on: today))
        #expect(saved === result.today.dailyTarget)
        #expect(targetStore.allTargets.count == 1)
    }

    @Test("Reconciliation preserves manual target behavior")
    func reconciliationSavesManualTodayTarget() throws {
        let targetStore = InMemoryDailyTargetStore()
        let phaseStore = InMemoryPhasePlanStore()
        try savePlan(
            to: phaseStore,
            startOffset: 0,
            strategy: .manual,
            calories: 2100,
            version: 1
        )
        let service = DailyTargetService(targetStore: targetStore, phaseStore: phaseStore)

        let result = try service.reconcile(on: today, profile: UserProfile())

        #expect(!result.today.requiresConfirmation)
        #expect(result.today.dailyTarget.calories == 2100)
        #expect(try targetStore.target(on: today) === result.today.dailyTarget)
    }

    @Test("Historical targets follow the phase active on each day")
    func historicalBackfillUsesDailyPhase() throws {
        let targetStore = InMemoryDailyTargetStore()
        let phaseStore = InMemoryPhasePlanStore()
        try savePlan(
            to: phaseStore,
            startOffset: -6,
            endOffset: -4,
            strategy: .manual,
            calories: 2200,
            version: 1
        )
        try savePlan(
            to: phaseStore,
            startOffset: -3,
            endOffset: -2,
            strategy: .manual,
            calories: 1900,
            version: 2
        )
        try savePlan(
            to: phaseStore,
            startOffset: 0,
            strategy: .manual,
            calories: 2100,
            version: 3
        )
        let service = DailyTargetService(targetStore: targetStore, phaseStore: phaseStore)

        let result = try service.reconcile(on: today, profile: UserProfile())

        #expect(result.backfilledDates.map(dayOffset) == [-6, -5, -4, -3, -2])
        #expect(try targetStore.target(on: day(-5))?.calories == 2200)
        #expect(try targetStore.target(on: day(-3))?.calories == 1900)
        #expect(try targetStore.target(on: day(-1)) == nil)
        #expect(try targetStore.target(on: today)?.calories == 2100)
    }

    @Test("Historical automatic targets use the current profile")
    func historicalAutomaticTargetUsesCurrentProfile() throws {
        let targetStore = InMemoryDailyTargetStore()
        let phaseStore = InMemoryPhasePlanStore()
        try savePlan(
            to: phaseStore,
            startOffset: -2,
            endOffset: -1,
            strategy: .automatic,
            adjustment: 10,
            version: 1
        )
        try savePlan(
            to: phaseStore,
            startOffset: 0,
            strategy: .manual,
            calories: 2100,
            version: 2
        )
        let service = DailyTargetService(targetStore: targetStore, phaseStore: phaseStore)

        let result = try service.reconcile(on: today, profile: profile(weight: 70))

        #expect(result.backfilledDates.map(dayOffset) == [-2, -1])
        let historical = try #require(try targetStore.target(on: day(-2)))
        #expect(abs(historical.calories - 2828.16875) < 0.0001)
        #expect(historical.proteinGrams == 126)
    }

    @Test("Future phases do not participate in reconciliation")
    func futurePhasesAreExcluded() throws {
        let targetStore = InMemoryDailyTargetStore()
        let phaseStore = InMemoryPhasePlanStore()
        try savePlan(
            to: phaseStore,
            startOffset: 0,
            strategy: .manual,
            calories: 2100,
            version: 1
        )
        try savePlan(
            to: phaseStore,
            startOffset: 1,
            strategy: .manual,
            calories: 1800,
            version: 2
        )
        let service = DailyTargetService(targetStore: targetStore, phaseStore: phaseStore)

        let result = try service.reconcile(on: today, profile: UserProfile())

        #expect(result.backfilledDates.isEmpty)
        #expect(try targetStore.target(on: day(1)) == nil)
    }

    @Test("Existing targets are never overwritten")
    func existingTargetsAreNotOverwritten() throws {
        let targetStore = InMemoryDailyTargetStore()
        let phaseStore = InMemoryPhasePlanStore()
        try savePlan(
            to: phaseStore,
            startOffset: -2,
            strategy: .manual,
            calories: 2200,
            version: 1
        )
        let override = DailyTarget(
            date: day(-2),
            calories: 2400,
            proteinGrams: 140,
            carbohydrateGrams: 250,
            fatGrams: 70,
            phasePlanVersion: 1,
            isSingleDayOverride: true
        )
        let accepted = DailyTarget(
            date: day(-1),
            calories: 2000,
            proteinGrams: 140,
            carbohydrateGrams: 180,
            fatGrams: 65,
            phasePlanVersion: 1
        )
        try targetStore.saveTarget(override)
        try targetStore.saveTarget(accepted)
        let service = DailyTargetService(targetStore: targetStore, phaseStore: phaseStore)

        let result = try service.reconcile(on: today, profile: UserProfile())

        #expect(result.backfilledDates.isEmpty)
        #expect(try targetStore.target(on: day(-2)) === override)
        #expect(override.calories == 2400)
        #expect(override.isSingleDayOverride)
        #expect(try targetStore.target(on: day(-1)) === accepted)
        #expect(accepted.calories == 2000)
        #expect(try targetStore.target(on: today)?.calories == 2200)
    }

    @Test("Reconciliation is idempotent")
    func reconciliationIsIdempotent() throws {
        let targetStore = InMemoryDailyTargetStore()
        let phaseStore = InMemoryPhasePlanStore()
        try savePlan(
            to: phaseStore,
            startOffset: -2,
            strategy: .manual,
            calories: 2200,
            version: 1
        )
        let service = DailyTargetService(targetStore: targetStore, phaseStore: phaseStore)

        let first = try service.reconcile(on: today, profile: UserProfile())
        #expect(first.backfilledDates.map(dayOffset) == [-2, -1])
        #expect(targetStore.allTargets.count == 3)
        let yesterdayBefore = try #require(try targetStore.target(on: day(-1)))

        let second = try service.reconcile(on: today, profile: UserProfile())
        #expect(second.backfilledDates.isEmpty)
        #expect(second.today.usedExistingTarget)
        #expect(targetStore.allTargets.count == 3)
        #expect(try targetStore.target(on: day(-1)) === yesterdayBefore)
    }

    @Test("Backfill errors preserve existing targets")
    func backfillErrorsPreserveExistingTargets() throws {
        let targetStore = InMemoryDailyTargetStore()
        let phaseStore = InMemoryPhasePlanStore()
        try savePlan(
            to: phaseStore,
            startOffset: -1,
            endOffset: -1,
            strategy: .manual,
            calories: 2100,
            version: 1
        )
        try savePlan(
            to: phaseStore,
            startOffset: 0,
            strategy: .automatic,
            version: 2
        )
        let existing = DailyTarget(
            date: day(-1),
            calories: 2100,
            proteinGrams: 140,
            carbohydrateGrams: 210,
            fatGrams: 70,
            phasePlanVersion: 1
        )
        try targetStore.saveTarget(existing)
        let service = DailyTargetService(targetStore: targetStore, phaseStore: phaseStore)

        #expect(throws: TargetEngineError.missingSex) {
            try service.reconcile(on: self.today, profile: self.profile(sex: nil))
        }
        #expect(try targetStore.target(on: day(-1)) === existing)
        #expect(existing.calories == 2100)
        #expect(targetStore.allTargets.count == 1)
    }

    @Test("Single-day update only changes today")
    func singleDayUpdateOnlyChangesToday() throws {
        let targetStore = InMemoryDailyTargetStore()
        let phaseStore = InMemoryPhasePlanStore()
        try savePlan(
            to: phaseStore,
            startOffset: -1,
            strategy: .manual,
            calories: 2200,
            version: 3
        )
        let service = DailyTargetService(targetStore: targetStore, phaseStore: phaseStore)
        _ = try service.reconcile(on: today, profile: UserProfile())
        let original = try #require(try targetStore.target(on: today))
        let yesterdayBefore = try #require(try targetStore.target(on: day(-1)))

        let updated = try service.updateTodayTarget(
            ManualNutritionTarget(calories: 1800, proteinGrams: 120, carbohydrateGrams: 0, fatGrams: 0),
            profile: UserProfile(),
            on: today
        )

        let todayAfter = try #require(try targetStore.target(on: today))
        #expect(todayAfter === original)
        #expect(todayAfter.calories == 1800)
        #expect(todayAfter.proteinGrams == 120)
        #expect(todayAfter.carbohydrateGrams == 0)
        #expect(todayAfter.fatGrams == 0)
        #expect(todayAfter.isSingleDayOverride)
        #expect(todayAfter.id == original.id)
        #expect(todayAfter.date == original.date)
        #expect(todayAfter.phasePlanVersion == 3)
        #expect(yesterdayBefore.calories == 2200)
        #expect(updated.dailyTarget === todayAfter)

        let unchanged = (
            todayAfter.calories,
            todayAfter.proteinGrams,
            todayAfter.carbohydrateGrams,
            todayAfter.fatGrams
        )
        #expect(throws: PhasePlanValidationError.negativeMacroTarget) {
            try service.updateTodayTarget(
                ManualNutritionTarget(calories: 1800, proteinGrams: -1, carbohydrateGrams: 0, fatGrams: 0),
                profile: UserProfile(),
                on: self.today
            )
        }
        #expect(todayAfter.calories == unchanged.0)
        #expect(todayAfter.proteinGrams == unchanged.1)
        #expect(todayAfter.carbohydrateGrams == unchanged.2)
        #expect(todayAfter.fatGrams == unchanged.3)

        let reconciled = try service.reconcile(on: today, profile: UserProfile())
        #expect(reconciled.today.usedExistingTarget)
        #expect(reconciled.today.dailyTarget.calories == 1800)
        #expect(reconciled.today.dailyTarget.isSingleDayOverride)
    }

    private func profile(sex: BiologicalSex? = .male, weight: Double = 70) -> UserProfile {
        UserProfile(
            ageYears: 28,
            heightCentimeters: 175,
            currentWeightKilograms: weight,
            biologicalSex: sex,
            activityLevel: .moderate
        )
    }

    private var today: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: today)!
    }

    private func dayOffset(_ date: Date) -> Int {
        Calendar.current.dateComponents([.day], from: today, to: date).day!
    }

    private func savePlan(
        to store: InMemoryPhasePlanStore,
        startOffset: Int,
        endOffset: Int? = nil,
        strategy: EnergyStrategy,
        calories: Double = 2200,
        adjustment: Double = 0,
        version: Int
    ) throws {
        let startDate = day(startOffset)
        let endDate = endOffset.map(day)
        let manualTarget = strategy == .manual
            ? ManualNutritionTarget(calories: calories, proteinGrams: 140, carbohydrateGrams: 220, fatGrams: 70)
            : nil
        let plan = PhasePlan(
            phaseType: .maintenance,
            startDate: startDate,
            endDate: endDate,
            version: version,
            energyStrategy: strategy,
            energyAdjustmentPercent: strategy == .automatic ? adjustment : nil,
            manualTarget: manualTarget,
            macroRule: strategy == .automatic ? .default : nil
        )
        try store.saveNewPhase(plan)
    }
}
