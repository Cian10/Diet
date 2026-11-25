import Foundation
#if DIETAPP_SWIFTDATA
import SwiftData
#endif

#if DIETAPP_SWIFTDATA
@Model
#endif
public final class NutritionSnapshot {
    #if DIETAPP_SWIFTDATA
    @Attribute(.unique)
    #endif
    public var id: UUID
    public var basisQuantity: Double
    public var basisUnitRaw: String
    public var calories: Double
    public var proteinGrams: Double
    public var carbohydrateGrams: Double
    public var fatGrams: Double
    public var fiberGrams: Double?
    public var sourceRaw: String
    public var estimationNote: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        basisQuantity: Double? = nil,
        basisUnit: NutritionBasisUnit = .grams,
        calories: Double,
        proteinGrams: Double,
        carbohydrateGrams: Double,
        fatGrams: Double,
        fiberGrams: Double? = nil,
        source: NutritionSource,
        estimationNote: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.basisQuantity = basisQuantity ?? (basisUnit == .serving ? 1 : 100)
        self.basisUnitRaw = basisUnit.rawValue
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.fiberGrams = fiberGrams
        self.sourceRaw = source.rawValue
        self.estimationNote = estimationNote
        self.createdAt = createdAt
    }

    public var basisUnit: NutritionBasisUnit {
        get { NutritionBasisUnit(rawValue: basisUnitRaw) ?? .grams }
        set { basisUnitRaw = newValue.rawValue }
    }

    public var source: NutritionSource {
        get { NutritionSource(rawValue: sourceRaw) ?? .modelEstimate }
        set { sourceRaw = newValue.rawValue }
    }

    public func independentCopy() -> NutritionSnapshot {
        NutritionSnapshot(
            basisQuantity: basisQuantity,
            basisUnit: basisUnit,
            calories: calories,
            proteinGrams: proteinGrams,
            carbohydrateGrams: carbohydrateGrams,
            fatGrams: fatGrams,
            fiberGrams: fiberGrams,
            source: source,
            estimationNote: estimationNote
        )
    }
}

#if DIETAPP_SWIFTDATA
@Model
#endif
public final class FoodItem {
    #if DIETAPP_SWIFTDATA
    @Attribute(.unique)
    #endif
    public var id: UUID
    public var name: String
    public var brand: String?
    public var regionCode: String?
    public var externalIdentifier: String?
    #if DIETAPP_SWIFTDATA
    @Relationship(deleteRule: .cascade)
    #endif
    public var nutritionSnapshots: [NutritionSnapshot]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        brand: String? = nil,
        regionCode: String? = nil,
        externalIdentifier: String? = nil,
        nutritionSnapshots: [NutritionSnapshot] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.regionCode = regionCode
        self.externalIdentifier = externalIdentifier
        self.nutritionSnapshots = nutritionSnapshots
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
