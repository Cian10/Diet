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

    @discardableResult
    public func delete(_ entry: MealEntry, deletingImage: Bool) -> Bool {
        do {
            let path = entry.localImagePath
            try mealStore.deleteEntry(entry)
            if deletingImage, let path { try? imageStore.delete(relativePath: path) }
            load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

public struct DiaryView: View {
    @StateObject private var viewModel: DiaryViewModel
    @State private var loggingRoute: DietLoggingRoute?
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

    private var displayedMealTypes: [MealType] {
        let standard: [MealType] = [.breakfast, .lunch, .dinner, .snack]
        return viewModel.entries.contains { $0.mealType == .other } ? standard + [.other] : standard
    }

    public var body: some View {
        NavigationStack {
            DietPage {
                DietPageHeader(title: "饮食日记", subtitle: "按日期和餐次回看已保存的真实记录。") {
                    DietLoggingMenu(
                        onText: { loggingRoute = .text },
                        onPhoto: { loggingRoute = .photo }
                    )
                }

                if let error = viewModel.errorMessage {
                    DietInlineNotice(.error, title: "需要处理", message: error)
                }

                dateNavigation
                dailySummary

                if !viewModel.intake.isComplete {
                    let names = viewModel.intake.unknownItemNames.joined(separator: "、")
                    DietInlineNotice(
                        .warning,
                        title: "当日为部分合计",
                        message: names.isEmpty ? "包含无法计算的项目，未知营养没有按零处理。" : "无法计算：\(names)。这些项目没有按零摄入处理。"
                    )
                }

                if viewModel.entries.isEmpty {
                    DietCard {
                        DietEmptyState(
                            title: "这一天没有记录",
                            message: "选择其他日期查看，或为当前日期添加一餐。",
                            systemImage: "book.closed"
                        ) {
                            Button("添加记录") { loggingRoute = .text }
                                .buttonStyle(.dietSecondary)
                        }
                    }
                }

                ForEach(displayedMealTypes, id: \.self) { mealType in
                    mealGroup(mealType)
                }
            }
            .navigationTitle("饮食日记")
            .onAppear { viewModel.load() }
            .sheet(item: $loggingRoute) { route in
                NavigationStack {
                    loggingDestination(route)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("关闭") { loggingRoute = nil }
                            }
                        }
                }
                .frame(minWidth: 620, idealWidth: 680, minHeight: 640, idealHeight: 700)
            }
        }
    }

    private var dateNavigation: some View {
        DietCard(padding: 10) {
            HStack(spacing: 10) {
                Button {
                    shiftDate(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.dietSecondary)
                .accessibilityLabel("前一天")

                DatePicker("查看日期", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .onChange(of: viewModel.selectedDate) { _, _ in viewModel.load() }
                    .accessibilityLabel("选择日记日期")

                Button {
                    shiftDate(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.dietSecondary)
                .accessibilityLabel("后一天")

                if !Calendar.current.isDateInToday(viewModel.selectedDate) {
                    Button("回到今天") {
                        viewModel.selectedDate = Date()
                        viewModel.load()
                    }
                    .buttonStyle(.dietText)
                }
            }
        }
    }

    private var dailySummary: some View {
        DietCard {
            VStack(alignment: .leading, spacing: 16) {
                DietSectionHeader(
                    title: Calendar.current.isDateInToday(viewModel.selectedDate) ? "今日摄入" : "当日摄入",
                    subtitle: DietFormat.day(viewModel.selectedDate)
                )
                HStack(spacing: 0) {
                    summaryValue("已知热量", value: DietFormat.number(viewModel.intake.calories, maximumFractionDigits: 0), unit: "kcal")
                    summaryDivider
                    summaryValue("蛋白质", value: DietFormat.number(viewModel.intake.proteinGrams), unit: "g")
                    summaryDivider
                    summaryValue(
                        "当天目标",
                        value: viewModel.target.map { DietFormat.number($0.calories, maximumFractionDigits: 0) } ?? "—",
                        unit: viewModel.target == nil ? "未设置" : "kcal"
                    )
                }
            }
        }
    }

    private func summaryValue(_ label: String, value: String, unit: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(DietTheme.Palette.inkSecondary)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(DietTheme.Palette.ink)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var summaryDivider: some View {
        Divider()
            .frame(height: 42)
            .overlay(DietTheme.Palette.border)
            .padding(.horizontal, 16)
    }

    private func mealGroup(_ mealType: MealType) -> some View {
        let entries = viewModel.entries
            .filter { $0.mealType == mealType }
            .sorted { $0.consumedAt < $1.consumedAt }
        return DietCard(padding: 12) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 9) {
                    DietMealIcon(mealType: mealType)
                    Text(mealType.displayName)
                        .font(.headline)
                        .foregroundStyle(DietTheme.Palette.ink)
                    Spacer()
                    Text(entries.isEmpty ? "未记录" : "\(entries.count) 条")
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                }
                .padding(.horizontal, 4)
                .padding(.top, 2)

                if entries.isEmpty {
                    Button { loggingRoute = .text } label: {
                        Label("添加\(mealType.displayName)", systemImage: "plus")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(DietTheme.Palette.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(DietTheme.Palette.surfaceMuted)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(DietTheme.Palette.primaryLine, style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                                    }
                            }
                    }
                    .buttonStyle(.plain)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Divider().overlay(DietTheme.Palette.border) }
                        NavigationLink {
                            MealDetailView(
                                entry: entry,
                                service: service,
                                imageStore: imageStore,
                                onChanged: { viewModel.load() },
                                onDelete: { deletingImage in
                                    viewModel.delete(entry, deletingImage: deletingImage)
                                }
                            )
                        } label: {
                            DietMealRow(entry: entry)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func shiftDate(by days: Int) {
        guard let date = Calendar.current.date(byAdding: .day, value: days, to: viewModel.selectedDate) else { return }
        viewModel.selectedDate = date
        viewModel.load()
    }

    @ViewBuilder
    private func loggingDestination(_ route: DietLoggingRoute) -> some View {
        switch route {
        case .text:
            TextLoggingView(service: service, onSwitchToPhoto: { loggingRoute = .photo }) {
                loggingRoute = nil
                viewModel.load()
            }
        case .photo:
            PhotoLoggingView(
                photoService: PhotoLoggingService(imageStore: imageStore, foodLogging: service),
                foodService: service,
                imageStore: imageStore,
                onSwitchToText: { loggingRoute = .text }
            ) {
                loggingRoute = nil
                viewModel.load()
            }
        }
    }
}

public struct MealDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isDeleteConfirmationPresented = false
    @State private var deletionError: String?

    let entry: MealEntry
    let service: FoodLoggingService
    let imageStore: ImageStoring
    let onChanged: () -> Void
    let onDelete: (Bool) -> Bool

    public var body: some View {
        DietPage {
            if let deletionError {
                DietInlineNotice(.error, title: "删除失败", message: deletionError)
            }

            DietPageHeader(
                title: entry.mealType.displayName,
                subtitle: entry.consumedAt.formatted(date: .abbreviated, time: .shortened)
            ) {
                DietStatusBadge(status: entry.status == .confirmed ? .confirmed : entry.status == .failed ? .failed : .pending)
            }

            DietCard {
                VStack(alignment: .leading, spacing: 12) {
                    DietSectionHeader(title: "原始记录")
                    if let text = entry.originalText {
                        Text(text)
                            .font(.body)
                            .foregroundStyle(DietTheme.Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let path = entry.localImagePath, let data = try? imageStore.loadOriginal(relativePath: path) {
                        MealLocalImage(data: data)
                            .frame(maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    if entry.originalText == nil && entry.localImagePath == nil {
                        Text("这条手动记录没有原始文本或图片。")
                            .font(.footnote)
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                    }
                    if let note = entry.note, !note.isEmpty {
                        DietKeyValueRow(title: "备注", value: note)
                    }
                }
            }

            DietCard {
                VStack(alignment: .leading, spacing: 14) {
                    DietSectionHeader(title: "食物与营养来源", subtitle: "\(entry.components.count) 项")
                    if entry.components.isEmpty {
                        Text("尚未添加食物。可进入编辑补充名称、份量与营养信息。")
                            .font(.footnote)
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                    }
                    ForEach(entry.components, id: \.id) { component in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(component.displayName)
                                .font(.headline)
                                .foregroundStyle(DietTheme.Palette.ink)
                            Text("\(DietFormat.number(component.originalQuantity)) \(component.originalUnit)")
                                .font(.footnote)
                                .foregroundStyle(DietTheme.Palette.inkSecondary)
                            if let snapshot = component.nutritionSnapshot {
                                Text("\(DietFormat.calories(snapshot.calories)) / \(DietFormat.number(snapshot.basisQuantity)) \(snapshot.basisUnit.displayName)")
                                    .font(.footnote)
                                    .foregroundStyle(DietTheme.Palette.ink)
                                Text("来源：\(snapshot.source.displayName)")
                                    .font(.caption)
                                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                            } else {
                                DietInlineNotice(.warning, message: "营养信息未知，未按零摄入处理。")
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(DietTheme.Palette.surfaceMuted)
                        }
                    }
                }
            }

            if let estimation = entry.estimationRecords.last {
                DietCard {
                    VStack(alignment: .leading, spacing: 10) {
                        DietSectionHeader(title: "识别依据")
                        DietKeyValueRow(title: "估算质量", value: estimation.quality.displayName)
                        if !estimation.assumptions.isEmpty {
                            Text("假设：\(estimation.assumptions.joined(separator: "；"))")
                                .font(.footnote)
                                .foregroundStyle(DietTheme.Palette.inkSecondary)
                        }
                        if !estimation.missingInformation.isEmpty {
                            DietInlineNotice(.warning, message: "缺失：\(estimation.missingInformation.joined(separator: "；"))")
                        }
                        if let notes = estimation.userCorrectionNotes {
                            Text(notes)
                                .font(.footnote)
                                .foregroundStyle(DietTheme.Palette.inkSecondary)
                        }
                    }
                }
            }

            HStack(spacing: 12) {
                NavigationLink {
                    MealConfirmationView(entry: entry, service: service, imageStore: imageStore, onConfirmed: onChanged)
                } label: {
                    Label("编辑并重新确认", systemImage: "pencil")
                }
                .buttonStyle(.dietSecondary)

                Spacer()

                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    Label("删除记录", systemImage: "trash")
                }
                .buttonStyle(.dietSecondary)
                .foregroundStyle(DietTheme.Palette.danger)
            }
        }
        .navigationTitle("餐食详情")
        .confirmationDialog(
            "删除这条饮食记录？",
            isPresented: $isDeleteConfirmationPresented,
            titleVisibility: .visible
        ) {
            if entry.localImagePath != nil {
                Button("删除记录，保留本机图片", role: .destructive) {
                    delete(deletingImage: false)
                }
                Button("删除记录及本机图片", role: .destructive) {
                    delete(deletingImage: true)
                }
            } else {
                Button("删除记录", role: .destructive) {
                    delete(deletingImage: false)
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("删除后，该餐不再计入饮食汇总。此操作无法撤销。")
        }
    }

    private func delete(deletingImage: Bool) {
        deletionError = nil
        if onDelete(deletingImage) {
            dismiss()
        } else {
            deletionError = "记录仍然保留。请返回上一页查看详细原因，或稍后重试。"
        }
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
