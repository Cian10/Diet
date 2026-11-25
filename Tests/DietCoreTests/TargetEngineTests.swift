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

    @Test("Automatic target remains a proposal until accepted")
    func automaticTargetRequiresConfirmation() throws {
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

    private func profile(sex: BiologicalSex? = .male) -> UserProfile {
        UserProfile(
            ageYears: 28,
            heightCentimeters: 175,
            currentWeightKilograms: 70,
            biologicalSex: sex,
            activityLevel: .moderate
        )
    }
}
