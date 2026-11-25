import Testing
import Foundation
@testable import DietCore

@Suite("FoodLoggingService")
@MainActor
final class FoodLoggingServiceTests {
    private let store = InMemoryMealEntryStore()
    private let provider = StubLLMClientProvider()
    private let service: FoodLoggingService

    init() {
        service = FoodLoggingService(store: store, clientProvider: provider)
    }

    @Test("Text analysis creates a draft and confirmation enables daily totals")
    func textToConfirmation() async throws {
        provider.result = .success(Self.result())
        let entry = try await service.analyzeText("一个汉堡", consumedAt: Date(), mealType: .lunch)
        #expect(entry.status == .draft)
        #expect(entry.originalText == "一个汉堡")
        #expect(entry.components.count == 1)
        #expect(entry.components.first?.nutritionSnapshot?.source == .modelEstimate)
        #expect(NutritionCalculator().dailyNutrition(entries: [entry], on: Date()).calories == 0)

        try service.confirm(entry)
        try service.confirm(entry)
        #expect(entry.status == .confirmed)
        #expect(try store.allEntries().count == 1)
        #expect(NutritionCalculator().dailyNutrition(entries: [entry], on: Date()).calories == 500)
    }

    @Test("Failure preserves original text and retry reuses the entry")
    func failureAndRetry() async throws {
        provider.result = .failure(LLMError.networkUnavailable)
        let entry = try service.createManualEntry(consumedAt: Date(), mealType: .dinner)
        await #expect(throws: LLMError.networkUnavailable) {
            _ = try await self.service.analyzeText(
                "一份鸡胸肉",
                consumedAt: entry.consumedAt,
                mealType: entry.mealType,
                existingEntry: entry
            )
        }
        #expect(entry.status == .failed)
        #expect(entry.originalText == "一份鸡胸肉")

        provider.result = .success(Self.result())
        let retried = try await service.analyzeText(
            "一份鸡胸肉",
            consumedAt: entry.consumedAt,
            mealType: entry.mealType,
            existingEntry: entry
        )
        #expect(retried === entry)
        #expect(entry.status == .draft)
        #expect(provider.requests.count == 2)
        #expect(try store.allEntries().count == 1)
    }

    @Test("Incomplete nutrition cannot be silently confirmed")
    func incompleteConfirmation() async throws {
        var result = Self.result()
        result.items[0].nutrition = nil
        result.items[0].missingInformation = ["缺少营养信息"]
        provider.result = .success(result)
        let entry = try await service.analyzeText("未知食物", consumedAt: Date(), mealType: .lunch)
        #expect(entry.estimationRecords.first?.quality == .low)
        #expect(throws: FoodLoggingError.incompleteComponent("汉堡", "该食物缺少营养数据，不能按零摄入处理。")) {
            try self.service.confirm(entry)
        }
        #expect(entry.status == .draft)
    }

    @Test("Clarification question and assumptions stay with the draft")
    func clarificationMetadata() async throws {
        var result = Self.result()
        result.needsClarification = true
        result.clarificationQuestion = "汉堡的具体名称是什么？"
        result.items[0].assumptions = ["普通尺寸"]
        provider.result = .success(result)
        let entry = try await service.analyzeText("麦当劳汉堡", consumedAt: Date(), mealType: .lunch)
        #expect(entry.estimationRecords.first?.clarificationQuestion == "汉堡的具体名称是什么？")
        #expect(entry.estimationRecords.first?.assumptions == ["普通尺寸"])
    }

    @Test("Image analysis stores local path and multiple candidates")
    func imageAnalysis() async throws {
        var result = Self.result()
        result.items.append(result.items[0])
        provider.result = .success(result)
        let entry = try await service.analyzeImage(
            uploadData: Data([1, 2, 3]),
            localImagePath: "meal.jpg",
            consumedAt: Date(),
            mealType: .dinner
        )
        #expect(entry.localImagePath == "meal.jpg")
        #expect(entry.components.count == 2)
        #expect(provider.requests.last?.imageData == Data([1, 2, 3]))
        #expect(entry.estimationRecords.first?.inputType == .image)
    }

    private static func result() -> FoodUnderstandingResult {
        FoodUnderstandingResult(items: [FoodCandidate(
            name: "汉堡",
            quantity: 1,
            unit: "个",
            estimatedGramsRange: EstimatedGramsRange(lower: 200, upper: 300),
            nutritionBasis: "常见配方",
            nutrition: NutritionCandidate(
                basisQuantity: 1,
                basisUnit: "serving",
                calories: 500,
                proteinGrams: 25,
                carbohydrateGrams: 50,
                fatGrams: 20
            ),
            assumptions: [],
            missingInformation: []
        )])
    }
}

@MainActor
private final class StubLLMClientProvider: LLMClientProviding {
    var result: Result<FoodUnderstandingResult, Error> = .failure(LLMError.emptyResult)
    var requests: [FoodUnderstandingRequest] = []

    func client() throws -> any LLMClient { StubClient(provider: self) }
}

@MainActor
private final class StubClient: LLMClient {
    let provider: StubLLMClientProvider
    init(provider: StubLLMClientProvider) { self.provider = provider }
    func analyzeFood(_ request: FoodUnderstandingRequest) async throws -> FoodUnderstandingResult {
        provider.requests.append(request)
        return try provider.result.get()
    }
}
