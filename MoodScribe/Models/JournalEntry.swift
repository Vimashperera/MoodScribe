import Foundation
import SwiftData

@Model
class JournalEntry {
    @Attribute(.unique) var id: UUID
    var text: String
    var date: Date
    var updatedAt: Date
    var sentimentScore: Double
    var sentimentLabel: String
    var keywords: [String]

    init(
        id: UUID = UUID(),
        text: String,
        date: Date = .now,
        updatedAt: Date = .now,
        sentimentScore: Double,
        sentimentLabel: String,
        keywords: [String]
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.updatedAt = updatedAt
        self.sentimentScore = sentimentScore
        self.sentimentLabel = sentimentLabel
        self.keywords = keywords
    }

    var sentiment: SentimentType {
        get { SentimentType(rawValue: sentimentLabel) ?? .neutral }
        set { sentimentLabel = newValue.rawValue }
    }
}

struct JournalEntrySnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    var text: String
    var date: Date
    var updatedAt: Date
    var sentimentScore: Double
    var sentiment: SentimentType
    var keywords: [String]

    var wasEdited: Bool {
        updatedAt.timeIntervalSince(date) > 1
    }

    init(
        id: UUID = UUID(),
        text: String,
        date: Date,
        updatedAt: Date? = nil,
        sentimentScore: Double,
        sentiment: SentimentType,
        keywords: [String]
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.updatedAt = updatedAt ?? date
        self.sentimentScore = sentimentScore
        self.sentiment = sentiment
        self.keywords = keywords
    }

    init(entry: JournalEntry) {
        id = entry.id
        text = entry.text
        date = entry.date
        updatedAt = entry.updatedAt
        sentimentScore = entry.sentimentScore
        sentiment = entry.sentiment
        keywords = entry.keywords
    }
}
