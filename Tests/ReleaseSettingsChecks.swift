import Foundation

@main enum ReleaseSettingsChecks {
    static func main() throws {
        let fresh = Preferences()
        precondition(fresh.allowedLanguages == [] && fresh.language == "auto")
        precondition(fresh.dictionary.isEmpty && fresh.modelPath.isEmpty)
        precondition(!fresh.translate && !fresh.saveAudio && !fresh.onboardingComplete && !fresh.warmMicrophone)
        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(fresh)) as! [String: Any]
        legacy.removeValue(forKey: "allowedLanguages")
        legacy.removeValue(forKey: "muteOutput")
        legacy.removeValue(forKey: "soundVolume")
        legacy["language"] = "de"
        legacy["modelPath"] = "/example/model.gguf"
        let migrated = try JSONDecoder().decode(Preferences.self, from: JSONSerialization.data(withJSONObject: legacy))
        precondition(migrated.language == "de" && migrated.modelPath == "/example/model.gguf")
        precondition(migrated.allowedLanguages == nil && LanguagePolicy.allowed(requested: "auto", selection: migrated.allowedLanguages) == ["de", "en"])
        precondition(migrated.muteOutput ?? true && migrated.soundVolume ?? 1 == 1)
        var configured = migrated
        configured.muteOutput = false; configured.soundVolume = 0.35; configured.allowedLanguages = ["fr", "en"]
        let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(configured))
        precondition(restored == configured)
        // First-run completion requires successful model loading, not merely a saved path.
        precondition(!SetupPolicy.ready(microphone: true, accessibility: true, automaticInsertion: true, modifierShortcut: false, modelPath: "/model", validatedModelPath: nil))
        precondition(!SetupPolicy.ready(microphone: true, accessibility: true, automaticInsertion: true, modifierShortcut: false, modelPath: "/new", validatedModelPath: "/old"))
        precondition(!SetupPolicy.ready(microphone: false, accessibility: true, automaticInsertion: true, modifierShortcut: false, modelPath: "/model", validatedModelPath: "/model"))
        precondition(!SetupPolicy.ready(microphone: true, accessibility: false, automaticInsertion: true, modifierShortcut: false, modelPath: "/model", validatedModelPath: "/model"))
        precondition(!SetupPolicy.ready(microphone: true, accessibility: false, automaticInsertion: false, modifierShortcut: true, modelPath: "/model", validatedModelPath: "/model"))
        precondition(SetupPolicy.ready(microphone: true, accessibility: false, automaticInsertion: false, modifierShortcut: false, modelPath: "/model", validatedModelPath: "/model"))
        precondition(SetupPolicy.ready(microphone: true, accessibility: true, automaticInsertion: true, modifierShortcut: true, modelPath: "/model", validatedModelPath: "/model"))
        precondition(SetupPolicy.recognitionLanguage(current: "auto", supported: ["en", "de"], automatic: false, preferred: "fr-FR") == "en")
        precondition(SetupPolicy.recognitionLanguage(current: "auto", supported: ["fr", "en"], automatic: false, preferred: "fr-FR") == "fr")
        precondition(SetupPolicy.recognitionLanguage(current: "de", supported: ["en-US", "de-DE"], automatic: true, preferred: "en-US") == "de")
        precondition(SetupPolicy.recognitionLanguage(current: "ja", supported: ["de", "en"], automatic: true, preferred: "de") == "auto")
        precondition(SetupPolicy.recognitionLanguage(current: "auto", supported: ["fr"], automatic: false, preferred: "en") == "fr")
        print("Release settings passed: neutral defaults, legacy preservation, sound/mute persistence, setup permission/model gating, and model-language switching.")
    }
}
