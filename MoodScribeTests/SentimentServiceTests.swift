import XCTest
@testable import MoodScribe

/// Calls NLTagger for real. Asserts range and ordering, not one frozen Apple score.
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

    func testCommonJournalNotesEvaluatePositivelyWhenEncouraging() {
        let sample = "I had a great day today! Went for a walk with my dog."
        let result = service.analyze(sample)
        XCTAssertGreaterThan(result.score, 0.1)
        XCTAssertEqual(result.label, .positive)
        XCTAssertEqual(result.label.moodDescription, "Good mood")
    }

    func testNeutralDailyNotesAreNotFalselyNegative() {
        let sample = "Cooked dinner and watched a movie."
        let result = service.analyze(sample)
        XCTAssertGreaterThanOrEqual(result.score, -0.1)
        XCTAssertEqual(result.label, .neutral)
    }

    func testSelectedMoodGuidesSentimentScoring() {
        let neutralText = "Cooked dinner and watched a movie."

        let withGoodMood = service.analyze(neutralText, mood: .good)
        XCTAssertGreaterThan(withGoodMood.score, 0.1)
        XCTAssertEqual(withGoodMood.label, .positive)
        XCTAssertEqual(withGoodMood.label.moodDescription, "Good mood")

        let withLowMood = service.analyze(neutralText, mood: .low)
        XCTAssertLessThan(withLowMood.score, -0.1)
        XCTAssertEqual(withLowMood.label, .negative)
        XCTAssertEqual(withLowMood.label.moodDescription, "Bad mood")

        let emptyWithGreatMood = service.analyze("", mood: .great)
        XCTAssertGreaterThan(emptyWithGreatMood.score, 0.5)
        XCTAssertEqual(emptyWithGreatMood.label, .positive)
    }

    func testSentimentTypeMoodDescription() {
        XCTAssertEqual(SentimentType.positive.moodDescription, "Good mood")
        XCTAssertEqual(SentimentType.neutral.moodDescription, "Neutral")
        XCTAssertEqual(SentimentType.negative.moodDescription, "Bad mood")
    }

    func testNegationFlipsAPositiveWord() {
        let result = service.analyze("I am not happy about today.")
        XCTAssertLessThanOrEqual(result.score, 0.1)
        XCTAssertNotEqual(result.label, .positive)
    }

    func testContrastLetsTheLaterClauseLead() {
        let turnedAround = service.analyze("The morning was awful and miserable, but the evening was wonderful and I felt grateful.")
        let stayedDown = service.analyze("The morning was awful and miserable, and the evening was terrible and hopeless.")
        XCTAssertGreaterThan(turnedAround.score, stayedDown.score)
        XCTAssertGreaterThan(turnedAround.score, 0)
    }

    func testPositiveJournalWithoutASelectedMoodIsNotNeutral() {
        let result = service.analyze("I had a lovely peaceful afternoon and I felt proud of how it turned out.")
        XCTAssertGreaterThan(result.score, 0.1)
        XCTAssertEqual(result.label, .positive)
    }

    func testWinningAMarathonReadsAsPositive() {
        let result = service.analyze("I won a marathon today")
        XCTAssertGreaterThan(result.score, 0.1)
        XCTAssertEqual(result.label, .positive)

        let reply = ReflectionReplyService.reply(text: "I won a marathon today", mood: nil, factors: [])
        let ordinary = ReflectionReplyService.reply(text: "Cooked dinner and watched a movie.", mood: nil, factors: [])
        XCTAssertEqual(reply.tone, .uplifting)
        XCTAssertTrue(reply.message.localizedCaseInsensitiveContains("marathon"))
        XCTAssertFalse(reply.message.contains("“"))
        XCTAssertNotEqual(reply.message, ordinary.message)
    }

    func testBleakWritingGetsASupportiveReply() {
        let reply = ReflectionReplyService.reply(
            text: "I feel terrible, sad, angry, and hopeless. This awful day is miserable and painful.",
            mood: nil,
            factors: []
        )
        XCTAssertEqual(reply.tone, .supportive)
        XCTAssertTrue(
            reply.message.localizedCaseInsensitiveContains("sad")
                || reply.message.localizedCaseInsensitiveContains("hopeless")
                || reply.message.localizedCaseInsensitiveContains("terrible")
        )
        XCTAssertFalse(reply.message.localizedCaseInsensitiveContains("mental health"))
        XCTAssertFalse(reply.message.localizedCaseInsensitiveContains("diagnos"))
        XCTAssertFalse(reply.message.contains("“"))
    }

    func testWarmWritingGetsAnUpliftingReply() {
        let reply = ReflectionReplyService.reply(
            text: "I am so happy, grateful, and excited. This wonderful day fills me with joy and love.",
            mood: nil,
            factors: [.friends]
        )
        XCTAssertEqual(reply.tone, .uplifting)
        XCTAssertTrue(
            reply.message.localizedCaseInsensitiveContains("happy")
                || reply.message.localizedCaseInsensitiveContains("grateful")
        )
        XCTAssertTrue(reply.message.localizedCaseInsensitiveContains("friends"))
    }

    func testMixedEntryAcknowledgesBothSides() {
        let reply = ReflectionReplyService.reply(
            text: "I feel terrible, sad, and hopeless. Later I felt grateful, happy, and full of joy.",
            mood: nil,
            factors: []
        )
        XCTAssertEqual(reply.tone, .mixed)
        XCTAssertTrue(reply.message.localizedCaseInsensitiveContains("both"))
    }

    func testReplyStaysTheSameForTheSameEntry() {
        let text = "I feel terrible, sad, angry, and hopeless."
        let first = ReflectionReplyService.reply(text: text, mood: nil, factors: [])
        let second = ReflectionReplyService.reply(text: text, mood: nil, factors: [])
        XCTAssertEqual(first, second)
    }

    func testCrisisLanguageAsksForImmediateHelp() {
        let reply = ReflectionReplyService.reply(
            text: "I want to die and I cannot see a way through today.",
            mood: nil,
            factors: []
        )
        XCTAssertEqual(reply.tone, .urgent)
        XCTAssertTrue(reply.message.localizedCaseInsensitiveContains("emergency"))
    }

    func testAnalysisPerformanceOnALongEntry() {
        let text = String(repeating: "I feel grateful and calm today. ", count: 40)
        measure {
            _ = service.analyze(text)
        }
    }
}
