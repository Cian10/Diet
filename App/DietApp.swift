import SwiftUI
import SwiftData
import DietCore
import DietFeatures

@main
struct DietApp: App {
    private let container: ModelContainer?
    private let modelContext: ModelContext?
    private let imageStore: ImageStoring?
    private let launchError: String?
    private let configurationStore: LLMConfigurationStoring
    private let keyStore: APIKeyStoring
    private let llmProvider: LLMClientProviding

    init() {
        let configurationStore = UserDefaultsLLMConfigurationStore()
        let keyStore = KeychainAPIKeyStore()
        self.configurationStore = configurationStore
        self.keyStore = keyStore
        self.llmProvider = ConfiguredLLMClientProvider(configurationStore: configurationStore, keyStore: keyStore)
        do {
            let container = try DietPersistence.makeContainer()
            let imageStore = try LocalImageStore()
            self.container = container
            self.modelContext = ModelContext(container)
            self.imageStore = imageStore
            self.launchError = nil
        } catch {
            self.container = nil
            self.modelContext = nil
            self.imageStore = nil
            self.launchError = error.localizedDescription
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container, let modelContext, let imageStore {
                    AppRootView(
                        profileStore: SwiftDataProfileStore(modelContext: modelContext),
                        phaseStore: SwiftDataPhasePlanStore(modelContext: modelContext),
                        targetStore: SwiftDataDailyTargetStore(modelContext: modelContext),
                        mealStore: SwiftDataMealEntryStore(modelContext: modelContext),
                        llmProvider: llmProvider,
                        imageStore: imageStore,
                        configurationStore: configurationStore,
                        keyStore: keyStore
                        , proposalStore: SwiftDataAdjustmentProposalStore(modelContext: modelContext)
                    )
                    .modelContainer(container)
                } else {
                    ContentUnavailableView(
                        "无法初始化 App",
                        systemImage: "externaldrive.badge.exclamationmark",
                        description: Text(launchError ?? "请重启 App 后再试。")
                    )
                }
            }
            #if os(macOS)
            .frame(minWidth: 960, minHeight: 640)
            #endif
        }
        #if os(macOS)
        .defaultSize(width: 1100, height: 760)
        #endif
    }
}
