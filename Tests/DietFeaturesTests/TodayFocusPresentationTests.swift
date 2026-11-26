import Testing
import DietCore
@testable import DietFeatures

@Suite("Today focus presentation")
struct TodayFocusPresentationTests {
    @Test("Pending meal has highest priority")
    func pendingMealFirst() {
        let presentation = TodayFocusPresentation(
            hasTarget: true,
            hasPendingOrFailedMeal: true,
            recordedMealTypes: [],
            hour: 8,
            isGoalMet: true
        )
        #expect(presentation.kind == .reviewMeal)
        #expect(presentation.needsAttention)
        #expect(presentation.title == "完成待确认餐食")
    }

    @Test("Pending or failed meal overrides meal suggestions across hours", arguments: [8, 12, 19])
    func pendingBeforeMealSuggestion(hour: Int) {
        let presentation = TodayFocusPresentation(
            hasTarget: true,
            hasPendingOrFailedMeal: true,
            recordedMealTypes: [],
            hour: hour,
            isGoalMet: false
        )
        #expect(presentation.kind == .reviewMeal)
        #expect(presentation.needsAttention)
    }

    @Test("Missing target never reports completed")
    func noTarget() {
        let presentation = TodayFocusPresentation(
            hasTarget: false,
            hasPendingOrFailedMeal: false,
            recordedMealTypes: [.breakfast, .lunch, .dinner],
            hour: 19,
            isGoalMet: true
        )
        #expect(presentation.kind == .startLogging)
        #expect(presentation.kind != .completed)
        #expect(!presentation.needsAttention)
    }

    @Test("8:00 suggests breakfast when unrecorded")
    func morningSuggestsBreakfast() {
        let presentation = TodayFocusPresentation(
            hasTarget: true,
            hasPendingOrFailedMeal: false,
            recordedMealTypes: [],
            hour: 8,
            isGoalMet: false
        )
        #expect(presentation.kind == .recordMeal(.breakfast))
        #expect(presentation.title == "记录早餐")
    }

    @Test("12:00 suggests lunch when unrecorded")
    func noonSuggestsLunch() {
        let presentation = TodayFocusPresentation(
            hasTarget: true,
            hasPendingOrFailedMeal: false,
            recordedMealTypes: [.breakfast],
            hour: 12,
            isGoalMet: false
        )
        #expect(presentation.kind == .recordMeal(.lunch))
        #expect(presentation.title == "记录午餐")
    }

    @Test("19:00 suggests dinner when unrecorded")
    func eveningSuggestsDinner() {
        let presentation = TodayFocusPresentation(
            hasTarget: true,
            hasPendingOrFailedMeal: false,
            recordedMealTypes: [.breakfast, .lunch],
            hour: 19,
            isGoalMet: false
        )
        #expect(presentation.kind == .recordMeal(.dinner))
        #expect(presentation.title == "记录晚餐")
    }

    @Test("Goal met after meals reports completed")
    func goalMetAfterMeals() {
        let presentation = TodayFocusPresentation(
            hasTarget: true,
            hasPendingOrFailedMeal: false,
            recordedMealTypes: [.breakfast, .lunch, .dinner],
            hour: 19,
            isGoalMet: true
        )
        #expect(presentation.kind == .completed)
        #expect(!presentation.needsAttention)
    }

    @Test("All relevant meals recorded without meeting goal falls back to maintain")
    func maintainFallback() {
        let presentation = TodayFocusPresentation(
            hasTarget: true,
            hasPendingOrFailedMeal: false,
            recordedMealTypes: [.lunch],
            hour: 13,
            isGoalMet: false
        )
        #expect(presentation.kind == .maintain)
        #expect(!presentation.needsAttention)
    }

    @Test("Suggested meal type matches hour and recorded meals")
    func suggestedMealTypeByHour() {
        #expect(TodayFocusPresentation.suggestedMealType(for: 8, recorded: []) == .breakfast)
        #expect(TodayFocusPresentation.suggestedMealType(for: 8, recorded: [.breakfast]) == .snack)
        #expect(TodayFocusPresentation.suggestedMealType(for: 12, recorded: [.breakfast]) == .lunch)
        #expect(TodayFocusPresentation.suggestedMealType(for: 12, recorded: [.breakfast, .lunch]) == .snack)
        #expect(TodayFocusPresentation.suggestedMealType(for: 19, recorded: [.breakfast, .lunch]) == .dinner)
        #expect(TodayFocusPresentation.suggestedMealType(for: 19, recorded: [.dinner]) == .snack)
        #expect(TodayFocusPresentation.suggestedMealType(for: 23, recorded: []) == .snack)
        #expect(TodayFocusPresentation.suggestedMealType(for: 2, recorded: []) == .snack)
    }
}
