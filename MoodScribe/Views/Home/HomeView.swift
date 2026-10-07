import SwiftUI
import UIKit

struct HomeView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        HomeScreen(dataService: SwiftDataService(context: modelContext))
    }
}

private struct HomeScreen: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(JournalPreference.showSentiment) private var showSentiment = true
    @State private var viewModel: HistoryViewModel

    init(dataService: any DataService) {
        _viewModel = State(initialValue: HistoryViewModel(dataService: dataService))
    }

    var body: some View {
        let summary = JournalInsights.weekSummary(entries: viewModel.entries, now: .now)
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(JournalInsights.greeting(for: .now))
                        .font(.title2.weight(.semibold))
                    Text("How are you feeling today?")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                NavigationLink(value: AppRoute.composer(.create)) {
                    Label("New Reflection", systemImage: "square.and.pencil")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(AccessibilityID.newEntry)

                VStack(alignment: .leading, spacing: 8) {
                    Text("This Week")
                        .font(.headline)
                    Text("\(summary.count) \(summary.count == 1 ? "reflection" : "reflections")")
                        .font(.title3.weight(.semibold))
                    Text(summary.detail)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .moodCardStyle()
                .accessibilityIdentifier(AccessibilityID.homeWeek)
                .accessibilityElement(children: .combine)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Recent Reflections")
                        .font(.headline)
                    if viewModel.entries.isEmpty {
                        Text("Your reflections will show up here.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(Array(viewModel.entries.prefix(3))) { entry in
                            NavigationLink(value: AppRoute.reflection(entry.id)) {
                                ReflectionRow(entry: entry, showsSentiment: showSentiment)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier(AccessibilityID.entryRow)
                        }
                    }
                }
            }
            .padding()
            .frame(maxWidth: sizeClass == .regular ? 680 : .infinity)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("MoodScribe")
        .task { viewModel.reload() }
        .refreshable { viewModel.reload() }
    }
}

struct ReflectionRow: View {
    let entry: JournalEntrySnapshot
    var showsSentiment: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(entry.mood?.emoji ?? "•")
                .font(.title3)
                .frame(width: 32)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.text)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(entry.date, format: .dateTime.month(.abbreviated).day().hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if showsSentiment, entry.didAnalyze {
                Text(entry.sentiment.rawValue)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(entry.sentiment.color(in: colorScheme))
            }
        }
        .padding(12)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [entry.mood?.title ?? "No mood selected", entry.text]
        if showsSentiment, entry.didAnalyze {
            parts.append("\(entry.sentiment.rawValue) writing tone")
        }
        return parts.joined(separator: ", ")
    }
}
