import SwiftUI
import SwiftData

struct RootView: View {
    var body: some View {
        TabView {
            JournalStack {
                HomeView()
            }
            .tabItem { Label("Home", systemImage: "sun.max") }

            JournalStack {
                CalendarJournalView()
            }
            .tabItem { Label("Calendar", systemImage: "calendar") }

            JournalStack {
                TrendsView()
            }
            .tabItem { Label("Trends", systemImage: "chart.line.uptrend.xyaxis") }

            JournalStack {
                SettingsView()
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

private struct JournalStack<Content: View>: View {
    @State private var path = NavigationPath()
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack(path: $path) {
            content()
                .navigationDestination(for: AppRoute.self) { route in
                    switch route {
                    case .composer(let mode):
                        ComposerView(mode: mode) { id in
                            switch mode {
                            case .edit:
                                if !path.isEmpty { path.removeLast() }
                            case .create:
                                if !path.isEmpty { path.removeLast() }
                                path.append(AppRoute.reflection(id))
                            }
                        }
                    case .reflection(let id):
                        EntryDetailView(entryID: id)
                    case .day(let day):
                        DayEntriesView(day: day)
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
