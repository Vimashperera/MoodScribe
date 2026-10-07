import XCTest
@testable import MoodScribe

final class SentimentServiceTests: XCTestCase {
    private let service = SentimentAnalysisService()

    func testEmptyTextIsNeutral() {
        let result = service.analyze("   \n")
        XCTAssertEqual(result, .empty)
        XCTAssertEqual(result.score, 0)
        XCTAssertEqual(result.label, .neutral)
        XCTAssertTrue(result.keywords.isEmpty)
    }

    func testScoreStaysInsidePolarityRange() {
        let samples = [
            "I love this wonderful happy day and I feel grateful.",
            "I hate this awful terrible day and I feel miserable.",
            "The library closes at six."
        ]
        for sample in samples {
            let score = service.analyze(sample).score
            XCTAssertGreaterThanOrEqual(score, -1)
            XCTAssertLessThanOrEqual(score, 1)
        }
    }

    func testPositiveTextScoresAboveNegativeText() {
        let positive = service.analyze("I am so happy, grateful, and excited. This wonderful day fills me with joy and love.")
        let negative = service.analyze("I feel terrible, sad, angry, and hopeless. This awful day is miserable and painful.")

        XCTAssertGreaterThan(positive.score, 0)
        XCTAssertLessThan(negative.score, 0)
        XCTAssertGreaterThan(positive.score, negative.score)
        XCTAssertEqual(positive.label, SentimentType.classify(positive.score))
        XCTAssertEqual(negative.label, SentimentType.classify(negative.score))
        XCTAssertEqual(positive.label, .positive)
        XCTAssertEqual(negative.label, .negative)
    }

    func testFactualSentenceScoresBelowClearPraise() {
        let factual = service.analyze("The meeting is in room four at three o'clock.")
        let positive = service.analyze("I am so happy, grateful, and excited. This wonderful day fills me with joy and love.")
        XCTAssertGreaterThan(positive.score, factual.score)
        XCTAssertEqual(factual.label, SentimentType.classify(factual.score))
    }

    func testKeywordExtractionFindsEmotionalWords() {
        let result = service.analyze("I feel anxious but also grateful and calm today.")
        let keywords = Set(result.keywords)
        XCTAssertTrue(keywords.contains("anxious"))
        XCTAssertTrue(keywords.contains("grateful"))
        XCTAssertTrue(keywords.contains("calm"))
        XCTAssertLessThanOrEqual(result.keywords.count, 6)
    }

    func testKeywordExtractionIgnoresEmptyAndStopWords() {
        XCTAssertTrue(service.extractKeywords(from: "   ").isEmpty)
        let keywords = service.extractKeywords(from: "the and but for with this")
        XCTAssertTrue(keywords.isEmpty)
    }

    func testClassificationBoundaries() {
        XCTAssertEqual(SentimentType.classify(0.11), .positive)
        XCTAssertEqual(SentimentType.classify(0.1), .neutral)
        XCTAssertEqual(SentimentType.classify(0), .neutral)
        XCTAssertEqual(SentimentType.classify(-0.1), .neutral)
        XCTAssertEqual(SentimentType.classify(-0.11), .negative)
    }

    func testToneLanguageDescribesWritingNotHealth() {
        let positive = SentimentAnalysis(score: 0.8, label: .positive, keywords: [])
        let slight = SentimentAnalysis(score: 0.2, label: .positive, keywords: [])
        let neutral = SentimentAnalysis(score: 0, label: .neutral, keywords: [])
        let negative = SentimentAnalysis(score: -0.8, label: .negative, keywords: [])

        XCTAssertEqual(positive.toneSentence, "Your writing has a positive tone.")
        XCTAssertEqual(slight.toneSentence, "Your writing has a slightly positive tone.")
        XCTAssertEqual(neutral.toneTitle, "Neutral")
        XCTAssertEqual(negative.toneSentence, "Your writing has a negative tone.")
        XCTAssertFalse(positive.toneSentence.localizedCaseInsensitiveContains("mental health"))
    }

    func testAnalysisPerformanceOnALongEntry() {
        let text = String(repeating: "I feel grateful and calm today. ", count: 40)
        measure {
            _ = service.analyze(text)
        }
    }
}
