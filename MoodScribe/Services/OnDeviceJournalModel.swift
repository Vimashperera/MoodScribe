import Foundation

struct JournalInterpretation: Equatable, Sendable {
    var analysis: SentimentAnalysis
    var reply: ReflectionReply
}

/// Prefers Apple's on-device foundation model, which reads the entry and writes a reply.
/// When that model is not on the device, the sentence embedding and a reply about the specific event are used.
enum OnDeviceJournalModel {
    static func interpret(text: String, mood: SelectedMood?, factors: [DayFactor]) async -> JournalInterpretation {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        #if canImport(FoundationModels)
        if let generated = await FoundationJournalReader.read(text: trimmed, mood: mood, factors: factors) {
            return blend(generated, mood: mood, keywordsFrom: trimmed)
        }
        #endif
        return fallback(text: trimmed, mood: mood, factors: factors)
    }

    static func fallback(text: String, mood: SelectedMood?, factors: [DayFactor]) -> JournalInterpretation {
        let service = SentimentAnalysisService()
        return JournalInterpretation(
            analysis: service.analyze(text, mood: mood),
            reply: ReflectionReplyService.reply(text: text, mood: mood, factors: factors)
        )
    }

    private static func blend(_ generated: ReflectionReply, score: Double, mood: SelectedMood?, keywords: [String]) -> JournalInterpretation {
        let blended = blendScore(score, mood: mood)
        var reply = generated
        reply.tone = tone(for: blended)
        return JournalInterpretation(
            analysis: SentimentAnalysis(score: blended, label: SentimentType.classify(blended), keywords: keywords),
            reply: reply
        )
    }

    private static func blend(_ reading: (score: Double, reply: ReflectionReply), mood: SelectedMood?, keywordsFrom text: String) -> JournalInterpretation {
        blend(reading.reply, score: reading.score, mood: mood, keywords: SentimentAnalysisService().extractKeywords(from: text))
    }

    private static func blendScore(_ textScore: Double, mood: SelectedMood?) -> Double {
        let final: Double
        if let mood {
            let moodScore = mood.sentimentScore
            if abs(textScore) < 0.15 {
                final = 0.25 * textScore + 0.75 * moodScore
            } else {
                final = 0.50 * textScore + 0.50 * moodScore
            }
        } else {
            final = textScore
        }
        let clamped = min(1, max(-1, final))
        return (clamped * 1000).rounded() / 1000
    }

    private static func tone(for score: Double) -> ReplyTone {
        if score > 0.1 { return .uplifting }
        if score < -0.1 { return .supportive }
        return .steady
    }
}

#if canImport(FoundationModels)
import FoundationModels

@Generable
enum WritingMood: String {
    case positive
    case slightlyPositive
    case neutral
    case slightlyNegative
    case negative

    var score: Double {
        switch self {
        case .positive: 0.72
        case .slightlyPositive: 0.34
        case .neutral: 0
        case .slightlyNegative: -0.34
        case .negative: -0.72
        }
    }
}

@Generable
struct GeneratedJournalReading {
    @Guide(description: "Mood of the whole journal entry. Winning, passing, reuniting, relief, pride, and good news are positive even when the writer does not use the word happy. A routine day with no evaluation is neutral. Loss, failure, fear, and pain are negative.")
    var mood: WritingMood

    @Guide(description: "Two to five words naming the specific event, for a reply title. No quotation marks.")
    var title: String

    @Guide(description: "Two or three original sentences written to the person about the specific events in their entry. Name the achievement, person, or difficulty in your own words. Do not quote them. Do not reuse a generic pep talk. Do not diagnose, and do not mention mental health treatment. If they may be in danger of suicide or self-harm, tell them to contact local emergency services or someone they trust.")
    var message: String
}

enum FoundationJournalReader {
    static func read(text: String, mood: SelectedMood?, factors: [DayFactor]) async -> (score: Double, reply: ReflectionReply)? {
        let model = SystemLanguageModel.default
        guard case .available = model.availability else { return nil }
        let factorList = factors.map(\.title).joined(separator: ", ")
        let moodLine = mood.map { "They also marked their mood as \($0.title)." } ?? "They did not mark a separate mood."
        let factorLine = factorList.isEmpty ? "They did not mark factors." : "They marked these factors: \(factorList)."
        let prompt = """
        Journal entry:
        \(text)

        \(moodLine)
        \(factorLine)

        Judge the writing itself. Reply only about what this entry describes.
        """
        let session = LanguageModelSession(instructions: """
        You are the reply inside a private on-device journal. Read the meaning of the whole entry.
        Write a reply that could only fit this entry, because it talks about the actual events.
        Never quote the entry. Never give a diagnosis.
        """)
        do {
            let response = try await session.respond(to: prompt, generating: GeneratedJournalReading.self)
            let reading = response.content
            let tone: ReplyTone
            switch reading.mood {
            case .positive, .slightlyPositive: tone = .uplifting
            case .negative, .slightlyNegative: tone = .supportive
            case .neutral: tone = .steady
            }
            let reply = ReflectionReply(
                title: sanitize(reading.title),
                message: sanitize(reading.message),
                tone: tone
            )
            guard !reply.message.isEmpty else { return nil }
            return (reading.mood.score, reply)
        } catch {
            return nil
        }
    }

    private static func sanitize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "“", with: "")
            .replacingOccurrences(of: "”", with: "")
            .replacingOccurrences(of: "\"", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
#endif
