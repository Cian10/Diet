import SwiftUI
import DietCore
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct ComponentEditState: Identifiable {
    public let id: UUID
    public var componentID: UUID?
    public var name = ""
    public var quantityText = "1"
    public var unit = "份"
    public var gramsText = ""
    public var lowerGrams: Double?
    public var upperGrams: Double?
    public var basisQuantityText = "1"
    public var basisUnit: NutritionBasisUnit = .serving
    public var caloriesText = ""
    public var proteinText = ""
    public var carbohydrateText = ""
    public var fatText = ""
    public var fiberText = ""
    public var estimationNote: String?
    public var source: NutritionSource?
    private var originalSnapshot: NutritionSnapshot?

    public init() { id = UUID() }

    public init(component: EntryComponent) {
        id = component.id
        componentID = component.id
        name = component.displayName
        quantityText = Self.text(component.originalQuantity)
        unit = component.originalUnit
        gramsText = component.estimatedGrams.map(Self.text) ?? ""
        lowerGrams = component.estimatedGramsLowerBound
        upperGrams = component.estimatedGramsUpperBound
        originalSnapshot = component.nutritionSnapshot
        estimationNote = component.nutritionSnapshot?.estimationNote
        source = component.nutritionSnapshot?.source
        if let snapshot = component.nutritionSnapshot {
            basisQuantityText = Self.text(snapshot.basisQuantity)
            basisUnit = snapshot.basisUnit
            caloriesText = Self.text(snapshot.calories)
            proteinText = Self.text(snapshot.proteinGrams)
            carbohydrateText = Self.text(snapshot.carbohydrateGrams)
            fatText = Self.text(snapshot.fatGrams)
            fiberText = snapshot.fiberGrams.map(Self.text) ?? ""
        }
    }

    public func makeComponent(existing: EntryComponent? = nil) throws -> EntryComponent {
        let quantity = try ProfileFormState.optionalDouble(quantityText, field: "食物数量") ?? 0
        let grams = try ProfileFormState.optionalDouble(gramsText, field: "估算克数")
        let basisQuantity = try ProfileFormState.optionalDouble(basisQuantityText, field: "营养基准份量") ?? 0
        let displayName = name.trimmingCharacters(in: .whitespacesAndNewlines)

        let calories = try ProfileFormState.optionalDouble(caloriesText, field: "热量")
        let protein = try ProfileFormState.optionalDouble(proteinText, field: "蛋白质")
        let carbohydrate = try ProfileFormState.optionalDouble(carbohydrateText, field: "碳水")
        let fat = try ProfileFormState.optionalDouble(fatText, field: "脂肪")
        let fiber = try ProfileFormState.optionalDouble(fiberText, field: "纤维")
        let snapshot: NutritionSnapshot?
        if let calories, let protein, let carbohydrate, let fat {
            if let originalSnapshot,
               originalSnapshot.basisQuantity == basisQuantity,
               originalSnapshot.basisUnit == basisUnit,
               originalSnapshot.calories == calories,
               originalSnapshot.proteinGrams == protein,
               originalSnapshot.carbohydrateGrams == carbohydrate,
               originalSnapshot.fatGrams == fat,
               originalSnapshot.fiberGrams == fiber {
                snapshot = originalSnapshot
            } else {
                snapshot = NutritionSnapshot(
                    basisQuantity: basisQuantity,
                    basisUnit: basisUnit,
                    calories: calories,
                    proteinGrams: protein,
                    carbohydrateGrams: carbohydrate,
                    fatGrams: fat,
                    fiberGrams: fiber,
                    source: .userCorrection,
                    estimationNote: estimationNote
                )
            }
        } else {
            snapshot = nil
        }
        let foodItem = FoodItem(
            name: displayName,
            brand: existing?.foodItem?.brand,
            regionCode: existing?.foodItem?.regionCode,
            externalIdentifier: existing?.foodItem?.externalIdentifier,
            nutritionSnapshots: snapshot.map { [$0.independentCopy()] } ?? []
        )
        let component = EntryComponent(
            foodItem: foodItem,
            displayName: displayName,
            originalQuantity: quantity,
            originalUnit: unit,
            estimatedGrams: grams,
            estimatedGramsLowerBound: lowerGrams,
            estimatedGramsUpperBound: upperGrams,
            nutritionSnapshot: snapshot.map { $0.independentCopy() }
        )
        return component
    }

    private static func text(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(value)
    }
}

