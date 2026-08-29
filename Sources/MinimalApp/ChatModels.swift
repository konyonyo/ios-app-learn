import Foundation
import SwiftData

@Model
final class ChatSession {
    var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage] = []

    init(title: String = "新しい会話") {
        self.id = UUID()
        self.title = title
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

@Model
final class ChatMessage {
    var id: UUID
    var role: String
    var content: String
    var createdAt: Date
    var session: ChatSession?

    var isUser: Bool {
        role == "user"
    }

    var llmMessage: LLMMessage {
        LLMMessage(
            role: role == "user" ? .user : .assistant,
            content: content
        )
    }

    init(content: String, role: String, session: ChatSession? = nil) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.createdAt = Date()
        self.session = session
    }
}
