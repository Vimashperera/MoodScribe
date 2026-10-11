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
    /// Empty when the person did not choose a mood. Separate from the writing score.
    var moodRaw: String = ""
    var factors: [String] = []
    /// False when the entry was saved with automatic analysis turned off.
    var didAnalyze: Bool = true
    var replyTitle: String = ""
    var replyMessage: String = ""
    var replyToneRaw: String = ""

    init(
        id: UUID = UUID(),
        text: String,
        date: Date = .now,
        updatedAt: Date = .now,
        sentimentScore: Double,
        sentimentLabel: String,
        keywords: [String],
        moodRaw: String = "",
        factors: [String] = [],
        didAnalyze: Bool = true,
        replyTitle: String = "",
        replyMessage: String = "",
        replyToneRaw: String = ""
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.updatedAt = updatedAt
        self.sentimentScore = sentimentScore
        self.sentimentLabel = sentimentLabel
        self.keywords = keywords
        self.moodRaw = moodRaw
        self.factors = factors
        self.didAnalyze = didAnalyze
        self.replyTitle = replyTitle
        self.replyMessage = replyMessage
        self.replyToneRaw = replyToneRaw
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
    var mood: SelectedMood?
    var factors: [DayFactor]
    var didAnalyze: Bool
    var replyTitle: String
    var replyMessage: String
    var replyTone: ReplyTone?

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
        keywords: [String],
        mood: SelectedMood? = nil,
        factors: [DayFactor] = [],
        didAnalyze: Bool = true,
        replyTitle: String = "",
        replyMessage: String = "",
        replyTone: ReplyTone? = nil
    ) {
        self.id = id
        self.text = text
        self.date = date
        self.updatedAt = updatedAt ?? date
        self.sentimentScore = sentimentScore
        self.sentiment = sentiment
        self.keywords = keywords
        self.mood = mood
        self.factors = factors
        self.didAnalyze = didAnalyze
        self.replyTitle = replyTitle
        self.replyMessage = replyMessage
        self.replyTone = replyTone
    }

    init(entry: JournalEntry) {
        id = entry.id
        text = entry.text
        date = entry.date
        updatedAt = entry.updatedAt
        sentimentScore = entry.sentimentScore
        sentiment = entry.sentiment
        keywords = entry.keywords
        mood = SelectedMood(rawValue: entry.moodRaw)
        factors = entry.factors.compactMap(DayFactor.init(rawValue:))
        didAnalyze = entry.didAnalyze
        replyTitle = entry.replyTitle
        replyMessage = entry.replyMessage
        replyTone = ReplyTone(rawValue: entry.replyToneRaw)
    }
}
