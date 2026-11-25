import Foundation

@MainActor
public protocol ProfileStoring: AnyObject {
    func fetchProfile() throws -> UserProfile?
    func saveProfile(_ profile: UserProfile, weightRecord: WeightRecord?) throws
    func allWeightRecords() throws -> [WeightRecord]
}

public struct ProfileInput: Sendable {
    public var ageYears: Int?
    public var heightCentimeters: Double?
    public var currentWeightKilograms: Double?
    public var biologicalSex: BiologicalSex?
    public var bodyFatPercentage: Double?
    public var activityLevel: ActivityLevel
    public var trainingSessionsPerWeek: Int
    public var dietaryPreferences: [String]
    public var avoidedFoods: [String]
    public var allergies: [String]

    public init(
        ageYears: Int? = nil,
        heightCentimeters: Double? = nil,
        currentWeightKilograms: Double? = nil,
        biologicalSex: BiologicalSex? = nil,
        bodyFatPercentage: Double? = nil,
        activityLevel: ActivityLevel = .moderate,
        trainingSessionsPerWeek: Int = 0,
        dietaryPreferences: [String] = [],
        avoidedFoods: [String] = [],
        allergies: [String] = []
    ) {
        self.ageYears = ageYears
        self.heightCentimeters = heightCentimeters
        self.currentWeightKilograms = currentWeightKilograms
        self.biologicalSex = biologicalSex
        self.bodyFatPercentage = bodyFatPercentage
        self.activityLevel = activityLevel
        self.trainingSessionsPerWeek = trainingSessionsPerWeek
        self.dietaryPreferences = dietaryPreferences
        self.avoidedFoods = avoidedFoods
        self.allergies = allergies
    }

    public init(profile: UserProfile) {
        self.init(
            ageYears: profile.ageYears,
            heightCentimeters: profile.heightCentimeters,
            currentWeightKilograms: profile.currentWeightKilograms,
            biologicalSex: profile.biologicalSex,
            bodyFatPercentage: profile.bodyFatPercentage,
            activityLevel: profile.activityLevel,
            trainingSessionsPerWeek: profile.trainingSessionsPerWeek,
            dietaryPreferences: profile.dietaryPreferences,
            avoidedFoods: profile.avoidedFoods,
            allergies: profile.allergies
        )
    }

    public func validated() throws -> ProfileInput {
        if let ageYears, !(13...120).contains(ageYears) {
            throw ProfileValidationError.invalidAge
        }
        if let heightCentimeters, !heightCentimeters.isFinite || !(100...250).contains(heightCentimeters) {
            throw ProfileValidationError.invalidHeight
        }
        if let currentWeightKilograms,
           !currentWeightKilograms.isFinite || !(30...400).contains(currentWeightKilograms) {
            throw ProfileValidationError.invalidWeight
        }
        if let bodyFatPercentage,
           !bodyFatPercentage.isFinite || !(1...75).contains(bodyFatPercentage) {
            throw ProfileValidationError.invalidBodyFat
        }
        guard (0...21).contains(trainingSessionsPerWeek) else {
            throw ProfileValidationError.invalidTrainingFrequency
        }

        var copy = self
        copy.dietaryPreferences = Self.normalizedList(dietaryPreferences)
        copy.avoidedFoods = Self.normalizedList(avoidedFoods)
        copy.allergies = Self.normalizedList(allergies)
        return copy
    }

    private static func normalizedList(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.compactMap { value in
            let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty, !seen.contains(normalized) else { return nil }
            seen.insert(normalized)
            return normalized
        }
    }
}

public enum ProfileValidationError: LocalizedError, Equatable {
    case invalidAge
    case invalidHeight
    case invalidWeight
    case invalidBodyFat
    case invalidTrainingFrequency
    case multipleProfiles

    public var errorDescription: String? {
        switch self {
        case .invalidAge: "年龄需在 13–120 岁之间。"
        case .invalidHeight: "身高需在 100–250 厘米之间。"
        case .invalidWeight: "体重需在 30–400 千克之间。"
        case .invalidBodyFat: "体脂率需在 1%–75% 之间。"
        case .invalidTrainingFrequency: "每周训练次数需在 0–21 次之间。"
        case .multipleProfiles: "检测到多份个人档案。为避免误改，请先处理重复数据。"
        }
    }
}

@MainActor
public final class ProfileService {
    private let store: ProfileStoring

    public init(store: ProfileStoring) {
        self.store = store
    }

    public func fetchProfile() throws -> UserProfile? {
        try store.fetchProfile()
    }

    @discardableResult
    public func saveProfile(_ input: ProfileInput, now: Date = Date()) throws -> UserProfile {
        let input = try input.validated()
        let existing = try fetchProfile()
        let previousWeight = existing?.currentWeightKilograms
        let profile = existing ?? UserProfile(createdAt: now, updatedAt: now)

        profile.ageYears = input.ageYears
        profile.heightCentimeters = input.heightCentimeters
        profile.currentWeightKilograms = input.currentWeightKilograms
        profile.biologicalSex = input.biologicalSex
        profile.bodyFatPercentage = input.bodyFatPercentage
        profile.activityLevel = input.activityLevel
        profile.trainingSessionsPerWeek = input.trainingSessionsPerWeek
        profile.dietaryPreferences = input.dietaryPreferences
        profile.avoidedFoods = input.avoidedFoods
        profile.allergies = input.allergies
        profile.updatedAt = now

        var weightRecord: WeightRecord?
        if let weight = input.currentWeightKilograms, previousWeight != weight {
            weightRecord = WeightRecord(date: now, weightKilograms: weight, source: "profile")
        }

        try store.saveProfile(profile, weightRecord: weightRecord)
        return profile
    }
}

@MainActor
public final class InMemoryProfileStore: ProfileStoring {
    private var profile: UserProfile?
    public private(set) var weightRecords: [WeightRecord] = []

    public init() {}

    public func fetchProfile() throws -> UserProfile? { profile }
    public func allWeightRecords() throws -> [WeightRecord] { weightRecords }

    public func saveProfile(_ profile: UserProfile, weightRecord: WeightRecord?) throws {
        self.profile = profile
        if let weightRecord { weightRecords.append(weightRecord) }
    }
}
