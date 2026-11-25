import Foundation

public enum NutritionTag: String, Sendable {
    case highProtein
    case highCarbohydrate
    case lowerFat
}

public struct ReferenceFood {
    public var name: String
    public var allergens: Set<String>
    public var isPlantBased: Bool
    public var tags: Set<NutritionTag>
    public var component: EntryComponent

    public init(
        name: String,
        allergens: Set<String> = [],
        isPlantBased: Bool,
        tags: Set<NutritionTag>,
        component: EntryComponent
    ) {
        self.name = name
        self.allergens = allergens
        self.isPlantBased = isPlantBased
        self.tags = tags
        self.component = component
    }
}

public struct FoodSuggestion: Identifiable {
    public var id = UUID()
    public var name: String
    public var portionDescription: String
    public var expectedNutrition: NutritionTotals

    public init(name: String, portionDescription: String, expectedNutrition: NutritionTotals) {
        self.name = name
        self.portionDescription = portionDescription
        self.expectedNutrition = expectedNutrition
    }
}

public enum RecommendationKind: String, Sendable {
    case incompleteRecord
    case protein
    case carbohydrate
    case neutral
}

public struct Recommendation: Identifiable {
    public var id: String { kind.rawValue }
    public var kind: RecommendationKind
    public var title: String
    public var reason: String
    public var suggestions: [FoodSuggestion]

    public init(kind: RecommendationKind, title: String, reason: String, suggestions: [FoodSuggestion] = []) {
        self.kind = kind
        self.title = title
        self.reason = reason
        self.suggestions = suggestions
    }
}

public struct RecommendationContext {
    public var intake: NutritionTotals
    public var target: DailyTarget
    public var phaseType: PhaseType
    public var profile: UserProfile
    public var hasUpcomingWorkout: Bool

    public init(
        intake: NutritionTotals,
        target: DailyTarget,
        phaseType: PhaseType,
        profile: UserProfile,
        hasUpcomingWorkout: Bool
    ) {
        self.intake = intake
        self.target = target
        self.phaseType = phaseType
        self.profile = profile
        self.hasUpcomingWorkout = hasUpcomingWorkout
    }
}

public struct RecommendationEngine {
    public var foods: [ReferenceFood]
    private let calculator = NutritionCalculator()

    public init(foods: [ReferenceFood] = RecommendationEngine.defaultFoods) {
        self.foods = foods
    }

    public func recommendations(for context: RecommendationContext) -> [Recommendation] {
        guard context.intake.isComplete else {
            return [Recommendation(
                kind: .incompleteRecord,
                title: "先补全无法计算的食物",
                reason: "当前合计包含未知项目：\(context.intake.unknownItemNames.joined(separator: "、"))。补全后再推荐，避免把未知当成零。"
            )]
        }
        let calorieRemaining = context.target.calories - context.intake.calories
        guard calorieRemaining > 0 else {
            return [Recommendation(
                kind: .neutral,
                title: "今天不需要为了达标继续进食",
                reason: "当前已达到或超过目标热量。无需禁食或增加惩罚性运动，也无需自动压缩明天目标。"
            )]
        }

        var results: [Recommendation] = []
        let proteinRemaining = context.target.proteinGrams - context.intake.proteinGrams
        if proteinRemaining > 10 {
            let suggestions = suggestions(tag: .highProtein, calorieRemaining: calorieRemaining, context: context)
            if !suggestions.isEmpty {
                results.append(Recommendation(
                    kind: .protein,
                    title: "优先补充蛋白质",
                    reason: "距离蛋白质目标约 \(Self.number(proteinRemaining)) g，目标热量余量约 \(Self.number(calorieRemaining)) kcal。",
                    suggestions: suggestions
                ))
            }
        }

        let carbohydrateRemaining = context.target.carbohydrateGrams - context.intake.carbohydrateGrams
        if context.hasUpcomingWorkout, carbohydrateRemaining > 20 {
            let suggestions = suggestions(tag: .highCarbohydrate, calorieRemaining: calorieRemaining, context: context)
            if !suggestions.isEmpty {
                results.append(Recommendation(
                    kind: .carbohydrate,
                    title: "训练前可补充碳水",
                    reason: "你标记了接下来有训练，且碳水目标尚余约 \(Self.number(carbohydrateRemaining)) g。请结合训练时间选择。",
                    suggestions: suggestions
                ))
            }
        }

        if results.isEmpty {
            results.append(Recommendation(
                kind: .neutral,
                title: "按剩余目标和个人偏好安排即可",
                reason: "当前没有需要优先处理的蛋白质或训练前碳水空缺。"
            ))
        }
        return results
    }

