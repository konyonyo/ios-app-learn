import Foundation

struct LLMMessage: Codable {
    let role: Role
    let content: String

    enum Role: String, Codable {
        case system
        case user
        case assistant
    }
}

protocol LLMClient {
    func send(messages: [LLMMessage]) async throws -> String
}

struct FixedResponseClient: LLMClient {
    let response: String

    func send(messages: [LLMMessage]) async throws -> String {
        response
    }
}

struct OpenAICompatibleClient: LLMClient {
    let endpoint: URL
    let model: String
    let apiKey: String?
    let organizationID: String?

    func send(messages: [LLMMessage]) async throws -> String {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }

        if let organizationID, !organizationID.isEmpty {
            request.setValue(organizationID, forHTTPHeaderField: "OpenAI-Organization")
        }

        let body = RequestBody(model: model, messages: messages, stream: false)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            let message = String(data: data, encoding: .utf8) ?? "Unknown server error"
            throw LLMError.httpError(statusCode: httpResponse.statusCode, message: message)
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let content = decoded.choices.first?.message.content,
              !content.isEmpty else {
            throw LLMError.emptyResponse
        }

        return content
    }

    private struct RequestBody: Encodable {
        let model: String
        let messages: [LLMMessage]
        let stream: Bool
    }

    private struct ResponseBody: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let message: LLMMessage
        }
    }
}

enum LLMError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "サーバーから不正なレスポンスが返されました。"
        case let .httpError(statusCode, message):
            "LLMエンドポイントがHTTP \(statusCode)を返しました。\n\(message)"
        case .emptyResponse:
            "LLMから空の回答が返されました。"
        }
    }
}
