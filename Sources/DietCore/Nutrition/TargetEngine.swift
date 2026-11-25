import Foundation

public enum TargetEngineError: LocalizedError, Equatable {
    case missingBodyData
    case missingManualTarget
    case missingSex
    case invalidBodyData
    case invalidTrainingCalories
    case macroTargetsExceedCalories
    case noActivePhase

    public var errorDescription: String? {
        switch self {
        case .missingBodyData: "自动目标需要年龄、身高和当前体重；也可以改用手动目标。"
        case .missingManualTarget: "当前阶段缺少手动目标，请先编辑阶段方案。"
        case .missingSex: "Mifflin–St Jeor 公式需要填写性别；也可以改用手动目标。"
        case .invalidBodyData: "身体数据无效，请先检查个人档案。"
        case .invalidTrainingCalories: "额外训练消耗必须是非负有限数值。"
        case .macroTargetsExceedCalories: "蛋白质和脂肪目标已超过目标热量，请调整宏量营养规则。"
        case .noActivePhase: "当前日期没有生效中的阶段方案。"
        }
    }
}

public enum TargetWarning: String, Sendable, Equatable {
    case targetBelowEstimatedBMR
    case largeEnergyAdjustment
    case activityMultiplierIncludesRoutineTraining

    public var displayName: String {
        switch self {
        case .targetBelowEstimatedBMR: "目标热量低于估算基础代谢，请确认是否适合长期执行。"
        case .largeEnergyAdjustment: "热量调整幅度较大，建议结合自身情况谨慎确认。"
        case .activityMultiplierIncludesRoutineTraining: "活动系数已包含日常训练，不应再次叠加相同训练消耗。"
        }
    }
}

public struct TargetResolution {
    public var dailyTarget: DailyTarget
    public var basalMetabolicRate: Double?
    public var estimatedMaintenanceCalories: Double?
    public var assumptions: [String]
    public var warnings: [TargetWarning]
    public var usedExistingTarget: Bool
    public var requiresConfirmation: Bool
}

public struct DailyTargetReconciliation {
    public var today: TargetResolution
    public var backfilledDates: [Date]

    public init(today: TargetResolution, backfilledDates: [Date]) {
        self.today = today
        self.backfilledDates = backfilledDates
    }
}

public struct TargetEngine: Sendable {
    public var energyFactors: MacroEnergyFactors

    public init(energyFactors: MacroEnergyFactors = MacroEnergyFactors()) {
        self.energyFactors = energyFactors
    }

    public func resolve(
        profile: UserProfile,
        phase: PhasePlan,
        date: Date,
        additionalTrainingCalories: Double? = nil
    ) throws -> TargetResolution {
        if let additionalTrainingCalories,
           !additionalTrainingCalories.isFinite || additionalTrainingCalories < 0 {
            throw TargetEngineError.invalidTrainingCalories
        }

        var bmr: Double?
        var maintenance: Double?
        var assumptions: [String] = []
        var warnings: [TargetWarning] = []
        if let estimate = try? expenditureEstimate(profile: profile, additionalTrainingCalories: additionalTrainingCalories) {
            bmr = estimate.bmr
            maintenance = estimate.maintenance
            assumptions = estimate.assumptions
            warnings.append(.activityMultiplierIncludesRoutineTraining)
        }

        let target: DailyTarget
        switch phase.energyStrategy {
        case .manual:
            guard let manual = phase.manualTarget else { throw TargetEngineError.missingManualTarget }
            _ = try manual.validated()
            target = DailyTarget(
                date: date,
                calories: manual.calories,
                proteinGrams: manual.proteinGrams,
                carbohydrateGrams: manual.carbohydrateGrams,
                fatGrams: manual.fatGrams,
                phasePlanVersion: phase.version
            )
            assumptions.append("热量与宏量营养目标由用户手动设置。")
        case .automatic:
            let estimate = try expenditureEstimate(
                profile: profile,
                additionalTrainingCalories: additionalTrainingCalories
            )
            bmr = estimate.bmr
            maintenance = estimate.maintenance
            assumptions = estimate.assumptions
            let adjustment = (phase.energyAdjustmentPercent ?? 0) / 100
            let calories = estimate.maintenance * (1 + adjustment)
            let rule = try phase.macroRule.validated()
            let protein = profile.currentWeightKilograms! * rule.proteinGramsPerKilogram
            let fat = calories * rule.fatEnergyProportion / energyFactors.fat
            let remainingCalories = calories - protein * energyFactors.protein - fat * energyFactors.fat
            guard remainingCalories.isFinite, remainingCalories >= 0 else {
                throw TargetEngineError.macroTargetsExceedCalories
            }
            let carbohydrate = remainingCalories / energyFactors.carbohydrate
            target = DailyTarget(
                date: date,
                calories: calories,
                proteinGrams: protein,
                carbohydrateGrams: carbohydrate,
                fatGrams: fat,
                phasePlanVersion: phase.version
            )
            assumptions.append("碳水为目标热量扣除蛋白质和脂肪后的剩余部分。")
            if abs(phase.energyAdjustmentPercent ?? 0) > 25 { warnings.append(.largeEnergyAdjustment) }
        }
        if let bmr, target.calories < bmr { warnings.append(.targetBelowEstimatedBMR) }

        return TargetResolution(
            dailyTarget: target,
            basalMetabolicRate: bmr,
            estimatedMaintenanceCalories: maintenance,
            assumptions: assumptions,
            warnings: warnings,
            usedExistingTarget: false,
            requiresConfirmation: phase.energyStrategy == .automatic
        )
    }