    private func suggestions(
        tag: NutritionTag,
        calorieRemaining: Double,
        context: RecommendationContext
    ) -> [FoodSuggestion] {
        foods.filter { food in
            food.tags.contains(tag) && !isExcluded(food, profile: context.profile)
        }.sorted { lhs, rhs in
            if tag == .highProtein, calorieRemaining < 200 {
                return lhs.tags.contains(.lowerFat) && !rhs.tags.contains(.lowerFat)
            }
            return lhs.name < rhs.name
        }.prefix(4).compactMap { food in
            suggestion(for: food, calorieRemaining: calorieRemaining)
        }.prefix(3).map { $0 }
    }

    private func suggestion(for food: ReferenceFood, calorieRemaining: Double) -> FoodSuggestion? {
        let original = food.component
        let component = EntryComponent(
            displayName: original.displayName,
            originalQuantity: original.originalQuantity,
            originalUnit: original.originalUnit,
            estimatedGrams: original.estimatedGrams,
            estimatedGramsLowerBound: original.estimatedGramsLowerBound,
            estimatedGramsUpperBound: original.estimatedGramsUpperBound,
            nutritionSnapshot: original.nutritionSnapshot?.independentCopy()
        )
        guard let baseline = try? calculator.componentNutrition(component), baseline.calories > 0 else { return nil }
        let scale = min(1, calorieRemaining / baseline.calories)
        guard scale >= 0.25 else { return nil }
        if component.nutritionSnapshot?.basisUnit == .serving {
            component.originalQuantity *= scale
        } else {
            component.originalQuantity *= scale
            if component.estimatedGrams != nil { component.estimatedGrams! *= scale }
        }
        guard let nutrition = try? calculator.componentNutrition(component) else { return nil }
        let portion = "\(Self.number(component.originalQuantity)) \(component.originalUnit)"
        return FoodSuggestion(name: food.name, portionDescription: portion, expectedNutrition: nutrition)
    }

    private func isExcluded(_ food: ReferenceFood, profile: UserProfile) -> Bool {
        if profile.dietaryPreferences.contains(where: { $0.contains("素食") }), !food.isPlantBased {
            return true
        }
        let restrictions = (profile.allergies + profile.avoidedFoods).map(Self.normalize).filter { !$0.isEmpty }
        let foodTerms = ([food.name] + food.allergens).map(Self.normalize)
        return restrictions.contains { restriction in
            foodTerms.contains { term in term.contains(restriction) || restriction.contains(term) }
        }
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func number(_ value: Double) -> String {
        String(format: "%.0f", value)
    }

    public static var defaultFoods: [ReferenceFood] {
        [
            ReferenceFood(
                name: "鸡胸肉",
                isPlantBased: false,
                tags: [.highProtein, .lowerFat],
                component: food(name: "鸡胸肉", grams: 100, calories: 165, protein: 31, carbohydrate: 0, fat: 3.6)
            ),
            ReferenceFood(
                name: "无糖希腊酸奶",
                allergens: ["牛奶", "乳制品", "乳"],
                isPlantBased: false,
                tags: [.highProtein, .lowerFat],
                component: food(name: "无糖希腊酸奶", grams: 170, calories: 100, protein: 17, carbohydrate: 6, fat: 0.7)
            ),
            ReferenceFood(
                name: "北豆腐",
                allergens: ["大豆", "黄豆"],
                isPlantBased: true,
                tags: [.highProtein],
                component: food(name: "北豆腐", grams: 150, calories: 120, protein: 12, carbohydrate: 4, fat: 7)
            ),
            ReferenceFood(
                name: "香蕉",
                isPlantBased: true,
                tags: [.highCarbohydrate],
                component: food(name: "香蕉", grams: 100, calories: 89, protein: 1.1, carbohydrate: 23, fat: 0.3)
            ),
            ReferenceFood(
                name: "燕麦",
                isPlantBased: true,
                tags: [.highCarbohydrate],
                component: food(name: "燕麦", grams: 40, calories: 152, protein: 5, carbohydrate: 27, fat: 3)
            ),
            ReferenceFood(
                name: "米饭",
                isPlantBased: true,
                tags: [.highCarbohydrate],
                component: food(name: "米饭", grams: 150, calories: 195, protein: 4, carbohydrate: 42, fat: 0.5)
            )
        ]
    }

    private static func food(
        name: String,
        grams: Double,
        calories: Double,
        protein: Double,
        carbohydrate: Double,
        fat: Double
    ) -> EntryComponent {
        let snapshot = NutritionSnapshot(
            basisQuantity: grams,
            basisUnit: .grams,
            calories: calories,
            proteinGrams: protein,
            carbohydrateGrams: carbohydrate,
            fatGrams: fat,
            source: .genericReference,
            estimationNote: "App 内置通用参考值，非品牌包装标签。"
        )
        return EntryComponent(
            displayName: name,
            originalQuantity: grams,
            originalUnit: "克",
            estimatedGrams: grams,
            nutritionSnapshot: snapshot
        )
    }
}
