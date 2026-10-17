import Charts
import Combine
import SwiftUI
import UIKit

/// Week or month view. Mood direction uses chosen moods. Sentiment averages only rows that were analysed.
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
        let trend = JournalInsights.moodTrend(entries: viewModel.entries, window: viewModel.trendWindow, now: .now)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Picker("Period", selection: $viewModel.trendWindow) {
                    ForEach(TrendWindow.allCases) { window in
                        Text(window == .week ? "Week" : "Month").tag(window)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier(AccessibilityID.trendCard)

                moodChart(trend)
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
        .onReceive(NotificationCenter.default.publisher(for: .journalStoreDidChange)) { _ in
            viewModel.reload()
        }
    }

    private func moodChart(_ trend: MoodTrend) -> some View {
        let hasMood = trend.points.contains { $0.chosenMood != nil }
        let hasTone = showSentiment && trend.points.contains { $0.writingTone != nil }
        let periodName = viewModel.trendWindow == .week ? "week" : "month"

        return VStack(alignment: .leading, spacing: 10) {
            Text("Mood over time")
                .font(.headline)
            if hasMood || hasTone {
                Chart {
                    ForEach(trend.points) { point in
                        if let mood = point.chosenMood {
                            LineMark(
                                x: .value("Day", point.day, unit: .day),
                                y: .value("Level", mood)
                            )
                            .foregroundStyle(by: .value("Series", "Chosen mood"))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2.5))

                            PointMark(
                                x: .value("Day", point.day, unit: .day),
                                y: .value("Level", mood)
                            )
                            .foregroundStyle(by: .value("Series", "Chosen mood"))
                            .symbolSize(70)
                        }
                        if showSentiment, let tone = point.writingTone {
                            LineMark(
                                x: .value("Day", point.day, unit: .day),
                                y: .value("Level", tone)
                            )
                            .foregroundStyle(by: .value("Series", "Writing tone"))
                            .interpolationMethod(.monotone)
                            .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 3]))

                            PointMark(
                                x: .value("Day", point.day, unit: .day),
                                y: .value("Level", tone)
                            )
                            .foregroundStyle(by: .value("Series", "Writing tone"))
                            .symbolSize(36)
                        }
                    }
                }
                .chartForegroundStyleScale([
                    "Chosen mood": Color.accentColor,
                    "Writing tone": SentimentType.interpolatedColor(for: 0.35, scheme: colorScheme)
                ])
                .chartYScale(domain: -0.2...4.2)
                .chartXScale(domain: trend.start...axisEnd(for: trend))
                .chartYAxis {
                    AxisMarks(position: .leading, values: [0, 1, 2, 3, 4]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            let rank = value.as(Int.self) ?? value.as(Double.self).map { Int($0.rounded()) }
                            if let rank, let mood = SelectedMood.allCases.first(where: { $0.rank == rank }) {
                                Text(mood.emoji)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: viewModel.trendWindow == .week ? 7 : 5)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                if viewModel.trendWindow == .week {
                                    Text(date, format: .dateTime.weekday(.narrow))
                                } else {
                                    Text(date, format: .dateTime.month(.abbreviated).day())
                                }
                            }
                        }
                    }
                }
                .chartLegend(position: .bottom)
                .frame(height: 240)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(chartDescription(trend, periodName: periodName))
                .accessibilityIdentifier(AccessibilityID.moodChart)

                Text(chartCaption(hasMood: hasMood, hasTone: hasTone))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Choose a mood on a few reflections to see how it swings across the \(periodName).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier(AccessibilityID.moodChart)
            }
        }
        .moodCardStyle()
    }

    private func axisEnd(for trend: MoodTrend) -> Date {
        Calendar.current.date(byAdding: .day, value: 1, to: trend.end) ?? trend.end
    }

    private func chartCaption(hasMood: Bool, hasTone: Bool) -> String {
        if hasMood, hasTone {
            return "The solid line is the mood you chose. The dashed line is the tone of your writing, drawn on the same scale. Days you skipped are left out."
        }
        if hasMood {
            return "Each point is the mood you chose. If you wrote more than once, the day shows the average."
        }
        return "No mood was selected in this period, so the line shows the tone of your writing instead."
    }

    private func chartDescription(_ trend: MoodTrend, periodName: String) -> String {
        let moodPoints = trend.points.filter { $0.chosenMood != nil }
        guard let first = moodPoints.first?.chosenMood, let last = moodPoints.last?.chosenMood else {
            return "Mood chart for this \(periodName). No chosen mood yet."
        }
        return "Mood chart for this \(periodName), from \(moodName(first)) to \(moodName(last))."
    }

    private func moodName(_ level: Double) -> String {
        let rank = Int(level.rounded())
        return SelectedMood.allCases.first { $0.rank == rank }?.title ?? "a mood"
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
