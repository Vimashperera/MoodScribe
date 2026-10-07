import SwiftUI
import UIKit

struct EntryDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(JournalPreference.showSentiment) private var showSentiment = true
    let entryID: UUID

    var body: some View {
        EntryDetailScreen(
            entryID: entryID,
            dataService: SwiftDataService(context: modelContext),
            showSentiment: showSentiment
        )
    }
}

private struct EntryDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var viewModel: EntryDetailViewModel
    @State private var confirmDelete = false
    let showSentiment: Bool

    init(entryID: UUID, dataService: any DataService, showSentiment: Bool) {
        _viewModel = State(initialValue: EntryDetailViewModel(entryID: entryID, dataService: dataService))
        self.showSentiment = showSentiment
    }

    var body: some View {
        ScrollView {
            if let snapshot = viewModel.snapshot {
                Group {
                    if sizeClass == .regular {
                        HStack(alignment: .top, spacing: 20) {
                            reflection(snapshot)
                            details(snapshot)
                        }
                    } else {
                        VStack(spacing: 16) {
                            reflection(snapshot)
                            details(snapshot)
                        }
                    }
                }
                .padding()
            } else {
                ContentUnavailableView(
                    "Reflection unavailable",
                    systemImage: "book.closed",
                    description: Text(viewModel.errorMessage ?? "It may have been deleted.")
                )
                .padding()
            }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete this reflection?",
            isPresented: $confirmDelete,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) { viewModel.delete() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This journal entry will be removed from this device.")
        }
        .task { viewModel.load() }
        .onChange(of: viewModel.didDelete) { _, deleted in
            if deleted { dismiss() }
        }
        .alert(
            "Could not update reflection",
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

    private var navigationTitle: String {
        guard let date = viewModel.snapshot?.date, Calendar.current.isDateInToday(date) else {
            return "Reflection"
        }
        return "Today's Reflection"
    }

    private func reflection(_ snapshot: JournalEntrySnapshot) -> some View {
        VStack(spacing: 12) {
            if showSentiment, snapshot.didAnalyze {
                ZStack {
                    SentimentAuraView(score: snapshot.sentimentScore)
                    SentimentGaugeView(score: snapshot.sentimentScore, label: snapshot.sentiment)
                }
                Text(snapshot.toneSentence)
                    .font(.title3.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AccessibilityID.toneSentence)
                Text("Sentiment score \(snapshot.sentimentScore.formatted(.number.sign(strategy: .always()).precision(.fractionLength(2))))")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier(AccessibilityID.detailScore)
                Text("This describes the tone of the writing.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            } else if showSentiment {
                Text("Sentiment analysis was turned off for this reflection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let mood = snapshot.mood {
                labeledRow(title: "Mood", value: "\(mood.emoji) \(mood.title)")
            }
            if !snapshot.factors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Factors")
                        .font(.subheadline.weight(.semibold))
                    FlexibleKeywordWrap(keywords: snapshot.factors.map(\.title))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .moodCardStyle(tint: reflectionTint(snapshot))
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

            if showSentiment, snapshot.didAnalyze {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Sentiment")
                        .font(.headline)
                    Text(snapshot.sentiment.rawValue)
                        .font(.body)
                    if snapshot.keywords.isEmpty {
                        Text("No distinct themes were found in this writing.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Detected themes")
                            .font(.subheadline.weight(.semibold))
                        FlexibleKeywordWrap(keywords: snapshot.keywords)
                    }
                }
            }

            HStack(spacing: 12) {
                NavigationLink(value: AppRoute.composer(.edit(viewModel.entryID))) {
                    Label("Edit", systemImage: "pencil")
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
        .moodCardStyle(tint: reflectionTint(snapshot))
    }

    private func labeledRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(value)
                .font(.title3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func reflectionTint(_ snapshot: JournalEntrySnapshot) -> Color {
        guard showSentiment, snapshot.didAnalyze else { return .accentColor }
        return snapshot.sentiment.color(in: colorScheme)
    }
}

private extension JournalEntrySnapshot {
    var toneSentence: String {
        SentimentAnalysis(score: sentimentScore, label: sentiment, keywords: keywords).toneSentence
    }
}
