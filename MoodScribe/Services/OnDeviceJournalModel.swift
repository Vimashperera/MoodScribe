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
        if #available(iOS 26.0, *) {
            if let generated = await FoundationJournalReader.read(text: trimmed, mood: mood, factors: factors) {
                return blend(generated, mood: mood, keywordsFrom: trimmed)
            }
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

@available(iOS 26.0, *)
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

        Judge the meaning of the whole entry. Winning, passing, relief, pride, and good news are positive even without the word happy. A routine day is neutral. Loss, failure, fear, and pain are negative.
        Reply in exactly this form, with no other text:
        SCORE: <a number from -1 to 1>
        TITLE: <two to five words naming the event>
        MESSAGE: <two or three original sentences about this specific entry. Do not use quotation marks. Do not diagnose.>
        """
        let session = LanguageModelSession(instructions: """
        You are the reply inside a private on-device journal.
        Write a reply that could only fit this entry, because it talks about the actual events.
        Never quote the entry. Never give a diagnosis.
        """)
        do {
            let response = try await session.respond(to: prompt)
            return parse(response.content)
        } catch {
            return nil
        }
    }

    private static func parse(_ raw: String) -> (score: Double, reply: ReflectionReply)? {
        var score: Double?
        var title = ""
        var messageLines: [String] = []
        var readingMessage = false
        for line in raw.components(separatedBy: .newlines) {
            if line.hasPrefix("SCORE:") {
                score = Double(line.dropFirst("SCORE:".count).trimmingCharacters(in: .whitespaces))
                readingMessage = false
            } else if line.hasPrefix("TITLE:") {
                title = sanitize(String(line.dropFirst("TITLE:".count)))
                readingMessage = false
            } else if line.hasPrefix("MESSAGE:") {
                readingMessage = true
                let rest = sanitize(String(line.dropFirst("MESSAGE:".count)))
                if !rest.isEmpty { messageLines.append(rest) }
            } else if readingMessage {
                let rest = line.trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty { messageLines.append(rest) }
            }
        }
        guard let score else { return nil }
        let message = sanitize(messageLines.joined(separator: " "))
        guard !title.isEmpty, !message.isEmpty else { return nil }
        let clamped = min(1, max(-1, score))
        let tone: ReplyTone = clamped > 0.1 ? .uplifting : (clamped < -0.1 ? .supportive : .steady)
        return (clamped, ReflectionReply(title: title, message: message, tone: tone))
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
