import Foundation

public struct ArchivePersonName: Sendable, Equatable, Identifiable {
    public var id: UUID
    public var fullName: String
    public var nickname: String?

    public init(id: UUID, fullName: String, nickname: String? = nil) {
        self.id = id
        self.fullName = fullName
        self.nickname = nickname
    }
}

public struct ArchiveNameSuggestion: Sendable, Equatable, Identifiable {
    public var id: UUID { personID }
    public var personID: UUID
    public var personName: String
    public var matchedText: String
    public var score: Double

    public init(personID: UUID, personName: String, matchedText: String, score: Double) {
        self.personID = personID
        self.personName = personName
        self.matchedText = matchedText
        self.score = score
    }
}

public enum ArchiveNameSuggester: Sendable {
    private static let stopwords: Set<String> = [
        "van", "thi", "the", "and", "of", "va", "o", "tai", "toi", "ban",
        "nguoi", "gia", "dinh", "nam", "nu", "sinh", "mat", "ngay",
        "family", "born", "died", "son", "daughter", "mr", "mrs",
    ]

    public static func suggest(
        ocrLines: [String],
        people: [ArchivePersonName],
        minimumScore: Double = 0.55
    ) -> [ArchiveNameSuggestion] {
        let blob = ocrLines.joined(separator: "\n")
        let foldedBlob = TextNormalize.folded(blob)
        guard foldedBlob.isEmpty == false, people.isEmpty == false else { return [] }

        var suggestions: [ArchiveNameSuggestion] = []
        for person in people {
            if let suggestion = match(person, foldedBlob: foldedBlob, originalBlob: blob), suggestion.score >= minimumScore {
                suggestions.append(suggestion)
            }
        }
        return suggestions.sorted { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            return lhs.personName.localizedStandardCompare(rhs.personName) == .orderedAscending
        }
    }

    private static func match(
        _ person: ArchivePersonName,
        foldedBlob: String,
        originalBlob: String
    ) -> ArchiveNameSuggestion? {
        let display = person.nickname?.isEmpty == false ? person.nickname! : person.fullName
        if let nickname = person.nickname {
            let foldedNick = TextNormalize.folded(nickname)
            if foldedNick.count >= 2, foldedBlob.contains(foldedNick) {
                return ArchiveNameSuggestion(
                    personID: person.id,
                    personName: display,
                    matchedText: snippet(containing: nickname, in: originalBlob),
                    score: 0.92
                )
            }
        }

        let foldedFull = TextNormalize.folded(person.fullName)
        if foldedFull.count >= 3, foldedBlob.contains(foldedFull) {
            return ArchiveNameSuggestion(
                personID: person.id,
                personName: display,
                matchedText: snippet(containing: person.fullName, in: originalBlob),
                score: 1.0
            )
        }

        let tokens = TextNormalize.tokens(person.fullName).filter { token in
            token.count >= 2 && stopwords.contains(token) == false
        }
        guard tokens.isEmpty == false else { return nil }

        let present = tokens.filter { foldedBlob.contains($0) }
        if present.count == tokens.count, tokens.count >= 2 {
            return ArchiveNameSuggestion(
                personID: person.id,
                personName: display,
                matchedText: snippet(containing: tokens.suffix(2).joined(separator: " "), in: originalBlob),
                score: 0.78
            )
        }

        let given = Array(tokens.suffix(2))
        if given.count == 2, given.allSatisfy({ foldedBlob.contains($0) }) {
            return ArchiveNameSuggestion(
                personID: person.id,
                personName: display,
                matchedText: snippet(containing: given.joined(separator: " "), in: originalBlob),
                score: 0.64
            )
        }

        return nil
    }

    private static func snippet(containing needle: String, in blob: String) -> String {
        let foldedBlob = TextNormalize.folded(blob)
        let foldedNeedle = TextNormalize.folded(needle)
        if let range = foldedBlob.range(of: foldedNeedle) {
            let start = foldedBlob.distance(from: foldedBlob.startIndex, to: range.lowerBound)
            let chars = Array(blob)
            let from = max(0, start - 18)
            let to = min(chars.count, start + needle.count + 18)
            if from < to {
                return String(chars[from..<to]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return needle
    }
}
