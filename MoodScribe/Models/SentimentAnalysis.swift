import Foundation

struct SentimentAnalysis: Equatable, Sendable {
    var score: Double
    var label: SentimentType
    var keywords: [String]

    static let empty = SentimentAnalysis(score: 0, label: .neutral, keywords: [])

    var moodIndexPercent: Int {
        let normalized = (min(1, max(-1, score)) + 1) / 2
        return Int((normalized * 100).rounded())
    }

    var scoreText: String {
        String(format: "%+.2f", score)
    }
}
