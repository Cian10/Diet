import Foundation

public enum FoodLoggingError: LocalizedError, Equatable {
    case emptyInput
    case emptyMeal
    case missingImage
    case incompleteComponent(String, String)

    public var errorDescription: String? {
        switch self {
        case .emptyInput: "请输入饮食描述，或改为手动记录。"
        case .emptyMeal: "请至少添加一种食物后再确认。"
        case .missingImage: "缺少可分析的图片，请重新选择。"
        case .incompleteComponent(let name, let reason): "“\(name)”尚不能确认：\(reason)"
        }
    }
}

@MainActor
public protocol MealEntryStoring: AnyObject {
    func allEntries() throws -> [MealEntry]
    func saveEntry(_ entry: MealEntry) throws
    func replaceAnalysis(for entry: MealEntry, components: [EntryComponent], records: [EstimationRecord]) throws
    func replaceComponents(for entry: MealEntry, components: [EntryComponent]) throws
    func deleteEntry(_ entry: MealEntry) throws
}

@MainActor
public final class InMemoryMealEntryStore: MealEntryStoring {
    private var entries: [MealEntry] = []

    public init() {}

    public func allEntries() throws -> [MealEntry] {
        entries.sorted { $0.consumedAt > $1.consumedAt }
    }

    public func saveEntry(_ entry: MealEntry) throws {
        if let index = entries.firstIndex(where: { $0 === entry }) {
            entries[index] = entry
        } else {
            entries.append(entry)
        }
    }

    public func replaceAnalysis(for entry: MealEntry, components: [EntryComponent], records: [EstimationRecord]) throws {
        entry.components = components
        entry.estimationRecords = records
        try saveEntry(entry)
    }

    public func replaceComponents(for entry: MealEntry, components: [EntryComponent]) throws {
        entry.components = components
        try saveEntry(entry)
    }

    public func deleteEntry(_ entry: MealEntry) throws {
        entries.removeAll { $0 === entry }
    }
}

@MainActor
public final class FoodLoggingService {
    private let store: MealEntryStoring
    private let clientProvider: LLMClientProviding
    private let calculator: NutritionCalculator

    public init(store: MealEntryStoring, clientProvider: LLMClientProviding, calculator: NutritionCalculator = NutritionCalculator()) {
        self.store = store
        self.clientProvider = clientProvider
        self.calculator = calculator
    }

    public func createManualEntry(consumedAt: Date = Date(), mealType: MealType = .other) throws -> MealEntry {
        let entry = MealEntry(consumedAt: consumedAt, mealType: mealType, status: .draft)
        try store.saveEntry(entry)
        return entry
    }

