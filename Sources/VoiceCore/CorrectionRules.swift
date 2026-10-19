import Foundation

/// Explicit, local text corrections. These rules do not train the speech model.
public enum CorrectionRules {
    private static let edges = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ".!?…"))

    public static func key(_ text: String) -> String {
        text.trimmingCharacters(in: edges).split(whereSeparator: { $0.isWhitespace }).joined(separator: " ").lowercased()
    }

    /// Suggest one changed span; the user reviews its text and scope before saving.
    public static func suggestion(original: String, corrected: String) -> Replacement? {
        let before = original.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        let after = corrected.split(whereSeparator: { $0.isWhitespace }).map(String.init)
        var prefix = 0
        while prefix < min(before.count, after.count), before[prefix] == after[prefix] { prefix += 1 }
        var suffix = 0
        while suffix < min(before.count, after.count) - prefix,
              before[before.count - suffix - 1] == after[after.count - suffix - 1] { suffix += 1 }
        let heard = before[prefix..<(before.count - suffix)].joined(separator: " ").trimmingCharacters(in: edges)
        let written = after[prefix..<(after.count - suffix)].joined(separator: " ").trimmingCharacters(in: edges)
        guard !heard.isEmpty, !written.isEmpty, heard != written else { return nil }
        let whole = prefix == 0 && suffix == 0
        return Replacement(heard: heard, written: whole ? corrected.trimmingCharacters(in: .whitespacesAndNewlines) : written, wholeUtterance: whole)
    }

    public static func saving(_ rule: Replacement, in dictionary: [Replacement]) -> [Replacement] {
        var result = dictionary
        let matches = result.indices.filter {
            key(result[$0].heard) == key(rule.heard) && (result[$0].wholeUtterance == true) == (rule.wholeUtterance == true)
        }
        var saved = rule
        saved.heard = saved.heard.trimmingCharacters(in: .whitespacesAndNewlines)
        saved.written = saved.written.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key(saved.heard).isEmpty, !saved.written.isEmpty else { return result }
        if let first = matches.first {
            saved.id = result[first].id
            if saved.protectLiterals == nil { saved.protectLiterals = result[first].protectLiterals }
            result[first] = saved
            for duplicate in matches.dropFirst().reversed() { result.remove(at: duplicate) }
        } else { result.append(saved) }
        return result
    }

    public static func apply(_ dictionary: [Replacement], to text: String) -> String {
        guard !text.isEmpty else { return text }
        if let exact = dictionary.first(where: { $0.wholeUtterance == true && !key($0.heard).isEmpty && key($0.heard) == key(text) }) {
            // Retain sentence punctuation unless the correction supplies its own.
            let suffix = text.reversed().prefix(while: { ".!?…".contains($0) }).reversed()
            return exact.written + (exact.written.last.map { ".!?…".contains($0) } == true ? "" : String(suffix))
        }
        let plan = compiled(dictionary)
        let rules = plan.rules
        guard let regex = plan.regex else { return text }
        let protected = rules.contains(where: { $0.protectLiterals == true })
            ? PunctuationRules.protected.matches(in: text, range: NSRange(text.startIndex..., in: text)).map(\.range) : []
        let output = NSMutableString(string: text)
        // Match the original once: a correction cannot trigger another correction.
        for match in regex.matches(in: text, range: NSRange(text.startIndex..., in: text)).reversed() {
            for index in rules.indices where match.range(at: index + 1).location != NSNotFound {
                if rules[index].protectLiterals != true || !protected.contains(where: { NSIntersectionRange($0, match.range).length > 0 }) {
                    output.replaceCharacters(in: match.range, with: rules[index].written)
                }
                break
            }
        }
        return output as String
    }
    private struct Plan {
        let rules: [Replacement]
        let regex: NSRegularExpression?
    }
    // One bounded cache; changing/deleting a dictionary rule invalidates it.
    private static let planLock = NSLock()
    private static var lastDictionary: [Replacement]?
    private static var lastPlan: Plan?
    private static func compiled(_ dictionary: [Replacement]) -> Plan {
        planLock.lock(); defer { planLock.unlock() }
        if dictionary == lastDictionary, let lastPlan { return lastPlan }
        let rules = dictionary.enumerated().filter { $0.element.wholeUtterance != true && !key($0.element.heard).isEmpty }
            .sorted { a, b in a.element.heard.count == b.element.heard.count ? a.offset < b.offset : a.element.heard.count > b.element.heard.count }
            .map(\.element)

        let alternatives = rules.map { rule in
            let phrase = rule.heard.split(whereSeparator: { $0.isWhitespace }).map { NSRegularExpression.escapedPattern(for: String($0)) }.joined(separator: "\\s+")
            return "((?<![\\p{L}\\p{N}_])" + phrase + "(?![\\p{L}\\p{N}_]))"
        }
        let regex = alternatives.isEmpty ? nil : try? NSRegularExpression(pattern: alternatives.joined(separator: "|"), options: .caseInsensitive)

        let plan = Plan(rules: rules, regex: regex)
        lastDictionary = dictionary; lastPlan = plan
        return plan
    }

}
