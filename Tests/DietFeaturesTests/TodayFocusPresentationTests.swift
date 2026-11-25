import Testing
@testable import DietFeatures

@Suite("Today focus presentation")
struct TodayFocusPresentationTests {
    @Test("Target confirmation has highest priority")
    func targetFirst() {
        let presentation = TodayFocusPresentation(
            hasTarget: true,
            targetRequiresConfirmation: true,
            hasPendingOrFailedMeal: true,
            hasDinner: false,
            isGoalMet: true
        )
        #expect(presentation.kind == .confirmTarget)
    }

    @Test("Pending or failed meal comes before dinner guidance", arguments: [true, false])
    func pendingBeforeDinner(hasDinner: Bool) {
        let presentation = TodayFocusPresentation(
            hasTarget: true,
            targetRequiresConfirmation: false,
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
            targetRequiresConfirmation: false,
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
            targetRequiresConfirmation: false,
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
            targetRequiresConfirmation: false,
            hasPendingOrFailedMeal: false,
            hasDinner: true,
            isGoalMet: true
        )
        #expect(presentation.kind == .startLogging)
        #expect(presentation.kind != .completed)
    }
}
