import Testing
import Foundation
@testable import DietFeatures
import DietCore

@Suite("Profile root view model")
@MainActor
final class ProfileRootViewModelTests {
    private let profileStore = InMemoryProfileStore()
    private let phaseStore = InMemoryPhasePlanStore()
    private let viewModel: ProfileRootViewModel

    init() {
        viewModel = ProfileRootViewModel(profileStore: profileStore, phasePlanStore: phaseStore)
    }

    @Test("Initial setup publishes profile and phase")
    func initialSetupPublishesProfileAndPhase() throws {
        viewModel.reload()
        #expect(viewModel.profile == nil)
        #expect(viewModel.plans.isEmpty)

        try viewModel.saveProfile(ProfileInput(ageYears: 30, currentWeightKilograms: 72))
        try viewModel.startNewPhase(PhasePlanInput(
            phaseType: .maintenance,
            energyStrategy: .manual,
            manualTarget: ManualNutritionTarget(
                calories: 2400,
                proteinGrams: 150,
                carbohydrateGrams: 240,
                fatGrams: 75
            )
        ))

        #expect(viewModel.profile?.currentWeightKilograms == 72)
        #expect(viewModel.plans.count == 1)
        #expect(viewModel.plans.first?.phaseType == .maintenance)
        #expect(viewModel.errorMessage == nil)
        #expect(profileStore.weightRecords.count == 1)
    }
}
