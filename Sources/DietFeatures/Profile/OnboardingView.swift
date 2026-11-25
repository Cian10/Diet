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
            VStack(spacing: 0) {
                VStack(spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "leaf.fill")
                            .font(.headline)
                            .foregroundStyle(DietTheme.Palette.onPrimary)
                            .frame(width: 34, height: 34)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(DietTheme.Palette.primary)
                            }
                            .accessibilityHidden(true)
                        Text("健身饮食")
                            .font(.title2.weight(.semibold))
                            .foregroundStyle(DietTheme.Palette.ink)
                    }
                    Text("建立你的个人档案与初始阶段")
                        .font(.headline)
                        .foregroundStyle(DietTheme.Palette.ink)
                    Text("数据保存在本机。未填写的身体数据不会用于猜测自动目标。")
                        .font(.footnote)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 26)
                .padding(.horizontal, 24)
                .padding(.bottom, 18)

                HStack(spacing: 0) {
                    Spacer(minLength: 20)
                    Form {
                        Section {
                            Text("可以留空暂时不了解的身体数据；若信息不完整，将不会自动生成目标，可选择手动目标。")
                                .font(.footnote)
                                .foregroundStyle(DietTheme.Palette.inkSecondary)
                        }
                        ProfileFormFields(state: $profileState)
                        PhasePlanFormFields(state: $phaseState)
                        if let errorMessage {
                            Section {
                                DietInlineNotice(.error, title: "暂时无法开始", message: errorMessage)
                            }
                            .listRowBackground(Color.clear)
                        }
                    }
                    .formStyle(.grouped)
                    .scrollContentBackground(.hidden)
                    .background(DietTheme.Palette.canvas)
                    .tint(DietTheme.Palette.primary)
                    .frame(maxWidth: 620)
                    Spacer(minLength: 20)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(DietTheme.Palette.canvas.ignoresSafeArea())
            .navigationTitle("开始使用")
            .safeAreaInset(edge: .bottom) {
                Button {
                    save()
                } label: {
                    Text("开始使用")
                        .frame(maxWidth: .infinity)
                }
                    .buttonStyle(.dietPrimary)
                    .keyboardShortcut(.return, modifiers: .command)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .frame(maxWidth: 628)
                    .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background {
                    DietTheme.Palette.surface
                        .overlay(alignment: .top) {
                            Divider().overlay(DietTheme.Palette.border)
                        }
                }
            }
        }
    }

    private func save() {
        do {
            errorMessage = nil
            let profileInput = try profileState.makeInput().validated()
            let phaseInput = try phaseState.makeInput().validated()
            try viewModel.saveProfile(profileInput)
            try viewModel.startNewPhase(phaseInput)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
