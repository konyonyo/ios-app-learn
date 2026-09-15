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

struct LLMStreamUpdate: Sendable {
    let content: String
    let reasoning: String
}

struct LLMResponse: Sendable {
    let content: String
    let reasoning: String
}

protocol LLMClient {
    func send(
        messages: [LLMMessage],
        onUpdate: @escaping @MainActor (LLMStreamUpdate) -> Void
    ) async throws -> LLMResponse
}

struct FixedResponseClient: LLMClient {
    let response: String

    func send(
        messages: [LLMMessage],
        onUpdate: @escaping @MainActor (LLMStreamUpdate) -> Void
    ) async throws -> LLMResponse {
        await onUpdate(LLMStreamUpdate(content: response, reasoning: ""))
        return LLMResponse(content: response, reasoning: "")
    }
}

struct OpenAICompatibleClient: LLMClient {
    let endpoint: URL
    let model: String
    let apiKey: String?
    let organizationID: String?
    let reasoningEffort: String?

    func send(
        messages: [LLMMessage],
        onUpdate: @escaping @MainActor (LLMStreamUpdate) -> Void
    ) async throws -> LLMResponse {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        if let apiKey, !apiKey.isEmpty {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        if let organizationID, !organizationID.isEmpty {
            request.setValue(organizationID, forHTTPHeaderField: "OpenAI-Organization")
        }

        let body = RequestBody(
            model: model,
            messages: messages,
            stream: true,
            reasoningEffort: reasoningEffort?.isEmpty == false ? reasoningEffort : nil
        )
        request.httpBody = try JSONEncoder().encode(body)

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            var body = ""
            for try await line in bytes.lines { body += line + "\n" }
            throw LLMError.httpError(statusCode: httpResponse.statusCode, message: body)
        }

        var content = ""
        var reasoning = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data:") else { continue }
            let payload = line.dropFirst("data:".count).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { break }
            guard let data = payload.data(using: .utf8) else { continue }
            let chunk = try JSONDecoder().decode(StreamChunk.self, from: data)
            guard let delta = chunk.choices.first?.delta else { continue }
            let contentPart = delta.content ?? ""
            let reasoningPart = delta.reasoningContent ?? delta.reasoning ?? ""
            content += contentPart
            reasoning += reasoningPart
            if !contentPart.isEmpty || !reasoningPart.isEmpty {
                await onUpdate(LLMStreamUpdate(content: contentPart, reasoning: reasoningPart))
            }
        }

        guard !content.isEmpty || !reasoning.isEmpty else {
            throw LLMError.emptyResponse
        }
        return LLMResponse(content: content, reasoning: reasoning)
    }

    private struct RequestBody: Encodable {
        let model: String
        let messages: [LLMMessage]
        let stream: Bool
        let reasoningEffort: String?

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case stream
            case reasoningEffort = "reasoning_effort"
        }
    }

    private struct StreamChunk: Decodable {
        let choices: [Choice]

        struct Choice: Decodable {
            let delta: Delta
        }

        struct Delta: Decodable {
            let content: String?
            let reasoningContent: String?
            let reasoning: String?

            enum CodingKeys: String, CodingKey {
                case content
                case reasoningContent = "reasoning_content"
                case reasoning
            }
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
