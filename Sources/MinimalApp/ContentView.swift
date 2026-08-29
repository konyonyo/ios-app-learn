import SwiftUI

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
}

struct ContentView: View {
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "こんにちは。メッセージを入力してください。", isUser: false)
    ]
    @State private var inputText = ""

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

                Divider()

                HStack(alignment: .bottom, spacing: 8) {
                    TextField("メッセージを入力", text: $inputText, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)

                    Button(action: sendMessage) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                    }
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding()
            }
            .navigationTitle("Simple Chat")
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

        messages.append(ChatMessage(text: text, isUser: true))
        messages.append(ChatMessage(text: "これは固定メッセージです。", isUser: false))
        inputText = ""
    }
}

#Preview {
    ContentView()
}
