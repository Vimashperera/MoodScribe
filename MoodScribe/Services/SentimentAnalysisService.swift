import Foundation
import NaturalLanguage

struct SentimentAnalysisService: Sendable {
    private let maximumKeywords = 6

    func analyze(_ text: String) -> SentimentAnalysis {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }

        let score = sentimentScore(for: trimmed)
        let keywords = extractKeywords(from: trimmed)
        return SentimentAnalysis(
            score: score,
            label: SentimentType.classify(score),
            keywords: keywords
        )
    }

    static func analyzeOffMain(_ text: String) async -> SentimentAnalysis {
        let service = SentimentAnalysisService()
        return await Task.detached(priority: .userInitiated) {
            service.analyze(text)
        }.value
    }

    private func sentimentScore(for text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let range = text.startIndex..<text.endIndex
        tagger.setLanguage(dominantLanguage(for: text), range: range)

        let sentenceScore = averageScore(tagger: tagger, text: text, unit: .sentence)
        let raw = sentenceScore ?? averageScore(tagger: tagger, text: text, unit: .paragraph) ?? 0
        let clamped = min(1, max(-1, raw))
        return (clamped * 1000).rounded() / 1000
    }

    private func averageScore(tagger: NLTagger, text: String, unit: NLTokenUnit) -> Double? {
        var weightedSum = 0.0
        var totalWeight = 0.0
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: unit,
            scheme: .sentimentScore,
            options: [.omitWhitespace]
        ) { tag, tokenRange in
            if let tag, let value = Double(tag.rawValue) {
                let weight = Double(text.distance(from: tokenRange.lowerBound, to: tokenRange.upperBound))
                weightedSum += value * max(weight, 1)
                totalWeight += max(weight, 1)
            }
            return true
        }
        guard totalWeight > 0 else { return nil }
        return weightedSum / totalWeight
    }

    private func dominantLanguage(for text: String) -> NLLanguage {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage ?? .english
    }

    func extractKeywords(from text: String) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = trimmed
        let range = trimmed.startIndex..<trimmed.endIndex
        tagger.setLanguage(dominantLanguage(for: trimmed), range: range)

        var scores: [String: Int] = [:]
        tagger.enumerateTags(
            in: range,
            unit: .word,
            scheme: .lemma,
            options: [.omitWhitespace, .omitPunctuation, .joinNames]
        ) { lemmaTag, tokenRange in
            let surface = String(trimmed[tokenRange]).lowercased()
            let lemma = lemmaTag?.rawValue.lowercased() ?? surface
            let token = lemma.filter(\.isLetter)
            guard token.count > 2, !Self.stopWords.contains(token) else { return true }

            let (classTag, _) = tagger.tag(at: tokenRange.lowerBound, unit: .word, scheme: .lexicalClass)
            let isContent = classTag == .adjective || classTag == .noun || classTag == .verb
            let isEmotion = Self.emotionLexicon.contains(token) || Self.emotionLexicon.contains(surface)

            if isEmotion {
                scores[token, default: 0] += 5
            } else if isContent {
                scores[token, default: 0] += 1
            }
            return true
        }

        return scores
            .sorted { lhs, rhs in
                if lhs.value == rhs.value { return lhs.key < rhs.key }
                return lhs.value > rhs.value
            }
            .prefix(maximumKeywords)
            .map(\.key)
    }

    private static let stopWords: Set<String> = [
        "the", "and", "but", "for", "with", "this", "that", "from", "have", "has", "had",
        "was", "were", "are", "been", "being", "you", "your", "yours", "myself", "just",
        "very", "really", "today", "feel", "feeling", "felt", "into", "about", "because",
        "there", "their", "they", "them", "then", "than", "what", "when", "where", "which",
        "while", "would", "could", "should", "also", "some", "more", "most", "much", "like"
    ]

    private static let emotionLexicon: Set<String> = [
        "happy", "happiness", "joy", "joyful", "grateful", "gratitude", "calm", "peaceful",
        "peace", "love", "loved", "loving", "hope", "hopeful", "excited", "excitement",
        "proud", "content", "relaxed", "optimistic", "wonderful", "great", "good", "better",
        "sad", "sadness", "angry", "anger", "anxious", "anxiety", "hopeless", "terrible",
        "awful", "miserable", "depressed", "depression", "lonely", "loneliness", "afraid",
        "fear", "worried", "worry", "stress", "stressed", "overwhelmed", "hurt", "pain",
        "painful", "guilty", "guilt", "shame", "ashamed", "frustrated", "frustration",
        "tired", "exhausted", "calmness", "relief", "relieved", "thankful"
    ]
}
