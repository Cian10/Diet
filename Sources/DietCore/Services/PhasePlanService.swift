import Foundation

@MainActor
public protocol PhasePlanStoring: AnyObject {
    func allPlans() throws -> [PhasePlan]
    func saveNewPhase(_ plan: PhasePlan) throws
}

public struct ManualNutritionTarget: Sendable, Equatable {
    public var calories: Double
    public var proteinGrams: Double
    public var carbohydrateGrams: Double
    public var fatGrams: Double

    public init(calories: Double, proteinGrams: Double, carbohydrateGrams: Double, fatGrams: Double) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
    }

    public func validated() throws -> ManualNutritionTarget {
        let values = [calories, proteinGrams, carbohydrateGrams, fatGrams]
        guard values.allSatisfy({ $0.isFinite }) else { throw PhasePlanValidationError.nonFiniteTarget }
        guard calories > 0 else { throw PhasePlanValidationError.missingManualCalories }
        guard proteinGrams >= 0, carbohydrateGrams >= 0, fatGrams >= 0 else {
            throw PhasePlanValidationError.negativeMacroTarget
        }
        return self
    }
}

public struct MacroTargetRule: Sendable, Equatable {
    public static let `default` = MacroTargetRule(proteinGramsPerKilogram: 1.8, fatEnergyProportion: 0.25)

    public var proteinGramsPerKilogram: Double
    public var fatEnergyProportion: Double

    public init(proteinGramsPerKilogram: Double, fatEnergyProportion: Double) {
        self.proteinGramsPerKilogram = proteinGramsPerKilogram
        self.fatEnergyProportion = fatEnergyProportion
    }

    public func validated() throws -> MacroTargetRule {
        guard proteinGramsPerKilogram.isFinite, fatEnergyProportion.isFinite,
              proteinGramsPerKilogram > 0, proteinGramsPerKilogram <= 5,
              fatEnergyProportion > 0, fatEnergyProportion <= 0.6 else {
            throw PhasePlanValidationError.invalidMacroRule
        }
        return self
    }
}

public struct PhasePlanInput: Sendable {
    public var phaseType: PhaseType
    public var startDate: Date
    public var endDate: Date?
    public var energyStrategy: EnergyStrategy
    public var energyAdjustmentPercent: Double?
    public var manualTarget: ManualNutritionTarget?
    public var macroRule: MacroTargetRule?
    public var usesTrainingDayTargets: Bool

    public init(
        phaseType: PhaseType = .maintenance,
        startDate: Date = Date(),
        endDate: Date? = nil,
        energyStrategy: EnergyStrategy = .manual,
        energyAdjustmentPercent: Double? = 0,
        manualTarget: ManualNutritionTarget? = nil,
        macroRule: MacroTargetRule? = .default,
        usesTrainingDayTargets: Bool = false
    ) {
        self.phaseType = phaseType
        self.startDate = startDate
        self.endDate = endDate
        self.energyStrategy = energyStrategy
        self.energyAdjustmentPercent = energyAdjustmentPercent
        self.manualTarget = manualTarget
        self.macroRule = macroRule
        self.usesTrainingDayTargets = usesTrainingDayTargets
    }

    public func validated() throws -> PhasePlanInput {
        if let endDate, Calendar.current.startOfDay(for: endDate) < Calendar.current.startOfDay(for: startDate) {
            throw PhasePlanValidationError.endDateBeforeStart
        }
        switch energyStrategy {
        case .manual:
            guard let manualTarget else { throw PhasePlanValidationError.missingManualCalories }
            _ = try manualTarget.validated()
        case .automatic:
            guard let energyAdjustmentPercent, energyAdjustmentPercent.isFinite else {
                throw PhasePlanValidationError.invalidEnergyAdjustment
            }
            guard (-50...50).contains(energyAdjustmentPercent) else {
                throw PhasePlanValidationError.invalidEnergyAdjustment
            }
            _ = try (macroRule ?? .default).validated()
        }
        return self
    }
}

public enum PhasePlanValidationError: LocalizedError, Equatable {
    case endDateBeforeStart
    case missingManualCalories
    case nonFiniteTarget
    case negativeMacroTarget
    case invalidEnergyAdjustment
    case invalidMacroRule
    case overlappingPhase

    public var errorDescription: String? {
        switch self {
        case .endDateBeforeStart: "结束日期不能早于开始日期。"
        case .missingManualCalories: "手动方案需要填写大于零的目标热量。"
        case .nonFiniteTarget: "目标数值无效，请重新输入。"
        case .negativeMacroTarget: "蛋白质、碳水和脂肪目标不能为负数。"
        case .invalidEnergyAdjustment: "热量调整比例需在 -50% 到 50% 之间。"
        case .invalidMacroRule: "蛋白质系数需大于 0 且不超过 5 g/kg，脂肪供能比例需大于 0 且不超过 60%。"
        case .overlappingPhase: "新方案与已有方案日期重叠，请调整开始或结束日期。"
        }
    }
}

@MainActor
public final class PhasePlanService {
    private let store: PhasePlanStoring
    private let calendar: Calendar

    public init(store: PhasePlanStoring, calendar: Calendar = .current) {
        self.store = store
        self.calendar = calendar
    }

    public func allPlans() throws -> [PhasePlan] {
        try store.allPlans().sorted {
            if $0.startDate == $1.startDate { return $0.version > $1.version }
            return $0.startDate > $1.startDate
        }
    }

    public func currentPlan(on date: Date = Date()) throws -> PhasePlan? {
        try allPlans().first { $0.contains(date) }
    }

    @discardableResult
    public func startNewPhase(_ input: PhasePlanInput, now: Date = Date()) throws -> PhasePlan {
        _ = try input.validated()
        let start = calendar.startOfDay(for: input.startDate)
        let end = input.endDate.map { calendar.startOfDay(for: $0) }
        let effectiveEnd = end ?? .distantFuture
        let existingPlans = try allPlans()
        var plansToTruncate: [PhasePlan] = []

        for plan in existingPlans {
            let existingStart = calendar.startOfDay(for: plan.startDate)
            let existingEnd = plan.endDate.map { calendar.startOfDay(for: $0) } ?? .distantFuture
            let overlaps = start <= existingEnd && effectiveEnd >= existingStart
            guard overlaps else { continue }

            if existingStart < start {
                plansToTruncate.append(plan)
            } else {
                throw PhasePlanValidationError.overlappingPhase
            }
        }

        // Validate the complete schedule before mutating any existing plan.
        for plan in plansToTruncate {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: start) else {
                throw PhasePlanValidationError.overlappingPhase
            }
            plan.endDate = previousDay
        }

        let nextVersion = (existingPlans.map(\.version).max() ?? 0) + 1
        let plan = PhasePlan(
            phaseType: input.phaseType,
            startDate: start,
            endDate: end,
            version: nextVersion,
            energyStrategy: input.energyStrategy,
            energyAdjustmentPercent: input.energyStrategy == .automatic ? input.energyAdjustmentPercent : nil,
            manualTarget: input.energyStrategy == .manual ? input.manualTarget : nil,
            macroRule: input.energyStrategy == .automatic ? (input.macroRule ?? .default) : nil,
            usesTrainingDayTargets: input.usesTrainingDayTargets,
            createdAt: now
        )
        try store.saveNewPhase(plan)
        return plan
    }
}

@MainActor
public final class InMemoryPhasePlanStore: PhasePlanStoring {
    private var plans: [PhasePlan] = []

    public init() {}

    public func allPlans() throws -> [PhasePlan] { plans }

    public func saveNewPhase(_ plan: PhasePlan) throws {
        plans.append(plan)
    }
}
