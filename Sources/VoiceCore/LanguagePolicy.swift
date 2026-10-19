import Foundation

/// Output guard, not a decoder vocabulary constraint or a general language classifier.
public enum LanguagePolicy {
    public static let defaults = ["de", "en"]
    public static func base(_ language: String) -> String {
        language.lowercased().replacingOccurrences(of: "_", with: "-").components(separatedBy: "-")[0]
    }
    public static func allowed(requested: String, selection: [String]?) -> [String] {
        if requested != "auto" { return [base(requested)] }
        return Array(Set((selection ?? defaults).map(base).filter { !$0.isEmpty && $0 != "auto" })).sorted()
    }
    public static func recognitionLanguage(requested: String, selection: [String]?) -> String {
        let languages = allowed(requested: requested, selection: selection)
        return requested == "auto" && languages.count == 1 ? languages[0] : requested
    }
    private static let tags = try! NSRegularExpression(pattern: #"<([a-z]{2,3}(?:[-_][A-Za-z]{2,4})?)>"#)
    private static let scripts: [(NSRegularExpression, Set<String>, String)] = [
        (#"\p{Cyrillic}"#, ["ru", "uk", "bg", "sr", "mk", "be", "kk"], "Cyrillic script"),
        (#"\p{Arabic}"#, ["ar", "fa", "ur", "ps"], "Arabic script"),
        (#"\p{Han}"#, ["zh", "ja", "ko"], "Chinese characters"),
        (#"[\p{Hiragana}\p{Katakana}]"#, ["ja"], "Japanese script"),
        (#"\p{Hangul}"#, ["ko"], "Korean script"),
        (#"\p{Hebrew}"#, ["he", "yi"], "Hebrew script"),
        (#"\p{Greek}"#, ["el"], "Greek script"),
        (#"\p{Devanagari}"#, ["hi", "mr", "ne", "sa"], "Devanagari script"),
        (#"\p{Thai}"#, ["th"], "Thai script")
    ].map { (try! NSRegularExpression(pattern: $0.0), Set($0.1), $0.2) }

    public static func warning(text: String, raw: String, detected: String, requested: String, selection: [String]?) -> String? {
        let permitted = Set(allowed(requested: requested, selection: selection))
        guard !permitted.isEmpty else { return nil } // Explicit unrestricted choice.
        let ns = raw as NSString
        var reported = Set(tags.matches(in: raw, range: NSRange(location: 0, length: ns.length)).map { base(ns.substring(with: $0.range(at: 1))) })
        if !detected.isEmpty && detected != "auto" { reported.insert(base(detected)) }
        let outside = reported.subtracting(permitted).sorted()
        if !outside.isEmpty { return "Model language not allowed: " + outside.joined(separator: ", ") + "." }
        // Model tags can be wrong (e.g. Arabic text carrying a German tag).
        // Quoted text, URLs and code remain valid literal content in any language.
        let prose = PunctuationRules.protected.stringByReplacingMatches(in: text, range: NSRange(text.startIndex..., in: text), withTemplate: " ")
        for (pattern, languages, name) in scripts where permitted.isDisjoint(with: languages) {
            if pattern.firstMatch(in: prose, range: NSRange(prose.startIndex..., in: prose)) != nil {
                return name + " detected outside the allowed languages."
            }
        }
        return nil
    }
    public static func shouldPaste(automatically: Bool, requested: Bool, warning: String?) -> Bool {
        automatically && requested && warning == nil
    }
}
