import SwiftUI
import UIKit

struct HistoryListView: View {
    private let dataService: any DataService

    init(dataService: any DataService) {
        self.dataService = dataService
    }

    var body: some View {
        HistoryScreen(dataService: dataService)
    }
}

private struct HistoryScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var viewModel: HistoryViewModel
    @State private var pendingDeleteID: UUID?

    init(dataService: any DataService) {
        _viewModel = State(initialValue: HistoryViewModel(dataService: dataService))
    }

    var body: some View {
        Group {
            if sizeClass == .regular {
                HStack(alignment: .top, spacing: 0) {
                    ScrollView {
                        VStack(spacing: 16) {
                            trendCard
                            calendarCard
                        }
                        .padding()
                    }
                    .frame(maxWidth: 420)
                    Divider()
                    entryList(includesOverview: false)
                }
            } else {
                entryList(includesOverview: true)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("MoodScribe")
        .searchable(text: $viewModel.query, prompt: "Search entries")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink(value: AppRoute.composer(.create)) {
                    Label("New Entry", systemImage: "square.and.pencil")
                }
                .accessibilityIdentifier(AccessibilityID.newEntry)
            }
        }
        .task {
            viewModel.reload()
        }
        .refreshable {
            viewModel.reload()
        }
        .confirmationDialog(
            "Delete this entry?",
            isPresented: Binding(
                get: { pendingDeleteID != nil },
                set: { if !$0 { pendingDeleteID = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let pendingDeleteID {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        viewModel.delete(id: pendingDeleteID)
                    }
                }
                pendingDeleteID = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteID = nil
            }
        } message: {
            Text("This journal entry will be removed from this device.")
        }
        .alert(
            "Could not load journal",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func entryList(includesOverview: Bool) -> some View {
        List {
            if includesOverview {
                Section {
                    trendCard
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    calendarCard
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                }
            }

            Section {
                filterBar
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)

                if let selectedDay = viewModel.selectedDay {
                    Button("Clear \(selectedDay.formatted(date: .abbreviated, time: .omitted))") {
                        viewModel.clearDayFilter()
                    }
                    .font(.subheadline)
                }

                if viewModel.filteredEntries.isEmpty {
                    emptyState
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(viewModel.filteredEntries) { entry in
                        NavigationLink(value: AppRoute.detail(entry.id)) {
                            EntryRow(entry: entry)
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
                Text("Journal")
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: viewModel.filteredEntries.map(\.id))
    }

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Mood trend", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                Spacer()
                Picker("Period", selection: $viewModel.trendWindow) {
                    ForEach(TrendWindow.allCases) { window in
                        Text(window.rawValue).tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 180)
            }

            if let average = viewModel.trendAverage {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(average, format: .number.sign(strategy: .always()).precision(.fractionLength(2)))
                        .font(.largeTitle.weight(.semibold))
                        .foregroundStyle(viewModel.trendLabel.color(in: colorScheme))
                    Text(viewModel.trendLabel.rawValue)
                        .font(.title3.weight(.medium))
                }
                Text("Average polarity across journal entries from the last \(viewModel.trendWindow.lengthInDays) days.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No entries in this period yet. A saved journal will start the trend.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .moodCardStyle(tint: viewModel.trendLabel.color(in: colorScheme))
        .accessibilityIdentifier(AccessibilityID.trendCard)
    }

    private var calendarCard: some View {
        CalendarMonthView(
            month: viewModel.visibleMonth,
            selectedDay: viewModel.selectedDay,
            sentimentForDay: { viewModel.sentiment(on: $0) },
            onSelect: { day in
                withAnimation { viewModel.select(day: day) }
            },
            onShiftMonth: { viewModel.shiftMonth(by: $0) }
        )
        .moodCardStyle(tint: .accentColor)
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
            HStack(spacing: 6) {
                if let sentiment {
                    Image(systemName: sentiment.systemImage)
                }
                Text(title)
            }
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("No entries yet", systemImage: "book.closed")
        } description: {
            Text("Write today’s note and MoodScribe will score the mood on this device.")
        } actions: {
            NavigationLink("Write an entry", value: AppRoute.composer(.create))
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }
}

private struct EntryRow: View {
    let entry: JournalEntrySnapshot

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.sentiment.systemImage)
                .font(.title3)
                .foregroundStyle(entry.sentiment.color(in: colorScheme))
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text)
                    .font(.body)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(entry.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text(entry.sentimentScore, format: .number.sign(strategy: .always()).precision(.fractionLength(2)))
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(entry.sentiment.color(in: colorScheme))
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.sentiment.rawValue) entry, \(entry.text)")
    }
}
