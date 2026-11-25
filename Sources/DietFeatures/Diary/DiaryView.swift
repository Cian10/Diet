import SwiftUI
import DietCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

@MainActor
public final class DiaryViewModel: ObservableObject {
    @Published public var selectedDate = Date()
    @Published public private(set) var entries: [MealEntry] = []
    @Published public private(set) var intake = NutritionTotals()
    @Published public private(set) var target: DailyTarget?
    @Published public var errorMessage: String?

    private let mealStore: MealEntryStoring
    private let targetStore: DailyTargetStoring
    private let imageStore: ImageStoring
    private let calculator = NutritionCalculator()

    public init(mealStore: MealEntryStoring, targetStore: DailyTargetStoring, imageStore: ImageStoring) {
        self.mealStore = mealStore
        self.targetStore = targetStore
        self.imageStore = imageStore
    }

    public func load() {
        do {
            entries = try mealStore.allEntries().filter {
                Calendar.current.isDate($0.consumedAt, inSameDayAs: selectedDate)
            }
            intake = calculator.dailyNutrition(entries: entries, on: selectedDate)
            target = try targetStore.target(on: selectedDate)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func delete(_ entry: MealEntry, deletingImage: Bool) {
        do {
            let path = entry.localImagePath
            try mealStore.deleteEntry(entry)
            if deletingImage, let path { try? imageStore.delete(relativePath: path) }
            load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

public struct DiaryView: View {
    @StateObject private var viewModel: DiaryViewModel
    @State private var entryToDelete: MealEntry?
    private let service: FoodLoggingService
    private let imageStore: ImageStoring

    public init(
        mealStore: MealEntryStoring,
        targetStore: DailyTargetStoring,
        imageStore: ImageStoring,
        service: FoodLoggingService
    ) {
        self.service = service
        self.imageStore = imageStore
        _viewModel = StateObject(wrappedValue: DiaryViewModel(
            mealStore: mealStore,
            targetStore: targetStore,
            imageStore: imageStore
        ))
    }

    public var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("查看日期", selection: $viewModel.selectedDate, displayedComponents: .date)
                        .onChange(of: viewModel.selectedDate) { _, _ in viewModel.load() }
                }
                Section("当日摄入") {
                    LabeledContent("已知热量", value: "\(viewModel.intake.calories.formatted()) kcal")
                    if let target = viewModel.target {
                        LabeledContent("当天目标", value: "\(target.calories.formatted()) kcal")
                    }
                    if !viewModel.intake.isComplete {
                        Text("包含无法计算的项目，当前为部分合计。").foregroundStyle(.orange)
                    }
                }
                Section("餐食记录") {
                    if viewModel.entries.isEmpty {
                        Text("这一天没有记录。").foregroundStyle(.secondary)
                    }
                    ForEach(viewModel.entries, id: \.id) { entry in
                        NavigationLink {
                            MealDetailView(entry: entry, service: service, imageStore: imageStore) {
                                viewModel.load()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(entry.components.isEmpty ? "尚未添加食物" : entry.components.map(\.displayName).joined(separator: "、"))
                                Text("\(entry.mealType.displayName) · \(entry.consumedAt.formatted(date: .omitted, time: .shortened)) · \(entry.status.displayName)")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .swipeActions {
                            Button("删除", role: .destructive) { entryToDelete = entry }
                        }
                    }
                }
                if let error = viewModel.errorMessage {
                    Section { Text(error).foregroundStyle(.red) }
                }
            }
            .navigationTitle("饮食日记")
            .onAppear { viewModel.load() }
            .confirmationDialog(
                "删除这条饮食记录？",
                isPresented: Binding(get: { entryToDelete != nil }, set: { if !$0 { entryToDelete = nil } }),
                titleVisibility: .visible
            ) {
                if let entry = entryToDelete {
                    if entry.localImagePath != nil {
                        Button("删除记录，保留本机图片", role: .destructive) {
                            viewModel.delete(entry, deletingImage: false)
                            entryToDelete = nil
                        }
                        Button("删除记录及本机图片", role: .destructive) {
                            viewModel.delete(entry, deletingImage: true)
                            entryToDelete = nil
                        }
                    } else {
                        Button("删除记录", role: .destructive) {
                            viewModel.delete(entry, deletingImage: false)
                            entryToDelete = nil
                        }
                    }
                }
                Button("取消", role: .cancel) { entryToDelete = nil }
            }
        }
    }
}

public struct MealDetailView: View {
    let entry: MealEntry
    let service: FoodLoggingService
    let imageStore: ImageStoring
    let onChanged: () -> Void

    public var body: some View {
        List {
            Section("记录信息") {
                LabeledContent("餐别", value: entry.mealType.displayName)
                LabeledContent("状态", value: entry.status.displayName)
                LabeledContent("时间", value: entry.consumedAt.formatted(date: .abbreviated, time: .shortened))
                if let text = entry.originalText { Text(text) }
                if let path = entry.localImagePath, let data = try? imageStore.loadOriginal(relativePath: path) {
                    MealLocalImage(data: data).frame(maxHeight: 300)
                }
            }
            Section("食物与营养来源") {
                ForEach(entry.components, id: \.id) { component in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(component.displayName).font(.headline)
                        Text("\(component.originalQuantity.formatted()) \(component.originalUnit)")
                        if let snapshot = component.nutritionSnapshot {
                            Text("\(snapshot.calories.formatted()) kcal / \(snapshot.basisQuantity.formatted()) \(snapshot.basisUnit.displayName)")
                            Text("来源：\(snapshot.source.displayName)").font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("营养信息未知").foregroundStyle(.orange)
                        }
                    }
                }
            }
            if let estimation = entry.estimationRecords.last {
                Section("估算记录") {
                    LabeledContent("质量", value: estimation.quality.displayName)
                    if !estimation.assumptions.isEmpty { Text(estimation.assumptions.joined(separator: "；")) }
                    if let notes = estimation.userCorrectionNotes { Text(notes) }
                }
            }
            Section {
                NavigationLink("编辑并重新确认") {
                    MealConfirmationView(entry: entry, service: service, onConfirmed: onChanged)
                }
            }
        }
        .navigationTitle("餐食详情")
    }
}

private struct MealLocalImage: View {
    let data: Data
    var body: some View {
        #if os(iOS)
        if let image = UIImage(data: data) { Image(uiImage: image).resizable().scaledToFit() }
        #elseif os(macOS)
        if let image = NSImage(data: data) { Image(nsImage: image).resizable().scaledToFit() }
        #endif
    }
}

public extension MealType {
    var displayName: String {
        switch self {
        case .breakfast: "早餐"
        case .lunch: "午餐"
        case .dinner: "晚餐"
        case .snack: "加餐"
        case .other: "其他"
        }
    }
}

public extension NutritionBasisUnit {
    var displayName: String {
        switch self {
        case .grams: "g"
        case .milliliters: "ml"
        case .serving: "份"
        }
    }
}
