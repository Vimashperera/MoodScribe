import Foundation
import NaturalLanguage

enum ReplyTone: String, Equatable, Sendable {
    case uplifting
    case steady
    case supportive
    case mixed
    case urgent
}

struct ReflectionReply: Equatable, Sendable {
    var title: String
    var message: String
    var tone: ReplyTone

    var systemImage: String {
        switch tone {
        case .uplifting: "sun.max.fill"
        case .steady: "leaf.fill"
        case .supportive: "heart.fill"
        case .mixed: "arrow.left.and.right"
        case .urgent: "phone.fill"
        }
    }
}

enum ReflectionReplyService {
    private static let service = SentimentAnalysisService()

    static func reply(text: String, mood: SelectedMood?, factors: [DayFactor]) -> ReflectionReply {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCrisis(trimmed) {
            return ReflectionReply(
                title: "Please reach out",
                message: "What you wrote sounds like you may be in danger. If you might hurt yourself, contact local emergency services or someone you trust right now. You do not have to go through this by yourself.",
                tone: .urgent
            )
        }

        let reading = service.read(trimmed)
        let tone = tone(for: reading)
        let focus = reading.sentences.max { abs($0.score) < abs($1.score) }?.text ?? trimmed
        let subject = topicPhrase(in: focus) ?? topicPhrase(in: trimmed) ?? "your day"
        let body = message(for: tone, score: reading.analysis.score, subject: subject, focus: focus, seed: trimmed)
        let context = contextSentences(mood: mood, textScore: reading.analysis.score, factors: factors)
        let combined = ([body] + context).joined(separator: " ")
        return ReflectionReply(title: title(for: tone, seed: trimmed), message: combined, tone: tone)
    }

    private static func tone(for reading: SentimentReading) -> ReplyTone {
        let highs = reading.sentences.contains { $0.score > 0.2 }
        let lows = reading.sentences.contains { $0.score < -0.2 }
        if highs, lows { return .mixed }
        if reading.analysis.score > 0.1 { return .uplifting }
        if reading.analysis.score < -0.1 { return .supportive }
        return .steady
    }

    private static func title(for tone: ReplyTone, seed: String) -> String {
        switch tone {
        case .uplifting:
            pick(["That landed warmly", "A bright entry", "Keep this one"], seed: seed)
        case .steady:
            pick(["A steady note", "You wrote it down"], seed: seed)
        case .supportive:
            pick(["This one was heavy", "A hard day on the page"], seed: seed)
        case .mixed:
            pick(["More than one feeling", "Both parts count"], seed: seed)
        case .urgent:
            "Please reach out"
        }
    }

    private static func message(
        for tone: ReplyTone,
        score: Double,
        subject: String,
        focus: String,
        seed: String
    ) -> String {
        let quote = quoted(focus)
        switch tone {
        case .uplifting:
            let line = score >= 0.45
                ? pick([
                    "There is real warmth in what you wrote about \(subject). Keep that detail close. It shows the day had something good in it, and you noticed.",
                    "This entry feels warm, especially around \(subject). Days like this are worth remembering when a later one is flatter.",
                    "Your words about \(subject) come through as warm and alive. You caught what was good in the day, not only what happened."
                ], seed: seed)
                : pick([
                    "There is a quiet warmth in this note about \(subject). It does not need to be a perfect day to count.",
                    "This writing has a warm edge when you talk about \(subject). Hold onto that smaller good part."
                ], seed: seed)
            return prefix(quote, line)
        case .steady:
            return pick([
                "This is a steady account of \(subject). An ordinary day is still worth writing down. It helps the week make sense later.",
                "You set \(subject) down in a steady way. Not every entry needs a strong feeling. Seeing the day clearly is enough."
            ], seed: seed)
        case .supportive:
            let line = score <= -0.45
                ? pick([
                    "This entry about \(subject) is heavy, and it makes sense that it feels like a lot. You are no longer holding it only in your head. If you can, tell one person you trust, or give yourself a quiet break before the next task.",
                    "What you wrote about \(subject) carries a heavy weight. Getting it onto the page is a real step. Be gentle with the next hour. You only need one small thing, not the whole repair."
                ], seed: seed)
                : pick([
                    "This was a heavy thing to write, and you still put it into words about \(subject). When you are ready, take the next small step and leave the rest of the day for later.",
                    "Your note about \(subject) sounds heavy. You do not have to fix the whole day tonight. One kind pause for yourself is a complete next step."
                ], seed: seed)
            return prefix(quote, line)
        case .mixed:
            let line = pick([
                "Both sides of this entry are real. Part of it is heavy, and part of it is warmer, especially around \(subject). You do not have to flatten the day into one feeling.",
                "You held both a hard part and a lighter part in the same note about \(subject). That is an honest record. Let each one stay."
            ], seed: seed)
            return prefix(quote, line)
        case .urgent:
            return ""
        }
    }

