import Foundation

struct TextCleanupOptions {
    let enabled: Bool
    let removeUm: Bool

    static let disabled = TextCleanupOptions(enabled: false, removeUm: false)
}

enum TextCleanup {
    private static let alwaysFillers = ["uh", "umm", "uhh", "erm"]

    static func apply(to text: String, options: TextCleanupOptions) -> String {
        guard options.enabled else { return text }
        return tidy(removeFillers(from: text, includingUm: options.removeUm))
    }

    private static func removeFillers(from text: String, includingUm: Bool) -> String {
        let fillers = includingUm ? alwaysFillers + ["um"] : alwaysFillers
        return fillers.reduce(text) { partial, filler in
            replace(partial, matching: filler, with: "")
        }
    }

    private static func replace(_ text: String, matching phrase: String, with replacement: String) -> String {
        let escaped = NSRegularExpression.escapedPattern(for: phrase)
        guard let regex = try? NSRegularExpression(
            pattern: "\\b\(escaped)\\b",
            options: [.caseInsensitive]
        ) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let template = NSRegularExpression.escapedTemplate(for: replacement)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: template)
    }

    private static func tidy(_ text: String) -> String {
        let collapsed = collapse(text, pattern: "[ \\t]+", replacement: " ")
        let spacedPunctuation = collapse(collapsed, pattern: " +([,.!?;:])", replacement: "$1")
        let trimmed = spacedPunctuation.trimmingCharacters(in: .whitespacesAndNewlines)
        return capitalizeFirstLetter(trimmed)
    }

    private static func collapse(_ text: String, pattern: String, replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, range: range, withTemplate: replacement)
    }

    private static func capitalizeFirstLetter(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }
}
