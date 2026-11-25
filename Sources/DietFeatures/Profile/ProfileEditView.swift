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
                if let errorMessage {
                    Section {
                        DietInlineNotice(.error, title: "无法保存", message: errorMessage)
                    }
                    .listRowBackground(Color.clear)
                }
                ProfileFormFields(state: $state)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(DietTheme.Palette.canvas)
            .tint(DietTheme.Palette.primary)
            .navigationTitle("编辑个人档案")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .keyboardShortcut(.return, modifiers: .command)
                }
            }
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 620, idealHeight: 700)
    }

    private func save() {
        do {
            errorMessage = nil
            try viewModel.saveProfile(state.makeInput())
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
