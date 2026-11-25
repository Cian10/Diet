import SwiftUI
import DietCore

public struct PhasePlanFormView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var viewModel: ProfileRootViewModel
    @State private var state: PhasePlanFormState
    @State private var errorMessage: String?

    public init(viewModel: ProfileRootViewModel, startDate: Date = Date()) {
        self.viewModel = viewModel
        _state = State(initialValue: PhasePlanFormState(startDate: startDate))
    }

    public var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        DietInlineNotice(.error, title: "无法保存阶段", message: errorMessage)
                    }
                    .listRowBackground(Color.clear)
                }
                PhasePlanFormFields(state: $state)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(DietTheme.Palette.canvas)
            .tint(DietTheme.Palette.primary)
            .navigationTitle("新阶段方案")
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
        .frame(minWidth: 560, idealWidth: 620, minHeight: 560, idealHeight: 650)
    }

    private func save() {
        do {
            errorMessage = nil
            let input = try state.makeInput()
            try viewModel.startNewPhase(input)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
