import SwiftUI
import UIKit

struct TrendsView: View {
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TrendsScreen(dataService: SwiftDataService(context: modelContext))
    }
}

private struct TrendsScreen: View {
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(JournalPreference.showSentiment) private var showSentiment = true
    @State private var viewModel: HistoryViewModel

    init(dataService: any DataService) {
        _viewModel = State(initialValue: HistoryViewModel(dataService: dataService))
    }

    var body: some View {
        let period = JournalInsights.periodEntries(viewModel.entries, window: viewModel.trendWindow, now: .now)
        let direction = JournalInsights.moodDirection(period)
        let average = JournalInsights.averageAnalyzedScore(period)
        let factors = JournalInsights.factorCounts(period)
        let themes = JournalInsights.repeatedKeywords(period)
        let note = JournalInsights.observation(period)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Period", selection: $viewModel.trendWindow) {
                    ForEach(TrendWindow.allCases) { window in
                        Text(window == .week ? "Week" : "Month").tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(AccessibilityID.trendCard)

                moodCard(period: period, direction: direction)
                sentimentCard(period: period, average: average)
                factorsCard(factors)
                if !themes.isEmpty, showSentiment {
                    themesCard(themes)
                }
                reflectionCard(period: period, average: average, factors: factors, direction: direction, note: note)
            }
            .padding()
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Trends")
        .task { viewModel.reload() }
        .refreshable { viewModel.reload() }
    }

    private func moodCard(period: [JournalEntrySnapshot], direction: MoodDirection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mood Trend")
                .font(.headline)
            if period.isEmpty {
                Text(JournalInsights.keepJournaling)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if direction == .notEnough {
                Text("Choose a mood on a few reflections to see how it changes.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text(direction.rawValue)
                    .font(.title2.weight(.semibold))
                Text("Based on the moods you selected in this \(viewModel.trendWindow == .week ? "week" : "month").")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .moodCardStyle()
    }

    private func sentimentCard(period: [JournalEntrySnapshot], average: Double?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sentiment Trend")
                .font(.headline)
            if !showSentiment {
                Text("Sentiment analysis is hidden in Settings.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if period.isEmpty {
                Text(JournalInsights.keepJournaling)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let average {
                let analysis = SentimentAnalysis(score: average, label: SentimentType.classify(average), keywords: [])
                Text(analysis.toneTitle)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(analysis.label.color(in: colorScheme))
                Text(analysis.toneSentence)
                    .font(.subheadline)
                Text("Average sentiment score \(analysis.scoreText). This is the tone of your writing, not a health score.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No sentiment has been saved for this period.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .moodCardStyle(tint: .accentColor)
    }

    private func factorsCard(_ factors: [FactorCount]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Common Factors")
                .font(.headline)
            if factors.isEmpty {
                Text(JournalInsights.keepJournaling)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(factors) { item in
                    HStack {
                        Label(item.factor.title, systemImage: item.factor.systemImage)
                        Spacer()
                        Text("\(item.count) \(item.count == 1 ? "entry" : "entries")")
                            .foregroundStyle(.secondary)
                    }
                    .font(.body)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .moodCardStyle()
    }

    private func themesCard(_ themes: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Repeated themes")
                .font(.headline)
            FlexibleKeywordWrap(keywords: themes)
        }
        .moodCardStyle()
    }

    private func reflectionCard(
        period: [JournalEntrySnapshot],
        average: Double?,
        factors: [FactorCount],
        direction: MoodDirection,
        note: String?
    ) -> some View {
        let title = viewModel.trendWindow == .week ? "Your Week" : "Your Month"
        return VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            if period.isEmpty {
                Text(JournalInsights.keepJournaling)
                    .font(.body)
                    .foregroundStyle(.secondary)
            } else {
                Text("You wrote \(period.count) \(period.count == 1 ? "reflection" : "reflections") this \(viewModel.trendWindow == .week ? "week" : "month").")
                    .font(.body)
                if showSentiment, let average {
                    let analysis = SentimentAnalysis(score: average, label: SentimentType.classify(average), keywords: [])
                    Text("Your overall writing tone was \(analysis.toneTitle).")
                        .font(.body)
                }
                if !factors.isEmpty {
                    Text("Most common factors")
                        .font(.subheadline.weight(.semibold))
                    FlexibleKeywordWrap(keywords: factors.prefix(3).map(\.factor.title))
                }
                Text("Mood trend")
                    .font(.subheadline.weight(.semibold))
                Text(direction == .notEnough ? JournalInsights.keepJournaling : direction.rawValue)
                    .font(.body)
                if let note {
                    Text(note)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .moodCardStyle()
    }
}
