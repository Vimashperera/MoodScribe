import Foundation
import NaturalLanguage

/// Short reply stored with the entry after save. It names the event in the writing.
/// A crisis-sounding entry only points the person to emergency help. It is not counselling.
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
    static func reply(text: String, mood: SelectedMood?, factors: [DayFactor]) -> ReflectionReply {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isCrisis(trimmed) {
            return ReflectionReply(
                title: "Please reach out",
                message: "What you wrote sounds like you may be in danger. If you might hurt yourself, contact local emergency services or someone you trust right now. You do not have to go through this by yourself.",
                tone: .urgent
            )
        }

        let reading = SentimentAnalysisService().read(trimmed)
        let tone = tone(for: reading)
        let sentences = reading.sentences.map(\.text)
        let primary = event(in: sentences.first ?? trimmed)
        let secondary = sentences.count > 1 ? event(in: sentences[sentences.count - 1]) : nil
        let body = message(tone: tone, score: reading.analysis.score, primary: primary, secondary: secondary, seed: trimmed)
        let extra = contextSentences(mood: mood, textScore: reading.analysis.score, factors: factors)
        return ReflectionReply(
            title: title(for: primary, tone: tone),
            message: ([body] + extra).joined(separator: " "),
            tone: tone
        )
    }

    private static func tone(for reading: SentimentReading) -> ReplyTone {
        let highs = reading.sentences.contains { $0.score > 0.2 }
        let lows = reading.sentences.contains { $0.score < -0.2 }
        if highs, lows { return .mixed }
        if reading.analysis.score > 0.1 { return .uplifting }
        if reading.analysis.score < -0.1 { return .supportive }
        return .steady
    }

    private static func title(for event: WrittenEvent, tone: ReplyTone) -> String {
        if let noun = event.noun?.capitalized {
            return noun
        }
        if let theme = event.themes.first?.capitalized {
            return theme
        }
        switch tone {
        case .uplifting: return "A good moment"
        case .steady: return "This day"
        case .supportive: return "A hard stretch"
        case .mixed: return "Two sides"
        case .urgent: return "Please reach out"
        }
    }

    private static func message(
        tone: ReplyTone,
        score: Double,
        primary: WrittenEvent,
        secondary: WrittenEvent?,
        seed: String
    ) -> String {
        if tone == .mixed, let secondary, secondary.phrase != primary.phrase {
            return "Both sides of this entry are real. \(primary.phrase) sits beside \(secondary.phrase). You do not have to flatten the day into one feeling."
        }

        let action = primary.phrase
        switch tone {
        case .uplifting:
            return pick([
                "\(action) is a bright part of this day. That did not have to be said with a big word for it to count, and you get to keep it.",
                "There is something glad in \(action.prefix(1).lowercased())\(action.dropFirst()). Let it stay with you instead of rushing past it.",
                "\(action) changes the shape of the day. You can enjoy that it happened."
            ], seed: seed)
        case .supportive:
            if score <= -0.45 {
                return pick([
                    "\(action) sounds like a lot to carry. You put it into words, and that is already a step. Be gentle with the next hour and let one small thing be enough.",
                    "\(action) comes through as heavy. You do not have to repair the whole day tonight. One quiet pause is a complete next step."
                ], seed: seed)
            }
            return pick([
                "\(action) sounds heavy. You do not have to fix all of it before the day ends. One kind pause for yourself is enough for now.",
                "There is weight in \(action.prefix(1).lowercased())\(action.dropFirst()). Leave the rest of the day smaller than the feeling, and take the next step when you can."
            ], seed: seed)
        case .steady:
            return pick([
                "\(action) is a plain piece of the day, and that is allowed. Noticing it is already a record of how things went.",
                "\(action) does not need to become a bigger story. Writing it down is enough."
            ], seed: seed)
        case .mixed:
            return "Both sides of this entry are real. \(action) does not have to cancel the rest of the day."
        case .urgent:
            return ""
        }
    }

    private static func contextSentences(mood: SelectedMood?, textScore: Double, factors: [DayFactor]) -> [String] {
        var lines: [String] = []
        if let line = factorSentence(factors) {
            lines.append(line)
        }
        if let mood {
            if mood.rank <= 1, textScore > 0.2 {
                lines.append("You marked this day as \(mood.title.lowercased()), and the writing is warmer than that. Both can be true.")
            } else if mood.rank >= 3, textScore < -0.2 {
                lines.append("You marked this day as \(mood.title.lowercased()), while the writing itself is heavier.")
            }
        }
        return lines
    }

    private static func factorSentence(_ factors: [DayFactor]) -> String? {
        let names = factors.map { $0.title.lowercased() }.sorted()
        guard !names.isEmpty else { return nil }
        if names.count == 1 { return "You also marked \(names[0])." }
        let head = names.dropLast().joined(separator: ", ")
        return "You also marked \(head) and \(names[names.count - 1])."
    }

    private struct WrittenEvent {
        var verbLemma: String?
        var objectPhrase: String?
        var noun: String?
        var themes: [String]

        var phrase: String {
            let feeling = ReflectionReplyService.describe(themes)
            if let verbLemma, !ReflectionReplyService.feelingVerbs.contains(verbLemma), let objectPhrase {
                return "\(ReflectionReplyService.gerund(verbLemma).capitalized) \(objectPhrase)"
            }
            if let feeling {
                return feeling
            }
            if let noun {
                return noun.capitalized
            }
            return "What you wrote"
        }
    }

    private static func event(in text: String) -> WrittenEvent {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return WrittenEvent(verbLemma: nil, objectPhrase: nil, noun: nil, themes: [])
        }
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = trimmed
        let range = trimmed.startIndex..<trimmed.endIndex
        let language = NLLanguageRecognizer.dominantLanguage(for: trimmed) ?? .english
        tagger.setLanguage(language, range: range)

        struct Token {
            var surface: String
            var lemma: String
            var kind: NLTag?
        }
        var tokens: [Token] = []
        tagger.enumerateTags(in: range, unit: .word, scheme: .lemma, options: [.omitWhitespace, .omitPunctuation]) { lemmaTag, tokenRange in
            let surface = String(trimmed[tokenRange])
            let lemma = lemmaTag?.rawValue.lowercased() ?? surface.lowercased()
            let (kind, _) = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lexicalClass)
            tokens.append(Token(surface: surface, lemma: lemma, kind: kind))
            return true
        }

        let verbIndex = tokens.firstIndex { token in
            token.kind == .verb && !helperVerbs.contains(token.lemma)
        }
        var objectWords: [String] = []
        var noun: String?
        if let verbIndex {
            for token in tokens.dropFirst(verbIndex + 1) {
                if token.kind == .verb || stopObject.contains(token.lemma) || stopObject.contains(token.surface.lowercased()) {
                    break
                }
                if token.kind == .noun || token.kind == .adjective || determiners.contains(token.lemma) || determiners.contains(token.surface.lowercased()) {
                    objectWords.append(token.surface.lowercased())
                    if token.kind == .noun {
                        noun = token.lemma.filter(\.isLetter)
                    }
                }
            }
        }
        if noun == nil {
            noun = tokens.last { $0.kind == .noun && $0.lemma.count > 3 && !skippedNouns.contains($0.lemma) }?.lemma
        }
        var themes: [String] = []
        var negated = false
        for token in tokens {
            let word = token.lemma.filter(\.isLetter)
            if negationWords.contains(token.lemma) || negationWords.contains(token.surface.lowercased()) {
                negated = true
            }
            guard token.kind == .adjective || token.kind == .noun, emotionWords.contains(word) else { continue }
            if !themes.contains(word) {
                themes.append(word)
            }
        }
        if negated {
            themes = themes.map { "not \($0)" }
        }
        let verb = verbIndex.map { tokens[$0].lemma.filter(\.isLetter) }.flatMap { $0.isEmpty ? nil : $0 }
        let phrase = objectWords.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return WrittenEvent(
            verbLemma: verb,
            objectPhrase: phrase.isEmpty ? nil : phrase,
            noun: noun.flatMap { $0.isEmpty ? nil : $0 },
            themes: themes
        )
    }

    private static func describe(_ themes: [String]) -> String? {
        guard !themes.isEmpty else { return nil }
        if themes.count == 1 { return "Feeling \(themes[0])" }
        if themes.count == 2 { return "Feeling \(themes[0]) and \(themes[1])" }
        let head = themes.dropLast().joined(separator: ", ")
        return "Feeling \(head), and \(themes[themes.count - 1])"
    }

    private static func gerund(_ lemma: String) -> String {
        let word = lemma.lowercased()
        if word.hasSuffix("ie") { return String(word.dropLast(2)) + "ying" }
        if word.hasSuffix("e"), !word.hasSuffix("ee"), !word.hasSuffix("ye") {
            return String(word.dropLast()) + "ing"
        }
        let vowels = Set("aeiou")
        if word.count >= 3 {
            let chars = Array(word)
            let last = chars[chars.count - 1]
            let middle = chars[chars.count - 2]
            let first = chars[chars.count - 3]
            if !vowels.contains(last), vowels.contains(middle), !vowels.contains(first), !["w", "x", "y"].contains(String(last)) {
                return word + String(last) + "ing"
            }
        }
        return word + "ing"
    }

    private static func pick(_ options: [String], seed: String) -> String {
        guard !options.isEmpty else { return "" }
        var hash = 5381
        for byte in seed.utf8 {
            hash = ((hash << 5) &+ hash) &+ Int(byte)
        }
        return options[(hash & Int.max) % options.count]
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

    private static let feelingVerbs: Set<String> = ["feel", "feeling", "felt", "seem", "seemed"]
    private static let negationWords: Set<String> = ["not", "no", "never", "n't"]
    private static let helperVerbs: Set<String> = [
        "be", "am", "is", "are", "was", "were", "been", "being",
        "do", "did", "does", "have", "has", "had"
    ]
    private static let determiners: Set<String> = ["a", "an", "the", "my", "our", "this", "that"]
    private static let stopObject: Set<String> = [
        "today", "yesterday", "tomorrow", "and", "but", "so", "because", "when", "while", "after", "before"
    ]
    private static let skippedNouns: Set<String> = ["day", "today", "time", "thing", "things", "stuff", "way"]
    private static let emotionWords: Set<String> = [
        "happy", "grateful", "calm", "proud", "excited", "joyful", "hopeful", "relieved", "glad",
        "sad", "angry", "anxious", "hopeless", "terrible", "awful", "miserable", "lonely",
        "afraid", "worried", "stressed", "overwhelmed", "hurt", "ashamed", "frustrated", "tired"
    ]
}

private extension NLLanguageRecognizer {
    static func dominantLanguage(for text: String) -> NLLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage
    }
}