@MainActor
public final class MealConfirmationViewModel: ObservableObject {
    @Published public var components: [ComponentEditState]
    @Published public var consumedAt: Date
    @Published public var mealType: MealType
    @Published public var totals = NutritionTotals()
    @Published public var errorMessage: String?
    @Published public var isSaving = false

    public let entry: MealEntry
    private let service: FoodLoggingService
    private let calculator = NutritionCalculator()

    public init(entry: MealEntry, service: FoodLoggingService) {
        self.entry = entry
        self.service = service
        self.components = entry.components.map(ComponentEditState.init)
        self.consumedAt = entry.consumedAt
        self.mealType = entry.mealType
        recalculatePreview()
    }

    public func addComponent() { components.append(ComponentEditState()) }
    public func removeComponent(at offsets: IndexSet) { components.remove(atOffsets: offsets) }

    public func recalculatePreview() {
        do {
            let preview = MealEntry(
                consumedAt: consumedAt,
                mealType: mealType,
                components: try components.map { try $0.makeComponent() }
            )
            totals = calculator.mealNutrition(preview)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    public func confirm() throws {
        isSaving = true
        defer { isSaving = false }
        let existing = Dictionary(uniqueKeysWithValues: entry.components.map { ($0.id, $0) })
        let updated = try components.map { state in
            try state.makeComponent(existing: state.componentID.flatMap { existing[$0] })
        }
        try service.validate(updated)
        try service.update(entry, components: updated, consumedAt: consumedAt, mealType: mealType)
        try service.confirm(entry)
    }
}

public struct MealConfirmationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: MealConfirmationViewModel
    private let imageStore: ImageStoring?
    public var onConfirmed: () -> Void

    public init(
        entry: MealEntry,
        service: FoodLoggingService,
        imageStore: ImageStoring? = nil,
        onConfirmed: @escaping () -> Void = {}
    ) {
        _viewModel = StateObject(wrappedValue: MealConfirmationViewModel(entry: entry, service: service))
        self.imageStore = imageStore
        self.onConfirmed = onConfirmed
    }

    public var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    DietPageHeader(title: "确认这一餐", subtitle: "核对食物、份量与营养来源后再保存。") {
                        DietStatusBadge(
                            status: viewModel.entry.status == .failed ? .failed : .pending,
                            title: viewModel.entry.status == .failed ? "分析失败，可手动补全" : "确认前请核对"
                        )
                    }

                    mealInformation

                    if geometry.size.width >= 760 {
                        HStack(alignment: .top, spacing: 18) {
                            originalContext
                                .frame(width: 250)
                            editorContent
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 18) {
                            originalContext
                            editorContent
                        }
                    }

                    if !viewModel.totals.isComplete {
                        DietInlineNotice(
                            .warning,
                            title: "部分营养未知",
                            message: "仍有项目无法计算：\(viewModel.totals.unknownItemNames.joined(separator: "、"))。这些项目没有按零摄入处理，请补充后再保存。"
                        )
                    }

                    if let error = viewModel.errorMessage {
                        DietInlineNotice(.error, title: "暂时无法保存", message: error)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 30)
                .frame(maxWidth: 1180)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .background(DietTheme.Palette.paper.ignoresSafeArea())
        }
        .navigationTitle("确认这一餐")
    }

    private var mealInformation: some View {
        DietCard {
            VStack(alignment: .leading, spacing: 13) {
                DietSectionHeader(title: "用餐信息")
                DatePicker("用餐时间", selection: $viewModel.consumedAt)
                MealTypePicker(selection: $viewModel.mealType)
            }
            .tint(DietTheme.Palette.primary)
        }
    }

    private var originalContext: some View {
        DietCard {
            VStack(alignment: .leading, spacing: 12) {
                DietSectionHeader(title: "原始输入")
                if let text = viewModel.entry.originalText {
                    Text(text)
                        .font(.footnote)
                        .foregroundStyle(DietTheme.Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let path = viewModel.entry.localImagePath {
                    if let imageStore,
                       let data = try? imageStore.loadOriginal(relativePath: path) {
                        ConfirmationLocalImage(data: data)
                            .frame(maxHeight: 240)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        Label("图片原图保存在本机", systemImage: "photo")
                            .font(.footnote)
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                    }
                }
                if viewModel.entry.originalText == nil && viewModel.entry.localImagePath == nil {
                    Label("手动记录，无模型原始输入", systemImage: "keyboard")
                        .font(.footnote)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                }

                if let estimation = viewModel.entry.estimationRecords.last {
                    Divider().overlay(DietTheme.Palette.border)
                    DietStatusBadge(status: .estimated, title: "估算质量：\(estimation.quality.displayName)")
                    if !estimation.assumptions.isEmpty {
                        Text("假设：\(estimation.assumptions.joined(separator: "；"))")
                            .font(.caption)
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !estimation.missingInformation.isEmpty {
                        DietInlineNotice(.warning, message: "缺失：\(estimation.missingInformation.joined(separator: "；"))")
                    }
                }
                if let question = viewModel.entry.estimationRecords.last?.clarificationQuestion {
                    DietInlineNotice(.warning, title: "模型追问", message: question)
                }
            }
        }
    }

    private var editorContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                DietSectionHeader(title: "食物与份量", subtitle: "\(viewModel.components.count) 项")
                Button("添加食物", action: viewModel.addComponent)
                    .buttonStyle(.dietText)
            }

            if viewModel.components.isEmpty {
                DietCard {
                    DietEmptyState(
                        title: "尚未添加食物",
                        message: "至少添加一种食物，并补全可计算的营养信息。"
                    ) {
                        Button("添加食物", action: viewModel.addComponent)
                            .buttonStyle(.dietSecondary)
                    }
                }
            }

            ForEach($viewModel.components) { $component in
                ComponentEditor(component: $component) {
                    viewModel.components.removeAll { $0.id == component.id }
                    viewModel.recalculatePreview()
                }
            }

            Button("更新营养预览", action: viewModel.recalculatePreview)
                .buttonStyle(.dietSecondary)
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 11) {
            HStack(spacing: 18) {
                totalValue("热量", value: DietFormat.calories(viewModel.totals.calories))
                totalValue("蛋白质", value: DietFormat.grams(viewModel.totals.proteinGrams))
                totalValue("碳水", value: DietFormat.grams(viewModel.totals.carbohydrateGrams))
                totalValue("脂肪", value: DietFormat.grams(viewModel.totals.fatGrams))
                Spacer()
            }
            HStack(spacing: 12) {
                Text(viewModel.totals.isComplete ? "已知营养合计" : "部分合计 · 含未知项")
                    .font(.caption)
                    .foregroundStyle(viewModel.totals.isComplete ? DietTheme.Palette.inkSecondary : DietTheme.Palette.warning)
                Spacer()
                Button("返回修改") { dismiss() }
                    .buttonStyle(.dietSecondary)
                    .disabled(viewModel.isSaving)
                Button {
                    do {
                        try viewModel.confirm()
                        onConfirmed()
                        dismiss()
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                } label: {
                    if viewModel.isSaving {
                        DietLoadingLabel(title: "正在保存…")
                    } else {
                        Text("确认并保存")
                    }
                }
                .buttonStyle(.dietPrimary)
                .disabled(viewModel.isSaving)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
        .background {
            DietTheme.Palette.surface
                .overlay(alignment: .top) {
                    Divider().overlay(DietTheme.Palette.border)
                }
                .shadow(color: DietTheme.Palette.ink.opacity(0.05), radius: 8, x: 0, y: -3)
        }
    }

    private func totalValue(_ label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(DietTheme.Palette.inkSecondary)
            Text(value)
                .font(.footnote.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(DietTheme.Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct ComponentEditor: View {
    @Binding var component: ComponentEditState
    let onRemove: () -> Void

    var body: some View {
        DietCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("食物项目")
                        .font(.headline)
                        .foregroundStyle(DietTheme.Palette.ink)
                    if component.source == .modelEstimate {
                        DietStatusBadge(status: .estimated)
                    }
                    Spacer()
                    Button("移除", role: .destructive, action: onRemove)
                        .buttonStyle(.dietText)
                        .foregroundStyle(DietTheme.Palette.danger)
                }

                labeledField("食物名称", text: $component.name, usesDecimalKeyboard: false)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    labeledField("数量", text: $component.quantityText)
                    labeledField("单位，如份、个、克、毫升", text: $component.unit, usesDecimalKeyboard: false)
                    labeledField("估算重量，克", text: $component.gramsText)
                    labeledField("营养基准份量", text: $component.basisQuantityText)
                }

                if let lower = component.lowerGrams, let upper = component.upperGrams {
                    DietInlineNotice(
                        .warning,
                        title: "模型估算范围",
                        message: "\(DietFormat.number(lower))–\(DietFormat.number(upper)) g；不会自动取范围中点，请填写实际确认的克数。"
                    )
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("营养基准单位")
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                    Picker("营养基准单位", selection: $component.basisUnit) {
                        Text("克").tag(NutritionBasisUnit.grams)
                        Text("毫升").tag(NutritionBasisUnit.milliliters)
                        Text("份").tag(NutritionBasisUnit.serving)
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .tint(DietTheme.Palette.primary)
                }

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    labeledField("基准热量，kcal", text: $component.caloriesText)
                    labeledField("蛋白质，g", text: $component.proteinText)
                    labeledField("碳水，g", text: $component.carbohydrateText)
                    labeledField("脂肪，g", text: $component.fatText)
                    labeledField("纤维，g（可选）", text: $component.fiberText)
                }

                if let note = component.estimationNote, !note.isEmpty {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let source = component.source {
                    Text("营养来源：\(source.displayName)")
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                } else {
                    DietInlineNotice(.warning, message: "尚未填写完整营养来源与数值，该项目不会按零摄入处理。")
                }
            }
        }
    }

    private func labeledField(
        _ title: String,
        text: Binding<String>,
        usesDecimalKeyboard: Bool = true
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(DietTheme.Palette.inkSecondary)
            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .dietDecimalKeyboard(optional: usesDecimalKeyboard)
        }
    }
}

private extension View {
    @ViewBuilder
    func dietDecimalKeyboard(optional: Bool) -> some View {
        if optional {
            self.dietDecimalKeyboard()
        } else {
            self
        }
    }
}

private struct ConfirmationLocalImage: View {
    let data: Data

    var body: some View {
        #if os(iOS)
        if let image = UIImage(data: data) {
            Image(uiImage: image).resizable().scaledToFit()
        }
        #elseif os(macOS)
        if let image = NSImage(data: data) {
            Image(nsImage: image).resizable().scaledToFit()
        }
        #endif
    }
}

public extension EstimationQuality {
    var displayName: String {
        switch self {
        case .high: "高"
        case .medium: "中（模型估算）"
        case .low: "低，需要补充信息"
        case .unknown: "未知"
        }
    }
}

public extension NutritionSource {
    var displayName: String {
        switch self {
        case .userLabel: "用户包装标签"
        case .verified: "可核验数据"
        case .genericReference: "App 内置通用参考值"
        case .modelEstimate: "模型估算"
        case .userCorrection: "用户修正"
        }
    }
}
