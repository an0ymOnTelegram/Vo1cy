import Foundation

/// Local, bounded formatting rules. No paraphrasing or inferred list contents.
/// Explicit list markers may be replaced by bullets; all item text is retained.
public enum DictationFormatter {
    private static func regex(_ pattern: String) -> NSRegularExpression {
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }
    private static let germanOrdinals = ["erstens", "zweitens", "drittens", "viertens", "fünftens", "sechstens", "siebtens", "achtens", "neuntens", "zehntens"]
    private static let englishOrdinals = ["firstly", "secondly", "thirdly", "fourthly", "fifthly", "sixthly", "seventhly", "eighthly", "ninthly", "tenthly"]
    private static let ordinalDE = regex(#"\b(?:erstens|zweitens|drittens|viertens|fünftens|sechstens|siebtens|achtens|neuntens|zehntens)\b"#)
    private static let ordinalEN = regex(#"\b(?:firstly|secondly|thirdly|fourthly|fifthly|sixthly|seventhly|eighthly|ninthly|tenthly)\b"#)
    private static let pointDE = regex(#"\bPunkt[ \t]+(eins|zwei|drei|vier|fünf|sechs|sieben|acht|neun|zehn|[1-9]|10)\b"#)
    private static let pointEN = regex(#"\bitem[ \t]+(one|two|three|four|five|six|seven|eight|nine|ten|[1-9]|10)\b"#)
    private static let bulletDE = regex(#"\bneuer[ \t]+(?:Stichpunkt|Listenpunkt|Punkt)\b"#)
    private static let bulletEN = regex(#"\bnew[ \t]+(?:bullet|list item)\b"#)
    private static let inlineIntroDE = regex(#"^(.*?\b(?:folgende[nr]? (?:Punkte|Aufgaben|Dinge|Positionen)|Einkaufsliste|To-do-Liste))\s*:\s*(.+)$"#)
    private static let bareIntroDE = regex(#"^((?:Folgende[nr]? (?:Punkte|Aufgaben|Dinge|Positionen)|Einkaufsliste|To-do-Liste))\s+(?!sind\b|werden\b|müssen\b|sollten\b)(.+)$"#)
    private static let bareIntroEN = regex(#"^((?:Following (?:items|tasks|points)|Shopping list|To-do list))\s+(?!is\b|are\b|will\b)(.+)$"#)
    private static let inlineIntroEN = regex(#"^(.*?\b(?:following (?:items|tasks|points)|shopping list|to-do list))\s*:\s*(.+)$"#)
    private static let inlineSeparatorsDE = regex(#"[,;]|\s+und\s+"#)
    private static let inlineSeparatorsEN = regex(#"[,;]|\s+and\s+"#)
    private static let complexClause = regex(#"\b(?:dass|weil|wenn|ob|obwohl|sondern|aber|wie|that|because|whether|although|but)\b"#)
    private static let paragraphDE = regex(#"\bneuer[ \t]+Absatz\b"#)
    private static let paragraphEN = regex(#"\bnew[ \t]+paragraph\b"#)
    private static let endDE = regex(#"\b(?:Listenende|Ende der Liste)\b"#)
    private static let endEN = regex(#"\bend of list\b"#)
    private static let literalContext = regex(#"\b(?:ein|einen|einem|einer|der|den|dem|dieser|diesem|jeder|kein|kein(?:en|em)|das Wort|der Befehl|heißt|bedeutet|über|zu|bei|a|the|called|means|about)\s*$"#)
    private static let leadConjunction = regex(#"\b(?:und|sowie|and)\s*$"#)
    private static let germanQuestion = regex(#"^(?:(?:geht|gehen|passt|passen|stimmt|stimmen|funktioniert|funktionieren|ist|sind|war|waren|wird|werden|hat|haben|hast|habt|kann|können|kannst|könnt|soll|sollen|sollst|darf|dürfen|darfst|will|wollen|willst|möchte|möchtest|möchten|kommt|kommen|kommst|brauche|brauchst|brauchen|gibt)\s+(?:ich|du|er|sie|es|wir|ihr|man|das|der|die|ein|eine)\b|(?:warum|wieso|weshalb|wann|wo|wie|was|wer)\s+(?:geht|ist|sind|war|waren|wird|werden|hat|haben|hast|kann|können|kannst|soll|sollen|möchtest|möchten|kommt|kommen|heißt|funktioniert|funktionieren)\b)"#)
    // A narrow request form remains a question even with an inserted relative clause.
    // Other comma-containing verb-first clauses can be conditionals; leave them alone.
    private static let requestQuestion = regex(#"^(?:kannst|könntest|würdest) du\b.*\b(?:bitte|verbessern|prüfen|erklären|zeigen|helfen|ändern|anschauen|überprüfen)\b"#)
    private static let conditionalContinuation = regex(#",\s*(?:dann|so|(?:komme|kommen|mache|machen|werde|werden|kann|können|muss|müssen|bleibe|bleiben)\s+(?:ich|wir|du|er|sie|es))\b"#)
    private static let englishQuestion = regex(#"^(?:(?:can|could|would|will|should|do|does|did|is|are|was|were|have|has)\s+(?:I|you|he|she|it|we|they|this|that|the)\b|(?:why|when|where|how|what|who)\s+(?:is|are|was|were|do|does|did|can|could|will|would|should|has|have)\b)"#)
    private static let germanStatement = regex(#"\b(?:(?:ich|du|er|sie|es|wir|ihr|man|das)\s+(?:möchte|möchtest|möchten|will|willst|wollen|habe|hast|hat|haben|bin|bist|ist|sind|seid|werde|wirst|wird|werden|kann|kannst|können|soll|sollst|sollen|muss|musst|müssen|komme|kommst|kommt|kommen|spreche|sprichst|spricht|sprechen|brauche|brauchst|braucht|brauchen|gehe|gehst|geht|gehen)|(?:habe|hast|hat|haben|bin|bist|ist|sind|werde|wirst|wird|werden|komme|kommst|kommt|kommen)\s+(?:ich|du|er|sie|es|wir|ihr))\b"#)
    private static let englishStatement = regex(#"\b(?:I|you|he|she|it|we|they|this|that)\s+(?:am|is|are|was|were|have|has|want|wants|need|needs|will|would|can|could|should|must|do|does)\b"#)
    private static let ackDE = regex(#"^(super|okay|ok|gut|prima|danke)\s+(?=(?:geht|passt|stimmt|funktioniert|ist|sind|kann|kannst|können)\s+(?:das|es|du|ich|wir)\b)"#)
    private static let shortQuestionBoundary = regex(#"^((?:geht|passt|stimmt|funktioniert|ist|kann)\s+(?:das|es)(?:\s+(?:so|jetzt|auch|schon|wirklich|noch|nicht))?)[, ]+((?:ich|wir|du)\s+(?:möchte|möchten|möchtest|will|wollen|willst|habe|haben|hast|bin|sind|bist)\b)"#)
    private static let temporalBoundary = regex(#"[ \t]+((?:morgen|heute|übermorgen|gestern|anschließend|danach)(?:\s+um\s+[\p{L}\p{N}:]+(?:\s+Uhr)?)?\s+(?:habe|haben|hat|bin|sind|ist|werde|werden|wird|komme|kommen|kommt)\s+(?:ich|wir|du|er|sie|es)\b)"#)
    private static let subordinateOrLink = regex(#"(?:[,;:]|\b(?:und|oder|aber|denn|weil|dass|wenn|ob|bevor|nachdem|wie))\s*$"#)
    private static let structuredLine = regex(#"^[ \t]*(?:[-*•] |\d+[.)] |[>#])"#)
    private static let commandExplanation = regex(#"^\s+(?:ist|heißt|bedeutet|steht|is|means)\b"#)
    private static let sentenceDelimiter = regex(#"[.!?]+(?:\s+|$)|\n+"#)

    public static func apply(_ input: String, language: String, sentences: Bool, lists: Bool) -> String {
        guard sentences || lists else { return input }
        let automatic = language == "auto"
        let de = automatic || language.lowercased().hasPrefix("de")
        guard de || language.lowercased().hasPrefix("en") else { return input }
        // Reuse the punctuation cleaner's literal coverage. Tokens do not resemble
        // natural words or sentence/list markers, and are restored verbatim last.
        let marker = "\u{E000}" + UUID().uuidString + "\u{E001}"
        let work = NSMutableString(string: input)
        var saved: [(String, String)] = []
        for (i, m) in PunctuationRules.protected.matches(in: input, range: NSRange(input.startIndex..., in: input)).enumerated().reversed() {
            let token = marker + String(i) + "\u{E002}"
            saved.append((token, (input as NSString).substring(with: m.range)))
            work.replaceCharacters(in: m.range, with: token)
        }
        var result = work as String
        if lists {
            result = paragraphs(result, de: de)
            if automatic { result = paragraphs(result, de: false) }
            result = result.components(separatedBy: "\n\n").map { block in
                // Existing Markdown lists must remain idempotent.
                if block.components(separatedBy: "\n").contains(where: { $0.hasPrefix("- ") || $0.hasPrefix("• ") }) { return block }
                return list(block, de: de) ?? inlineList(block, de: de)
                    ?? (automatic ? (list(block, de: false) ?? inlineList(block, de: false)) : nil) ?? block
            }.joined(separator: "\n\n")
        }
        if sentences {
            result = result.components(separatedBy: "\n").map {
                let formatted = formatLine($0, de: de)
                return automatic ? formatLine(formatted, de: false) : formatted
            }.joined(separator: "\n")
        }
        for (token, original) in saved { result = result.replacingOccurrences(of: token, with: original) }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func matches(_ r: NSRegularExpression, _ s: String) -> [NSTextCheckingResult] {
        r.matches(in: s, range: NSRange(s.startIndex..., in: s))
    }
    private static func has(_ r: NSRegularExpression, _ s: String) -> Bool { !matches(r, s).isEmpty }
    private static func replace(_ r: NSRegularExpression, _ s: String, _ template: String) -> String {
        r.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: template)
    }
    private static func capitalizedStart(_ s: String) -> String {
        guard let first = s.first, first.isLetter else { return s }
        return String(first).uppercased() + s.dropFirst()
    }
    private static func trim(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
    private static func paragraphs(_ s: String, de: Bool) -> String {
        let ns = s as NSString; let out = NSMutableString(string: s)
        for m in matches(de ? paragraphDE : paragraphEN, s).reversed() {
            let before = ns.substring(to: m.range.location)
            let after = ns.substring(from: NSMaxRange(m.range))
            guard !has(literalContext, before), !has(commandExplanation, after) else { continue }
            var end = NSMaxRange(m.range)
            while end < ns.length, ",.;: \t".contains(ns.substring(with: NSRange(location: end, length: 1))) { end += 1 }
            out.replaceCharacters(in: NSRange(location: m.range.location, length: end - m.range.location), with: "\n\n")
        }
        return (out as String).components(separatedBy: "\n\n").map(trim).joined(separator: "\n\n")
    }

    private static func list(_ s: String, de: Bool) -> String? {
        let ns = s as NSString
        for kind in 0..<3 {
            let pattern = kind == 0 ? (de ? ordinalDE : ordinalEN) : kind == 1 ? (de ? pointDE : pointEN) : (de ? bulletDE : bulletEN)
            var markers = matches(pattern, s)
            guard markers.count >= (kind == 2 ? 1 : 2) else { continue }
            // An explicit end marker separates following prose from the last item.
            let end = matches(de ? endDE : endEN, s).first(where: { $0.range.location > markers[0].range.location })
            if let end { markers = markers.filter { $0.range.location < end.range.location } }
            guard markers.count >= (kind == 2 ? 1 : 2) else { continue }
            let prefix = trim(ns.substring(to: markers[0].range.location))
            guard !has(literalContext, prefix) else { continue }
            if kind == 2 && markers.count == 1 && !prefix.isEmpty && !prefix.hasSuffix(":") { continue }
            if kind < 2 {
                let words = kind == 0 ? (de ? germanOrdinals : englishOrdinals) : (de ? ["eins","zwei","drei","vier","fünf","sechs","sieben","acht","neun","zehn"] : ["one","two","three","four","five","six","seven","eight","nine","ten"])
                let values = markers.map { m -> Int in
                    let word = ns.substring(with: kind == 0 ? m.range : m.range(at: 1)).lowercased()
                    return kind == 1 ? (Int(word) ?? ((words.firstIndex(of: word) ?? -100) + 1)) : ((words.firstIndex(of: word) ?? -100) + 1)
                }
                guard values == Array(1...values.count) else { continue }
            }
            var items: [String] = []
            for i in markers.indices {
                let start = NSMaxRange(markers[i].range)
                let stop = i + 1 < markers.count ? markers[i + 1].range.location : (end?.range.location ?? ns.length)
                var item = ns.substring(with: NSRange(location: start, length: stop - start))
                item = item.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",:;")))
                // Model punctuation immediately after a marker ("erstens. Milch").
                if item.hasPrefix(". ") { item = trim(String(item.dropFirst(2))) }
                if i + 1 < markers.count {
                    item = replace(leadConjunction, item, "")
                    item = item.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",;")))
                }
                guard !item.isEmpty, item.rangeOfCharacter(from: .letters.union(.decimalDigits)) != nil else { items = []; break }
                items.append("- " + capitalizedStart(item))
            }
            guard items.count == markers.count else { continue }
            var intro = prefix
            if !intro.isEmpty && !".:!?".contains(intro.last!) { intro += ":" }
            var output = (intro.isEmpty ? "" : intro + "\n") + items.joined(separator: "\n")
            if let end {
                let suffix = ns.substring(from: NSMaxRange(end.range)).trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ",.;:")))
                if !suffix.isEmpty { output += "\n\n" + suffix }
            }
            return output
        }
        return nil
    }

    private static func inlineList(_ text: String, de: Bool) -> String? {
        guard let match = matches(de ? inlineIntroDE : inlineIntroEN, text).first ?? matches(de ? bareIntroDE : bareIntroEN, text).first else { return nil }
        let ns = text as NSString
        let intro = ns.substring(with: match.range(at: 1))
        let body = ns.substring(with: match.range(at: 2))
        guard !has(complexClause, body), !body.contains("\n") else { return nil }
        let content = body as NSString
        // Parentheses may contain commas. Semicolons explicitly delimit whole
        // items and take precedence over commas/conjunctions inside an item.
        let useSemicolons = body.contains(";")
        var items: [String] = [], cursor = 0
        for separator in matches(de ? inlineSeparatorsDE : inlineSeparatorsEN, body) {
            let token = content.substring(with: separator.range)
            if useSemicolons && token != ";" { continue }
            let before = content.substring(to: separator.range.location)
            let depth = before.reduce(0) { $1 == "(" || $1 == "[" ? $0 + 1 : $1 == ")" || $1 == "]" ? $0 - 1 : $0 }
            if depth != 0 { continue }
            let item = trim(content.substring(with: NSRange(location: cursor, length: separator.range.location - cursor)))
            if !item.isEmpty { items.append(item) }
            cursor = NSMaxRange(separator.range)
        }
        let last = trim(content.substring(from: cursor))
        if !last.isEmpty { items.append(last) }
        guard items.count >= 2, !last.isEmpty else { return nil }
        return intro + ":\n" + items.map { "- " + capitalizedStart($0) }.joined(separator: "\n")
    }

    private static func formatLine(_ line: String, de: Bool) -> String {
        // Preserve structured lists, indentation and their fragment punctuation.
        if has(structuredLine, line) || line.first?.isNumber == true { return line }
        var text = trim(line)
        guard !text.isEmpty else { return line }
        if de {
            text = replace(ackDE, text, "$1. ")
            // Apply a narrow short-question boundary after an acknowledgement too.
            text = text.components(separatedBy: ". ").map { replace(shortQuestionBoundary, $0, "$1? $2") }.joined(separator: ". ")
            let ns = text as NSString; let work = NSMutableString(string: text)
            for m in matches(temporalBoundary, text).reversed() {
                let before = ns.substring(to: m.range.location)
                guard has(germanStatement, before), !has(subordinateOrLink, before),
                      before.last.map({ !".!?".contains($0) }) == true else { continue }
                work.replaceCharacters(in: m.range, with: ". " + capitalizedStart(ns.substring(with: m.range(at: 1))))
            }
            text = work as String
        }
        let ns = text as NSString
        var output = "", cursor = 0
        for boundary in matches(sentenceDelimiter, text) {
            let clause = ns.substring(with: NSRange(location: cursor, length: boundary.range.location - cursor))
            output += capitalizedStart(clause)
            let separator = ns.substring(with: boundary.range)
            if separator.hasPrefix("."), !separator.hasPrefix(".."), (!clause.contains(",") || (de && has(requestQuestion, clause) && !has(conditionalContinuation, clause))), has(de ? germanQuestion : englishQuestion, clause) {
                output += "?" + separator.dropFirst()
            } else { output += separator }
            cursor = NSMaxRange(boundary.range)
        }
        var tail = capitalizedStart(ns.substring(from: cursor))
        if !tail.isEmpty && tail.last.map({ !".!?:;,…\u{E002}".contains($0) }) == true {
            if has(de ? germanQuestion : englishQuestion, tail) { tail += "?" }
            else if has(de ? germanStatement : englishStatement, tail) { tail += "." }
        }
        return output + tail
    }
}
