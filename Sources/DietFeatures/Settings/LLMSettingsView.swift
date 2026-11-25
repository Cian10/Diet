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
        DietPage {
            DietPageHeader(title: "模型设置", subtitle: "配置 OpenAI 兼容接口，用于你主动发起的饮食分析。") {
                DietStatusBadge(
                    status: viewModel.hasStoredKey ? .confirmed : .neutral,
                    title: viewModel.hasStoredKey ? "Key 已保存" : "未保存 Key"
                )
            }

            DietCard {
                VStack(alignment: .leading, spacing: 16) {
                    DietSectionHeader(title: "OpenAI 兼容接口")
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Base URL").font(.footnote.weight(.medium))
                        TextField("https://api.openai.com/v1", text: $viewModel.baseURL)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("模型名称").font(.footnote.weight(.medium))
                        TextField("输入供应商提供的模型名称", text: $viewModel.model)
                            .textFieldStyle(.roundedBorder)
                            .autocorrectionDisabled()
                    }
                    VStack(alignment: .leading, spacing: 7) {
                        Text("API Key").font(.footnote.weight(.medium))
                        SecureField(viewModel.hasStoredKey ? "输入新 Key 以替换" : "API Key", text: $viewModel.apiKey)
                            .textFieldStyle(.roundedBorder)
                        Text(viewModel.hasStoredKey ? "API Key 已保存在 Keychain，界面不会显示明文。" : "API Key 将保存在 Keychain，不写入普通设置。")
                            .font(.caption)
                            .foregroundStyle(DietTheme.Palette.inkSecondary)
                    }
                }
                .foregroundStyle(DietTheme.Palette.ink)
            }

            DietCard {
                VStack(alignment: .leading, spacing: 13) {
                    DietSectionHeader(title: "保存与连接测试")
                    HStack(spacing: 12) {
                        Button("保存设置", action: save)
                            .buttonStyle(.dietPrimary)
                        Button {
                            Task { await viewModel.testConnection() }
                        } label: {
                            if viewModel.isTesting {
                                DietLoadingLabel(title: "正在测试…")
                            } else {
                                Text("保存并用“一个苹果”测试")
                            }
                        }
                        .buttonStyle(.dietSecondary)
                        .disabled(viewModel.isTesting)
                    }
                    if viewModel.hasStoredKey {
                        Button("删除 API Key", role: .destructive, action: deleteKey)
                            .buttonStyle(.dietText)
                            .foregroundStyle(DietTheme.Palette.danger)
                    }
                    Text("连接测试会发起一次真实 API 请求，可能产生少量费用。Base URL 可填写到 /v1，也可填写完整 /chat/completions 地址。")
                        .font(.caption)
                        .foregroundStyle(DietTheme.Palette.inkSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if let status = viewModel.statusMessage {
                DietInlineNotice(.info, title: "状态", message: status)
            }

            DietInlineNotice(
                .info,
                title: "隐私边界",
                message: "只有点击文本分析、图片识别或连接测试时，相关内容才会发送给当前配置的供应商。"
            )
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
