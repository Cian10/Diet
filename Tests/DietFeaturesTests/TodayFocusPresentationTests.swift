import Testing
@testable import DietFeatures

@Suite("Today focus presentation")
struct TodayFocusPresentationTests {
    @Test("Pending meal has highest priority")
    func pendingMealFirst() {
        let presentation = TodayFocusPresentation(
            hasTarget: true,
            hasPendingOrFailedMeal: true,
            hasDinner: false,
            isGoalMet: true
        )
        #expect(presentation.kind == .reviewMeal)
        #expect(presentation.needsAttention)
    }

    @Test("Pending or failed meal comes before dinner guidance", arguments: [true, false])
    func pendingBeforeDinner(hasDinner: Bool) {
        let presentation = TodayFocusPresentation(
            hasTarget: true,
            hasPendingOrFailedMeal: true,
            hasDinner: hasDinner,
            isGoalMet: false
        )
        #expect(presentation.kind == .reviewMeal)
    }

    @Test("Confirmed target without dinner suggests dinner")
    func dinner() {
        let presentation = TodayFocusPresentation(
            hasTarget: true,
            hasPendingOrFailedMeal: false,
            hasDinner: false,
            isGoalMet: false
        )
        #expect(presentation.kind == .recordDinner)
    }

    @Test("Goal met produces completed state only with a target")
    func completed() {
        let presentation = TodayFocusPresentation(
            hasTarget: true,
            hasPendingOrFailedMeal: false,
            hasDinner: true,
            isGoalMet: true
        )
        #expect(presentation.kind == .completed)
    }

    @Test("Missing target never produces false completion")
    func noTarget() {
        let presentation = TodayFocusPresentation(
            hasTarget: false,
            hasPendingOrFailedMeal: false,
            hasDinner: true,
            isGoalMet: true
        )
        #expect(presentation.kind == .startLogging)
        #expect(presentation.kind != .completed)
    }
}
