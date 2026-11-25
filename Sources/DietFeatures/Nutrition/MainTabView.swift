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
            List(selection: sidebarSelection) {
                Label("今天", systemImage: "sun.max").tag(AppTab.today)
                Label("日记", systemImage: "book").tag(AppTab.diary)
                Label("趋势", systemImage: "chart.line.uptrend.xyaxis").tag(AppTab.trends)
                Label("我的", systemImage: "person").tag(AppTab.profile)
            }
            .listStyle(.sidebar)
            .navigationTitle("健身饮食")
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 260)
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

    #if os(macOS)
    private var sidebarSelection: Binding<AppTab?> {
        Binding(
            get: { selection },
            set: { selection = $0 ?? .today }
        )
    }
    #endif

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

    public var body: some View {
        NavigationStack {
            List {
                Section("个人设置") {
                    NavigationLink("个人档案与健身阶段") {
                        ProfileRootView(viewModel: profileViewModel)
                    }
                    NavigationLink("LLM API 设置") {
                        LLMSettingsView(configurationStore: configurationStore, keyStore: keyStore, provider: provider)
                    }
                }
                Section("隐私") {
                    Text("身体数据、饮食记录与原图默认保存在本机。只有主动分析时，相关文本或图片才会发送给所配置的模型供应商。")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("我的")
        }
    }
}
