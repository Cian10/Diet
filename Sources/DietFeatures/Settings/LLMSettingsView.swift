import SwiftUI
import DietCore

@MainActor
public final class LLMSettingsViewModel: ObservableObject {
    @Published public var baseURL = "https://api.openai.com/v1"
    @Published public var model = ""
    @Published public var apiKey = ""
    @Published public private(set) var hasStoredKey = false
    @Published public var statusMessage: String?
    @Published public var isTesting = false

    private let configurationStore: LLMConfigurationStoring
    private let keyStore: APIKeyStoring
    private let provider: LLMClientProviding

    public init(configurationStore: LLMConfigurationStoring, keyStore: APIKeyStoring, provider: LLMClientProviding) {
        self.configurationStore = configurationStore
        self.keyStore = keyStore
        self.provider = provider
        if let configuration = try? configurationStore.loadConfiguration() {
            baseURL = configuration.baseURLString
            model = configuration.model
        }
        hasStoredKey = (try? keyStore.loadAPIKey())?.isEmpty == false
    }

    public func save() throws {
        let configuration = try LLMConfiguration(baseURLString: baseURL, model: model).validated()
        try configurationStore.saveConfiguration(configuration)
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            try keyStore.saveAPIKey(apiKey.trimmingCharacters(in: .whitespacesAndNewlines))
            apiKey = ""
        }
        hasStoredKey = (try keyStore.loadAPIKey())?.isEmpty == false
        statusMessage = "设置已保存。"
    }

    public func deleteKey() throws {
        try keyStore.deleteAPIKey()
        hasStoredKey = false
        statusMessage = "API Key 已删除。"
    }

    public func testConnection() async {
        isTesting = true
        defer { isTesting = false }
        do {
            try save()
            let request = FoodUnderstandingRequest(text: "一个苹果", consumedAt: Date(), mealType: .snack)
            _ = try await provider.client().analyzeFood(request)
            statusMessage = "连接成功，模型已返回可用的结构化结果。"
        } catch {
            statusMessage = error.localizedDescription
        }
    }
}

public struct LLMSettingsView: View {
    @StateObject private var viewModel: LLMSettingsViewModel

    public init(configurationStore: LLMConfigurationStoring, keyStore: APIKeyStoring, provider: LLMClientProviding) {
        _viewModel = StateObject(wrappedValue: LLMSettingsViewModel(
            configurationStore: configurationStore,
            keyStore: keyStore,
            provider: provider
        ))
    }

    public var body: some View {
        Form {
            Section("OpenAI 兼容接口") {
                TextField("Base URL", text: $viewModel.baseURL)
                    .autocorrectionDisabled()
                TextField("模型名称", text: $viewModel.model)
                    .autocorrectionDisabled()
                SecureField(viewModel.hasStoredKey ? "输入新 Key 以替换" : "API Key", text: $viewModel.apiKey)
                Text(viewModel.hasStoredKey ? "API Key 已保存在 Keychain。" : "API Key 将保存在 Keychain，不写入普通设置。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section {
                Button("保存设置", action: save)
                Button(viewModel.isTesting ? "正在测试…" : "保存并用“一个苹果”测试") {
                    Task { await viewModel.testConnection() }
                }
                .disabled(viewModel.isTesting)
                if viewModel.hasStoredKey {
                    Button("删除 API Key", role: .destructive, action: deleteKey)
                }
            } footer: {
                Text("连接测试会发起一次真实 API 请求，可能产生少量费用。Base URL 可填写到 /v1，也可填写完整 /chat/completions 地址。")
            }
            if let status = viewModel.statusMessage {
                Section("状态") { Text(status) }
            }
        }
        .navigationTitle("模型设置")
    }

    private func save() {
        do { try viewModel.save() } catch { viewModel.statusMessage = error.localizedDescription }
    }

    private func deleteKey() {
        do { try viewModel.deleteKey() } catch { viewModel.statusMessage = error.localizedDescription }
    }
}
