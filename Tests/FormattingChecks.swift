import Foundation

@main enum FormattingChecks {
    static func main() throws {
        var count = 0
        func format(_ s: String, language: String = "de", sentences: Bool = true, lists: Bool = true) -> String {
            TextRules.apply(s, language: language, fillers: false, dictionary: [], punctuation: true, sentences: sentences, lists: lists)
        }
        func check(_ input: String, _ expected: String, language: String = "de", sentences: Bool = true, lists: Bool = true) {
            let actual = format(input, language: language, sentences: sentences, lists: lists)
            guard actual == expected else { fatalError("Expected: \(expected)\nActual: \(actual)\nInput: \(input)") }
            precondition(format(actual, language: language, sentences: sentences, lists: lists) == actual, "Non-idempotent: \(actual)")
            count += 1
        }
        check("Super geht das, ich möchte die Dateien sortieren morgen um zehn Uhr habe ich Zeit", "Super. Geht das? Ich möchte die Dateien sortieren. Morgen um zehn Uhr habe ich Zeit.")
        check("geht das", "Geht das?")
        check("Geht das.", "Geht das?")
        check("Geht das nicht, ich möchte das nicht ändern", "Geht das nicht? Ich möchte das nicht ändern.")
        check("Kannst du mir helfen", "Kannst du mir helfen?")
        check("Warum ist das so", "Warum ist das so?")
        check("Ich möchte nicht um vierzehn Uhr kommen", "Ich möchte nicht um vierzehn Uhr kommen.")
        check("Ich komme morgen und danach habe ich Zeit", "Ich komme morgen und danach habe ich Zeit.")
        check("Ich weiß dass morgen habe ich Zeit", "Ich weiß dass morgen habe ich Zeit.") // Do not invent a boundary inside a malformed subordinate clause.
        check("Ich komme heute danach habe ich Zeit", "Ich komme heute. Danach habe ich Zeit.")
        check("Hallo. ich komme morgen", "Hallo. Ich komme morgen.")
        check("Das klappt wenn es nicht regnet", "Das klappt, wenn es nicht regnet")
        check("Ich weiß nicht ob das klappt", "Ich weiß nicht, ob das klappt")
        check("Erstens Milch zweitens Brot drittens Eier", "- Milch\n- Brot\n- Eier")
        check("Ich brauche erstens Milch zweitens Brot und drittens Eier", "Ich brauche:\n- Milch\n- Brot\n- Eier")
        check("Erstens. Milch. Zweitens. Brot.", "- Milch.\n- Brot.")
        check("Erstens: Milch, zweitens: Brot, drittens: Eier.", "- Milch\n- Brot\n- Eier.")
        check("Punkt eins E-Mails beantworten Punkt zwei Rechnung bezahlen", "- E-Mails beantworten\n- Rechnung bezahlen")
        check("Punkt 1 nicht löschen Punkt 2 erst am 12.10.2026 bezahlen", "- Nicht löschen\n- Erst am 12.10.2026 bezahlen")
        check("Neuer Punkt Milch neuer Punkt Brot", "- Milch\n- Brot")
        check("Neuer Stichpunkt nicht absagen neuer Stichpunkt um 14:30 kommen", "- Nicht absagen\n- Um 14:30 kommen")
        check("Folgende Aufgaben: neuer Punkt E-Mails lesen neuer Punkt Antworten schreiben", "Folgende Aufgaben:\n- E-Mails lesen\n- Antworten schreiben")
        check("Neuer Punkt Milch neuer Punkt Brot Listenende Ich gehe einkaufen", "- Milch\n- Brot\n\nIch gehe einkaufen.")
        check("Erstens nicht löschen zweitens 245,90 € bezahlen Ende der Liste Morgen habe ich Zeit", "- Nicht löschen\n- 245,90 € bezahlen\n\nMorgen habe ich Zeit.")
        check("Ich komme morgen neuer Absatz Wir sprechen später", "Ich komme morgen.\n\nWir sprechen später.")
        check("Ich komme morgen. Neuer Absatz. Wir sprechen später.", "Ich komme morgen.\n\nWir sprechen später.")
        check("Ein neuer Absatz ist hier sinnvoll.", "Ein neuer Absatz ist hier sinnvoll.")
        check("Neuer Absatz bedeutet eine Leerzeile.", "Neuer Absatz bedeutet eine Leerzeile.")
        check("Das Wort erstens steht vor zweitens.", "Das Wort erstens steht vor zweitens.")
        check("Wir sprechen über Punkt eins und später über Punkt zwei.", "Wir sprechen über Punkt eins und später über Punkt zwei.")
        check("Erstens Milch drittens Brot", "Erstens Milch drittens Brot")
        check("Zweitens Milch drittens Brot", "Zweitens Milch drittens Brot")
        check("Erstens zweitens Brot", "Erstens zweitens Brot")
        check("Erstens Milch zweitens", "Erstens Milch zweitens")
        check("Das ist ein neuer Punkt und kein neuer Punkt im Ablauf.", "Das ist ein neuer Punkt und kein neuer Punkt im Ablauf.")
        check("Ich sage „erstens Milch zweitens Brot“.", "Ich sage „erstens Milch zweitens Brot“.")
        check("`neuer Absatz` und `erstens Milch zweitens Brot`", "`neuer Absatz` und `erstens Milch zweitens Brot`")
        check("245,90 € am 12.10.2026 um 14:30, Version 1.2.3.", "245,90 € am 12.10.2026 um 14:30, Version 1.2.3.")
        check("https://example.com/a,b?x=1.2 und mail@example.org", "https://example.com/a,b?x=1.2 und mail@example.org")
        check("Erstens https://example.com/a,b zweitens `foo(1,2)`", "- https://example.com/a,b\n- `foo(1,2)`")
        check("- Milch\n- Brot", "- Milch\n- Brot")
        check("1. Milch\n2. Brot", "1. Milch\n2. Brot")
        check("Neuer Punkt Milch", "- Milch")
        check("Folgende Punkte Milch, Brot und Eier", "Folgende Punkte:\n- Milch\n- Brot\n- Eier")
        check("Folgende Punkte sind wichtig, damit alles klappt.", "Folgende Punkte sind wichtig, damit alles klappt.")
        check("Following items milk, bread and eggs", "Following items:\n- Milk\n- Bread\n- Eggs", language: "en")
        check("Ich brauche erstens Milch, zweitens Brot und drittens Eier.", "Ich brauche:\n- Milch\n- Brot\n- Eier.")
        check("Folgende Punkte: Milch, Brot und Eier", "Folgende Punkte:\n- Milch\n- Brot\n- Eier")
        check("Folgende Positionen: oben links, Mitte oben, oben rechts, unten links, Mitte unten und unten rechts", "Folgende Positionen:\n- Oben links\n- Mitte oben\n- Oben rechts\n- Unten links\n- Mitte unten\n- Unten rechts")
        check("Einkaufsliste: Nudeln (ohne Ei, ohne Salz), Milch und Brot", "Einkaufsliste:\n- Nudeln (ohne Ei, ohne Salz)\n- Milch\n- Brot")
        check("Folgende Punkte: 245,90 €, 12.10.2026 und 14:30", "Folgende Punkte:\n- 245,90 €\n- 12.10.2026\n- 14:30")
        check("Folgende Aufgaben: prüfen, ob es geht, und testen, ob es läuft.", "Folgende Aufgaben: prüfen, ob es geht, und testen, ob es läuft.")
        check("Folgende Aufgaben: E-Mails lesen und beantworten; Rechnungen prüfen und zahlen", "Folgende Aufgaben:\n- E-Mails lesen und beantworten\n- Rechnungen prüfen und zahlen")
        check("Ich brauche Milch, Brot und Eier.", "Ich brauche Milch, Brot und Eier.")
        check("Shopping list: milk, bread and eggs", "Shopping list:\n- Milk\n- Bread\n- Eggs", language: "en")
        check("Firstly milk secondly bread thirdly eggs", "- Milk\n- Bread\n- Eggs", language: "en")
        check("Item one send email item two review changes", "- Send email\n- Review changes", language: "en")
        check("New bullet send email new bullet review changes end of list I will call you", "- Send email\n- Review changes\n\nI will call you.", language: "en")
        check("Can you help me", "Can you help me?", language: "en")
        check("I need this tomorrow new paragraph We have enough time", "I need this tomorrow.\n\nWe have enough time.", language: "en")
        check("This is a new paragraph about formatting.", "This is a new paragraph about formatting.", language: "en")
        check("Erstens Milch zweitens Brot", "Erstens Milch zweitens Brot", lists: false)
        check("geht das", "geht das", sentences: false)
        check("erstens milch zweitens brot", "- Milch\n- Brot", sentences: false)
        check("bonjour", "bonjour", language: "fr")
        check("geht das. Can you help me.", "Geht das? Can you help me?", language: "auto")
        check("I need this tomorrow. Ich habe um vierzehn Uhr einen Termin", "I need this tomorrow. Ich habe um vierzehn Uhr einen Termin.", language: "auto")
        check("Firstly milk secondly bread", "- Milk\n- Bread", language: "auto")
        check("Erstens Milch zweitens Brot", "- Milch\n- Brot", language: "auto")
        check("New bullet review changes new bullet Änderungen speichern", "- Review changes\n- Änderungen speichern", language: "auto")
        check("Ich habe Zeit new paragraph Can you help me", "Ich habe Zeit.\n\nCan you help me?", language: "auto")
        check("I need this neuer Absatz Ich habe Zeit", "I need this.\n\nIch habe Zeit.", language: "auto")
        check("Ich hoffe dass es klappt. Can you help me", "Ich hoffe, dass es klappt. Can you help me?", language: "auto")
        check("Use `um` and \"new bullet\" at https://example.com.", "Use `um` and \"new bullet\" at https://example.com.", language: "auto")
        precondition(Preferences().language == "auto")
        for detected in ["", "en-US", "de-DE"] {
            precondition(TextRules.formattingLanguage(requested: "auto", detected: detected) == "auto")
        }
        precondition(TextRules.formattingLanguage(requested: "de", detected: "") == "de")
        precondition(TextRules.formattingLanguage(requested: "en", detected: "en-US") == "en-US")
        let mixed = TextRules.apply("äh I need this um vierzehn Uhr uh bitte", language: "auto", fillers: true, dictionary: [])
        precondition(mixed == "I need this um vierzehn Uhr bitte", mixed)
        precondition(TextRules.apply("um I need this", language: "en", fillers: true, dictionary: []) == "I need this")
        let literal = TextRules.apply("Alias", language: "de", fillers: false, dictionary: [Replacement(heard: "Alias", written: "erstens x zweitens y")], punctuation: true, sentences: true, lists: true)
        precondition(literal == "erstens x zweitens y", "Dictionary must be applied last")
        var settings = Preferences(); settings.shortcutCode = 63; settings.language = "de"
        var old = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as! [String: Any]
        old.removeValue(forKey: "formatSentences"); old.removeValue(forKey: "formatLists")
        let legacy = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: old))
        precondition(legacy == settings && (legacy.formatLists ?? true) && (legacy.formatSentences ?? true))
        settings.formatLists = false; settings.formatSentences = false
        let saved = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(settings))
        precondition(saved == settings)
        let sample = "Super geht das, ich möchte die Dateien sortieren morgen um zehn Uhr habe ich Zeit"
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<1000 { _ = format(sample) }
        print("\(count) formatting fixtures passed, including idempotence; dictionary and legacy settings passed.")
        print(String(format: "Full text pipeline average: %.3f ms", Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9))
    }
}
