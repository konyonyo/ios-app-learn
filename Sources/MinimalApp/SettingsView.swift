import SwiftUI

struct SettingsView: View {
    @Binding var configuration: LLMConfiguration
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("OpenAI互換API") {
                    TextField("Endpoint URL", text: $configuration.endpoint)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .autocorrectionDisabled()

                    TextField("Model", text: $configuration.model)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    TextField("Organization ID (optional)", text: $configuration.organizationID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    SecureField("API Key", text: $configuration.apiKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }

                Section {
                    Text("未設定の場合は固定応答を使用します。APIキーはKeychainに保存します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                }
            }
        }
    }

    private func save() {
        do {
            try configuration.save()
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    SettingsView(configuration: .constant(.default))
}
