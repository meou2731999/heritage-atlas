import Foundation

public enum TextNormalize: Sendable {
    public static func folded(_ string: String) -> String {
        string
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func tokens(_ string: String) -> [String] {
        folded(string)
            .split { character in
                character.isWhitespace || character.isPunctuation
            }
            .map(String.init)
            .filter { $0.isEmpty == false }
    }

    public static func contains(_ haystack: String, needle: String) -> Bool {
        let foldedNeedle = folded(needle)
        guard foldedNeedle.isEmpty == false else { return true }
        return folded(haystack).contains(foldedNeedle)
    }
}