    private static func contextSentences(mood: SelectedMood?, textScore: Double, factors: [DayFactor]) -> [String] {
        var lines: [String] = []
        if let factorsLine = factorSentence(factors) {
            lines.append(factorsLine)
        }
        if let mood {
            if mood.rank <= 1, textScore > 0.2 {
                lines.append("You marked this day as \(mood.title.lowercased()), and the writing is warmer than that label. Both can be true.")
            } else if mood.rank >= 3, textScore < -0.2 {
                lines.append("You marked this day as \(mood.title.lowercased()), while the writing itself is heavier. The words are worth listening to as well.")
            }
        }
        return lines
    }

    private static func factorSentence(_ factors: [DayFactor]) -> String? {
        let names = factors.map { $0.title.lowercased() }.sorted()
        guard !names.isEmpty else { return nil }
        if names.count == 1 {
            return "You also marked \(names[0])."
        }
        let head = names.dropLast().joined(separator: ", ")
        let last = names[names.count - 1]
        return "You also marked \(head) and \(last)."
    }

    private static func prefix(_ quote: String?, _ line: String) -> String {
        guard let quote else { return line }
        return "“\(quote)” \(line)"
    }

    private static func quoted(_ sentence: String) -> String? {
        let trimmed = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 12 else { return nil }
        if trimmed.count <= 110 { return trimmed }
        let end = trimmed.index(trimmed.startIndex, offsetBy: 107)
        return String(trimmed[..<end]).trimmingCharacters(in: .whitespacesAndNewlines) + "…"
    }

    private static func topicPhrase(in text: String) -> String? {
        guard let noun = salientNoun(in: text) else { return nil }
        return "your \(noun)"
    }

    private static func salientNoun(in text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = trimmed
        let range = trimmed.startIndex..<trimmed.endIndex
        tagger.setLanguage(NLLanguageRecognizer.dominantLanguage(for: trimmed) ?? .english, range: range)

        var nouns: [String] = []
        tagger.enumerateTags(
            in: range,
            unit: .word,
            scheme: .lemma,
            options: [.omitWhitespace, .omitPunctuation]
        ) { lemmaTag, tokenRange in
            let surface = String(trimmed[tokenRange]).lowercased()
            let lemma = (lemmaTag?.rawValue.lowercased() ?? surface).filter(\.isLetter)
            let (classTag, _) = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lexicalClass)
            guard classTag == .noun, lemma.count > 3, !skippedNouns.contains(lemma) else { return true }
            nouns.append(lemma)
            return true
        }
        return nouns.last
    }

    private static func pick(_ options: [String], seed: String) -> String {
        guard !options.isEmpty else { return "" }
        var hash = 5381
        for byte in seed.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        let index = (hash & Int.max) % options.count
        return options[index]
    }

    private static func isCrisis(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let phrases = [
            "kill myself", "killing myself", "suicide", "suicidal",
            "end my life", "take my life", "want to die", "wanna die",
            "don't want to be alive", "do not want to be alive"
        ]
        return phrases.contains { lowered.contains($0) }
    }

    private static let skippedNouns: Set<String> = [
        "day", "today", "time", "thing", "things", "stuff", "life", "feeling",
        "moment", "something", "someone", "everyone", "anything", "everything",
        "morning", "afternoon", "evening", "night", "yesterday", "tomorrow",
        "week", "month", "kind", "sort", "part", "rest", "lot", "bits"
    ]
}

private extension NLLanguageRecognizer {
    static func dominantLanguage(for text: String) -> NLLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage
    }
}
