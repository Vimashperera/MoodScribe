import SwiftUI
import UIKit

struct CalendarJournalView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        CalendarScreen(dataService: SwiftDataService(context: modelContext))
    }
}

struct DayEntriesView: View {
    @Environment(\.modelContext) private var modelContext
    let day: Date

    var body: some View {
        DayEntriesScreen(day: day, dataService: SwiftDataService(context: modelContext))
    }
}

private struct CalendarScreen: View {
    @AppStorage(JournalPreference.showSentiment) private var showSentiment = true
    @State private var viewModel: HistoryViewModel
    @State private var pendingDeleteID: UUID?
    @State private var openedDay: OpenedDay?

    init(dataService: any DataService) {
        _viewModel = State(initialValue: HistoryViewModel(dataService: dataService))
    }

    var body: some View {
        List {
            Section {
                CalendarMonthView(
                    month: viewModel.visibleMonth,
                    selectedDay: viewModel.selectedDay,
                    markerForDay: { viewModel.marker(on: $0) },
                    onSelect: { openedDay = OpenedDay(date: $0) },
                    onShiftMonth: { viewModel.shiftMonth(by: $0) }
                )
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            Section {
                filterBar
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                if viewModel.filteredEntries.isEmpty {
                    ContentUnavailableView(
                        "No reflections",
                        systemImage: "calendar",
                        description: Text(emptyMessage)
                    )
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                } else {
                    ForEach(viewModel.filteredEntries) { entry in
                        NavigationLink(value: AppRoute.reflection(entry.id)) {
                            ReflectionRow(entry: entry, showsSentiment: showSentiment)
                        }
                        .accessibilityIdentifier(AccessibilityID.entryRow)
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                pendingDeleteID = entry.id
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            } header: {
                Text("Reflections")
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.filteredEntries.map(\.id))
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Calendar")
        .navigationDestination(item: $openedDay) { day in
            DayEntriesView(day: day.date)
        }
        .searchable(text: $viewModel.query, prompt: "Search entries")
        .task { viewModel.reload() }
        .refreshable { viewModel.reload() }
        .confirmationDialog(
            "Delete this reflection?",
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { if !$0 { pendingDeleteID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let pendingDeleteID {
                    withAnimation { viewModel.delete(id: pendingDeleteID) }
                }
                pendingDeleteID = nil
            }
            Button("Cancel", role: .cancel) { pendingDeleteID = nil }
        } message: {
            Text("This journal entry will be removed from this device.")
        }
    }

    private var emptyMessage: String {
        if !viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || viewModel.sentimentFilter != nil {
            return "Nothing matches this search."
        }
        return "Days with a reflection show your mood and the tone of the writing."
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                filterChip(title: "All", sentiment: nil)
                ForEach(SentimentType.allCases) { sentiment in
                    filterChip(title: sentiment.rawValue, sentiment: sentiment)
                }
            }
        }
    }

    private func filterChip(title: String, sentiment: SentimentType?) -> some View {
        let isSelected = viewModel.sentimentFilter == sentiment
        return Button {
            withAnimation { viewModel.sentimentFilter = sentiment }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background {
                    Capsule().fill(isSelected ? Color.accentColor : Color.primary.opacity(0.08))
                }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(AccessibilityID.filter(title))
        .accessibilityValue(isSelected ? "selected" : "not selected")
        .accessibilityAddTraits(isSelected ? .isSelected : .isButton)
    }
}

private struct OpenedDay: Identifiable, Hashable {
    let date: Date
    var id: Date { date }
}

private struct DayEntriesScreen: View {
    @AppStorage(JournalPreference.showSentiment) private var showSentiment = true
    @State private var viewModel: HistoryViewModel
    let day: Date

    init(day: Date, dataService: any DataService) {
        self.day = day
        _viewModel = State(initialValue: HistoryViewModel(dataService: dataService))
    }

    var body: some View {
        let matches = viewModel.entries(on: day)
        Group {
            if matches.isEmpty {
                ContentUnavailableView(
                    "No reflection recorded",
                    systemImage: "calendar.badge.minus",
                    description: Text("Nothing was saved for \(day.formatted(date: .abbreviated, time: .omitted)).")
                )
            } else {
                List(matches) { entry in
                    NavigationLink(value: AppRoute.reflection(entry.id)) {
                        ReflectionRow(entry: entry, showsSentiment: showSentiment)
                    }
                    .accessibilityIdentifier(AccessibilityID.entryRow)
                }
            }
        }
        .navigationTitle(day.formatted(date: .abbreviated, time: .omitted))
        .task { viewModel.reload() }
    }
}
