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
    public var onConfirmed: () -> Void

    public init(service: FoodLoggingService, onConfirmed: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: TextLoggingViewModel(service: service))
        self.onConfirmed = onConfirmed
    }

    public var body: some View {
        Form {
            Section("用餐信息") {
                DatePicker("用餐时间", selection: $viewModel.consumedAt)
                MealTypePicker(selection: $viewModel.mealType)
            }
            Section("描述这一餐") {
                TextField("例如：一个麦当劳汉堡、一份中薯条和一杯无糖可乐", text: $viewModel.text, axis: .vertical)
                    .lineLimit(3...6)
                Button(viewModel.isAnalyzing ? "正在分析…" : "分析文本") {
                    Task {
                        await viewModel.analyze()
                        if viewModel.draft?.status == .draft { isConfirming = true }
                    }
                }
                .disabled(viewModel.isAnalyzing || viewModel.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("不调用模型，手动记录") {
                    viewModel.createManual()
                    isConfirming = true
                }
            }
            if let error = viewModel.errorMessage {
                Section("分析失败") {
                    Text(error).foregroundStyle(.red)
                    if viewModel.draft != nil {
                        Button("保留原文并手动补全／重试") { isConfirming = true }
                    }
                }
            }
            if let clarification = viewModel.draft?.estimationRecords.last?.clarificationQuestion {
                Section("需要确认") { Text(clarification) }
            }
        }
        .navigationTitle("文本记录")
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