    public func analyzeText(
        _ text: String,
        consumedAt: Date = Date(),
        mealType: MealType = .other,
        existingEntry: MealEntry? = nil
    ) async throws -> MealEntry {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw FoodLoggingError.emptyInput }
        let entry = existingEntry ?? MealEntry(
            consumedAt: consumedAt,
            mealType: mealType,
            status: .draft,
            originalText: trimmed
        )
        entry.originalText = trimmed
        entry.consumedAt = consumedAt
        entry.mealType = mealType
        entry.status = .draft
        try store.saveEntry(entry)
        let request = FoodUnderstandingRequest(text: trimmed, consumedAt: consumedAt, mealType: mealType)
        return try await analyze(request, entry: entry, inputType: .text)
    }

    public func analyzeImage(
        uploadData: Data,
        localImagePath: String,
        consumedAt: Date = Date(),
        mealType: MealType = .other,
        existingEntry: MealEntry? = nil
    ) async throws -> MealEntry {
        guard !uploadData.isEmpty else { throw FoodLoggingError.missingImage }
        let entry = existingEntry ?? MealEntry(
            consumedAt: consumedAt,
            mealType: mealType,
            status: .draft,
            localImagePath: localImagePath
        )
        entry.localImagePath = localImagePath
        entry.consumedAt = consumedAt
        entry.mealType = mealType
        entry.status = .draft
        try store.saveEntry(entry)
        let request = FoodUnderstandingRequest(imageData: uploadData, consumedAt: consumedAt, mealType: mealType)
        return try await analyze(request, entry: entry, inputType: .image)
    }

    public func confirm(_ entry: MealEntry, now: Date = Date()) throws {
        try validate(entry.components)
        guard entry.status != .confirmed else { return }
        entry.status = .confirmed
        entry.updatedAt = now
        try store.saveEntry(entry)
    }

    public func validate(_ components: [EntryComponent]) throws {
        guard !components.isEmpty else { throw FoodLoggingError.emptyMeal }
        for component in components {
            do {
                _ = try calculator.componentNutrition(component)
            } catch {
                throw FoodLoggingError.incompleteComponent(component.displayName, error.localizedDescription)
            }
        }
    }

    public func update(
        _ entry: MealEntry,
        components: [EntryComponent],
        consumedAt: Date,
        mealType: MealType
    ) throws {
        entry.consumedAt = consumedAt
        entry.mealType = mealType
        entry.updatedAt = Date()
        try store.replaceComponents(for: entry, components: components)
    }

    public func delete(_ entry: MealEntry) throws {
        try store.deleteEntry(entry)
    }

    private func analyze(
        _ request: FoodUnderstandingRequest,
        entry: MealEntry,
        inputType: EstimationInputType
    ) async throws -> MealEntry {
        do {
            let result = try await clientProvider.client().analyzeFood(request).validated()
            var components: [EntryComponent] = []
            for candidate in result.items {
                let snapshot = candidate.nutrition.map { nutrition in
                    NutritionSnapshot(
                        basisQuantity: nutrition.basisQuantity,
                        basisUnit: NutritionBasisUnit(rawValue: nutrition.basisUnit)!,
                        calories: nutrition.calories,
                        proteinGrams: nutrition.proteinGrams,
                        carbohydrateGrams: nutrition.carbohydrateGrams,
                        fatGrams: nutrition.fatGrams,
                        fiberGrams: nutrition.fiberGrams,
                        source: .modelEstimate,
                        estimationNote: [candidate.nutritionBasis, nutrition.sourceNote]
                            .compactMap { $0 }.joined(separator: "；")
                    )
                }
                let food = FoodItem(
                    name: candidate.name,
                    brand: candidate.brand,
                    nutritionSnapshots: snapshot.map { [$0] } ?? []
                )
                components.append(EntryComponent(
                    foodItem: food,
                    displayName: candidate.name,
                    originalQuantity: candidate.quantity,
                    originalUnit: candidate.unit,
                    estimatedGrams: candidate.estimatedGrams,
                    estimatedGramsLowerBound: candidate.estimatedGramsRange?.lower,
                    estimatedGramsUpperBound: candidate.estimatedGramsRange?.upper,
                    nutritionSnapshot: snapshot.map { $0.independentCopy() }
                ))
            }
            let rawResult = String(data: try JSONEncoder().encode(result), encoding: .utf8) ?? "{}"
            let missing = result.items.flatMap(\.missingInformation)
            let hasIncompleteNutrition = result.items.contains { $0.nutrition == nil }
            let record = EstimationRecord(
                inputType: inputType,
                rawStructuredResult: rawResult,
                quality: missing.isEmpty && !hasIncompleteNutrition ? .medium : .low,
                assumptions: result.items.flatMap(\.assumptions),
                missingInformation: missing,
                clarificationQuestion: result.clarificationQuestion
            )
            entry.status = .draft
            entry.updatedAt = Date()
            try store.replaceAnalysis(for: entry, components: components, records: [record])
            return entry
        } catch {
            entry.status = .failed
            entry.updatedAt = Date()
            try? store.saveEntry(entry)
            throw error
        }
    }
}
