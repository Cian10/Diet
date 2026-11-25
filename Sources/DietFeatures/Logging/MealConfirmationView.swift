import SwiftUI
import DietCore

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
    public var onConfirmed: () -> Void

    public init(entry: MealEntry, service: FoodLoggingService, onConfirmed: @escaping () -> Void = {}) {
        _viewModel = StateObject(wrappedValue: MealConfirmationViewModel(entry: entry, service: service))
        self.onConfirmed = onConfirmed
    }

    public var body: some View {
        Form {
            Section("用餐信息") {
                DatePicker("用餐时间", selection: $viewModel.consumedAt)
                MealTypePicker(selection: $viewModel.mealType)
            }
            if let question = viewModel.entry.estimationRecords.last?.clarificationQuestion {
                Section("模型追问") { Text(question) }
            }
            if let estimation = viewModel.entry.estimationRecords.last {
                Section("识别依据") {
                    LabeledContent("估算质量", value: estimation.quality.displayName)
                    if !estimation.assumptions.isEmpty {
                        Text("假设：\(estimation.assumptions.joined(separator: "；"))")
                    }
                    if !estimation.missingInformation.isEmpty {
                        Text("缺失：\(estimation.missingInformation.joined(separator: "；"))")
                            .foregroundStyle(.orange)
                    }
                }
            }
            ForEach($viewModel.components) { $component in
                Section("食物") {
                    TextField("食物名称", text: $component.name)
                    TextField("数量", text: $component.quantityText).dietDecimalKeyboard()
                    TextField("单位，如份、个、克、毫升", text: $component.unit)
                    TextField("估算重量，克（按克计算时必填）", text: $component.gramsText).dietDecimalKeyboard()
                    if let lower = component.lowerGrams, let upper = component.upperGrams {
                        Text("模型估算范围：\(lower.formatted())–\(upper.formatted()) g；确认页不会自动取中点。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    Picker("营养基准单位", selection: $component.basisUnit) {
                        Text("克").tag(NutritionBasisUnit.grams)
                        Text("毫升").tag(NutritionBasisUnit.milliliters)
                        Text("份").tag(NutritionBasisUnit.serving)
                    }
                    TextField("基准份量", text: $component.basisQuantityText).dietDecimalKeyboard()
                    TextField("基准热量，kcal", text: $component.caloriesText).dietDecimalKeyboard()
                    TextField("蛋白质，g", text: $component.proteinText).dietDecimalKeyboard()
                    TextField("碳水，g", text: $component.carbohydrateText).dietDecimalKeyboard()
                    TextField("脂肪，g", text: $component.fatText).dietDecimalKeyboard()
                    TextField("纤维，g（可选）", text: $component.fiberText).dietDecimalKeyboard()
                    if let note = component.estimationNote, !note.isEmpty {
                        Text(note).font(.footnote).foregroundStyle(.secondary)
                    }
                    if let source = component.source {
                        Text("营养来源：\(source.displayName)")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete(perform: viewModel.removeComponent)
            Section {
                Button("添加食物", action: viewModel.addComponent)
                Button("更新营养预览", action: viewModel.recalculatePreview)
            }
            Section("已知营养合计") {
                LabeledContent("热量", value: "\(viewModel.totals.calories.formatted()) kcal")
                LabeledContent("蛋白质", value: "\(viewModel.totals.proteinGrams.formatted()) g")
                LabeledContent("碳水", value: "\(viewModel.totals.carbohydrateGrams.formatted()) g")
                LabeledContent("脂肪", value: "\(viewModel.totals.fatGrams.formatted()) g")
                if !viewModel.totals.isComplete {
                    Text("仍有项目无法计算：\(viewModel.totals.unknownItemNames.joined(separator: "、"))。这些项目没有按零摄入处理。")
                        .foregroundStyle(.orange)
                }
            }
            if let error = viewModel.errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("确认这一餐")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("确认保存") {
                    do {
                        try viewModel.confirm()
                        onConfirmed()
                        dismiss()
                    } catch {
                        viewModel.errorMessage = error.localizedDescription
                    }
                }
                .disabled(viewModel.isSaving)
            }
        }
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
