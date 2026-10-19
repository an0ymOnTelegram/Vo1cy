import Foundation

/// Conservative punctuation-only cleanup, not a grammar rewriter. Model output
/// remains the source of sentence boundaries; uncertain clauses are left alone.
public enum PunctuationRules {
    static let protected = try! NSRegularExpression(pattern: #"(?is)```.*?```|`[^`\n]+`|https?://\S+|www\.\S+|[\p{L}\p{N}._%+\-]+@[\p{L}\p{N}.\-]+\.[\p{L}]{2,}|(?:[~/]|[A-Z]:\\)[^\s]+|\b[\p{L}\p{N}_]+(?:::[\p{L}\p{N}_]+)+|\b\d+(?:[.,:/\-]\d+)+\b|\b(?:z\.[ \t]*B\.|d\.[ \t]*h\.|u\.[ \t]*a\.|e\.[ \t]*g\.|i\.[ \t]*e\.)|\b(?:Dr|Prof|Mr|Mrs|Ms|Nr|Abs|Art|ca|bzw|usw)\.|\b(?:[a-z]\.){2,}|\b[\p{L}\p{N}_\-]+\.(?:swift|py|js|ts|tsx|jsx|json|md|txt|csv|zip|app|gguf|wav|mp3|pdf|docx|png|jpg|html|css|rs|toml|com|org|net|de|io|dev|co|uk|at|ch)\b|\b(?:[0-9a-f]{0,4}:){2,}[0-9a-f:]+\b|\.{3,}|\.(?:[ \t]+\.){2,}|[„“\"][^„“\"\n]*[„“\"]"#)
    private static let rules: [(NSRegularExpression, String)] = [
        (#"\.[ \t]+\."#, "."),
        (#",(?:[ \t]*,)+"#, ","),
        (#"([!?])[ \t]+\."#, "$1"),
        (#"(?<=\S)[ \t]+([,.;:!?])"#, "$1"),
        (#"([,;:!?])(?=\p{L})"#, "$1 "),
        (#"\.(?=[A-ZÄÖÜ])"#, ". "),
        (#"[ \t]{2,}"#, " ")
    ].map { (try! NSRegularExpression(pattern: $0.0), $0.1) }
    private static let germanCommas: [(NSRegularExpression, String)] = [
        // These subordinators are not ordinary adverbs such as "aber" or "damit".
        (#"(?<=[\p{L}\p{N}])[ \t]+(dass|weil|obwohl|sodass|sofern|wenn|falls|bevor|nachdem|ob)\b(?=[ \t]+(?:ich|du|er|sie|es|wir|ihr|man|das|der|die|ein|eine|kein|keine|jemand|niemand|alle|alles)\b)"#, ", $1"),
        // Require an explicit subject and finite verb; leave comparisons like
        // "so groß wie ich" and infinitive phrases unchanged.
        (#"(?<=\p{L})[ \t]+(wie[ \t]+(?:ich|du|er|sie|es|wir|ihr|man)[ \t]+(?:bin|bist|ist|sind|seid|war|waren|geht|funktioniert)\b)"#, ", $1")
    ].map { (try! NSRegularExpression(pattern: $0.0, options: .caseInsensitive), $0.1) }

    public static func apply(_ input: String, language: String) -> String {
        // Protect literals before changing punctuation. Use a per-call namespace
        // so input cannot accidentally collide with a placeholder.
        let marker = "\u{E000}" + UUID().uuidString + "\u{E001}"
        var saved: [(String, String)] = []
        let working = NSMutableString(string: input)
        for (index, match) in protected.matches(in: input, range: NSRange(input.startIndex..., in: input)).enumerated().reversed() {
            let token = marker + String(index) + "\u{E002}"
            saved.append((token, (input as NSString).substring(with: match.range)))
            working.replaceCharacters(in: match.range, with: token)
        }
        var result = working as String
        for (regex, replacement) in rules + ((language == "auto" || language.hasPrefix("de")) ? germanCommas : []) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(result.startIndex..., in: result), withTemplate: replacement)
        }
        for (token, text) in saved { result = result.replacingOccurrences(of: token, with: text) }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
