import SwiftUI
import DietCore

public struct ProfileEditView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: ProfileRootViewModel
    @State private var state: ProfileFormState
    @State private var errorMessage: String?

    public init(profile: UserProfile, viewModel: ProfileRootViewModel) {
        self.viewModel = viewModel
        _state = State(initialValue: ProfileFormState(profile: profile))
    }

    public var body: some View {
        NavigationStack {
            Form {
                ProfileFormFields(state: $state)
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("编辑个人档案")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                }
            }
        }
    }

    private func save() {
        do {
            try viewModel.saveProfile(state.makeInput())
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
