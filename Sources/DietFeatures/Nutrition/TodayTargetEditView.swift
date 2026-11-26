import SwiftUI
import DietCore

struct TodayTargetEditView: View {
    @Environment(\.dismiss) private var dismiss

    private let onSave: (ManualNutritionTarget) throws -> Void

    @State private var caloriesText: String
    @State private var proteinText: String
    @State private var carbohydrateText: String
    @State private var fatText: String
    @State private var errorMessage: String?

    init(initialTarget: DailyTarget, onSave: @escaping (ManualNutritionTarget) throws -> Void) {
        self.onSave = onSave
        _caloriesText = State(initialValue: Self.numberText(initialTarget.calories, digits: 0))
        _proteinText = State(initialValue: Self.numberText(initialTarget.proteinGrams, digits: 1))
        _carbohydrateText = State(initialValue: Self.numberText(initialTarget.carbohydrateGrams, digits: 1))
        _fatText = State(initialValue: Self.numberText(initialTarget.fatGrams, digits: 1))
    }

    var body: some View {
        NavigationStack {
            Form {
                if let errorMessage {
                    Section {
                        errorBanner(message: errorMessage)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        editableNumberRow(title: "目标热量", unit: "kcal", text: $caloriesText)
                        if let estimatedCalories = estimatedMacroCalories {
                            Text("按当前蛋白/碳水/脂肪折算约 \(DietFormat.calories(estimatedCalories))")
                                .font(.caption)
                                .monospacedDigit()
                                .foregroundStyle(DietTheme.Palette.inkSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel("宏量折算热量参考，约 \(DietFormat.calories(estimatedCalories))")
                        }
                    }
                    editableNumberRow(title: "蛋白质", unit: "g", text: $proteinText)
                    editableNumberRow(title: "碳水化合物", unit: "g", text: $carbohydrateText)
                    editableNumberRow(title: "脂肪", unit: "g", text: $fatText)
                } header: {
                    Text("今日目标")
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                } footer: {
                    Text("仅修改今天的目标，不改变阶段方案，也不影响昨天或明天。")
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                }
                .listRowBackground(DietTheme.Palette.surface)
                .listRowSeparatorTint(DietTheme.Palette.hairline)
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .background(DietTheme.Palette.canvas)
            .tint(DietTheme.Palette.primary)
            .navigationTitle("修改今日目标")
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
        .frame(minWidth: 520, idealWidth: 580, minHeight: 420, idealHeight: 470)
    }

    private var estimatedMacroCalories: Double? {
        guard let protein = try? ProfileFormState.optionalDouble(proteinText, field: "蛋白质"),
              let carbs = try? ProfileFormState.optionalDouble(carbohydrateText, field: "碳水化合物"),
              let fat = try? ProfileFormState.optionalDouble(fatText, field: "脂肪"),
              protein.isFinite, carbs.isFinite, fat.isFinite,
              protein >= 0, carbs >= 0, fat >= 0 else {
            return nil
        }
        return NutritionCalculator().energyFromMacros(
            protein: protein,
            carbohydrate: carbs,
            fat: fat
        )
    }

    private func errorBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.body)
                .foregroundStyle(DietTheme.Palette.danger)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text("无法保存今日目标")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(DietTheme.Palette.ink)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(DietTheme.Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: DietTheme.Metrics.controlRadius + 2, style: .continuous)
                .fill(DietTheme.Palette.dangerSoft)
                .overlay {
                    RoundedRectangle(cornerRadius: DietTheme.Metrics.controlRadius + 2, style: .continuous)
                        .stroke(DietTheme.Palette.danger.opacity(0.35), lineWidth: 1)
                }
        }
        .accessibilityElement(children: .combine)
    }

    private func editableNumberRow(title: String, unit: String, text: Binding<String>) -> some View {
        LabeledContent {
            HStack(spacing: 6) {
                TextField("", text: text)
                    .multilineTextAlignment(.trailing)
                    .monospacedDigit()
                    .foregroundStyle(DietTheme.Palette.ink)
                    .accessibilityLabel(title)
                Text(unit)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
                    .frame(width: 34, alignment: .leading)
            }
        } label: {
            Text(title)
                .foregroundStyle(DietTheme.Palette.ink)
        }
    }

    private func save() {
        do {
            errorMessage = nil
            let target = try ManualNutritionTarget(
                calories: requiredNumber(caloriesText, field: "目标热量"),
                proteinGrams: requiredNumber(proteinText, field: "蛋白质"),
                carbohydrateGrams: requiredNumber(carbohydrateText, field: "碳水化合物"),
                fatGrams: requiredNumber(fatText, field: "脂肪")
            ).validated()
            try onSave(target)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func requiredNumber(_ text: String, field: String) throws -> Double {
        guard let value = try ProfileFormState.optionalDouble(text, field: field) else {
            throw FormStateError.invalidNumber(field: field)
        }
        return value
    }

    private static func numberText(_ value: Double, digits: Int) -> String {
        value.formatted(
            .number
                .precision(.fractionLength(0...digits))
                .grouping(.never)
                .locale(Locale(identifier: "en_US_POSIX"))
        )
    }
}
