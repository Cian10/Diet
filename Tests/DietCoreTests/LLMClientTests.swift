import Testing
import Foundation
@testable import DietCore

@Suite("OpenAI compatible client", .serialized)
final class LLMClientTests {
    @Test("Text request uses structured output and parses candidates")
    func textRequest() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        let session = stubSession { request in
            capturedRequest = request
            capturedBody = Self.body(from: request)
            return Self.response(status: 200, content: Self.validResultJSON)
        }
        let client = OpenAICompatibleLLMClient(
            configuration: LLMConfiguration(baseURLString: "https://example.com/v1", model: "test-model"),
            apiKey: "secret",
            session: session
        )
        let result = try await client.analyzeFood(FoodUnderstandingRequest(
            text: "一个汉堡",
            consumedAt: Date(),
            mealType: .lunch
        ))

        #expect(result.items.count == 1)
        #expect(result.items.first?.name == "汉堡")
        let request = try #require(capturedRequest)
        #expect(request.url?.absoluteString == "https://example.com/v1/chat/completions")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer secret")
        let body = try #require(capturedBody)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["model"] as? String == "test-model")
        #expect((object["response_format"] as? [String: String])?["type"] == "json_object")
    }

    @Test("Plain text request omits response_format and returns trimmed text")
    func plainTextGeneration() async throws {
        var capturedRequest: URLRequest?
        var capturedBody: Data?
        let session = stubSession { request in
            capturedRequest = request
            capturedBody = Self.body(from: request)
            return Self.response(status: 200, content: "  \n这是一段普通饮食分析。\n  ")
        }
        let client = OpenAICompatibleLLMClient(
            configuration: LLMConfiguration(baseURLString: "https://example.com/v1", model: "analysis-model"),
            apiKey: "secret",
            session: session
        )
        let result = try await client.generateText(TextGenerationRequest(
            systemPrompt: "只输出中文分析。",
            userPrompt: "分析今天的记录。"
        ))

        #expect(result == "这是一段普通饮食分析。")
        _ = try #require(capturedRequest)
        let body = try #require(capturedBody)
        let object = try #require(try JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(object["response_format"] == nil)
        #expect(object["model"] as? String == "analysis-model")
        let messages = try #require(object["messages"] as? [[String: Any]])
        #expect(messages.count == 2)
    }

    @Test("Plain text request rejects blank model output")
    func plainTextEmptyResponse() async {
        let session = stubSession { _ in
            Self.response(status: 200, content: "  \n\n ")
        }
        let client = OpenAICompatibleLLMClient(
            configuration: LLMConfiguration(baseURLString: "https://example.com/v1", model: "analysis-model"),
            apiKey: "secret",
            session: session
        )
        await #expect(throws: LLMError.invalidResponse("模型返回了空文本。")) {
            _ = try await client.generateText(TextGenerationRequest(
                systemPrompt: "输出分析。",
                userPrompt: "分析记录。"
            ))
        }
    }

    @Test("Plain text request surfaces HTTP errors")
    func plainTextHTTPError() async {
        let session = stubSession { _ in
            (HTTPURLResponse(
                url: URL(string: "https://example.com")!,
                statusCode: 500,
                httpVersion: nil,
                headerFields: nil
            )!, Data("server unavailable".utf8))
        }
        let client = OpenAICompatibleLLMClient(
            configuration: LLMConfiguration(baseURLString: "https://example.com/v1", model: "analysis-model"),
            apiKey: "secret",
            session: session
        )
        await #expect(throws: LLMError.httpError(500, "server unavailable")) {
            _ = try await client.generateText(TextGenerationRequest(
                systemPrompt: "输出分析。",
                userPrompt: "分析记录。"
            ))
        }
    }

    @Test("Image request embeds JPEG data URL")
    func imageRequest() async throws {
        var capturedBody: Data?
        let session = stubSession { request in
            capturedBody = Self.body(from: request)
            return Self.response(status: 200, content: Self.validResultJSON)
        }
        let client = OpenAICompatibleLLMClient(
            configuration: LLMConfiguration(baseURLString: "https://example.com/v1/chat/completions", model: "vision"),
            apiKey: "secret",
            session: session
        )
        _ = try await client.analyzeFood(FoodUnderstandingRequest(
            imageData: Data([1, 2, 3]),
            consumedAt: Date(),
            mealType: .dinner
        ))
        let body = String(data: try #require(capturedBody), encoding: .utf8)
        let unescapedBody = body?.replacingOccurrences(of: "\\/", with: "/")
        #expect(unescapedBody?.contains("data:image/jpeg;base64,AQID") == true)
    }

    @Test("Markdown fence is accepted but invalid nutrition is rejected")
    func responseValidation() async throws {
        let fenced = stubSession { _ in
            Self.response(status: 200, content: "```json\n\(Self.validResultJSON)\n```")
        }
        let client = OpenAICompatibleLLMClient(
            configuration: LLMConfiguration(baseURLString: "https://example.com/v1", model: "test"),
            apiKey: "key",
            session: fenced
        )
        let result = try await client.analyzeFood(FoodUnderstandingRequest(text: "汉堡", consumedAt: Date(), mealType: .lunch))
        #expect(result.items.count == 1)

        let invalid = stubSession { _ in
            Self.response(status: 200, content: Self.validResultJSON.replacingOccurrences(of: "\"basisQuantity\":1", with: "\"basisQuantity\":0"))
        }
        let invalidClient = OpenAICompatibleLLMClient(
            configuration: LLMConfiguration(baseURLString: "https://example.com/v1", model: "test"),
            apiKey: "key",
            session: invalid
        )
        await #expect(throws: LLMError.invalidResponse("营养基准必须大于零，营养数值不能为负。")) {
            _ = try await invalidClient.analyzeFood(FoodUnderstandingRequest(text: "汉堡", consumedAt: Date(), mealType: .lunch))
        }
    }

    @Test("Unauthorized response maps to invalid API key")
    func unauthorized() async {
        let session = stubSession { _ in
            let data = Data("{\"error\":{\"message\":\"bad key\"}}".utf8)
            return (HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 401, httpVersion: nil, headerFields: nil)!, data)
        }
        let client = OpenAICompatibleLLMClient(
            configuration: LLMConfiguration(baseURLString: "https://example.com/v1", model: "test"),
            apiKey: "bad",
            session: session
        )
        await #expect(throws: LLMError.invalidAPIKey) {
            _ = try await client.analyzeFood(FoodUnderstandingRequest(text: "苹果", consumedAt: Date(), mealType: .snack))
        }
    }

    @Test("One rate-limit response is retried")
    func retryRateLimit() async throws {
        var count = 0
        let session = stubSession { _ in
            count += 1
            if count == 1 {
                return (HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 429, httpVersion: nil, headerFields: nil)!, Data("{}".utf8))
            }
            return Self.response(status: 200, content: Self.validResultJSON)
        }
        let client = OpenAICompatibleLLMClient(
            configuration: LLMConfiguration(baseURLString: "https://example.com/v1", model: "test"),
            apiKey: "key",
            session: session
        )
        let result = try await client.analyzeFood(FoodUnderstandingRequest(text: "汉堡", consumedAt: Date(), mealType: .lunch))
        #expect(result.items.count == 1)
        #expect(count == 2)
    }

    private func stubSession(
        handler: @escaping (URLRequest) -> (HTTPURLResponse, Data)
    ) -> URLSession {
        URLProtocolStub.handler = handler
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [URLProtocolStub.self]
        return URLSession(configuration: configuration)
    }

    private static func response(status: Int, content: String) -> (HTTPURLResponse, Data) {
        let object: [String: Any] = ["choices": [["message": ["content": content]]]]
        let data = try! JSONSerialization.data(withJSONObject: object)
        return (
            HTTPURLResponse(url: URL(string: "https://example.com/v1/chat/completions")!, statusCode: status, httpVersion: nil, headerFields: nil)!,
            data
        )
    }

    private static func body(from request: URLRequest) -> Data? {
        if let body = request.httpBody { return body }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }

    private static let validResultJSON = """
    {"items":[{"name":"汉堡","brand":null,"quantity":1,"unit":"个","estimatedGrams":null,"estimatedGramsRange":{"lower":200,"upper":300},"mealTime":null,"nutritionBasis":"常见配方","nutrition":{"basisQuantity":1,"basisUnit":"serving","calories":500,"proteinGrams":25,"carbohydrateGrams":50,"fatGrams":20,"fiberGrams":null,"sourceNote":"估算"},"assumptions":["普通汉堡"],"missingInformation":[]}],"needsClarification":false,"clarificationQuestion":null}
    """
}

private final class URLProtocolStub: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
