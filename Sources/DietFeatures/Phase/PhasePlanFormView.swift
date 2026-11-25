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
                PhasePlanFormFields(state: $state)
                if let errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("新阶段方案")
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
            let input = try state.makeInput()
            try viewModel.startNewPhase(input)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
