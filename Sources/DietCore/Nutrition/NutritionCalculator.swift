import Foundation

public struct MacroEnergyFactors: Sendable, Equatable {
    public var protein: Double
    public var carbohydrate: Double
    public var fat: Double

    public init(protein: Double = 4, carbohydrate: Double = 4, fat: Double = 9) {
        self.protein = protein
        self.carbohydrate = carbohydrate
        self.fat = fat
    }
}

public struct NutritionTotals: Sendable, Equatable {
    public var calories: Double
    public var proteinGrams: Double
    public var carbohydrateGrams: Double
    public var fatGrams: Double
    public var fiberGrams: Double?
    public var isComplete: Bool
    public var unknownItemNames: [String]

    public init(
        calories: Double = 0,
        proteinGrams: Double = 0,
        carbohydrateGrams: Double = 0,
        fatGrams: Double = 0,
        fiberGrams: Double? = 0,
        isComplete: Bool = true,
        unknownItemNames: [String] = []
    ) {
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.isComplete = isComplete
        self.unknownItemNames = unknownItemNames
    }

    public func adding(_ other: NutritionTotals) -> NutritionTotals {
        NutritionTotals(
            calories: calories + other.calories,
            proteinGrams: proteinGrams + other.proteinGrams,
            carbohydrateGrams: carbohydrateGrams + other.carbohydrateGrams,
            fatGrams: fatGrams + other.fatGrams,
            fiberGrams: fiberGrams.flatMap { lhs in other.fiberGrams.map { lhs + $0 } },
            isComplete: isComplete && other.isComplete,
            unknownItemNames: unknownItemNames + other.unknownItemNames
        )
    }
}

public struct NutritionAssessment: Sendable, Equatable {
    public var targetCalorieDifference: Double
    public var actualCalorieDeficit: Double?
    public var remainingProteinGrams: Double
    public var remainingCarbohydrateGrams: Double
    public var remainingFatGrams: Double
}

public enum NutritionCalculationError: LocalizedError, Equatable {
    case missingSnapshot
    case missingWeight
    case missingVolume
    case invalidBasisQuantity
    case invalidQuantity
    case negativeNutrition
    case nonFiniteNutrition

    public var errorDescription: String? {
        switch self {
        case .missingSnapshot: "该食物缺少营养数据，不能按零摄入处理。"
        case .missingWeight: "该食物缺少可计算的重量，请补充克数。"
        case .missingVolume: "该食物缺少可计算的体积，请补充毫升数或改用份量。"
        case .invalidBasisQuantity: "营养基准份量必须大于零。"
        case .invalidQuantity: "食物数量必须大于零。"
        case .negativeNutrition: "营养数值不能为负数。"
        case .nonFiniteNutrition: "营养数值无效。"
        }
    }
}

public struct NutritionCalculator: Sendable {
    public var energyFactors: MacroEnergyFactors

    public init(energyFactors: MacroEnergyFactors = MacroEnergyFactors()) {
        self.energyFactors = energyFactors
    }

    public func energyFromMacros(protein: Double, carbohydrate: Double, fat: Double) -> Double {
        protein * energyFactors.protein + carbohydrate * energyFactors.carbohydrate + fat * energyFactors.fat
    }

    public func componentNutrition(_ component: EntryComponent) throws -> NutritionTotals {
        guard let snapshot = component.nutritionSnapshot else { throw NutritionCalculationError.missingSnapshot }
        guard snapshot.basisQuantity.isFinite, snapshot.basisQuantity > 0 else {
            throw NutritionCalculationError.invalidBasisQuantity
        }
        guard component.originalQuantity.isFinite, component.originalQuantity > 0 else {
            throw NutritionCalculationError.invalidQuantity
        }
        let nutrients = [snapshot.calories, snapshot.proteinGrams, snapshot.carbohydrateGrams, snapshot.fatGrams]
        guard nutrients.allSatisfy(\.isFinite), snapshot.fiberGrams?.isFinite != false else {
            throw NutritionCalculationError.nonFiniteNutrition
        }
        guard nutrients.allSatisfy({ $0 >= 0 }), snapshot.fiberGrams ?? 0 >= 0 else {
            throw NutritionCalculationError.negativeNutrition
        }

        let consumedBasisQuantity: Double
        switch snapshot.basisUnit {
        case .grams:
            let grams = component.estimatedGrams ?? Self.directQuantity(component, units: ["g", "gram", "grams", "克"])
            guard let grams, grams.isFinite, grams > 0 else { throw NutritionCalculationError.missingWeight }
            consumedBasisQuantity = grams
        case .milliliters:
            guard let milliliters = Self.directQuantity(component, units: ["ml", "milliliter", "milliliters", "毫升"]),
                  milliliters.isFinite, milliliters > 0 else {
                throw NutritionCalculationError.missingVolume
            }
            consumedBasisQuantity = milliliters
        case .serving:
            consumedBasisQuantity = component.originalQuantity
        }

        let scale = consumedBasisQuantity / snapshot.basisQuantity
        return NutritionTotals(
            calories: snapshot.calories * scale,
            proteinGrams: snapshot.proteinGrams * scale,
            carbohydrateGrams: snapshot.carbohydrateGrams * scale,
            fatGrams: snapshot.fatGrams * scale,
            fiberGrams: snapshot.fiberGrams.map { $0 * scale }
        )
    }

    public func mealNutrition(_ meal: MealEntry) -> NutritionTotals {
        meal.components.reduce(into: NutritionTotals()) { result, component in
            do {
                result = result.adding(try componentNutrition(component))
            } catch {
                result.isComplete = false
                result.fiberGrams = nil
                result.unknownItemNames.append(component.displayName)
            }
        }
    }

    public func dailyNutrition(entries: [MealEntry], on date: Date, calendar: Calendar = .current) -> NutritionTotals {
        entries.filter { entry in
            entry.isConfirmed && calendar.isDate(entry.consumedAt, inSameDayAs: date)
        }.reduce(into: NutritionTotals()) { result, entry in
            result = result.adding(mealNutrition(entry))
        }
    }

    public func assess(
        intake: NutritionTotals,
        target: DailyTarget,
        estimatedExpenditure: Double? = nil
    ) -> NutritionAssessment {
        NutritionAssessment(
            targetCalorieDifference: target.calories - intake.calories,
            actualCalorieDeficit: estimatedExpenditure.map { $0 - intake.calories },
            remainingProteinGrams: target.proteinGrams - intake.proteinGrams,
            remainingCarbohydrateGrams: target.carbohydrateGrams - intake.carbohydrateGrams,
            remainingFatGrams: target.fatGrams - intake.fatGrams
        )
    }

    private static func directQuantity(_ component: EntryComponent, units: [String]) -> Double? {
        let unit = component.originalUnit.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return units.contains(unit) ? component.originalQuantity : nil
    }
}
