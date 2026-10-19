import Foundation

@main enum PunctuationChecks {
    static func main() throws {
        var count = 0
        func check(_ input: String, _ expected: String, language: String = "de") {
            let actual = TextRules.apply(input, language: language, fillers: false, dictionary: [], punctuation: true)
            precondition(actual == expected, "Expected: \(expected)\nActual: \(actual)")
            let words = try! NSRegularExpression(pattern: #"[\p{L}\p{N}]+"#)
            func tokens(_ s: String) -> [String] { words.matches(in: s, range: NSRange(s.startIndex..., in: s)).map { (s as NSString).substring(with: $0.range) } }
            precondition(tokens(actual) == tokens(input), "Punctuation changed words or numbers")
            precondition(PunctuationRules.apply(actual, language: language) == actual, "Cleanup is not idempotent")
            count += 1
        }
        check("unten rechts. . Und danach", "unten rechts. Und danach")
        check("Hallo ,Welt !", "Hallo, Welt!")
        check("eins, , zwei", "eins, zwei")
        check("Fertig? . Weiter! .", "Fertig? Weiter!")
        check("Fertig.Nächster Satz.", "Fertig. Nächster Satz.")
        check("Ich glaube dass das geht.", "Ich glaube, dass das geht.")
        check("Das bleibt so weil es funktioniert.", "Das bleibt so, weil es funktioniert.")
        check("So bleiben wie es ist.", "So bleiben, wie es ist.")
        check("Das ist so groß wie ich.", "Das ist so groß wie ich.")
        check("Das Wort weil ist eine Konjunktion.", "Das Wort weil ist eine Konjunktion.")
        check("Das ist aber gut. Ich bin damit zufrieden.", "Das ist aber gut. Ich bin damit zufrieden.")
        check("Ich glaube, dass es nicht geht.", "Ich glaube, dass es nicht geht.")
        check("Weil es funktioniert, bleibt es so.", "Weil es funktioniert, bleibt es so.")
        check("245,90 € am 12.10.2026 um 14:30, Version 1.2.3.", "245,90 € am 12.10.2026 um 14:30, Version 1.2.3.")
        check("U.S.A. und U.K.", "U.S.A. und U.K.")
        check("README.MD und Example.COM", "README.MD und Example.COM")
        check("Adresse fe80::1 und 2001:db8::1", "Adresse fe80::1 und 2001:db8::1")
        check("Dr. Müller meint z. B. 1,5 statt 15.", "Dr. Müller meint z. B. 1,5 statt 15.")
        check("https://example.org/a,b?x=1.2 und test.name@example.org", "https://example.org/a,b?x=1.2 und test.name@example.org")
        check("/tmp/a,b.txt ~/Documents/test.md std::vector", "/tmp/a,b.txt ~/Documents/test.md std::vector")
        check("`foo(1,2);bar()` und ```x = 1.2\ny=3```", "`foo(1,2);bar()` und ```x = 1.2\ny=3```")
        check("Warte... oder . . . doch nicht?", "Warte... oder . . . doch nicht?")
        check("1. Erster Punkt\n2. Zweiter Punkt", "1. Erster Punkt\n2. Zweiter Punkt")
        check("Er sagt „das Wort weil“ und geht.", "Er sagt „das Wort weil“ und geht.")
        check("Das geht nicht obwohl es so aussieht.", "Das geht nicht, obwohl es so aussieht.")
        check("Hello ,world ! This is not 1.5 dollars.", "Hello, world! This is not 1.5 dollars.", language: "en")
        check("I think that this works because it is correct.", "I think that this works because it is correct.", language: "en")
        check("Warte?! Nein!!", "Warte?! Nein!!")
        let raw = "Die neue Ansicht ist fertig. . Das Layout soll so bleiben wie es ist. Bitte prüfe Version 2.4.1 und den Termin um 09:15 Uhr."
        let expected = raw.replacingOccurrences(of: ". .", with: ".").replacingOccurrences(of: "bleiben wie es ist", with: "bleiben, wie es ist")
        check(raw, expected)
        precondition(TextRules.apply(raw, language: "de", fillers: false, dictionary: [], punctuation: false) == raw)
        let custom = TextRules.apply("Alias.", language: "de", fillers: false, dictionary: [Replacement(heard: "Alias", written: "x,y")], punctuation: true)
        precondition(custom == "x,y.", "Explicit dictionary output should stay literal")
        var prefs = Preferences(); prefs.shortcutCode = 63; prefs.onboardingComplete = true
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(prefs)) as! [String: Any]
        legacy.removeValue(forKey: "cleanPunctuation")
        let loaded = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy))
        precondition(loaded == prefs && (loaded.cleanPunctuation ?? true))
        prefs.cleanPunctuation = false
        let roundTrip = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(prefs))
        precondition(roundTrip == prefs)
        let start = DispatchTime.now().uptimeNanoseconds
        for _ in 0..<1000 { _ = PunctuationRules.apply(raw, language: "de") }
        let ms = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6 / 1000
        print("\(count) punctuation fixtures passed; word/number preservation and idempotence checked for each.")
        print("PASS: disabled cleanup, literal dictionary output, legacy preferences and disabled-toggle persistence")
        print(String(format: "Mean cleanup time: %.3f ms per example (1000 rounds)", ms))
        print("Example result: \(expected)")
    }
}
