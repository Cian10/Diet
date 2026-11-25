import Testing
import Foundation
@testable import DietCore

@Suite("ProfileService")
@MainActor
final class ProfileServiceTests {
    private let store = InMemoryProfileStore()
    private let service: ProfileService

    init() {
        service = ProfileService(store: store)
    }

    @Test("Saving keeps one profile and normalizes lists")
    func savingProfileKeepsOneProfileAndNormalizesLists() throws {
        let first = ProfileInput(
            ageYears: 28,
            heightCentimeters: 175,
            currentWeightKilograms: 70,
            activityLevel: .moderate,
            trainingSessionsPerWeek: 4,
            dietaryPreferences: [" 高蛋白 ", "高蛋白", ""],
            avoidedFoods: ["香菜"],
            allergies: ["花生", "花生"]
        )
        _ = try service.saveProfile(first)

        var updated = first
        updated.ageYears = 29
        _ = try service.saveProfile(updated)

        let fetchedProfile = try service.fetchProfile()
        let profile = try #require(fetchedProfile)
        #expect(profile.ageYears == 29)
        #expect(profile.dietaryPreferences == ["高蛋白"])
        #expect(profile.allergies == ["花生"])
        #expect(store.weightRecords.count == 1)
    }

    @Test("Weight changes append history")
    func weightChangeAppendsHistory() throws {
        _ = try service.saveProfile(ProfileInput(currentWeightKilograms: 70))
        _ = try service.saveProfile(ProfileInput(currentWeightKilograms: 70))
        _ = try service.saveProfile(ProfileInput(currentWeightKilograms: 69.4))

        #expect(store.weightRecords.map(\.weightKilograms) == [70, 69.4])
    }

    @Test("Invalid profile does not save")
    func invalidProfileDoesNotSave() throws {
        #expect(throws: ProfileValidationError.invalidAge) {
            try self.service.saveProfile(ProfileInput(ageYears: 8))
        }
        let savedProfile = try service.fetchProfile()
        #expect(savedProfile == nil)
        #expect(store.weightRecords.isEmpty)
    }

    @Test("Optional body data can remain empty")
    func optionalBodyDataCanRemainEmpty() throws {
        let profile = try service.saveProfile(ProfileInput(activityLevel: .light))
        #expect(profile.ageYears == nil)
        #expect(profile.currentWeightKilograms == nil)
        #expect(store.weightRecords.isEmpty)
    }
}
