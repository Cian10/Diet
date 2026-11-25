import Foundation
#if DIETAPP_SWIFTDATA
import SwiftData
#endif

#if DIETAPP_SWIFTDATA
@Model
#endif
public final class WeightRecord {
    #if DIETAPP_SWIFTDATA
    @Attribute(.unique)
    #endif
    public var id: UUID
    public var date: Date
    public var weightKilograms: Double
    public var source: String?
    public var createdAt: Date

    public init(id: UUID = UUID(), date: Date, weightKilograms: Double, source: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.weightKilograms = weightKilograms
        self.source = source
        self.createdAt = createdAt
    }
}

#if DIETAPP_SWIFTDATA
@Model
#endif
public final class DailySummary {
    #if DIETAPP_SWIFTDATA
    @Attribute(.unique)
    #endif
    public var id: UUID
    #if DIETAPP_SWIFTDATA
    @Attribute(.unique)
    #endif
    public var date: Date
    public var calories: Double
    public var proteinGrams: Double
    public var carbohydrateGrams: Double
    public var fatGrams: Double
    public var isComplete: Bool
    public var unknownItemNames: [String]
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        date: Date,
        calories: Double = 0,
        proteinGrams: Double = 0,
        carbohydrateGrams: Double = 0,
        fatGrams: Double = 0,
        isComplete: Bool = true,
        unknownItemNames: [String] = [],
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.isComplete = isComplete
        self.unknownItemNames = unknownItemNames
        self.updatedAt = updatedAt
    }
}

#if DIETAPP_SWIFTDATA
@Model
#endif
public final class AdjustmentProposal {
    #if DIETAPP_SWIFTDATA
    @Attribute(.unique)
    #endif
    public var id: UUID
    public var triggerSummary: String
    public var effectiveDate: Date
    public var oldCalories: Double?
    public var newCalories: Double?
    public var oldProteinGrams: Double?
    public var newProteinGrams: Double?
    public var oldCarbohydrateGrams: Double?
    public var newCarbohydrateGrams: Double?
    public var oldFatGrams: Double?
    public var newFatGrams: Double?
    public var statusRaw: String
    public var createdAt: Date
    public var resolvedAt: Date?

    public init(
        id: UUID = UUID(),
        triggerSummary: String,
        effectiveDate: Date,
        oldCalories: Double? = nil,
        newCalories: Double? = nil,
        oldProteinGrams: Double? = nil,
        newProteinGrams: Double? = nil,
        oldCarbohydrateGrams: Double? = nil,
        newCarbohydrateGrams: Double? = nil,
        oldFatGrams: Double? = nil,
        newFatGrams: Double? = nil,
        status: AdjustmentStatus = .pending,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.triggerSummary = triggerSummary
        self.effectiveDate = effectiveDate
        self.oldCalories = oldCalories
        self.newCalories = newCalories
        self.oldProteinGrams = oldProteinGrams
        self.newProteinGrams = newProteinGrams
        self.oldCarbohydrateGrams = oldCarbohydrateGrams
        self.newCarbohydrateGrams = newCarbohydrateGrams
        self.oldFatGrams = oldFatGrams
        self.newFatGrams = newFatGrams
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }

    public var status: AdjustmentStatus {
        get { AdjustmentStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }
}

#if DIETAPP_SWIFTDATA
@Model
#endif
public final class NotificationSettings {
    #if DIETAPP_SWIFTDATA
    @Attribute(.unique)
    #endif
    public var id: UUID
    public var mealRemindersEnabled: Bool
    public var mealReminderMinutes: [Int]
    public var progressRemindersEnabled: Bool
    public var weeklyReviewEnabled: Bool
    public var phaseReviewEnabled: Bool
    public var progressReminderMinute: Int
    public var weeklyReviewWeekday: Int
    public var weeklyReviewMinute: Int
    public var quietHoursStartMinute: Int?
    public var quietHoursEndMinute: Int?

    public init(
        id: UUID = UUID(),
        mealRemindersEnabled: Bool = false,
        mealReminderMinutes: [Int] = [],
        progressRemindersEnabled: Bool = false,
        weeklyReviewEnabled: Bool = false,
        phaseReviewEnabled: Bool = false,
        progressReminderMinute: Int = 18 * 60,
        weeklyReviewWeekday: Int = 1,
        weeklyReviewMinute: Int = 19 * 60,
        quietHoursStartMinute: Int? = nil,
        quietHoursEndMinute: Int? = nil
    ) {
        self.id = id
        self.mealRemindersEnabled = mealRemindersEnabled
        self.mealReminderMinutes = mealReminderMinutes
        self.progressRemindersEnabled = progressRemindersEnabled
        self.weeklyReviewEnabled = weeklyReviewEnabled
        self.phaseReviewEnabled = phaseReviewEnabled
        self.progressReminderMinute = progressReminderMinute
        self.weeklyReviewWeekday = weeklyReviewWeekday
        self.weeklyReviewMinute = weeklyReviewMinute
        self.quietHoursStartMinute = quietHoursStartMinute
        self.quietHoursEndMinute = quietHoursEndMinute
    }
}
