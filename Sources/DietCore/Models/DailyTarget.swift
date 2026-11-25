import Foundation
#if DIETAPP_SWIFTDATA
import SwiftData
#endif

#if DIETAPP_SWIFTDATA
@Model
#endif
public final class DailyTarget {
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
    public var phasePlanVersion: Int?
    public var isSingleDayOverride: Bool
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        date: Date,
        calories: Double,
        proteinGrams: Double,
        carbohydrateGrams: Double,
        fatGrams: Double,
        phasePlanVersion: Int? = nil,
        isSingleDayOverride: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.date = Calendar.current.startOfDay(for: date)
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbohydrateGrams = carbohydrateGrams
        self.fatGrams = fatGrams
        self.phasePlanVersion = phasePlanVersion
        self.isSingleDayOverride = isSingleDayOverride
        self.createdAt = createdAt
    }
}
