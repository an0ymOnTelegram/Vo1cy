import Foundation

/// Small, precompiled text rules. No sentence reconstruction or acoustic inference.
public enum SpeechCleanup {
    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    }
    private static let restartDE = regex(#"\b(die nicht|von der|in den|ich möchte|ich will|ich habe|ich kann|wir müssen|wir möchten|das ist|das war|dass ich|dass wir|dass man)(?:[ \t,]+(?:äh|ähm)[ \t,]+\1\b)+"#)
    private static let restartEN = regex(#"\b(I want|I need|I would|we need)(?:[ \t,]+(?:uh|um)[ \t,]+\1\b)+"#)
    private static let fillerWords = ["de": "äh|ähm", "en": "uh|um", "auto": "äh|ähm|uh"]
    private static let fillerRules: [String: [(NSRegularExpression, String)]] = fillerWords.mapValues { words in
        [
            // Remove the punctuation of a standalone filler sentence, not the
            // meaningful sentence before it. Do this before removing filler words.
            (regex("(^|(?<=[.!?])[ \\t]+)(?:" + words + ")[, ]*[.!?](?=\\s|$)"), "$1"),
            (regex("(?<![\\p{L}\\p{N}_])(?:" + words + ")(?![\\p{L}\\p{N}_])[, ]*"), ""),
            (regex(#",[ \t]*([.!?])"#), "$1")
        ]
    }
    private static let spellingRules: [(NSRegularExpression, String)] = [
        (regex(#"(?<![\p{L}\p{N}_])U[ \t]+S[ \t]+B(?![\p{L}\p{N}_])"#), "USB"),
        (regex(#"(?<![\p{L}\p{N}_])K[ \t]+I(?![\p{L}\p{N}_])"#), "KI"),
        (regex(#"\bE[ \t]+Mail\b"#), "E-Mail")
    ]
    public static func apply(_ input: String, language: String, fillers: Bool, restarts: Bool, spellings: Bool) -> String {
        let lang = language == "auto" ? "auto" : LanguagePolicy.base(language)
        guard fillerWords[lang] != nil, fillers || restarts || spellings else { return input }
        let marker = "\u{E000}" + UUID().uuidString + "\u{E001}"
        let work = NSMutableString(string: input)
        var saved: [(String, String)] = []
        for (i, match) in PunctuationRules.protected.matches(in: input, range: NSRange(input.startIndex..., in: input)).enumerated().reversed() {
            let token = marker + String(i) + "\u{E002}"
            saved.append((token, (input as NSString).substring(with: match.range)))
            work.replaceCharacters(in: match.range, with: token)
        }
        var result = work as String
        var rules: [(NSRegularExpression, String)] = []
        if restarts {
            if lang != "en" { rules.append((restartDE, "$1")) }
            if lang != "de" { rules.append((restartEN, "$1")) }
        }
        if fillers { rules += fillerRules[lang] ?? [] }
        if spellings { rules += spellingRules }
        for (pattern, replacement) in rules {
            result = pattern.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: replacement)
        }
        for (token, original) in saved { result = result.replacingOccurrences(of: token, with: original) }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
