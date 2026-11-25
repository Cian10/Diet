import Testing
import Foundation
@testable import DietCore

@Suite("Diet analysis service")
@MainActor
final class DietAnalysisServiceTests {
    @Test("All ranges include today and use exact local-calendar boundaries", arguments: DietAnalysisRange.allCases)
    func windowBoundaries(range: DietAnalysisRange) throws {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 25, hour: 12, calendar: calendar)
        let todayStart = calendar.startOfDay(for: now)
        let start = try #require(calendar.date(byAdding: .day, value: -(range.days - 1), to: todayStart))
        let tomorowStart = try #require(calendar.date(byAdding: .day, value: 1, to: todayStart))
        let mealStore = InMemoryMealEntryStore()
        let targetStore = InMemoryDailyTargetStore()
        let provider = AnalysisLLMProvider()

        try mealStore.saveEntry(MealEntry(consumedAt: start, status: .confirmed, originalText: "范围起点"))
        try mealStore.saveEntry(MealEntry(consumedAt: now, status: .confirmed, originalText: "今天记录"))

        let service = DietAnalysisService(
            mealStore: mealStore,
            targetStore: targetStore,
            llmProvider: provider,
            calendar: calendar
        )
        let request = try service.prepare(range: range, now: now)

        #expect(request.range == range)
        #expect(request.windowStart == start)
        #expect(request.windowEnd == tomorowStart)
        #expect(request.confirmedEntryCount == 2)
        #expect(request.userPrompt.contains("2026-11-25"))
        #expect(request.userPrompt.contains("范围起点"))
        #expect(request.userPrompt.contains("今天记录"))
    }

    @Test("Only confirmed in-window entries are uploaded")
    func filtersStatusAndWindow() throws {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 25, hour: 12, calendar: calendar)
        let range = DietAnalysisRange.sevenDays
        let todayStart = calendar.startOfDay(for: now)
        let start = try #require(calendar.date(byAdding: .day, value: -6, to: todayStart))
        let beforeWindow = start.addingTimeInterval(-1)
        let mealStore = InMemoryMealEntryStore()
        let targetStore = InMemoryDailyTargetStore()
        let provider = AnalysisLLMProvider()

        let included = MealEntry(
            consumedAt: now,
            mealType: .lunch,
            status: .confirmed,
            originalText: "鸡胸肉饭",
            localImagePath: "/private/user/meal-photo.jpg",
            note: "少油",
            components: [
                EntryComponent(
                    displayName: "鸡胸肉饭",
                    originalQuantity: 1,
                    originalUnit: "份",
                    nutritionSnapshot: NutritionSnapshot(
                        basisQuantity: 1,
                        basisUnit: .serving,
                        calories: 520,
                        proteinGrams: 35,
                        carbohydrateGrams: 65,
                        fatGrams: 12,
                        source: .verified
                    )
                )
            ]
        )
        try mealStore.saveEntry(included)
        try mealStore.saveEntry(MealEntry(consumedAt: now, status: .draft, originalText: "草稿炸鸡"))
        try mealStore.saveEntry(MealEntry(consumedAt: now, status: .failed, originalText: "失败拉面"))
        try mealStore.saveEntry(MealEntry(consumedAt: beforeWindow, status: .confirmed, originalText: "范围外火锅"))

        let target = DailyTarget(
            date: now,
            calories: 2100,
            proteinGrams: 140,
            carbohydrateGrams: 220,
            fatGrams: 70
        )
        try targetStore.saveTarget(target)

        let service = DietAnalysisService(
            mealStore: mealStore,
            targetStore: targetStore,
            llmProvider: provider,
            calendar: calendar
        )
        let request = try service.prepare(range: range, now: now)

        #expect(request.confirmedEntryCount == 1)
        #expect(request.userPrompt.contains("鸡胸肉饭"))
        #expect(request.userPrompt.contains("少油"))
        #expect(request.userPrompt.contains("已保存目标"))
        #expect(request.userPrompt.contains("2100"))
        #expect(request.userPrompt.contains("本地汇总（完整）"))
        #expect(!request.userPrompt.contains("草稿炸鸡"))
        #expect(!request.userPrompt.contains("失败拉面"))
        #expect(!request.userPrompt.contains("范围外火锅"))
        #expect(!request.userPrompt.contains("/private/user/meal-photo.jpg"))
        #expect(!request.userPrompt.contains("meal-photo.jpg"))
    }

    @Test("Unknown nutrition and missing information are explicit, not treated as zero")
    func unknownNutritionAndMissingInformation() throws {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 25, hour: 19, calendar: calendar)
        let mealStore = InMemoryMealEntryStore()
        let targetStore = InMemoryDailyTargetStore()
        let provider = AnalysisLLMProvider()

        let unknownComponent = EntryComponent(
            displayName: "来源不明的配菜",
            originalQuantity: 1,
            originalUnit: "份",
            nutritionSnapshot: nil
        )
        let entry = MealEntry(
            consumedAt: now,
            mealType: .dinner,
            status: .confirmed,
            originalText: "晚餐",
            components: [unknownComponent],
            estimationRecords: [
                EstimationRecord(
                    inputType: .manual,
                    rawStructuredResult: "{}",
                    missingInformation: ["配菜重量未知"]
                )
            ]
        )
        try mealStore.saveEntry(entry)

        let service = DietAnalysisService(
            mealStore: mealStore,
            targetStore: targetStore,
            llmProvider: provider,
            calendar: calendar
        )
        let request = try service.prepare(range: .sevenDays, now: now)

        #expect(request.userPrompt.contains("本地汇总（已知部分，不完整）"))
        #expect(request.userPrompt.contains("营养数据未知"))
        #expect(request.userPrompt.contains("配菜重量未知"))
        #expect(request.userPrompt.contains("未按零处理"))
        #expect(request.userPrompt.contains("已保存目标：无"))
    }

    @Test("No confirmed entries fails before creating an LLM client")
    func noConfirmedEntriesDoesNotCallLLM() async throws {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 25, hour: 12, calendar: calendar)
        let mealStore = InMemoryMealEntryStore()
        let targetStore = InMemoryDailyTargetStore()
        let provider = AnalysisLLMProvider()

        try mealStore.saveEntry(MealEntry(consumedAt: now, status: .draft, originalText: "未确认食物"))
        try mealStore.saveEntry(MealEntry(consumedAt: now, status: .failed, originalText: "失败食物"))

        let service = DietAnalysisService(
            mealStore: mealStore,
            targetStore: targetStore,
            llmProvider: provider,
            calendar: calendar
        )

        await #expect(throws: DietAnalysisError.noConfirmedEntries) {
            _ = try await service.analyze(range: .sevenDays, now: now)
        }
        #expect(provider.clientRequestCount == 0)
        #expect(provider.textRequests.isEmpty)
    }

    @Test("Analysis calls text generation and preserves readable trailing whitespace trimming")
    func textGeneration() async throws {
        let calendar = testCalendar()
        let now = testDate(2026, 11, 25, hour: 12, calendar: calendar)
        let mealStore = InMemoryMealEntryStore()
        let targetStore = InMemoryDailyTargetStore()
        let provider = AnalysisLLMProvider()
        provider.result = .success("  \n建议保持规律记录。\n ")

        try mealStore.saveEntry(MealEntry(consumedAt: now, status: .confirmed, originalText: "早餐"))
        let service = DietAnalysisService(
            mealStore: mealStore,
            targetStore: targetStore,
            llmProvider: provider,
            calendar: calendar
        )

        let report = try await service.analyze(range: .sevenDays, now: now)

        #expect(report == "建议保持规律记录。")
        let request = try #require(provider.textRequests.first)
        #expect(request.systemPrompt.contains("600–900"))
        #expect(request.systemPrompt.contains("不提供疾病诊断"))
        #expect(request.userPrompt.contains("早餐"))
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
private final class AnalysisLLMProvider: LLMClientProviding {
    var result: Result<String, Error> = .success("饮食分析结果")
    var clientRequestCount = 0
    var textRequests: [TextGenerationRequest] = []

    func client() throws -> any LLMClient {
        clientRequestCount += 1
        return AnalysisLLMClient(provider: self)
    }
}

@MainActor
private final class AnalysisLLMClient: LLMClient {
    let provider: AnalysisLLMProvider

    init(provider: AnalysisLLMProvider) {
        self.provider = provider
    }

    func analyzeFood(_ request: FoodUnderstandingRequest) async throws -> FoodUnderstandingResult {
        throw LLMError.emptyResult
    }

    func generateText(_ request: TextGenerationRequest) async throws -> String {
        provider.textRequests.append(request)
        return try provider.result.get()
    }
}
