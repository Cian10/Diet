import SwiftUI
import DietCore

public enum AppTab: Hashable {
    case today
    case diary
    case trends
    case profile
}

public struct MainTabView: View {
    @State private var selection: AppTab = .today
    @ObservedObject private var profileViewModel: ProfileRootViewModel

    private let profileStore: ProfileStoring
    private let phaseStore: PhasePlanStoring
    private let targetStore: DailyTargetStoring
    private let mealStore: MealEntryStoring
    private let llmProvider: LLMClientProviding
    private let imageStore: ImageStoring
    private let configurationStore: LLMConfigurationStoring
    private let keyStore: APIKeyStoring
    private let proposalStore: AdjustmentProposalStoring

    public init(
        profileViewModel: ProfileRootViewModel,
        profileStore: ProfileStoring,
        phaseStore: PhasePlanStoring,
        targetStore: DailyTargetStoring,
        mealStore: MealEntryStoring,
        llmProvider: LLMClientProviding,
        imageStore: ImageStoring,
        configurationStore: LLMConfigurationStoring,
        keyStore: APIKeyStoring,
        proposalStore: AdjustmentProposalStoring
    ) {
        self.profileViewModel = profileViewModel
        self.profileStore = profileStore
        self.phaseStore = phaseStore
        self.targetStore = targetStore
        self.mealStore = mealStore
        self.llmProvider = llmProvider
        self.imageStore = imageStore
        self.configurationStore = configurationStore
        self.keyStore = keyStore
        self.proposalStore = proposalStore
    }

    public var body: some View {
        #if os(macOS)
        NavigationSplitView {
            DietSidebar(selection: $selection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 218, max: 240)
        } detail: {
            destination(for: selection)
        }
        #else
        TabView(selection: $selection) {
            destination(for: .today)
                .tabItem { Label("今天", systemImage: "sun.max") }
                .tag(AppTab.today)
            destination(for: .diary)
                .tabItem { Label("日记", systemImage: "book") }
                .tag(AppTab.diary)
            destination(for: .trends)
                .tabItem { Label("趋势", systemImage: "chart.line.uptrend.xyaxis") }
                .tag(AppTab.trends)
            destination(for: .profile)
                .tabItem { Label("我的", systemImage: "person") }
                .tag(AppTab.profile)
        }
        #endif
    }

    @ViewBuilder
    private func destination(for tab: AppTab) -> some View {
        switch tab {
        case .today:
            NutritionHomeView(
                profileStore: profileStore,
                phaseStore: phaseStore,
                targetStore: targetStore,
                mealStore: mealStore,
                llmProvider: llmProvider,
                imageStore: imageStore
            )
        case .diary:
            DiaryView(
                mealStore: mealStore,
                targetStore: targetStore,
                imageStore: imageStore,
                service: foodService
            )
        case .trends:
            TrendsView(
                service: TrendsService(
                    mealStore: mealStore,
                    targetStore: targetStore,
                    phaseStore: phaseStore,
                    profileStore: profileStore
                ),
                profileStore: profileStore,
                phaseStore: phaseStore,
                proposalStore: proposalStore,
                onReviewChanged: { profileViewModel.reload() }
            )
        case .profile:
            SettingsHubView(
                profileViewModel: profileViewModel,
                configurationStore: configurationStore,
                keyStore: keyStore,
                provider: llmProvider
            )
        }
    }

    private var foodService: FoodLoggingService {
        FoodLoggingService(store: mealStore, clientProvider: llmProvider)
    }
}

public struct SettingsHubView: View {
    @ObservedObject var profileViewModel: ProfileRootViewModel
    let configurationStore: LLMConfigurationStoring
    let keyStore: APIKeyStoring
    let provider: LLMClientProviding
    @State private var isEditingProfile = false

    private var currentPlan: PhasePlan? {
        profileViewModel.plans.first(where: { $0.contains(Date()) })
    }

    public var body: some View {
        NavigationStack {
            DietPage {
                DietPageHeader(title: "我的", subtitle: "管理个人目标与偏好，数据默认保存在本机。") {
                    Button("编辑档案") { isEditingProfile = true }
                        .buttonStyle(.dietSecondary)
                        .disabled(profileViewModel.profile == nil)
                }

                if let error = profileViewModel.errorMessage {
                    DietInlineNotice(.error, title: "无法读取个人数据", message: error)
                }

                if let profile = profileViewModel.profile {
                    profileSummary(profile)
                    settingsGrid(profile)
                } else {
                    DietCard {
                        DietEmptyState(
                            title: "尚未建立个人档案",
                            message: "完成首次设置后，可在这里管理档案、阶段和模型服务。",
                            systemImage: "person.crop.circle"
                        )
                    }
                }

                DietInlineNotice(
                    .info,
                    title: "本地优先",
                    message: "身体数据、饮食记录与原图默认保存在本机。只有主动分析时，相关文本或图片才会发送给所配置的模型供应商。"
                )
            }
            .navigationTitle("我的")
            .onAppear { profileViewModel.reload() }
            .sheet(isPresented: $isEditingProfile) {
                if let profile = profileViewModel.profile {
                    ProfileEditView(profile: profile, viewModel: profileViewModel)
                }
            }
        }
    }

