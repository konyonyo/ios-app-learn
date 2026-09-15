import SwiftData
import SwiftUI

struct SessionListView: View {
    let sessions: [ChatSession]
    @Binding var selectedSessionID: UUID?
    let onCreate: () -> Void
    let onDelete: (ChatSession) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var sessionToDelete: ChatSession?

    var body: some View {
        NavigationStack {
            List {
                ForEach(sessions) { session in
                    Button {
                        selectedSessionID = session.id
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(session.title)
                                .foregroundStyle(.primary)
                            Text(session.updatedAt, style: .date)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            sessionToDelete = session
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onCreate()
                        dismiss()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New session")
                }
            }
            .alert("セッションを削除しますか？", isPresented: deleteAlertIsPresented) {
                Button("キャンセル", role: .cancel) {
                    sessionToDelete = nil
                }
                Button("削除", role: .destructive) {
                    if let sessionToDelete {
                        onDelete(sessionToDelete)
                    }
                    self.sessionToDelete = nil
                }
            } message: {
                Text(sessionToDelete?.title ?? "")
            }
        }
    }

    private var deleteAlertIsPresented: Binding<Bool> {
        Binding(
            get: { sessionToDelete != nil },
            set: { isPresented in
                if !isPresented { sessionToDelete = nil }
            }
        )
    }
}
