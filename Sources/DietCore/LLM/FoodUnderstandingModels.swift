import Foundation

public struct EstimatedGramsRange: Codable, Sendable, Equatable {
    public var lower: Double
    public var upper: Double

    public init(lower: Double, upper: Double) {
        self.lower = lower
        self.upper = upper
    }
}

public struct NutritionCandidate: Codable, Sendable, Equatable {
    public var basisQuantity: Double
    public var basisUnit: String
    public var calories: Double
    public var proteinGrams: Double
    public var carbohydrateGrams: Double
    public var fatGrams: Double
    public var fiberGrams: Double?
    public var sourceNote: String?

    public init(
        basisQuantity: Double,
        basisUnit: String,
        calories: Double,
        proteinGrams: Double,
        carbohydrateGrams: Double,
        fatGrams: Double,
        fiberGrams: Double? = nil,
        sourceNote: String? = nil
    ) {
        self.basisQuantity = basisQuantity
        self.basisUnit = basisUnit
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sourceNote = sourceNote
    }
}

public struct FoodCandidate: Codable, Sendable, Equatable {
    public var name: String
    public var brand: String?
    public var quantity: Double
    public var unit: String
    public var estimatedGrams: Double?
    public var estimatedGramsRange: EstimatedGramsRange?
    public var mealTime: String?
    public var nutritionBasis: String?
    public var nutrition: NutritionCandidate?
    public var assumptions: [String]
    public var missingInformation: [String]

    public init(
        name: String,
        brand: String? = nil,
        quantity: Double,
        unit: String,
        estimatedGrams: Double? = nil,
        estimatedGramsRange: EstimatedGramsRange? = nil,
        mealTime: String? = nil,
        nutritionBasis: String? = nil,
        nutrition: NutritionCandidate? = nil,
        assumptions: [String] = [],
        missingInformation: [String] = []
    ) {
        self.name = name
        self.brand = brand
        self.quantity = quantity
        self.unit = unit
        self.estimatedGrams = estimatedGrams
        self.estimatedGramsRange = estimatedGramsRange
        self.mealTime = mealTime
        self.nutritionBasis = nutritionBasis
        self.nutrition = nutrition
        self.assumptions = assumptions
        self.missingInformation = missingInformation
    }

    private enum CodingKeys: String, CodingKey {
        case name, brand, quantity, unit, estimatedGrams, estimatedGramsRange, mealTime
        case nutritionBasis, nutrition, assumptions, missingInformation
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        brand = try container.decodeIfPresent(String.self, forKey: .brand)
        quantity = try container.decode(Double.self, forKey: .quantity)
        unit = try container.decode(String.self, forKey: .unit)
        estimatedGrams = try container.decodeIfPresent(Double.self, forKey: .estimatedGrams)
        estimatedGramsRange = try container.decodeIfPresent(EstimatedGramsRange.self, forKey: .estimatedGramsRange)
        mealTime = try container.decodeIfPresent(String.self, forKey: .mealTime)
        nutritionBasis = try container.decodeIfPresent(String.self, forKey: .nutritionBasis)
        nutrition = try container.decodeIfPresent(NutritionCandidate.self, forKey: .nutrition)
        assumptions = try container.decodeIfPresent([String].self, forKey: .assumptions) ?? []
        missingInformation = try container.decodeIfPresent([String].self, forKey: .missingInformation) ?? []
    }
}

public struct FoodUnderstandingResult: Codable, Sendable, Equatable {
    public var items: [FoodCandidate]
    public var needsClarification: Bool
    public var clarificationQuestion: String?

    public init(items: [FoodCandidate], needsClarification: Bool = false, clarificationQuestion: String? = nil) {
        self.items = items
        self.needsClarification = needsClarification
        self.clarificationQuestion = clarificationQuestion
    }

    public func validated() throws -> FoodUnderstandingResult {
        guard !items.isEmpty else { throw LLMError.emptyResult }
        for item in items {
            guard !item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !item.unit.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LLMError.invalidResponse("食物名称或单位为空。")
            }
            guard item.quantity.isFinite, item.quantity > 0 else {
                throw LLMError.invalidResponse("食物数量必须大于零。")
            }
            if let grams = item.estimatedGrams, !grams.isFinite || grams <= 0 {
                throw LLMError.invalidResponse("估算克数必须大于零。")
            }
            if let range = item.estimatedGramsRange {
                guard range.lower.isFinite, range.upper.isFinite,
                      range.lower > 0, range.upper >= range.lower else {
                    throw LLMError.invalidResponse("估算克数范围无效。")
                }
            }
            if let nutrition = item.nutrition {
                guard NutritionBasisUnit(rawValue: nutrition.basisUnit) != nil else {
                    throw LLMError.invalidResponse("未知营养基准单位：\(nutrition.basisUnit)")
                }
                let values = [
                    nutrition.basisQuantity,
                    nutrition.calories,
                    nutrition.proteinGrams,
                    nutrition.carbohydrateGrams,
                    nutrition.fatGrams
                ]
                guard values.allSatisfy(\.isFinite), nutrition.fiberGrams?.isFinite != false else {
                    throw LLMError.invalidResponse("营养数值不是有限数值。")
                }
                guard nutrition.basisQuantity > 0,
                      nutrition.calories >= 0,
                      nutrition.proteinGrams >= 0,
                      nutrition.carbohydrateGrams >= 0,
                      nutrition.fatGrams >= 0,
                      nutrition.fiberGrams ?? 0 >= 0 else {
                    throw LLMError.invalidResponse("营养基准必须大于零，营养数值不能为负。")
                }
            }
        }
        if needsClarification {
            guard let clarificationQuestion,
                  !clarificationQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LLMError.invalidResponse("需要澄清时必须在 clarificationQuestion 中给出一个问题。")
            }
        }
        return self
    }
}

public struct FoodUnderstandingRequest: Sendable {
    public var text: String?
    public var imageData: Data?
    public var consumedAt: Date
    public var mealType: MealType

    public init(text: String? = nil, imageData: Data? = nil, consumedAt: Date, mealType: MealType) {
        self.text = text
        self.imageData = imageData
        self.consumedAt = consumedAt
        self.mealType = mealType
    }
}

public struct TextGenerationRequest: Sendable, Equatable {
    public var systemPrompt: String
    public var userPrompt: String

    public init(systemPrompt: String, userPrompt: String) {
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
    }
}

public protocol LLMClient {
    func analyzeFood(_ request: FoodUnderstandingRequest) async throws -> FoodUnderstandingResult
    func generateText(_ request: TextGenerationRequest) async throws -> String
}

public extension LLMClient {
    func generateText(_ request: TextGenerationRequest) async throws -> String {
        throw LLMError.invalidResponse("当前 LLM 客户端不支持纯文本生成。")
    }
}

@MainActor
public protocol LLMClientProviding: AnyObject {
    func client() throws -> any LLMClient
}
