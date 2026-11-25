import SwiftUI
import DietCore

@MainActor
public final class TextLoggingViewModel: ObservableObject {
    @Published public var text = ""
    @Published public var consumedAt = Date()
    @Published public var mealType: MealType = .other
    @Published public var draft: MealEntry?
    @Published public var isAnalyzing = false
    @Published public var errorMessage: String?

    public let service: FoodLoggingService

    public init(service: FoodLoggingService) { self.service = service }

    public func analyze() async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            let entry = try draft ?? service.createManualEntry(consumedAt: consumedAt, mealType: mealType)
            draft = entry
            errorMessage = nil
            _ = try await service.analyzeText(
                text,
                consumedAt: consumedAt,
                mealType: mealType,
                existingEntry: entry
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func createManual() {
        do {
            draft = try service.createManualEntry(consumedAt: consumedAt, mealType: mealType)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

public struct TextLoggingView: View {
    @StateObject private var viewModel: TextLoggingViewModel
    @State private var isConfirming = false
    private let onSwitchToPhoto: () -> Void
    public var onConfirmed: () -> Void

    public init(
        service: FoodLoggingService,
        onSwitchToPhoto: @escaping () -> Void = {},
        onConfirmed: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: TextLoggingViewModel(service: service))
        self.onSwitchToPhoto = onSwitchToPhoto
        self.onConfirmed = onConfirmed
    }

    private var trimmedText: String {
        viewModel.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public var body: some View {
        DietPage {
            DietPageHeader(title: "记一餐", subtitle: "用文字描述食物与份量，核对估算后再保存。")

            Picker("输入类型", selection: Binding<DietLoggingRoute>(
                get: { .text },
                set: { route in if route == .photo { onSwitchToPhoto() } }
            )) {
                Text("文字描述").tag(DietLoggingRoute.text)
                Text("图片识别").tag(DietLoggingRoute.photo)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .tint(DietTheme.Palette.primary)
            .frame(maxWidth: 360)

            DietCard {
                VStack(alignment: .leading, spacing: 14) {
                    DietSectionHeader(title: "用餐信息")
                    DatePicker("用餐时间", selection: $viewModel.consumedAt)
                    MealTypePicker(selection: $viewModel.mealType)
                }
                .tint(DietTheme.Palette.primary)
            }

            DietCard {
                VStack(alignment: .leading, spacing: 12) {
                    DietSectionHeader(title: "描述这一餐", subtitle: "越具体，估算越可核对")
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $viewModel.text)
                            .font(.body)
                            .foregroundStyle(DietTheme.Palette.ink)
                            .scrollContentBackground(.hidden)
                            .padding(8)
                            .frame(minHeight: 126)
                            .disabled(viewModel.isAnalyzing)
                        if viewModel.text.isEmpty {
                            Text("例如：一个麦当劳汉堡、一份中薯条和一杯无糖可乐")
                                .font(.body)
                                .foregroundStyle(DietTheme.Palette.inkSecondary)
                                .padding(.horizontal, 13)
                                .padding(.vertical, 16)
                                .allowsHitTesting(false)
                        }
                    }
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DietTheme.Palette.surfaceMuted)
                            .overlay {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(DietTheme.Palette.border, lineWidth: 1)
                            }
                    }
                    Text("模型结果属于估算。确认前请核对食物、份量与营养来源；未知信息不会被当成 0。")
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let error = viewModel.errorMessage {
                        DietInlineNotice(.error, title: "分析失败，原文已保留", message: error)
                        if viewModel.draft != nil {
                            Button("保留原文并手动补全／重试") { isConfirming = true }
                                .buttonStyle(.dietSecondary)
                        }
                    }

                    if let clarification = viewModel.draft?.estimationRecords.last?.clarificationQuestion {
                        DietInlineNotice(.warning, title: "需要确认", message: clarification)
                    }

                    HStack(spacing: 12) {
                        Button {
                            Task {
                                await viewModel.analyze()
                                if viewModel.draft?.status == .draft { isConfirming = true }
                            }
                        } label: {
                            if viewModel.isAnalyzing {
                                DietLoadingLabel(title: "正在分析…")
                            } else {
                                Text("分析这一餐")
                            }
                        }
                        .buttonStyle(.dietPrimary)
                        .disabled(viewModel.isAnalyzing || trimmedText.isEmpty)
                        .keyboardShortcut(.return, modifiers: .command)

                        Button("不调用模型，手动记录") {
                            viewModel.createManual()
                            isConfirming = true
                        }
                        .buttonStyle(.dietSecondary)
                        .disabled(viewModel.isAnalyzing)
                    }
                }
            }
        }
        .navigationTitle("记一餐")
        .navigationDestination(isPresented: $isConfirming) {
            if let draft = viewModel.draft {
                MealConfirmationView(entry: draft, service: viewModel.service) {
                    viewModel.draft = nil
                    viewModel.text = ""
                    onConfirmed()
                }
            }
        }
    }
}

public struct MealTypePicker: View {
    @Binding var selection: MealType
    public init(selection: Binding<MealType>) { _selection = selection }
    public var body: some View {
        Picker("餐别", selection: $selection) {
            Text("早餐").tag(MealType.breakfast)
            Text("午餐").tag(MealType.lunch)
            Text("晚餐").tag(MealType.dinner)
            Text("加餐").tag(MealType.snack)
            Text("其他").tag(MealType.other)
        }
    }
}
