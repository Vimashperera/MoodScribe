import Foundation

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
