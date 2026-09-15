import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ChatSession.updatedAt, order: .reverse)
    private var sessions: [ChatSession]

    @State private var selectedSessionID: UUID?
    @State private var inputText = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var configuration = LLMConfiguration.load()
    @State private var profile = ProfileData.load()
    @State private var isShowingSettings = false
    @State private var isShowingProfile = false
    @State private var isShowingSessions = false
    @State private var isShowingKnowledge = false
    private let knowledgeStore = ChatGPTSQLiteStore()

    private var currentSession: ChatSession? {
        if let selectedSessionID {
            return sessions.first { $0.id == selectedSessionID }
        }
        return sessions.first
    }

    private var currentMessages: [ChatMessage] {
        currentSession?.messages.sorted { $0.createdAt < $1.createdAt } ?? []
    }

    private var llmClient: any LLMClient {
        guard configuration.isConfigured,
              let endpoint = URL(string: configuration.endpoint) else {
            return FixedResponseClient(response: "これは固定メッセージです。")
        }

        return OpenAICompatibleClient(
            endpoint: endpoint,
            model: configuration.model,
            apiKey: configuration.apiKey,
            organizationID: configuration.organizationID,
            reasoningEffort: configuration.reasoningEffort
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let currentSession {
                    messageList(for: currentSession)
                } else {
                    ContentUnavailableView(
                        "会話がありません",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("新しい会話を作成してください")
                    )
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Divider()
                inputBar
            }
            .navigationTitle(currentSession?.title ?? "Simple Chat")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSessions = true
                    } label: {
                        Image(systemName: "list.bullet")
                    }
                    .accessibilityLabel("Sessions")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingKnowledge = true
                    } label: {
                        Image(systemName: "books.vertical")
                    }
                    .accessibilityLabel("ChatGPT history")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingProfile = true
                    } label: {
                        Image(systemName: "person.text.rectangle")
                    }
                    .accessibilityLabel("Profile data")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .sheet(isPresented: $isShowingSettings) {
                SettingsView(configuration: $configuration)
            }
            .sheet(isPresented: $isShowingProfile) {
                ProfileView(profile: $profile)
            }
            .sheet(isPresented: $isShowingKnowledge) {
                KnowledgeView()
            }
            .sheet(isPresented: $isShowingSessions) {
                SessionListView(
                    sessions: sessions,
                    selectedSessionID: $selectedSessionID,
                    onCreate: createSession
                )
            }
            .task {
                ensureSession()
            }
        }
    }

    private func messageList(for session: ChatSession) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(currentMessages) { message in
                    messageBubble(message)
                }
            }
            .padding()
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("メッセージを入力", text: $inputText, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(isSending)

            Button(action: sendMessage) {
                if isSending {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
            }
            .disabled(
                isSending ||
                currentSession == nil ||
                inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            )
        }
        .padding()
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 48)
            }

            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .foregroundStyle(message.isUser ? .white : .primary)
                .background(message.isUser ? Color.blue : Color(.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 16))

            if !message.isUser {
                Spacer(minLength: 48)
            }
        }
    }

    private func ensureSession() {
        guard sessions.isEmpty else {
            if selectedSessionID == nil {
                selectedSessionID = sessions.first?.id
            }
            return
        }
        createSession()
    }

    private func createSession() {
        let session = ChatSession()
        modelContext.insert(session)
        session.messages.append(
            ChatMessage(
                content: "こんにちは。メッセージを入力してください。",
                role: "assistant",
                session: session
            )
        )
        selectedSessionID = session.id
        saveContext()
    }

    private func sendMessage() {
        guard let session = currentSession else { return }

        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        errorMessage = nil

        let userMessage = ChatMessage(content: text, role: "user", session: session)
        session.messages.append(userMessage)
        session.updatedAt = Date()
        saveContext()
        isSending = true

        let conversation = session.messages
            .sorted { $0.createdAt < $1.createdAt }
        let knowledge: [KnowledgeSearchResult]
        do {
            knowledge = try knowledgeStore.search(text, limit: 6)
        } catch {
            errorMessage = "過去の会話の検索に失敗しました: \(error.localizedDescription)"
            isSending = false
            return
        }
        let context = ContextBuilder.build(profile: profile, messages: conversation, knowledge: knowledge)
        let client = llmClient

        Task { @MainActor in
            do {
                let response = try await client.send(messages: context)
                session.messages.append(
                    ChatMessage(content: response, role: "assistant", session: session)
                )
                session.updatedAt = Date()
                saveContext()
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }

    private func saveContext() {
        do {
            try modelContext.save()
        } catch {
            errorMessage = "会話の保存に失敗しました: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [ChatSession.self, ChatMessage.self], inMemory: true)
}
