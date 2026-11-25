import Testing
import Foundation
@testable import DietCore

@Suite("ReviewEngine and adjustments")
@MainActor
final class ReviewEngineTests {
    @Test("Five complete days alone do not trigger adjustment without weight trend")
    func missingWeight() {
        let result = ReviewEngine().review(days: days(count: 5), overview: overview(weight: nil, span: 0), endingOn: Date())
        #expect(result.proposal == nil)
        #expect(result.explanation.contains("体重") == true)
    }

    @Test("Under-intake plus meaningful weight loss creates only a pending five-percent proposal")
    func pendingProposal() {
        let end = Date()
        let result = ReviewEngine().review(days: days(count: 5, ratio: 0.75), overview: overview(weight: -1, span: 6), endingOn: end)
        let proposal = try? #require(result.proposal)
        #expect(proposal?.status == .pending)
        #expect(proposal?.oldCalories == 2000)
        #expect(proposal?.newCalories == 2100)
        #expect(proposal?.newCarbohydrateGrams == 225)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: end))
        #expect(proposal?.effectiveDate == tomorrow)
    }

    @Test("Under-intake with weight gain does not trigger adjustment")
    func contradictoryTrend() {
        let result = ReviewEngine().review(days: days(count: 5, ratio: 0.75), overview: overview(weight: 1, span: 6), endingOn: Date())
        #expect(result.proposal == nil)
    }

    @Test("Single-day excess creates only neutral feedback")
    func singleDay() {
        let day = dayTrend(date: Date(), calories: 2600, target: 2000)
        let message = ReviewEngine().singleDayMessage(for: day)
        #expect(message?.contains("不建议禁食") == true)
    }

    @Test("Only acceptance creates a future phase version; rejection does not")
    func acceptAndReject() throws {
        let phaseStore = InMemoryPhasePlanStore()
        let proposalStore = InMemoryAdjustmentProposalStore()
        _ = try PhasePlanService(store: phaseStore).startNewPhase(PhasePlanInput(
            phaseType: .cutting,
            startDate: Date(),
            energyStrategy: .manual,
            manualTarget: ManualNutritionTarget(calories: 2000, proteinGrams: 150, carbohydrateGrams: 200, fatGrams: 60)
        ))
        let service = AdjustmentService(store: proposalStore, phaseStore: phaseStore)
        let proposal = ReviewEngine().review(
            days: days(count: 5, ratio: 0.75),
            overview: overview(weight: -1, span: 6),
            endingOn: Date()
        ).proposal!
        let accepted = try service.accept(proposal, phaseType: .cutting)
        #expect(accepted.version == 2)
        #expect(accepted.manualTarget?.calories == 2100)
        #expect(proposal.status == .accepted)

        let second = AdjustmentProposal(
            triggerSummary: "test",
            effectiveDate: Calendar.current.date(byAdding: .day, value: 7, to: Date())!,
            oldCalories: 2000,
            newCalories: 1900,
            oldProteinGrams: 150,
            newProteinGrams: 150,
            oldCarbohydrateGrams: 200,
            newCarbohydrateGrams: 175,
            oldFatGrams: 60,
            newFatGrams: 60
        )
        try service.reject(second)
        #expect(second.status == .rejected)
        #expect(try phaseStore.allPlans().count == 2)
    }

    private func days(count: Int, ratio: Double = 0.75) -> [DailyTrend] {
        (0..<7).map { index in
            let date = Calendar.current.date(byAdding: .day, value: index - 6, to: Date())!
            if index < count {
                return dayTrend(date: date, calories: 2000 * ratio, target: 2000)
            }
            return DailyTrend(
                date: date,
                intake: NutritionTotals(),
                target: nil,
                phaseType: .cutting,
                hasConfirmedEntries: false
            )
        }
    }

    private func dayTrend(date: Date, calories: Double, target: Double) -> DailyTrend {
        DailyTrend(
            date: date,
            intake: NutritionTotals(calories: calories, proteinGrams: 100, carbohydrateGrams: 100, fatGrams: 50),
            target: DailyTarget(date: date, calories: target, proteinGrams: 150, carbohydrateGrams: 200, fatGrams: 60),
            phaseType: .cutting,
            hasConfirmedEntries: true
        )
    }

    private func overview(weight: Double?, span: Int) -> TrendsOverview {
        TrendsOverview(
            recordedDays: 5,
            averageCalories: 1500,
            targetCompletionRate: 0,
            weightChangeKilograms: weight,
            weightSpanDays: span,
            hasSufficientData: true
        )
    }
}
