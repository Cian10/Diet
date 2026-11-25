import Foundation
#if DIETAPP_SWIFTDATA
import SwiftData
#endif

#if DIETAPP_SWIFTDATA
@Model
#endif
public final class MealEntry {
    #if DIETAPP_SWIFTDATA
    @Attribute(.unique)
    #endif
    public var id: UUID
    public var consumedAt: Date
    public var mealTypeRaw: String
    public var statusRaw: String
    public var originalText: String?
    public var localImagePath: String?
    public var note: String?
    #if DIETAPP_SWIFTDATA
    @Relationship(deleteRule: .cascade)
    #endif
    public var components: [EntryComponent]
    #if DIETAPP_SWIFTDATA
    @Relationship(deleteRule: .cascade)
    #endif
    public var estimationRecords: [EstimationRecord]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        consumedAt: Date,
        mealType: MealType = .other,
        status: MealEntryStatus = .draft,
        originalText: String? = nil,
        localImagePath: String? = nil,
        note: String? = nil,
        components: [EntryComponent] = [],
        estimationRecords: [EstimationRecord] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.consumedAt = consumedAt
        self.mealTypeRaw = mealType.rawValue
        self.statusRaw = status.rawValue
        self.originalText = originalText
        self.localImagePath = localImagePath
        self.note = note
        self.components = components
        self.estimationRecords = estimationRecords
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .other }
        set { mealTypeRaw = newValue.rawValue }
    }

    public var status: MealEntryStatus {
        get { MealEntryStatus(rawValue: statusRaw) ?? .draft }
        set { statusRaw = newValue.rawValue }
    }

    public var isConfirmed: Bool { status == .confirmed }
}

#if DIETAPP_SWIFTDATA
@Model
#endif
public final class EntryComponent {
    #if DIETAPP_SWIFTDATA
    @Attribute(.unique)
    #endif
    public var id: UUID
    public var foodItem: FoodItem?
    public var displayName: String
    public var originalQuantity: Double
    public var originalUnit: String
    public var estimatedGrams: Double?
    public var estimatedGramsLowerBound: Double?
    public var estimatedGramsUpperBound: Double?
    #if DIETAPP_SWIFTDATA
    @Relationship(deleteRule: .cascade)
    #endif
    public var nutritionSnapshot: NutritionSnapshot?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        foodItem: FoodItem? = nil,
        displayName: String,
        originalQuantity: Double,
        originalUnit: String,
        estimatedGrams: Double? = nil,
        estimatedGramsLowerBound: Double? = nil,
        estimatedGramsUpperBound: Double? = nil,
        nutritionSnapshot: NutritionSnapshot? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.foodItem = foodItem
        self.displayName = displayName
        self.originalQuantity = originalQuantity
        self.originalUnit = originalUnit
        self.estimatedGrams = estimatedGrams
        self.estimatedGramsLowerBound = estimatedGramsLowerBound
        self.estimatedGramsUpperBound = estimatedGramsUpperBound
        self.nutritionSnapshot = nutritionSnapshot
        self.createdAt = createdAt
    }
}

#if DIETAPP_SWIFTDATA
@Model
#endif
public final class EstimationRecord {
    #if DIETAPP_SWIFTDATA
    @Attribute(.unique)
    #endif
    public var id: UUID
    public var inputTypeRaw: String
    public var rawStructuredResult: String
    public var qualityRaw: String
    public var assumptions: [String]
    public var missingInformation: [String]
    public var userCorrectionNotes: String?
    public var clarificationQuestion: String?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        inputType: EstimationInputType,
        rawStructuredResult: String,
        quality: EstimationQuality = .unknown,
        assumptions: [String] = [],
        missingInformation: [String] = [],
        userCorrectionNotes: String? = nil,
        clarificationQuestion: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.inputTypeRaw = inputType.rawValue
        self.rawStructuredResult = rawStructuredResult
        self.qualityRaw = quality.rawValue
        self.assumptions = assumptions
        self.missingInformation = missingInformation
        self.userCorrectionNotes = userCorrectionNotes
        self.clarificationQuestion = clarificationQuestion
        self.createdAt = createdAt
    }

    public var inputType: EstimationInputType {
        get { EstimationInputType(rawValue: inputTypeRaw) ?? .manual }
        set { inputTypeRaw = newValue.rawValue }
    }

    public var quality: EstimationQuality {
        get { EstimationQuality(rawValue: qualityRaw) ?? .unknown }
        set { qualityRaw = newValue.rawValue }
    }
}
