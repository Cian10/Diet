import Foundation
#if DIETAPP_SWIFTDATA
import SwiftData
#endif

#if DIETAPP_SWIFTDATA
@Model
#endif
public final class PhasePlan {
    #if DIETAPP_SWIFTDATA
    @Attribute(.unique)
    #endif
    public var id: UUID
    public var phaseTypeRaw: String
    public var startDate: Date
    public var endDate: Date?
    public var version: Int
    public var energyStrategyRaw: String
    public var energyAdjustmentPercent: Double?
    public var manualCalories: Double?
    public var manualProteinGrams: Double?
    public var manualCarbohydrateGrams: Double?
    public var manualFatGrams: Double?
    public var proteinGramsPerKilogram: Double?
    public var fatEnergyProportion: Double?
    public var usesTrainingDayTargets: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        phaseType: PhaseType,
        startDate: Date,
        endDate: Date? = nil,
        version: Int,
        energyStrategy: EnergyStrategy = .automatic,
        energyAdjustmentPercent: Double? = nil,
        manualTarget: ManualNutritionTarget? = nil,
        macroRule: MacroTargetRule? = nil,
        usesTrainingDayTargets: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.phaseTypeRaw = phaseType.rawValue
        self.startDate = startDate
        self.endDate = endDate
        self.version = version
        self.energyStrategyRaw = energyStrategy.rawValue
        self.energyAdjustmentPercent = energyAdjustmentPercent
        self.manualCalories = manualTarget?.calories
        self.manualProteinGrams = manualTarget?.proteinGrams
        self.manualCarbohydrateGrams = manualTarget?.carbohydrateGrams
        self.manualFatGrams = manualTarget?.fatGrams
        self.proteinGramsPerKilogram = macroRule?.proteinGramsPerKilogram
        self.fatEnergyProportion = macroRule?.fatEnergyProportion
        self.usesTrainingDayTargets = usesTrainingDayTargets
        self.createdAt = createdAt
    }

    public var phaseType: PhaseType {
        get { PhaseType(rawValue: phaseTypeRaw) ?? .maintenance }
        set { phaseTypeRaw = newValue.rawValue }
    }

    public var energyStrategy: EnergyStrategy {
        get { EnergyStrategy(rawValue: energyStrategyRaw) ?? .manual }
        set { energyStrategyRaw = newValue.rawValue }
    }

    public var manualTarget: ManualNutritionTarget? {
        guard let manualCalories else { return nil }
        return ManualNutritionTarget(
            calories: manualCalories,
            proteinGrams: manualProteinGrams ?? 0,
            carbohydrateGrams: manualCarbohydrateGrams ?? 0,
            fatGrams: manualFatGrams ?? 0
        )
    }

    public var macroRule: MacroTargetRule {
        MacroTargetRule(
            proteinGramsPerKilogram: proteinGramsPerKilogram ?? MacroTargetRule.default.proteinGramsPerKilogram,
            fatEnergyProportion: fatEnergyProportion ?? MacroTargetRule.default.fatEnergyProportion
        )
    }

    public func contains(_ date: Date) -> Bool {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        let start = calendar.startOfDay(for: startDate)
        let end = endDate.map { calendar.startOfDay(for: $0) } ?? .distantFuture
        return day >= start && day <= end
    }

    public func status(on date: Date) -> PhaseStatus {
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: date)
        if day < calendar.startOfDay(for: startDate) { return .scheduled }
        if let endDate, day > calendar.startOfDay(for: endDate) { return .ended }
        return .active
    }
}
