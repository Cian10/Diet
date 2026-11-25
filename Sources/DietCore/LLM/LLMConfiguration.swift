import Foundation
import Security

public enum LLMError: LocalizedError, Equatable {
    case notConfigured
    case invalidConfiguration
    case missingAPIKey
    case invalidAPIKey
    case rateLimited
    case networkUnavailable
    case invalidResponse(String)
    case httpError(Int, String)
    case emptyResult
    case invalidImage

    public var errorDescription: String? {
        switch self {
        case .notConfigured: "请先配置 LLM Base URL 和模型名称。"
        case .invalidConfiguration: "LLM 配置无效，请检查 Base URL 和模型名称。"
        case .missingAPIKey: "请先填写并保存 API Key。"
        case .invalidAPIKey: "API Key 无效或没有访问权限。"
        case .rateLimited: "模型服务请求过于频繁，请稍后重试。"
        case .networkUnavailable: "网络连接失败或请求超时，草稿已保留，可稍后重试。"
        case .invalidResponse(let message): "模型返回结果无法使用：\(message)"
        case .httpError(let code, let message): "模型服务返回 HTTP \(code)：\(message)"
        case .emptyResult: "模型没有返回食物项目，请补充描述或改为手动记录。"
        case .invalidImage: "图片无法读取或压缩，请更换图片。"
        }
    }
}

public struct LLMConfiguration: Codable, Sendable, Equatable {
    public var baseURLString: String
    public var model: String

    public init(baseURLString: String = "https://api.openai.com/v1", model: String = "") {
        self.baseURLString = baseURLString
        self.model = model
    }

    public func validated() throws -> LLMConfiguration {
        let base = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: base), let scheme = url.scheme,
              ["http", "https"].contains(scheme.lowercased()), url.host != nil,
              !model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMError.invalidConfiguration
        }
        return LLMConfiguration(baseURLString: base, model: model.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public var chatCompletionsURL: URL? {
        let base = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if base.hasSuffix("/chat/completions") {
            return URL(string: base)
        }
        return URL(string: base + "/chat/completions")
    }
}

public protocol LLMConfigurationStoring: AnyObject {
    func loadConfiguration() throws -> LLMConfiguration?
    func saveConfiguration(_ configuration: LLMConfiguration) throws
}

public final class InMemoryLLMConfigurationStore: LLMConfigurationStoring {
    private var configuration: LLMConfiguration?
    public init(configuration: LLMConfiguration? = nil) { self.configuration = configuration }
    public func loadConfiguration() throws -> LLMConfiguration? { configuration }
    public func saveConfiguration(_ configuration: LLMConfiguration) throws { self.configuration = configuration }
}

public final class UserDefaultsLLMConfigurationStore: LLMConfigurationStoring {
    private let defaults: UserDefaults
    private let key = "dietapp.llm.configuration"

    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func loadConfiguration() throws -> LLMConfiguration? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try JSONDecoder().decode(LLMConfiguration.self, from: data)
    }

    public func saveConfiguration(_ configuration: LLMConfiguration) throws {
        let data = try JSONEncoder().encode(try configuration.validated())
        defaults.set(data, forKey: key)
    }
}

public protocol APIKeyStoring: AnyObject {
    func loadAPIKey() throws -> String?
    func saveAPIKey(_ key: String) throws
    func deleteAPIKey() throws
}

public final class InMemoryAPIKeyStore: APIKeyStoring {
    private var key: String?
    public init(key: String? = nil) { self.key = key }
    public func loadAPIKey() throws -> String? { key }
    public func saveAPIKey(_ key: String) throws { self.key = key }
    public func deleteAPIKey() throws { key = nil }
}

public final class KeychainAPIKeyStore: APIKeyStoring {
    private let service = "com.yuzhao.DietApp.LLM"
    private let account = "personal-api-key"

    public init() {}

    public func loadAPIKey() throws -> String? {
        var query = baseQuery
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw LLMError.invalidResponse("无法读取 Keychain，状态码 \(status)。")
        }
        return String(data: data, encoding: .utf8)
    }

    public func saveAPIKey(_ key: String) throws {
        let data = Data(key.utf8)
        var query = baseQuery
        let status: OSStatus
        if try loadAPIKey() == nil {
            query[kSecValueData as String] = data
            query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            status = SecItemAdd(query as CFDictionary, nil)
        } else {
            status = SecItemUpdate(baseQuery as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        }
        guard status == errSecSuccess else {
            throw LLMError.invalidResponse("无法保存 API Key，Keychain 状态码 \(status)。")
        }
    }

    public func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw LLMError.invalidResponse("无法删除 API Key，Keychain 状态码 \(status)。")
        }
    }

    private var baseQuery: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}

public final class ConfiguredLLMClientProvider: LLMClientProviding {
    private let configurationStore: LLMConfigurationStoring
    private let keyStore: APIKeyStoring
    private let session: URLSession

    public init(configurationStore: LLMConfigurationStoring, keyStore: APIKeyStoring, session: URLSession = .shared) {
        self.configurationStore = configurationStore
        self.keyStore = keyStore
        self.session = session
    }

    public func client() throws -> any LLMClient {
        guard let configuration = try configurationStore.loadConfiguration() else { throw LLMError.notConfigured }
        guard let key = try keyStore.loadAPIKey()?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            throw LLMError.missingAPIKey
        }
        return OpenAICompatibleLLMClient(
            configuration: try configuration.validated(),
            apiKey: key,
            session: session
        )
    }
}
