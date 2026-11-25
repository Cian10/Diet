#if DIETAPP_SWIFTDATA
import Foundation
import SwiftData

public enum DietPersistence {
    public static let schema = Schema([
        UserProfile.self,
        PhasePlan.self,
        DailyTarget.self,
        FoodItem.self,
        NutritionSnapshot.self,
        MealEntry.self,
        EntryComponent.self,
        EstimationRecord.self,
        WeightRecord.self,
        DailySummary.self,
        AdjustmentProposal.self,
        NotificationSettings.self
    ])

    public static func makeContainer(isStoredInMemoryOnly: Bool = false) throws -> ModelContainer {
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

@MainActor
public final class SwiftDataProfileStore: ProfileStoring {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchProfile() throws -> UserProfile? {
        let profiles = try modelContext.fetch(FetchDescriptor<UserProfile>())
        guard profiles.count <= 1 else { throw ProfileValidationError.multipleProfiles }
        return profiles.first
    }

    public func allWeightRecords() throws -> [WeightRecord] {
        try modelContext.fetch(FetchDescriptor<WeightRecord>()).sorted { $0.date < $1.date }
    }

    public func saveProfile(_ profile: UserProfile, weightRecord: WeightRecord?) throws {
        let existing = try modelContext.fetch(FetchDescriptor<UserProfile>())
        if !existing.contains(where: { $0 === profile }) {
            modelContext.insert(profile)
        }
        if let weightRecord { modelContext.insert(weightRecord) }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

@MainActor
public final class SwiftDataPhasePlanStore: PhasePlanStoring {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func allPlans() throws -> [PhasePlan] {
        try modelContext.fetch(FetchDescriptor<PhasePlan>())
    }

    public func saveNewPhase(_ plan: PhasePlan) throws {
        modelContext.insert(plan)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

@MainActor
public final class SwiftDataDailyTargetStore: DailyTargetStoring {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) { self.modelContext = modelContext }

    public func target(on date: Date) throws -> DailyTarget? {
        let day = Calendar.current.startOfDay(for: date)
        return try modelContext.fetch(FetchDescriptor<DailyTarget>()).first {
            Calendar.current.isDate($0.date, inSameDayAs: day)
        }
    }

    public func saveTarget(_ target: DailyTarget) throws {
        let existing = try modelContext.fetch(FetchDescriptor<DailyTarget>())
        if !existing.contains(where: { $0 === target }) { modelContext.insert(target) }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

@MainActor
public final class SwiftDataMealEntryStore: MealEntryStoring {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) { self.modelContext = modelContext }

    public func allEntries() throws -> [MealEntry] {
        try modelContext.fetch(FetchDescriptor<MealEntry>()).sorted { $0.consumedAt > $1.consumedAt }
    }

    public func saveEntry(_ entry: MealEntry) throws {
        let existing = try modelContext.fetch(FetchDescriptor<MealEntry>())
        if !existing.contains(where: { $0 === entry }) { modelContext.insert(entry) }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }

    public func replaceAnalysis(for entry: MealEntry, components: [EntryComponent], records: [EstimationRecord]) throws {
        entry.components.forEach(modelContext.delete)
        entry.estimationRecords.forEach(modelContext.delete)
        entry.components = components
        entry.estimationRecords = records
        try saveEntry(entry)
    }

    public func replaceComponents(for entry: MealEntry, components: [EntryComponent]) throws {
        entry.components.forEach(modelContext.delete)
        entry.components = components
        try saveEntry(entry)
    }

    public func deleteEntry(_ entry: MealEntry) throws {
        modelContext.delete(entry)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

@MainActor
public final class SwiftDataAdjustmentProposalStore: AdjustmentProposalStoring {
    private let modelContext: ModelContext
    public init(modelContext: ModelContext) { self.modelContext = modelContext }

    public func allProposals() throws -> [AdjustmentProposal] {
        try modelContext.fetch(FetchDescriptor<AdjustmentProposal>())
    }

    public func saveProposal(_ proposal: AdjustmentProposal) throws {
        let existing = try modelContext.fetch(FetchDescriptor<AdjustmentProposal>())
        if !existing.contains(where: { $0 === proposal }) { modelContext.insert(proposal) }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}

@MainActor
public final class SwiftDataNotificationSettingsStore: NotificationSettingsStoring {
    private let modelContext: ModelContext
    public init(modelContext: ModelContext) { self.modelContext = modelContext }

    public func loadSettings() throws -> NotificationSettings? {
        try modelContext.fetch(FetchDescriptor<NotificationSettings>()).first
    }

    public func saveSettings(_ settings: NotificationSettings) throws {
        let existing = try modelContext.fetch(FetchDescriptor<NotificationSettings>())
        if !existing.contains(where: { $0 === settings }) { modelContext.insert(settings) }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw error
        }
    }
}
#endif
