import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            HistoryListView(dataService: SwiftDataService(context: modelContext))
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .composer(let mode):
                        ComposerView(mode: mode)
                    case .detail(let id):
                        EntryDetailView(entryID: id)
                    }
                }
        }
    }
}

#Preview {
    let schema = Schema([JournalEntry.self])
    let configuration = ModelConfiguration(
        "Preview",
        schema: schema,
        isStoredInMemoryOnly: true,
        cloudKitDatabase: .none
    )
    let container = try! ModelContainer(for: schema, configurations: [configuration])
    return RootView()
        .modelContainer(container)
}
