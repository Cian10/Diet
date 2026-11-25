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
            if viewModel.profile == nil, let errorMessage = viewModel.errorMessage {
                DietPage {
                    DietPageHeader(title: "档案与健身阶段", subtitle: "个人数据读取失败时，不会显示虚假的首次设置状态。")
                    DietInlineNotice(.error, title: "无法读取个人数据", message: errorMessage)
                    Button("重新读取") { viewModel.reload() }
                        .buttonStyle(.dietSecondary)
                }
            } else if let profile = viewModel.profile {
                profileContent(profile)
            } else {
                OnboardingView(viewModel: viewModel)
            }
        }
        .task { viewModel.reload() }
    }

    private func profileContent(_ profile: UserProfile) -> some View {
        DietPage {
            DietPageHeader(title: "档案与健身阶段", subtitle: "当前方案与历史目标分别保存，不追溯改写。") {
                Button("编辑档案") { isEditingProfile = true }
                    .buttonStyle(.dietSecondary)
            }

            if let errorMessage = viewModel.errorMessage {
                DietInlineNotice(.error, title: "无法读取个人数据", message: errorMessage)
            }

            DietCard {
                VStack(alignment: .leading, spacing: 13) {
                    HStack {
                        DietSectionHeader(title: "当前方案")
                        Button("创建或切换阶段") { isAddingPhase = true }
                            .buttonStyle(.dietText)
                    }
                    if let current = viewModel.plans.first(where: { $0.contains(Date()) }) {
                        DietKeyValueRow(title: "健身阶段", value: current.phaseType.displayName)
                        DietKeyValueRow(title: "方案版本", value: "v\(current.version)")
                        DietKeyValueRow(title: "开始日期", value: current.startDate.formatted(date: .abbreviated, time: .omitted))
                        targetSummary(current)
                    } else {
                        DietInlineNotice(.warning, message: "当前日期没有生效中的阶段方案，请创建或切换阶段。")
                    }
                }
            }

            DietCard {
                VStack(alignment: .leading, spacing: 13) {
                    DietSectionHeader(title: "个人档案")
                    DietKeyValueRow(title: "年龄", value: profile.ageYears.map { "\($0) 岁" } ?? "未填写")
                    DietKeyValueRow(title: "身高", value: profile.heightCentimeters.map { "\(DietFormat.number($0)) cm" } ?? "未填写")
                    DietKeyValueRow(title: "体重", value: profile.currentWeightKilograms.map { "\(DietFormat.number($0)) kg" } ?? "未填写")
                    DietKeyValueRow(title: "活动水平", value: profile.activityLevel.displayName)
                    DietKeyValueRow(title: "每周训练", value: "\(profile.trainingSessionsPerWeek) 次")
                    Divider().overlay(DietTheme.Palette.border)
                    DietKeyValueRow(title: "饮食偏好", value: listValue(profile.dietaryPreferences))
                    DietKeyValueRow(title: "忌口", value: listValue(profile.avoidedFoods))
                    DietKeyValueRow(title: "过敏", value: listValue(profile.allergies))
                }
            }

            DietCard(padding: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    DietSectionHeader(title: "阶段历史", subtitle: "\(viewModel.plans.count) 个版本")
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                    if viewModel.plans.isEmpty {
                        Text("尚无阶段方案。")
                            .font(.footnote)
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                            .padding(6)
                    } else {
                        ForEach(viewModel.plans, id: \.id) { plan in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(plan.phaseType.displayName) · v\(plan.version)")
                                        .font(.headline)
                                        .foregroundStyle(DietTheme.Palette.ink)
                                    Text(dateRange(plan))
                                        .font(.footnote)
                                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                                }
                                Spacer()
                                DietStatusBadge(
                                    status: plan.status(on: Date()) == .active ? .confirmed : .neutral,
                                    title: plan.status(on: Date()).displayName
                                )
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 8)
                            if plan.id != viewModel.plans.last?.id {
                                Divider().overlay(DietTheme.Palette.border)
                            }
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

    @ViewBuilder
    private func targetSummary(_ plan: PhasePlan) -> some View {
        if plan.energyStrategy == .manual, let target = plan.manualTarget {
            DietKeyValueRow(title: "目标热量", value: DietFormat.calories(target.calories))
            DietKeyValueRow(
                title: "蛋白质／碳水／脂肪",
                value: "\(DietFormat.number(target.proteinGrams))／\(DietFormat.number(target.carbohydrateGrams))／\(DietFormat.number(target.fatGrams)) g"
            )
        } else {
            DietKeyValueRow(title: "热量调整规则", value: "\(DietFormat.number(plan.energyAdjustmentPercent ?? 0))%")
            DietKeyValueRow(title: "蛋白质系数", value: "\(DietFormat.number(plan.macroRule.proteinGramsPerKilogram)) g/kg")
            DietKeyValueRow(title: "脂肪供能比例", value: "\(DietFormat.number(plan.macroRule.fatEnergyProportion * 100))%")
            Text("今日页面会按当天档案生成并保存目标，之后修改档案不会重写历史目标。")
                .font(.caption)
                .foregroundStyle(DietTheme.Palette.inkSecondary)
        }
    }

    private func listValue(_ values: [String]) -> String {
        values.isEmpty ? "未填写" : values.joined(separator: "、")
    }

    private func dateRange(_ plan: PhasePlan) -> String {
        let start = plan.startDate.formatted(date: .abbreviated, time: .omitted)
        let end = plan.endDate?.formatted(date: .abbreviated, time: .omitted) ?? "持续中"
        return "\(start) – \(end)"
    }
}
