import SwiftUI
import UniformTypeIdentifiers

struct KnowledgeView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    @State private var results: [KnowledgeSearchResult] = []
    @State private var isImporting = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    private let store = ChatGPTSQLiteStore()

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                HStack {
                    TextField("過去の会話を検索", text: $query)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { search() }
                    Button("検索") { search() }
                        .disabled(query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal)

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                if results.isEmpty {
                    ContentUnavailableView("検索結果がありません", systemImage: "magnifyingglass", description: Text("ChatGPTエクスポートをインポートして検索してください"))
                } else {
                    List(results) { result in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(result.title).font(.headline)
                            Text(result.role == "user" ? "User" : "Assistant")
                                .font(.caption).foregroundStyle(.secondary)
                            Text(result.content).lineLimit(5)
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("ChatGPT履歴")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Import ZIP") { isImporting = true }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
            .fileImporter(isPresented: $isImporting, allowedContentTypes: [.zip, .json], allowsMultipleSelection: false) { result in
                importFile(result)
            }
            .task {
                if !store.exists {
                    statusMessage = "まだChatGPTエクスポートがインポートされていません。"
                }
            }
        }
    }

    private func search() {
        do {
            results = try store.search(query)
            errorMessage = nil
            statusMessage = "\(results.count)件のメッセージが見つかりました。"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func importFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let imported = try ChatGPTImporter().importFile(at: url)
            statusMessage = "会話\(imported.importedConversationCount)件、メッセージ\(imported.messageCount)件をインポートしました。"
            errorMessage = nil
            results = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    KnowledgeView()
}
