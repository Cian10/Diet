import Foundation

public struct OpenAICompatibleLLMClient: LLMClient {
    private let configuration: LLMConfiguration
    private let apiKey: String
    private let session: URLSession

    public init(configuration: LLMConfiguration, apiKey: String, session: URLSession = .shared) {
        self.configuration = configuration
        self.apiKey = apiKey
        self.session = session
    }

    public func analyzeFood(_ request: FoodUnderstandingRequest) async throws -> FoodUnderstandingResult {
        guard let endpoint = configuration.chatCompletionsURL else { throw LLMError.invalidConfiguration }
        guard request.text != nil || request.imageData != nil else {
            throw LLMError.invalidResponse("文本和图片不能同时为空。")
        }

        var urlRequest = URLRequest(url: endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 60
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.httpBody = try JSONEncoder().encode(ChatRequest(
            model: configuration.model,
            messages: messages(for: request),
            responseFormat: ResponseFormat(type: "json_object")
        ))

        var lastError: Error?
        for attempt in 0...1 {
            do {
                let (data, response) = try await session.data(for: urlRequest)
                guard let http = response as? HTTPURLResponse else {
                    throw LLMError.invalidResponse("服务器未返回 HTTP 响应。")
                }
                if http.statusCode == 429, attempt == 0 {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    continue
                }
                guard (200...299).contains(http.statusCode) else {
                    let message = Self.errorMessage(from: data)
                    switch http.statusCode {
                    case 401, 403: throw LLMError.invalidAPIKey
                    case 429: throw LLMError.rateLimited
                    default: throw LLMError.httpError(http.statusCode, message)
                    }
                }
                let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
                guard let content = chatResponse.choices.first?.message.content else {
                    throw LLMError.invalidResponse("响应中没有 message.content。")
                }
                let json = Self.stripCodeFence(content)
                guard let jsonData = json.data(using: .utf8) else {
                    throw LLMError.invalidResponse("模型文本不是 UTF-8。")
                }
                do {
                    return try JSONDecoder().decode(FoodUnderstandingResult.self, from: jsonData).validated()
                } catch let error as LLMError {
                    throw error
                } catch {
                    throw LLMError.invalidResponse("结构化 JSON 解析失败：\(error.localizedDescription)")
                }
            } catch let error as LLMError {
                throw error
            } catch let error as URLError {
                lastError = error
                if attempt == 0, [.timedOut, .networkConnectionLost].contains(error.code) {
                    try await Task.sleep(nanoseconds: 200_000_000)
                    continue
                }
                throw LLMError.networkUnavailable
            } catch {
                lastError = error
                throw LLMError.invalidResponse(error.localizedDescription)
            }
        }
        throw lastError.map { LLMError.invalidResponse($0.localizedDescription) } ?? LLMError.networkUnavailable
    }

    private func messages(for request: FoodUnderstandingRequest) -> [ChatMessageRequest] {
        let system = """
        你是健身饮食 App 的食物理解器。把文本或图片转换为一个 JSON 对象，不要输出 Markdown 或解释文字。
        只返回候选项，不计算每日汇总，不假装照片可以精确测量重量。
        JSON 结构：
        {"items":[{"name":"名称","brand":null,"quantity":1,"unit":"个","estimatedGrams":null,"estimatedGramsRange":{"lower":200,"upper":300},"mealTime":null,"nutritionBasis":"模型估算依据","nutrition":{"basisQuantity":1,"basisUnit":"serving","calories":500,"proteinGrams":25,"carbohydrateGrams":50,"fatGrams":20,"fiberGrams":null,"sourceNote":"常见配方估算"},"assumptions":["假设"],"missingInformation":["缺失信息"]}],"needsClarification":false,"clarificationQuestion":null}
        basisUnit 只能是 grams、milliliters、serving。营养基准与数量必须匹配；不知道营养时 nutrition 返回 null，不能用 0 代替未知。
        多个食物必须拆分。需要追问时 needsClarification=true，并在 clarificationQuestion 只提出一个最影响结果的问题。
        """
        let formatter = ISO8601DateFormatter()
        let context = "用餐时间：\(formatter.string(from: request.consumedAt))；餐别：\(request.mealType.rawValue)。"
        var userContent: [ChatContent] = [.text(context + "\n" + (request.text ?? "请识别图片中的食物。"))]
        if let imageData = request.imageData {
            userContent.append(.imageURL("data:image/jpeg;base64,\(imageData.base64EncodedString())"))
        }
        return [
            ChatMessageRequest(role: "system", content: .text(system)),
            ChatMessageRequest(role: "user", content: .parts(userContent))
        ]
    }

    private static func stripCodeFence(_ content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("```"), trimmed.hasSuffix("```") else { return trimmed }
        let lines = trimmed.components(separatedBy: .newlines)
        return lines.dropFirst().dropLast().joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func errorMessage(from data: Data) -> String {
        if let response = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
            return response.error.message
        }
        return String(data: data, encoding: .utf8).map { String($0.prefix(300)) } ?? "无错误详情"
    }
}

private struct ChatRequest: Encodable {
    let model: String
    let messages: [ChatMessageRequest]
    let responseFormat: ResponseFormat

    enum CodingKeys: String, CodingKey {
        case model, messages, responseFormat = "response_format"
    }
}

private struct ResponseFormat: Encodable { let type: String }

private struct ChatMessageRequest: Encodable {
    enum MessageContent: Encodable {
        case text(String)
        case parts([ChatContent])

        func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .text(let text): try container.encode(text)
            case .parts(let parts): try container.encode(parts)
            }
        }
    }

    let role: String
    let content: MessageContent
}

private enum ChatContent: Encodable {
    case text(String)
    case imageURL(String)

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .text(let text):
            try container.encode("text", forKey: .type)
            try container.encode(text, forKey: .text)
        case .imageURL(let url):
            try container.encode("image_url", forKey: .type)
            try container.encode(ImageURL(url: url), forKey: .imageURL)
        }
    }

    enum CodingKeys: String, CodingKey { case type, text, imageURL = "image_url" }
    struct ImageURL: Encodable { let url: String }
}

private struct ChatResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                if let text = try? container.decode(String.self, forKey: .content) {
                    content = text
                } else if let parts = try? container.decode([ContentPart].self, forKey: .content) {
                    content = parts.compactMap(\.text).joined(separator: "\n")
                } else {
                    content = nil
                }
            }

            enum CodingKeys: String, CodingKey { case content }
        }
        let message: Message
    }
    struct ContentPart: Decodable { let text: String? }
    let choices: [Choice]
}

private struct ErrorResponse: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}
