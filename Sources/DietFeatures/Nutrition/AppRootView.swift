import SwiftUI
import DietCore

public struct AppRootView: View {
    @StateObject private var profileViewModel: ProfileRootViewModel

    private let profileStore: ProfileStoring
    private let phaseStore: PhasePlanStoring
    private let targetStore: DailyTargetStoring
    private let mealStore: MealEntryStoring
    private let llmProvider: LLMClientProviding
    private let imageStore: ImageStoring
    private let configurationStore: LLMConfigurationStoring
    private let keyStore: APIKeyStoring
    private let proposalStore: AdjustmentProposalStoring

    public init(
        profileStore: ProfileStoring,
        phaseStore: PhasePlanStoring,
        targetStore: DailyTargetStoring,
        mealStore: MealEntryStoring,
        llmProvider: LLMClientProviding,
        imageStore: ImageStoring,
        configurationStore: LLMConfigurationStoring,
        keyStore: APIKeyStoring
        , proposalStore: AdjustmentProposalStoring
    ) {
        self.profileStore = profileStore
        self.phaseStore = phaseStore
        self.targetStore = targetStore
        self.mealStore = mealStore
        self.llmProvider = llmProvider
        self.imageStore = imageStore
        self.configurationStore = configurationStore
        self.keyStore = keyStore
        self.proposalStore = proposalStore
        _profileViewModel = StateObject(wrappedValue: ProfileRootViewModel(
            profileStore: profileStore,
            phasePlanStore: phaseStore
        ))
    }

    public var body: some View {
        Group {
            if profileViewModel.profile == nil {
                ProfileRootView(viewModel: profileViewModel)
            } else {
                MainTabView(
                    profileViewModel: profileViewModel,
                    profileStore: profileStore,
                    phaseStore: phaseStore,
                    targetStore: targetStore,
                    mealStore: mealStore,
                    llmProvider: llmProvider,
                    imageStore: imageStore,
                    configurationStore: configurationStore,
                    keyStore: keyStore
                    , proposalStore: proposalStore
                )
            }
        }
        .task { profileViewModel.reload() }
    }
}
