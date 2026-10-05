import SwiftUI
import UIKit

struct EntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let entryID: UUID

    var body: some View {
        EntryDetailScreen(entryID: entryID, dataService: SwiftDataService(context: modelContext))
    }
}

private struct EntryDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var viewModel: EntryDetailViewModel
    @State private var confirmDelete = false

    init(entryID: UUID, dataService: any DataService) {
        _viewModel = State(initialValue: EntryDetailViewModel(entryID: entryID, dataService: dataService))
    }

    var body: some View {
        ScrollView {
            if let snapshot = viewModel.snapshot {
                Group {
                    if sizeClass == .regular {
                        HStack(alignment: .top, spacing: 20) {
                            meter(snapshot)
                            details(snapshot)
                        }
                    } else {
                        VStack(spacing: 16) {
                            meter(snapshot)
                            details(snapshot)
                        }
                    }
                }
                .padding()
            } else {
                ContentUnavailableView(
                    "Entry unavailable",
                    systemImage: "book.closed",
                    description: Text(viewModel.errorMessage ?? "It may have been deleted.")
                )
                .padding()
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this entry?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                viewModel.delete()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This journal entry will be removed from this device.")
        }
        .task {
            viewModel.load()
        }
        .onChange(of: viewModel.didDelete) { _, deleted in
            if deleted { dismiss() }
        }
        .alert(
            "Could not update entry",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil && viewModel.snapshot != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func meter(_ snapshot: JournalEntrySnapshot) -> some View {
        VStack(spacing: 12) {
            SentimentGaugeView(score: snapshot.sentimentScore, label: snapshot.sentiment)
            Text(snapshot.sentimentScore, format: .number.sign(strategy: .always()).precision(.fractionLength(2)))
                .font(.title2.monospacedDigit().weight(.semibold))
                .accessibilityIdentifier(AccessibilityID.detailScore)
            Text("Polarity from -1.0 to +1.0")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .moodCardStyle(tint: snapshot.sentiment.color(in: colorScheme))
    }

    private func details(_ snapshot: JournalEntrySnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(snapshot.date, format: .dateTime.weekday(.wide).month(.wide).day().year().hour().minute())
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if snapshot.wasEdited {
                    Text("Edited \(snapshot.updatedAt, format: .dateTime.month().day().hour().minute())")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text(snapshot.text)
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier(AccessibilityID.detailText)

            HStack(spacing: 12) {
                statTile(title: "Mood index", value: "\(SentimentAnalysis(score: snapshot.sentimentScore, label: snapshot.sentiment, keywords: snapshot.keywords).moodIndexPercent)%")
                statTile(title: "Words", value: "\(wordCount(snapshot.text))")
                statTile(title: "Class", value: snapshot.sentiment.rawValue)
            }

            VStack(alignment: .leading, spacing: 8) {
                Label("Emotional keywords", systemImage: "text.magnifyingglass")
                    .font(.headline)
                if snapshot.keywords.isEmpty {
                    Text("No distinct keywords were extracted from this entry.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    FlexibleKeywordWrap(keywords: snapshot.keywords)
                }
            }

            HStack(spacing: 12) {
                NavigationLink(value: AppRoute.composer(.edit(viewModel.entryID))) {
                    Label("Edit Entry", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier(AccessibilityID.detailEdit)

                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier(AccessibilityID.detailDelete)
            }
        }
        .moodCardStyle(tint: snapshot.sentiment.color(in: colorScheme))
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func wordCount(_ text: String) -> Int {
        text.split { $0.isWhitespace }.count
    }
}
