import Foundation
#if DIETAPP_SWIFTDATA
import SwiftData
#endif

#if DIETAPP_SWIFTDATA
@Model
#endif
public final class UserProfile {
    #if DIETAPP_SWIFTDATA
    @Attribute(.unique)
    #endif
    public var id: UUID
    public var ageYears: Int?
    public var heightCentimeters: Double?
    public var currentWeightKilograms: Double?
    public var biologicalSexRaw: String?
    public var bodyFatPercentage: Double?
    public var activityLevelRaw: String
    public var trainingSessionsPerWeek: Int
    public var dietaryPreferences: [String]
    public var avoidedFoods: [String]
    public var allergies: [String]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        ageYears: Int? = nil,
        heightCentimeters: Double? = nil,
        currentWeightKilograms: Double? = nil,
        biologicalSex: BiologicalSex? = nil,
        bodyFatPercentage: Double? = nil,
        activityLevel: ActivityLevel = .moderate,
        trainingSessionsPerWeek: Int = 0,
        dietaryPreferences: [String] = [],
        avoidedFoods: [String] = [],
        allergies: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.ageYears = ageYears
        self.heightCentimeters = heightCentimeters
        self.currentWeightKilograms = currentWeightKilograms
        self.biologicalSexRaw = biologicalSex?.rawValue
        self.bodyFatPercentage = bodyFatPercentage
        self.activityLevelRaw = activityLevel.rawValue
        self.trainingSessionsPerWeek = trainingSessionsPerWeek
        self.dietaryPreferences = dietaryPreferences
        self.avoidedFoods = avoidedFoods
        self.allergies = allergies
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var biologicalSex: BiologicalSex? {
        get { biologicalSexRaw.flatMap(BiologicalSex.init(rawValue:)) }
        set { biologicalSexRaw = newValue?.rawValue }
    }

    public var activityLevel: ActivityLevel {
        get { ActivityLevel(rawValue: activityLevelRaw) ?? .moderate }
        set { activityLevelRaw = newValue.rawValue }
    }
}
