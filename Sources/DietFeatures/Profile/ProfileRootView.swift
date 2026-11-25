import SwiftUI
import DietCore

public struct ProfileRootView: View {
    @StateObject private var viewModel: ProfileRootViewModel
    @State private var isEditingProfile = false
    @State private var isAddingPhase = false

    public init(profileStore: ProfileStoring, phasePlanStore: PhasePlanStoring) {
        _viewModel = StateObject(wrappedValue: ProfileRootViewModel(
            profileStore: profileStore,
            phasePlanStore: phasePlanStore
        ))
    }

    public init(viewModel: ProfileRootViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    public var body: some View {
        Group {
            if let errorMessage = viewModel.errorMessage {
                ContentUnavailableView(
                    "无法读取个人数据",
                    systemImage: "exclamationmark.triangle",
                    description: Text(errorMessage)
                )
            } else if let profile = viewModel.profile {
                profileContent(profile)
            } else {
                OnboardingView(viewModel: viewModel)
            }
        }
        .task { viewModel.reload() }
    }

    private func profileContent(_ profile: UserProfile) -> some View {
        NavigationStack {
            List {
                Section("当前方案") {
                    if let current = viewModel.plans.first(where: { $0.contains(Date()) }) {
                        LabeledContent("健身阶段", value: current.phaseType.displayName)
                        LabeledContent("方案版本", value: "v\(current.version)")
                        LabeledContent("开始日期", value: current.startDate.formatted(date: .abbreviated, time: .omitted))
                        targetSummary(current)
                    } else {
                        Text("当前日期没有生效中的阶段方案。")
                            .foregroundStyle(.secondary)
                    }
                    Button("创建或切换阶段") { isAddingPhase = true }
                }

                Section("个人档案") {
                    LabeledContent("年龄", value: profile.ageYears.map { "\($0) 岁" } ?? "未填写")
                    LabeledContent("身高", value: profile.heightCentimeters.map { "\($0.formatted()) cm" } ?? "未填写")
                    LabeledContent("体重", value: profile.currentWeightKilograms.map { "\($0.formatted()) kg" } ?? "未填写")
                    LabeledContent("活动水平", value: profile.activityLevel.displayName)
                    LabeledContent("每周训练", value: "\(profile.trainingSessionsPerWeek) 次")
                    LabeledContent("饮食偏好", value: profile.dietaryPreferences.joined(separator: "、"))
                    LabeledContent("忌口", value: profile.avoidedFoods.joined(separator: "、"))
                    LabeledContent("过敏", value: profile.allergies.joined(separator: "、"))
                    Button("编辑档案") { isEditingProfile = true }
                }

                Section("阶段历史") {
                    if viewModel.plans.isEmpty {
                        Text("尚无阶段方案。")
                    } else {
                        ForEach(viewModel.plans, id: \.id) { plan in
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\(plan.phaseType.displayName) · v\(plan.version)")
                                    .font(.headline)
                                Text("\(plan.status(on: Date()).displayName) · \(dateRange(plan))")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("我的饮食目标")
            .sheet(isPresented: $isEditingProfile) {
                ProfileEditView(profile: profile, viewModel: viewModel)
            }
            .sheet(isPresented: $isAddingPhase) {
                PhasePlanFormView(viewModel: viewModel, startDate: viewModel.suggestedPhaseStartDate())
            }
        }
    }

    @ViewBuilder
    private func targetSummary(_ plan: PhasePlan) -> some View {
        if plan.energyStrategy == .manual, let target = plan.manualTarget {
            LabeledContent("目标热量", value: "\(target.calories.formatted()) kcal")
            LabeledContent("蛋白质／碳水／脂肪", value: "\(target.proteinGrams.formatted())／\(target.carbohydrateGrams.formatted())／\(target.fatGrams.formatted()) g")
        } else {
            LabeledContent("热量调整规则", value: "\(plan.energyAdjustmentPercent?.formatted() ?? "0")%")
            LabeledContent("蛋白质系数", value: "\(plan.macroRule.proteinGramsPerKilogram.formatted()) g/kg")
            LabeledContent("脂肪供能比例", value: "\((plan.macroRule.fatEnergyProportion * 100).formatted())%")
            Text("今日页面会按当天档案生成并保存目标，之后修改档案不会重写历史目标。")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func dateRange(_ plan: PhasePlan) -> String {
        let start = plan.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = plan.endDate?.formatted(date: .abbreviated, time: .omitted) ?? "持续中"
        return "\(start) – \(end)"
    }
}
