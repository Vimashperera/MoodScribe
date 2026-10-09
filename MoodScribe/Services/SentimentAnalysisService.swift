import Foundation
import NaturalLanguage

struct SentimentAnalysisService: Sendable {
    private let maximumKeywords = 6

    func analyze(_ text: String, mood: SelectedMood? = nil) -> SentimentAnalysis {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            if let mood {
                let score = mood.sentimentScore
                return SentimentAnalysis(
                    score: score,
                    label: SentimentType.classify(score),
                    keywords: []
                )
            }
            return .empty
        }

        let score = sentimentScore(for: trimmed, mood: mood)
        let keywords = extractKeywords(from: trimmed)
        return SentimentAnalysis(
            score: score,
            label: SentimentType.classify(score),
            keywords: keywords
        )
    }

    static func analyzeOffMain(_ text: String, mood: SelectedMood? = nil) async -> SentimentAnalysis {
        let service = SentimentAnalysisService()
        return await Task.detached(priority: .userInitiated) {
            service.analyze(text, mood: mood)
        }.value
    }

    private func sentimentScore(for text: String, mood: SelectedMood?) -> Double {
        let textScore = computeTextScore(for: text)

        let finalScore: Double
        if let mood {
            let moodScore = mood.sentimentScore
            if abs(textScore) < 0.15 {
                finalScore = 0.25 * textScore + 0.75 * moodScore
            } else {
                finalScore = 0.50 * textScore + 0.50 * moodScore
            }
        } else {
            finalScore = textScore
        }

        let clamped = min(1.0, max(-1.0, finalScore))
        return (clamped * 1000).rounded() / 1000
    }

    private func computeTextScore(for text: String) -> Double {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma, .sentimentScore])
        tagger.string = text
        let range = text.startIndex..<text.endIndex
        tagger.setLanguage(dominantLanguage(for: text), range: range)

        // 1. Lexicon and negation analysis using token lemmas
        var tokens: [(surface: String, lemma: String)] = []
        tagger.enumerateTags(
            in: range,
            unit: .word,
            scheme: .lemma,
            options: [.omitWhitespace, .omitPunctuation]
        ) { lemmaTag, tokenRange in
            let surface = String(text[tokenRange]).lowercased()
            let lemma = lemmaTag?.rawValue.lowercased() ?? surface
            tokens.append((surface, lemma))
            return true
        }

        var tokenScores: [Double] = []
        var posCount = 0
        var negCount = 0

        for i in 0..<tokens.count {
            let surface = tokens[i].surface
            let lemma = tokens[i].lemma

            var isNegated = false
            let lookback = max(0, i - 2)
            for j in lookback..<i {
                if Self.negationWords.contains(tokens[j].surface) || Self.negationWords.contains(tokens[j].lemma) {
                    isNegated = true
                    break
                }
            }

            let wordScore = Self.positiveLexicon[surface] ?? Self.positiveLexicon[lemma]
            let negativeWordScore = Self.negativeLexicon[surface] ?? Self.negativeLexicon[lemma]

            if let val = wordScore {
                if isNegated {
                    tokenScores.append(-val * 0.8)
                    negCount += 1
                } else {
                    tokenScores.append(val)
                    posCount += 1
                }
            } else if let val = negativeWordScore {
                if isNegated {
                    tokenScores.append(-val * 0.5)
                    posCount += 1
                } else {
                    tokenScores.append(val)
                    negCount += 1
                }
            }
        }

        // 2. NLTagger sentence-level sentiment
        let sentenceScore = averageScore(tagger: tagger, text: text, unit: .sentence)
        let taggerAvg = sentenceScore ?? averageScore(tagger: tagger, text: text, unit: .paragraph) ?? 0.0

        // 3. Reconcile Lexicon and NLTagger
        if !tokenScores.isEmpty {
            let lexiconSum = tokenScores.reduce(0.0, +)
            let lexiconAvg = lexiconSum / Double(tokenScores.count)

            if negCount == 0 && taggerAvg < 0 {
                // False negative from NLTagger with no negative words: rely on positive lexicon
                return lexiconAvg
            } else if posCount == 0 && taggerAvg > 0 {
                // False positive from NLTagger with only negative words
                return lexiconAvg
            } else if taggerAvg != 0 {
                return 0.65 * lexiconAvg + 0.35 * taggerAvg
            } else {
                return lexiconAvg
            }
        } else {
            // No sentiment words found: if NLTagger is negative without any negative words, do not falsely penalize
            if taggerAvg < 0 {
                return 0.0
            }
            return taggerAvg
        }
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

    private static let positiveLexicon: [String: Double] = [
        "wonderful": 1.0, "fantastic": 1.0, "amazing": 1.0, "awesome": 1.0, "excellent": 1.0,
        "super": 0.8, "fabulous": 1.0, "love": 0.9, "loved": 0.9, "loving": 0.9,
        "thrilled": 1.0, "joy": 0.9, "joyful": 0.9, "delighted": 0.9, "blessed": 0.9,
        "happy": 0.8, "happiness": 0.8, "grateful": 0.8, "gratitude": 0.8, "calm": 0.6,
        "peaceful": 0.7, "peace": 0.6, "hope": 0.6, "hopeful": 0.7, "excited": 0.8,
        "excitement": 0.8, "proud": 0.7, "content": 0.6, "relaxed": 0.6, "relax": 0.5,
        "relaxing": 0.6, "optimistic": 0.7, "great": 0.8, "good": 0.6, "better": 0.5,
        "best": 0.8, "calmness": 0.6, "relief": 0.6, "relieved": 0.6, "thankful": 0.8,
        "fine": 0.4, "nice": 0.6, "fun": 0.7, "enjoy": 0.7, "enjoyed": 0.7, "enjoying": 0.7,
        "pleasant": 0.6, "productive": 0.6, "satisfying": 0.6, "accomplished": 0.7,
        "cheer": 0.6, "cheerful": 0.7, "serene": 0.7, "energized": 0.7, "inspired": 0.7,
        "glad": 0.6, "cool": 0.4, "sweet": 0.5, "special": 0.5, "well": 0.4, "smile": 0.6,
        "smiled": 0.6, "smiling": 0.6, "laugh": 0.7, "laughed": 0.7, "laughing": 0.7,
        "refreshing": 0.6, "refreshed": 0.6, "comfortable": 0.5, "cozy": 0.5,
        "friendly": 0.5, "kind": 0.5, "kindness": 0.6, "helpful": 0.5, "brilliant": 0.8,
        "favorite": 0.6, "positive": 0.6, "strong": 0.4, "healthy": 0.5, "peacefully": 0.7
    ]

    private static let negativeLexicon: [String: Double] = [
        "terrible": -1.0, "awful": -1.0, "horrible": -1.0, "miserable": -1.0,
        "depressed": -1.0, "depression": -1.0, "hopeless": -1.0, "furious": -1.0,
        "hate": -0.9, "hated": -0.9, "hating": -0.9, "disgusted": -0.9, "devastated": -1.0,
        "sad": -0.7, "sadness": -0.7, "angry": -0.8, "anger": -0.8, "mad": -0.7,
        "anxious": -0.7, "anxiety": -0.7, "afraid": -0.7, "fear": -0.7, "fearful": -0.7,
        "worried": -0.6, "worry": -0.6, "stress": -0.6, "stressed": -0.7, "stressful": -0.7,
        "overwhelmed": -0.8, "hurt": -0.7, "pain": -0.7, "painful": -0.7, "guilty": -0.6,
        "guilt": -0.6, "shame": -0.7, "ashamed": -0.7, "frustrated": -0.7, "frustration": -0.7,
        "tired": -0.4, "exhausted": -0.6, "drained": -0.6, "bad": -0.7, "worst": -1.0,
        "worse": -0.6, "upset": -0.7, "annoyed": -0.6, "annoying": -0.6, "gloomy": -0.6,
        "disappointed": -0.7, "sick": -0.5, "bored": -0.4, "nervous": -0.5, "dread": -0.8,
        "poor": -0.5, "lonely": -0.7, "loneliness": -0.7, "fail": -0.7, "failed": -0.7, "failure": -0.8,
        "unhappy": -0.7, "grief": -0.8, "sorrow": -0.8, "regret": -0.6, "trouble": -0.5,
        "hard": -0.3, "crying": -0.6, "cry": -0.6, "tears": -0.5, "negative": -0.6
    ]

    private static let negationWords: Set<String> = [
        "not", "no", "never", "hardly", "barely", "scarcely", "without",
        "isnt", "isn't", "wasnt", "wasn't", "arent", "aren't", "werent", "weren't",
        "dont", "don't", "doesnt", "doesn't", "didnt", "didn't",
        "wont", "won't", "wouldnt", "wouldn't", "cant", "can't", "cannot",
        "couldnt", "couldn't", "shouldnt", "shouldn't"
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
