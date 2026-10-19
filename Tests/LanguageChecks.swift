import Foundation

@main enum LanguageChecks {
    static func main() throws {
        var count = 0
        func check(_ text: String, _ raw: String = "", detected: String = "", requested: String = "auto", selection: [String]? = nil, blocked: Bool) {
            let warning = LanguagePolicy.warning(text: text, raw: raw, detected: detected, requested: requested, selection: selection)
            precondition((warning != nil) == blocked, "Unexpected policy for: \(text)")
            precondition(LanguagePolicy.shouldPaste(automatically: true, requested: true, warning: warning) == !blocked)
            count += 1
        }
        check("Hallo. Please help me.", "Hallo. <de-DE> Please help me. <en-US>", blocked: false)
        check("Привет.", "Привет. <ru-RU>", blocked: true)
        check("Привет.", "", blocked: true)
        check("يا مرحبا bitte ändern", "يا مرحبا bitte ändern <de-DE>", blocked: true)
        check("Bonjour tout le monde.", "Bonjour tout le monde. <fr-FR>", blocked: true)
        check("Bonjour.", detected: "fr-FR", blocked: true)
        check("Hello.", "Hello. <en-GB>", blocked: false)
        check("Hallo.", "Hallo. <de_DE>", blocked: false)
        check("Hello.", "Hello. <en-US>", selection: ["de"], blocked: true)
        check("Bonjour.", "Bonjour. <fr-FR>", selection: ["de", "fr"], blocked: false)
        check("Привет.", "Привет. <ru-RU>", selection: ["de", "ru"], blocked: false)
        check("مرحبا", "مرحبا <ar-AR>", selection: ["ar"], blocked: false)
        check("中文", selection: ["ja"], blocked: false)
        check("こんにちは", blocked: true)
        check("안녕하세요", blocked: true)
        check("שלום", blocked: true)
        check("Γεια", blocked: true)
        check("नमस्ते", blocked: true)
        check("สวัสดี", blocked: true)
        check("Привет", selection: [], blocked: false)
        check("Hallo", "Hallo <de-DE>", requested: "de", selection: ["en"], blocked: false)
        check("Hallo", "Hallo <de-DE>", requested: "en", selection: [], blocked: true)
        check("Use `Привет` or https://example.com/مرحبا", blocked: false)
        check("Das Wort heißt \"Привет\".", blocked: false)
        check("Wir haben ein Meeting um 14:30. Please check the dashboard.", blocked: false)
        // Deliberate limitation: no guessing a language from short Latin text.
        check("Bonjour", blocked: false)
        precondition(!LanguagePolicy.shouldPaste(automatically: false, requested: true, warning: nil))
        precondition(!LanguagePolicy.shouldPaste(automatically: true, requested: false, warning: nil))
        precondition(LanguagePolicy.allowed(requested: "auto", selection: nil) == ["de", "en"])
        precondition(LanguagePolicy.recognitionLanguage(requested: "auto", selection: ["de-DE"]) == "de")
        precondition(LanguagePolicy.recognitionLanguage(requested: "auto", selection: ["de", "en"]) == "auto")
        precondition(LanguagePolicy.recognitionLanguage(requested: "auto", selection: []) == "auto")
        var settings = Preferences()
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as! [String: Any]
        legacy.removeValue(forKey: "allowedLanguages")
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy))
        precondition(decoded.allowedLanguages == nil)
        settings.allowedLanguages = ["de", "en", "fr"]
        let restoredSettings = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(settings))
        precondition(restoredSettings == settings)
        var entry = HistoryEntry(text: "Привет", raw: "Привет <ru-RU>", model: "test", language: "auto", duration: 1, computeMS: 10)
        entry.languageWarning = "Not allowed"
        let restored = try JSONDecoder().decode(HistoryEntry.self, from: JSONEncoder().encode(entry))
        precondition(restored.raw == entry.raw && restored.languageWarning == entry.languageWarning)
        print("\(count) language guard cases passed; paste gating, language routing and persistence passed.")
    }
}