    public func expenditureEstimate(
        profile: UserProfile,
        additionalTrainingCalories: Double? = nil
    ) throws -> (bmr: Double, maintenance: Double, assumptions: [String]) {
        guard let age = profile.ageYears,
              let height = profile.heightCentimeters,
              let weight = profile.currentWeightKilograms else {
            throw TargetEngineError.missingBodyData
        }
        guard let sex = profile.biologicalSex else { throw TargetEngineError.missingSex }
        guard age > 0, height > 0, weight > 0 else { throw TargetEngineError.invalidBodyData }
        if let additionalTrainingCalories,
           !additionalTrainingCalories.isFinite || additionalTrainingCalories < 0 {
            throw TargetEngineError.invalidTrainingCalories
        }

        let sexConstant: Double = sex == .male ? 5 : -161
        let bmr = 10 * weight + 6.25 * height - 5 * Double(age) + sexConstant
        guard bmr.isFinite, bmr > 0 else { throw TargetEngineError.invalidBodyData }
        let maintenance = bmr * profile.activityLevel.expenditureMultiplier + (additionalTrainingCalories ?? 0)
        return (
            bmr,
            maintenance,
            [
                "基础代谢采用 Mifflin–St Jeor 公式。",
                "活动系数为 \(profile.activityLevel.expenditureMultiplier)，包含日常活动与日常训练。",
                additionalTrainingCalories.map { "额外加入明确输入的训练消耗 \($0) kcal。" } ?? "未额外叠加训练消耗。"
            ]
        )
    }
}

public extension ActivityLevel {
    var expenditureMultiplier: Double {
        switch self {
        case .sedentary: 1.2
        case .light: 1.375
        case .moderate: 1.55
        case .high: 1.725
        case .veryHigh: 1.9
        }
    }
}

@MainActor
public protocol DailyTargetStoring: AnyObject {
    func target(on date: Date) throws -> DailyTarget?
    func saveTarget(_ target: DailyTarget) throws
}

@MainActor
public final class InMemoryDailyTargetStore: DailyTargetStoring {
    private var targets: [DailyTarget] = []

    public init() {}

    public var allTargets: [DailyTarget] { targets }

    public func target(on date: Date) throws -> DailyTarget? {
        let day = Calendar.current.startOfDay(for: date)
        return targets.first { Calendar.current.isDate($0.date, inSameDayAs: day) }
    }

    public func saveTarget(_ target: DailyTarget) throws {
        if let index = targets.firstIndex(where: { $0 === target }) {
            targets[index] = target
        } else {
            targets.append(target)
        }
    }
}

@MainActor
public final class DailyTargetService {
    private let targetStore: DailyTargetStoring
    private let phaseStore: PhasePlanStoring
    private let engine: TargetEngine

    public init(targetStore: DailyTargetStoring, phaseStore: PhasePlanStoring, engine: TargetEngine = TargetEngine()) {
        self.targetStore = targetStore
        self.phaseStore = phaseStore
        self.engine = engine
    }

