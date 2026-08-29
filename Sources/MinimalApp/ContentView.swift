import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool

    var llmMessage: LLMMessage {
        LLMMessage(
            role: isUser ? .user : .assistant,
            content: text
        )
    }
}

struct ContentView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "こんにちは。メッセージを入力してください。", isUser: false)
    ]
    @State private var inputText = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var configuration = LLMConfiguration.load()
    @State private var isShowingSettings = false

    private var llmClient: any LLMClient {
        guard configuration.isConfigured,
              let endpoint = URL(string: configuration.endpoint) else {
            return FixedResponseClient(response: "これは固定メッセージです。")
        }

        return OpenAICompatibleClient(
            endpoint: endpoint,
            model: configuration.model,
            apiKey: configuration.apiKey,
            organizationID: configuration.organizationID
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            messageBubble(message)
                        }
                    }
                    .padding()
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                Divider()

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
                        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    )
                }
                .padding()
            }
            .navigationTitle("Simple Chat")
            .toolbar {
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
        }
    }

    private func messageBubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.isUser {
                Spacer(minLength: 48)
            }

            Text(message.text)
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

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        errorMessage = nil
        messages.append(ChatMessage(text: text, isUser: true))
        isSending = true

        let conversation = messages.map(\.llmMessage)
        let client = llmClient

        Task { @MainActor in
            do {
                let response = try await client.send(messages: conversation)
                messages.append(ChatMessage(text: response, isUser: false))
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}

#Preview {
    ContentView()
}