    private func profileSummary(_ profile: UserProfile) -> some View {
        DietCard {
            HStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(DietTheme.Palette.primaryText)
                    .frame(width: 54, height: 54)
                    .background { Circle().fill(DietTheme.Palette.primarySoft) }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 6) {
                    Text("个人档案")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(DietTheme.Palette.ink)
                    Text(bodySummary(profile))
                        .font(.footnote)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                DietStatusBadge(
                    status: currentPlan == nil ? .neutral : .confirmed,
                    title: currentPlan.map { "\($0.phaseType.displayName) · v\($0.version)" } ?? "未设置阶段"
                )
            }
        }
    }

    private func settingsGrid(_ profile: UserProfile) -> some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
            spacing: 12
        ) {
            NavigationLink {
                ProfileRootView(viewModel: profileViewModel)
            } label: {
                DietSettingsCard(
                    title: "今日目标",
                    value: targetSummary,
                    systemImage: "target"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                ProfileRootView(viewModel: profileViewModel)
            } label: {
                DietSettingsCard(
                    title: "健身阶段",
                    value: currentPlan.map { "\($0.phaseType.displayName) · 方案 v\($0.version)" } ?? "创建或切换阶段",
                    systemImage: "figure.strengthtraining.traditional"
                )
            }
            .buttonStyle(.plain)

            Button { isEditingProfile = true } label: {
                DietSettingsCard(
                    title: "身体数据",
                    value: bodySummary(profile),
                    systemImage: "heart.text.square"
                )
            }
            .buttonStyle(.plain)

            Button { isEditingProfile = true } label: {
                DietSettingsCard(
                    title: "饮食偏好",
                    value: preferenceSummary(profile),
                    systemImage: "leaf"
                )
            }
            .buttonStyle(.plain)

            NavigationLink {
                LLMSettingsView(configurationStore: configurationStore, keyStore: keyStore, provider: provider)
            } label: {
                DietSettingsCard(
                    title: "LLM API",
                    value: "配置兼容接口，Key 保存在 Keychain",
                    systemImage: "key"
                )
            }
            .buttonStyle(.plain)

            DietSettingsCard(
                title: "隐私与数据",
                value: "本地保存 · 仅主动分析时上传",
                systemImage: "lock.shield",
                showsChevron: false
            )
        }
    }

    private var targetSummary: String {
        guard let currentPlan else { return "尚未创建阶段目标" }
        if currentPlan.energyStrategy == .manual, let target = currentPlan.manualTarget {
            return "\(DietFormat.calories(target.calories)) · 蛋白质 \(DietFormat.grams(target.proteinGrams))"
        }
        return "按当前档案与阶段规则生成"
    }

    private func bodySummary(_ profile: UserProfile) -> String {
        let age = profile.ageYears.map { "\($0) 岁" } ?? "年龄未填"
        let height = profile.heightCentimeters.map { "\(DietFormat.number($0)) cm" } ?? "身高未填"
        let weight = profile.currentWeightKilograms.map { "\(DietFormat.number($0)) kg" } ?? "体重未填"
        return "\(age) · \(height) · \(weight) · 每周训练 \(profile.trainingSessionsPerWeek) 次"
    }

    private func preferenceSummary(_ profile: UserProfile) -> String {
        let preferences = profile.dietaryPreferences.isEmpty ? "未填写饮食偏好" : profile.dietaryPreferences.joined(separator: "、")
        let restrictions = profile.allergies.isEmpty && profile.avoidedFoods.isEmpty
            ? "未填写忌口或过敏"
            : "已设置忌口／过敏过滤"
        return "\(preferences)；\(restrictions)"
    }
}

private struct DietSettingsCard: View {
    let title: String
    let value: String
    let systemImage: String
    var showsChevron = true

    var body: some View {
        DietCard {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.body.weight(.medium))
                    .foregroundStyle(DietTheme.Palette.primaryText)
                    .frame(width: 34, height: 34)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(DietTheme.Palette.primarySoft)
                    }
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 7) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(DietTheme.Palette.ink)
                    Text(value)
                        .font(.footnote)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                if showsChevron {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .accessibilityHidden(true)
                }
            }
            .frame(minHeight: 60, alignment: .leading)
        }
        .contentShape(Rectangle())
    }
}
