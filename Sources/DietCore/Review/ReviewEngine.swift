import Foundation

public struct WeeklyReviewResult {
    public var overview: TrendsOverview
    public var proposal: AdjustmentProposal?
    public var explanation: String

    public init(overview: TrendsOverview, proposal: AdjustmentProposal?, explanation: String) {
        self.overview = overview
        self.proposal = proposal
        self.explanation = explanation
    }
}

public struct ReviewEngine {
    public var minimumCompleteDays = 5
    public var minimumWeightSpanDays = 5
    public var deviationThreshold = 0.15
    public var significantWeightChange = 0.75
    public var maximumAdjustment = 0.05

    public init() {}

    public func singleDayMessage(for day: DailyTrend) -> String? {
        guard day.hasConfirmedEntries, let target = day.target, target.calories > 0 else { return nil }
        guard day.intake.isComplete else { return "先补全今天无法计算的食物，再评价摄入是否足够。" }
        let ratio = day.intake.calories / target.calories
        if ratio < 0.8 { return "今天已知摄入低于目标，可在今天剩余时间按偏好补充，不需要自动修改明天目标。" }
        if ratio > 1.2 { return "今天已知摄入高于目标，正常记录即可，不建议禁食或用惩罚性运动补偿。" }
        return nil
    }

    public func review(
        days: [DailyTrend],
        overview: TrendsOverview,
        endingOn endDate: Date
    ) -> WeeklyReviewResult {
        let eligible = days.filter { $0.isEligibleForTargetCompletion && $0.target!.calories > 0 }
        guard eligible.count >= minimumCompleteDays else {
            return WeeklyReviewResult(
                overview: overview,
                proposal: nil,
                explanation: "至少需要 \(minimumCompleteDays) 个营养完整且有目标的记录日，当前为 \(eligible.count) 天，不生成调整建议。"
            )
        }
        guard let weightChange = overview.weightChangeKilograms,
              overview.weightSpanDays >= minimumWeightSpanDays else {
            return WeeklyReviewResult(
                overview: overview,
                proposal: nil,
                explanation: "记录天数已满足，但还需要至少 \(minimumWeightSpanDays) 天跨度的两次体重记录。"
            )
        }
        let averageIntake = eligible.reduce(0.0) { $0 + $1.intake.calories } / Double(eligible.count)
        let averageTarget = eligible.reduce(0.0) { $0 + $1.target!.calories } / Double(eligible.count)
        let ratio = averageIntake / averageTarget
        let direction: Double
        if ratio < 1 - deviationThreshold, weightChange <= -significantWeightChange {
            direction = 1
        } else if ratio > 1 + deviationThreshold, weightChange >= significantWeightChange {
            direction = -1
        } else {
            return WeeklyReviewResult(
                overview: overview,
                proposal: nil,
                explanation: "摄入偏差和体重变化没有同时达到调整条件，保持当前方案并继续观察。"
            )
        }

        guard let latestTarget = eligible.sorted(by: { $0.date < $1.date }).last?.target else {
            return WeeklyReviewResult(overview: overview, proposal: nil, explanation: "没有可用于调整的目标基准。")
        }
        let newCalories = latestTarget.calories * (1 + direction * maximumAdjustment)
        let newCarbohydrate = latestTarget.carbohydrateGrams + (newCalories - latestTarget.calories) / 4
        guard newCalories > 0, newCarbohydrate >= 0 else {
            return WeeklyReviewResult(overview: overview, proposal: nil, explanation: "计算出的调整不合理，本次不生成建议。")
        }
        let effectiveDate = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: endDate)) ?? endDate
        let summary = "完整记录 \(eligible.count) 天，平均摄入/目标为 \(Int((ratio * 100).rounded()))%，体重在 \(overview.weightSpanDays) 天变化 \(weightChange) kg；建议仅调整 \(Int(direction * maximumAdjustment * 100))%。"
        let proposal = AdjustmentProposal(
            triggerSummary: summary,
            effectiveDate: effectiveDate,
            oldCalories: latestTarget.calories,
            newCalories: newCalories,
            oldProteinGrams: latestTarget.proteinGrams,
            newProteinGrams: latestTarget.proteinGrams,
            oldCarbohydrateGrams: latestTarget.carbohydrateGrams,
            newCarbohydrateGrams: newCarbohydrate,
            oldFatGrams: latestTarget.fatGrams,
            newFatGrams: latestTarget.fatGrams
        )
        return WeeklyReviewResult(
            overview: overview,
            proposal: proposal,
            explanation: "条件已满足，但建议只有在用户确认后才会创建新阶段版本。"
        )
    }
}

public enum AdjustmentError: LocalizedError, Equatable {
    case alreadyResolved
    case incompleteProposal

    public var errorDescription: String? {
        switch self {
        case .alreadyResolved: "该调整建议已经处理。"
        case .incompleteProposal: "调整建议缺少完整的新旧目标。"
        }
    }
}

@MainActor
public protocol AdjustmentProposalStoring: AnyObject {
    func allProposals() throws -> [AdjustmentProposal]
    func saveProposal(_ proposal: AdjustmentProposal) throws
}

@MainActor
public final class InMemoryAdjustmentProposalStore: AdjustmentProposalStoring {
    private var proposals: [AdjustmentProposal] = []
    public init() {}
    public func allProposals() throws -> [AdjustmentProposal] { proposals }
    public func saveProposal(_ proposal: AdjustmentProposal) throws {
        if let index = proposals.firstIndex(where: { $0 === proposal }) {
            proposals[index] = proposal
        } else {
            proposals.append(proposal)
        }
    }
}

@MainActor
public final class AdjustmentService {
    private let store: AdjustmentProposalStoring
    private let phaseStore: PhasePlanStoring

    public init(store: AdjustmentProposalStoring, phaseStore: PhasePlanStoring) {
        self.store = store
        self.phaseStore = phaseStore
    }

    @discardableResult
    public func accept(_ proposal: AdjustmentProposal, phaseType: PhaseType, now: Date = Date()) throws -> PhasePlan {
        guard proposal.status == .pending else { throw AdjustmentError.alreadyResolved }
        guard let oldCalories = proposal.oldCalories,
              let newCalories = proposal.newCalories,
              let newProtein = proposal.newProteinGrams,
              let newCarbohydrate = proposal.newCarbohydrateGrams,
              let newFat = proposal.newFatGrams else {
            throw AdjustmentError.incompleteProposal
        }
        _ = oldCalories
        let target = ManualNutritionTarget(
            calories: newCalories,
            proteinGrams: newProtein,
            carbohydrateGrams: newCarbohydrate,
            fatGrams: newFat
        )
        let plan = try PhasePlanService(store: phaseStore).startNewPhase(PhasePlanInput(
            phaseType: phaseType,
            startDate: proposal.effectiveDate,
            energyStrategy: .manual,
            manualTarget: target
        ))
        proposal.status = .accepted
        proposal.resolvedAt = now
        try store.saveProposal(proposal)
        return plan
    }

    public func reject(_ proposal: AdjustmentProposal, now: Date = Date()) throws {
        guard proposal.status == .pending else { throw AdjustmentError.alreadyResolved }
        proposal.status = .rejected
        proposal.resolvedAt = now
        try store.saveProposal(proposal)
    }
}
