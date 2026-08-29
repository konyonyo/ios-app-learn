import SwiftData
import SwiftUI

struct SessionListView: View {
    let sessions: [ChatSession]
    @Binding var selectedSessionID: UUID?
    let onCreate: () -> Void
    @Environment(\.dismiss) private var dismiss

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
        }
    }
}
