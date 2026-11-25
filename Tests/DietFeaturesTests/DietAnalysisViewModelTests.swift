import Testing
import Foundation
@testable import DietFeatures
import DietCore

@Suite("Diet analysis view model")
@MainActor
final class DietAnalysisViewModelTests {
    @Test("Defaults to seven days and range changes do not request automatically")
    func rangeSelectionIsExplicit() {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 25, hour: 12, calendar: calendar)
        let meals = InMemoryMealEntryStore()
        let targets = InMemoryDailyTargetStore()
        let provider = ViewModelLLMProvider()
        let viewModel = makeViewModel(
            meals: meals,
            targets: targets,
            provider: provider,
            calendar: calendar,
            now: now
        )

        #expect(viewModel.selectedRange == .sevenDays)
        viewModel.selectedRange = .thirtyDays
        viewModel.rangeDidChange()
        #expect(provider.textRequestCount == 0)
        #expect(viewModel.isLoading == false)
    }

    @Test("Loading state prevents duplicate requests and successful report replaces state")
    func loadingAndSuccess() async throws {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 25, hour: 12, calendar: calendar)
        let meals = InMemoryMealEntryStore()
        let targets = InMemoryDailyTargetStore()
        let provider = ViewModelLLMProvider()
        provider.delayNanoseconds = 100_000_000
        provider.results = [.success("分析完成")]

        try meals.saveEntry(confirmedMeal(at: now))
        let viewModel = makeViewModel(
            meals: meals,
            targets: targets,
            provider: provider,
            calendar: calendar,
            now: now
        )

        let firstTask = Task { await viewModel.analyze() }
        while !viewModel.isLoading {
            await Task.yield()
        }
        #expect(viewModel.isLoading)
        #expect(viewModel.resultText == nil)

        await viewModel.analyze()
        await firstTask.value

        #expect(provider.textRequestCount == 1)
        #expect(viewModel.isLoading == false)
        #expect(viewModel.resultText == "分析完成")
        #expect(viewModel.lastCompletedRange == .sevenDays)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.hasNoConfirmedEntries == false)
    }

    @Test("Failure exposes an error and a later retry can succeed")
    func failureAndRetry() async throws {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 25, hour: 12, calendar: calendar)
        let meals = InMemoryMealEntryStore()
        let targets = InMemoryDailyTargetStore()
        let provider = ViewModelLLMProvider()
        provider.results = [.failure(LLMError.networkUnavailable), .success("重试成功")]

        try meals.saveEntry(confirmedMeal(at: now))
        let viewModel = makeViewModel(
            meals: meals,
            targets: targets,
            provider: provider,
            calendar: calendar,
            now: now
        )

        await viewModel.analyze()
        #expect(viewModel.isLoading == false)
        #expect(viewModel.errorMessage == LLMError.networkUnavailable.localizedDescription)
        #expect(viewModel.resultText == nil)

        await viewModel.analyze()
        #expect(provider.textRequestCount == 2)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.resultText == "重试成功")
        #expect(viewModel.lastCompletedRange == .sevenDays)
    }

    @Test("No confirmed records shows an empty state without calling the LLM")
    func noConfirmedRecords() async throws {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 25, hour: 12, calendar: calendar)
        let meals = InMemoryMealEntryStore()
        let targets = InMemoryDailyTargetStore()
        let provider = ViewModelLLMProvider()

        try meals.saveEntry(MealEntry(consumedAt: now, status: .draft, originalText: "草稿"))
        try meals.saveEntry(MealEntry(consumedAt: now, status: .failed, originalText: "失败"))
        let viewModel = makeViewModel(
            meals: meals,
            targets: targets,
            provider: provider,
            calendar: calendar,
            now: now
        )

        await viewModel.analyze()

        #expect(provider.clientRequestCount == 0)
        #expect(provider.textRequestCount == 0)
        #expect(viewModel.hasNoConfirmedEntries)
        #expect(viewModel.errorMessage == nil)
        #expect(viewModel.resultText == nil)
    }

    private func makeViewModel(
        meals: InMemoryMealEntryStore,
        targets: InMemoryDailyTargetStore,
        provider: ViewModelLLMProvider,
        calendar: Calendar,
        now: Date
    ) -> DietAnalysisViewModel {
        DietAnalysisViewModel(
            mealStore: meals,
            targetStore: targets,
            llmProvider: provider,
            calendar: calendar,
            nowProvider: { now }
        )
    }

    private func confirmedMeal(at date: Date) -> MealEntry {
        MealEntry(
            consumedAt: date,
            mealType: .lunch,
            status: .confirmed,
            originalText: "鸡胸肉沙拉",
            components: [
                EntryComponent(
                    displayName: "鸡胸肉沙拉",
                    originalQuantity: 1,
                    originalUnit: "份",
                    nutritionSnapshot: NutritionSnapshot(
                        basisQuantity: 1,
                        basisUnit: .serving,
                        calories: 450,
                        proteinGrams: 38,
                        carbohydrateGrams: 32,
                        fatGrams: 16,
                        source: .verified
                    )
                )
            ]
        )
    }

    private func testCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func testDate(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int,
        calendar: Calendar
    ) -> Date {
        calendar.date(from: DateComponents(
            timeZone: calendar.timeZone,
            year: year,
            month: month,
            day: day,
            hour: hour
        ))!
    }
}

@MainActor
private final class ViewModelLLMProvider: LLMClientProviding {
    var results: [Result<String, Error>] = [.success("分析结果")]
    var delayNanoseconds: UInt64 = 0
    var clientRequestCount = 0
    var textRequestCount = 0

    func client() throws -> any LLMClient {
        clientRequestCount += 1
        return ViewModelLLMClient(provider: self)
    }
}

@MainActor
private final class ViewModelLLMClient: LLMClient {
    let provider: ViewModelLLMProvider

    init(provider: ViewModelLLMProvider) {
        self.provider = provider
    }

    func analyzeFood(_ request: FoodUnderstandingRequest) async throws -> FoodUnderstandingResult {
        throw LLMError.emptyResult
    }

    func generateText(_ request: TextGenerationRequest) async throws -> String {
        provider.textRequestCount += 1
        if provider.delayNanoseconds > 0 {
            try await Task.sleep(nanoseconds: provider.delayNanoseconds)
        }
        guard !provider.results.isEmpty else { throw LLMError.emptyResult }
        return try provider.results.removeFirst().get()
    }
}
