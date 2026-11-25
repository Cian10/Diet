import SwiftUI
import DietCore

public struct ProfileFormFields: View {
    @Binding var state: ProfileFormState

    public init(state: Binding<ProfileFormState>) {
        self._state = state
    }

    public var body: some View {
        Section("身体信息") {
            TextField("年龄（可选）", text: $state.ageText)
                .dietNumberKeyboard()
            TextField("身高，厘米（可选）", text: $state.heightText)
                .dietDecimalKeyboard()
            TextField("当前体重，千克（可选）", text: $state.weightText)
                .dietDecimalKeyboard()
            Picker("性别（可选）", selection: $state.biologicalSex) {
                Text("不填写").tag(BiologicalSex?.none)
                ForEach(BiologicalSex.allCases, id: \.self) { sex in
                    Text(sex.displayName).tag(BiologicalSex?.some(sex))
                }
            }
            TextField("体脂率，%（可选）", text: $state.bodyFatText)
                .dietDecimalKeyboard()
        }

        Section("活动与训练") {
            Picker("日常活动水平", selection: $state.activityLevel) {
                ForEach(ActivityLevel.allCases, id: \.self) { level in
                    Text(level.displayName).tag(level)
                }
            }
            Stepper("每周训练 \(state.trainingSessionsPerWeek) 次", value: $state.trainingSessionsPerWeek, in: 0...21)
        }

        Section("饮食约束") {
            TextField("饮食偏好，用顿号分隔", text: $state.dietaryPreferencesText, axis: .vertical)
            TextField("忌口食物，用顿号分隔", text: $state.avoidedFoodsText, axis: .vertical)
            TextField("过敏食物，用顿号分隔", text: $state.allergiesText, axis: .vertical)
            Text("过敏与忌口会在后续推荐模块中作为硬过滤条件。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

extension View {
    func dietNumberKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.numberPad)
        #else
        self
        #endif
    }

    func dietDecimalKeyboard() -> some View {
        #if os(iOS)
        keyboardType(.decimalPad)
        #else
        self
        #endif
    }
}
