import SwiftUI
import SwiftData

@main
struct MoodScribeApp: App {
    private let container: ModelContainer

    init() {
        let inMemory = ProcessInfo.processInfo.arguments.contains("-ui-testing")
        let schema = Schema([JournalEntry.self])
        let configuration = ModelConfiguration(
            "MoodScribe",
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )
        do {
            container = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("MoodScribe could not open its local store: \(error.localizedDescription)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(container)
    }
}
