import SwiftData
import SwiftUI

@main
struct MinimalApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [ChatSession.self, ChatMessage.self])
    }
}
