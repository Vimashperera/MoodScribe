import Foundation

/// One sentence and the tone score given to that sentence alone.
struct SentenceReading: Equatable, Sendable {
    var text: String
    var score: Double
}

/// The whole reading: a document-level analysis plus each sentence.
struct SentimentReading: Equatable, Sendable {
    var analysis: SentimentAnalysis
    var sentences: [SentenceReading]
}

/// Tone of the writing, from -1 to +1. This is not a mental-health measurement.
/// Labels use ±0.1. The sentences shown to the user use a wider ±0.45 band.
struct SentimentAnalysis: Equatable, Sendable {
    var score: Double
    var label: SentimentType
    var keywords: [String]

    static let empty = SentimentAnalysis(score: 0, label: .neutral, keywords: [])

    var scoreText: String {
        String(format: "%+.2f", score)
    }

    /// Describes the tone of the writing. It is not a mental-health measurement.
    var toneSentence: String {
        switch score {
        case 0.45...:
            "Your writing has a positive tone."
        case 0.1..<0.45:
            "Your writing has a slightly positive tone."
        case ..<(-0.45):
            "Your writing has a negative tone."
        case -0.45..<(-0.1):
            "Your writing has a slightly negative tone."
        default:
            "Your writing has a neutral tone."
        }
    }

    var toneTitle: String {
        switch score {
        case 0.45...:
            "Positive"
        case 0.1..<0.45:
            "Slightly Positive"
        case ..<(-0.45):
            "Negative"
        case -0.45..<(-0.1):
            "Slightly Negative"
        default:
            "Neutral"
        }
    }

    var moodSentence: String {
        switch score {
        case 0.1...:
            "Indicates a good mood."
        case ..<(-0.1):
            "Indicates a bad mood."
        default:
            "Indicates a neutral mood."
        }
    }
}
