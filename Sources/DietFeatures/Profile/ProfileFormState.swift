import Foundation
import DietCore

public enum FormStateError: LocalizedError, Equatable {
    case invalidNumber(field: String)

    public var errorDescription: String? {
        switch self {
        case .invalidNumber(let field): "请检查“\(field)”中的数字。"
        }
    }
}

public struct ProfileFormState {
    public var ageText = ""
    public var heightText = ""
    public var weightText = ""
    public var biologicalSex: BiologicalSex?
    public var bodyFatText = ""
    public var activityLevel: ActivityLevel = .moderate
    public var trainingSessionsPerWeek = 3
    public var dietaryPreferencesText = ""
    public var avoidedFoodsText = ""
    public var allergiesText = ""

    public init() {}

    public init(profile: UserProfile) {
        ageText = profile.ageYears.map(String.init) ?? ""
        heightText = profile.heightCentimeters.map { Self.numberText($0) } ?? ""
        weightText = profile.currentWeightKilograms.map { Self.numberText($0) } ?? ""
        biologicalSex = profile.biologicalSex
        bodyFatText = profile.bodyFatPercentage.map { Self.numberText($0) } ?? ""
        activityLevel = profile.activityLevel
        trainingSessionsPerWeek = profile.trainingSessionsPerWeek
        dietaryPreferencesText = profile.dietaryPreferences.joined(separator: "、")
        avoidedFoodsText = profile.avoidedFoods.joined(separator: "、")
        allergiesText = profile.allergies.joined(separator: "、")
    }

    public func makeInput() throws -> ProfileInput {
        ProfileInput(
            ageYears: try Self.optionalInt(ageText, field: "年龄"),
            heightCentimeters: try Self.optionalDouble(heightText, field: "身高"),
            currentWeightKilograms: try Self.optionalDouble(weightText, field: "体重"),
            biologicalSex: biologicalSex,
            bodyFatPercentage: try Self.optionalDouble(bodyFatText, field: "体脂率"),
            activityLevel: activityLevel,
            trainingSessionsPerWeek: trainingSessionsPerWeek,
            dietaryPreferences: Self.list(from: dietaryPreferencesText),
            avoidedFoods: Self.list(from: avoidedFoodsText),
            allergies: Self.list(from: allergiesText)
        )
    }

    static func optionalDouble(_ text: String, field: String) throws -> Double? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let normalized = trimmed.replacingOccurrences(of: ",", with: "")
        guard let value = Double(normalized) else { throw FormStateError.invalidNumber(field: field) }
        return value
    }

    static func optionalInt(_ text: String, field: String) throws -> Int? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let value = Int(trimmed) else { throw FormStateError.invalidNumber(field: field) }
        return value
    }

    static func list(from text: String) -> [String] {
        text.components(separatedBy: CharacterSet(charactersIn: ",，、;\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    static func numberText(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}

public struct PhasePlanFormState {
    public var phaseType: PhaseType = .maintenance
    public var startDate = Date()
    public var hasEndDate = false
    public var endDate = Date()
    public var energyStrategy: EnergyStrategy = .manual
    public var energyAdjustmentText = "0"
    public var caloriesText = ""
    public var proteinText = "0"
    public var carbohydrateText = "0"
    public var fatText = "0"
    public var proteinPerKilogramText = "1.8"
    public var fatEnergyPercentText = "25"
    public var usesTrainingDayTargets = false

    public init(startDate: Date = Date()) {
        self.startDate = startDate
        self.endDate = startDate
    }

    public func makeInput() throws -> PhasePlanInput {
        let target: ManualNutritionTarget?
        let adjustment: Double?
        let macroRule: MacroTargetRule?

        switch energyStrategy {
        case .manual:
            target = ManualNutritionTarget(
                calories: try ProfileFormState.optionalDouble(caloriesText, field: "目标热量") ?? 0,
                proteinGrams: try ProfileFormState.optionalDouble(proteinText, field: "蛋白质目标") ?? 0,
                carbohydrateGrams: try ProfileFormState.optionalDouble(carbohydrateText, field: "碳水目标") ?? 0,
                fatGrams: try ProfileFormState.optionalDouble(fatText, field: "脂肪目标") ?? 0
            )
            adjustment = nil
            macroRule = nil
        case .automatic:
            target = nil
            adjustment = try ProfileFormState.optionalDouble(energyAdjustmentText, field: "热量调整比例")
            let protein = try ProfileFormState.optionalDouble(proteinPerKilogramText, field: "蛋白质系数") ?? 0
            let fatPercent = try ProfileFormState.optionalDouble(fatEnergyPercentText, field: "脂肪供能比例") ?? 0
            macroRule = MacroTargetRule(
                proteinGramsPerKilogram: protein,
                fatEnergyProportion: fatPercent / 100
            )
        }

        return PhasePlanInput(
            phaseType: phaseType,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            energyStrategy: energyStrategy,
            energyAdjustmentPercent: adjustment,
            manualTarget: target,
            macroRule: macroRule,
            usesTrainingDayTargets: usesTrainingDayTargets
        )
    }
}