    public func target(
        on date: Date,
        profile: UserProfile,
        additionalTrainingCalories: Double? = nil
    ) throws -> TargetResolution {
        if let existing = try targetStore.target(on: date) {
            let expenditure = try? engine.expenditureEstimate(
                profile: profile,
                additionalTrainingCalories: additionalTrainingCalories
            )
            return TargetResolution(
                dailyTarget: existing,
                basalMetabolicRate: expenditure?.bmr,
                estimatedMaintenanceCalories: expenditure?.maintenance,
                assumptions: ["使用当天已保存的目标，不因后续档案或阶段变化而重写。"],
                warnings: [],
                usedExistingTarget: true,
                requiresConfirmation: false
            )
        }
        guard let phase = try phaseStore.allPlans().first(where: { $0.contains(date) }) else {
            throw TargetEngineError.noActivePhase
        }
        let resolution = try engine.resolve(
            profile: profile,
            phase: phase,
            date: date,
            additionalTrainingCalories: additionalTrainingCalories
        )
        if !resolution.requiresConfirmation {
            try targetStore.saveTarget(resolution.dailyTarget)
        }
        return resolution
    }

    public func reconcile(
        on date: Date = Date(),
        profile: UserProfile,
        additionalTrainingCalories: Double? = nil
    ) throws -> DailyTargetReconciliation {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: date)
        let plans = try phaseStore.allPlans()
        let backfilledDates = try backfillMissingTargets(
            through: today,
            plans: plans,
            profile: profile,
            additionalTrainingCalories: additionalTrainingCalories
        )

        if let existing = try targetStore.target(on: today) {
            return DailyTargetReconciliation(
                today: existingResolution(
                    existing,
                    profile: profile,
                    additionalTrainingCalories: additionalTrainingCalories
                ),
                backfilledDates: backfilledDates
            )
        }

        guard let phase = plans.first(where: { $0.contains(today) }) else {
            throw TargetEngineError.noActivePhase
        }
        var resolution = try engine.resolve(
            profile: profile,
            phase: phase,
            date: today,
            additionalTrainingCalories: additionalTrainingCalories
        )
        resolution.requiresConfirmation = false
        try targetStore.saveTarget(resolution.dailyTarget)
        return DailyTargetReconciliation(today: resolution, backfilledDates: backfilledDates)
    }

    @discardableResult
    public func updateTodayTarget(
        _ manualTarget: ManualNutritionTarget,
        profile: UserProfile,
        on date: Date = Date(),
        additionalTrainingCalories: Double? = nil
    ) throws -> TargetResolution {
        let validated = try manualTarget.validated()
        _ = try reconcile(
            on: date,
            profile: profile,
            additionalTrainingCalories: additionalTrainingCalories
        )
        guard let target = try targetStore.target(on: date) else {
            throw TargetEngineError.noActivePhase
        }

        target.calories = validated.calories
        target.proteinGrams = validated.proteinGrams
        target.carbohydrateGrams = validated.carbohydrateGrams
        target.fatGrams = validated.fatGrams
        target.isSingleDayOverride = true
        try targetStore.saveTarget(target)
        return existingResolution(
            target,
            profile: profile,
            additionalTrainingCalories: additionalTrainingCalories
        )
    }

    public func accept(_ resolution: TargetResolution) throws {
        try targetStore.saveTarget(resolution.dailyTarget)
    }

    private func backfillMissingTargets(
        through today: Date,
        plans: [PhasePlan],
        profile: UserProfile,
        additionalTrainingCalories: Double?
    ) throws -> [Date] {
        let calendar = Calendar.current
        let eligibleStarts = plans
            .map(\.startDate)
            .map(calendar.startOfDay(for:))
            .filter { $0 <= today }
        guard let earliestStart = eligibleStarts.min(),
              let yesterday = calendar.date(byAdding: .day, value: -1, to: today) else {
            return []
        }

        var backfilledDates: [Date] = []
        var day = earliestStart
        while day <= yesterday {
            if try targetStore.target(on: day) == nil,
               let phase = plans.first(where: { $0.contains(day) }) {
                let resolution = try engine.resolve(
                    profile: profile,
                    phase: phase,
                    date: day,
                    additionalTrainingCalories: additionalTrainingCalories
                )
                try targetStore.saveTarget(resolution.dailyTarget)
                backfilledDates.append(day)
            }
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }
        return backfilledDates
    }

    private func existingResolution(
        _ target: DailyTarget,
        profile: UserProfile,
        additionalTrainingCalories: Double?
    ) -> TargetResolution {
        let expenditure = try? engine.expenditureEstimate(
            profile: profile,
            additionalTrainingCalories: additionalTrainingCalories
        )
        return TargetResolution(
            dailyTarget: target,
            basalMetabolicRate: expenditure?.bmr,
            estimatedMaintenanceCalories: expenditure?.maintenance,
            assumptions: ["使用当天已保存的目标，不因后续档案或阶段变化而重写。"],
            warnings: [],
            usedExistingTarget: true,
            requiresConfirmation: false
        )
    }
}
