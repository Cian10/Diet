import SwiftUI
import DietCore

public struct PhasePlanFormFields: View {
    @Binding var state: PhasePlanFormState

    public init(state: Binding<PhasePlanFormState>) {
        self._state = state
    }

    public var body: some View {
        Section("阶段") {
            Picker("健身阶段", selection: $state.phaseType) {
                ForEach(PhaseType.allCases, id: \.self) { phase in
                    Text(phase.displayName).tag(phase)
                }
            }
            DatePicker("开始日期", selection: $state.startDate, displayedComponents: .date)
            Toggle("设置结束日期", isOn: $state.hasEndDate)
            if state.hasEndDate {
                DatePicker("结束日期", selection: $state.endDate, in: state.startDate..., displayedComponents: .date)
            }
            Toggle("区分训练日与休息日", isOn: $state.usesTrainingDayTargets)
        }

        Section("目标方式") {
            Picker("目标方式", selection: $state.energyStrategy) {
                ForEach(EnergyStrategy.allCases, id: \.self) { strategy in
                    Text(strategy.displayName).tag(strategy)
                }
            }

            if state.energyStrategy == .automatic {
                TextField("相对维持热量的调整比例，%", text: $state.energyAdjustmentText)
                    .dietDecimalKeyboard()
                TextField("蛋白质系数，g/kg", text: $state.proteinPerKilogramText)
                    .dietDecimalKeyboard()
                TextField("脂肪供能比例，%", text: $state.fatEnergyPercentText)
                    .dietDecimalKeyboard()
                Text("活动系数包含日常训练；碳水由目标热量扣除蛋白质和脂肪后计算。")
                    .font(.footnote)
                    .foregroundStyle(DietTheme.Palette.inkSecondary)
            } else {
                TextField("目标热量，kcal", text: $state.caloriesText)
                    .dietDecimalKeyboard()
                TextField("蛋白质，g", text: $state.proteinText)
                    .dietDecimalKeyboard()
                TextField("碳水化合物，g", text: $state.carbohydrateText)
                    .dietDecimalKeyboard()
                TextField("脂肪，g", text: $state.fatText)
                    .dietDecimalKeyboard()
            }
        }
    }
}
