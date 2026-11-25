import SwiftUI
import DietCore

public struct OnboardingView: View {
    @ObservedObject private var viewModel: ProfileRootViewModel
    @State private var profileState = ProfileFormState()
    @State private var phaseState = PhasePlanFormState()
    @State private var errorMessage: String?

    public init(viewModel: ProfileRootViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("先建立个人档案和初始阶段。数据保存在本机；不完整的身体数据不会用于猜测自动目标。")
                        .foregroundStyle(.secondary)
                }
                ProfileFormFields(state: $profileState)
                PhasePlanFormFields(state: $phaseState)
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("开始使用")
            .safeAreaInset(edge: .bottom) {
                Button("保存并开始") { save() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(.regularMaterial)
            }
        }
    }

    private func save() {
        do {
            let profileInput = try profileState.makeInput().validated()
            let phaseInput = try phaseState.makeInput().validated()
            try viewModel.saveProfile(profileInput)
            try viewModel.startNewPhase(phaseInput)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
