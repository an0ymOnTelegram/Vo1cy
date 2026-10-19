import Foundation

public enum SetupPolicy {
    public static func ready(microphone: Bool, accessibility: Bool, automaticInsertion: Bool, modifierShortcut: Bool, modelPath: String, validatedModelPath: String?) -> Bool {
        microphone && !modelPath.isEmpty && modelPath == validatedModelPath
            && (!(automaticInsertion || modifierShortcut) || accessibility)
    }

    public static func recognitionLanguage(current: String, supported: [String], automatic: Bool, preferred: String) -> String {
        let languages = Set(supported.map(LanguagePolicy.base))
        if current == "auto", automatic { return current }
        if current != "auto", languages.contains(LanguagePolicy.base(current)) { return LanguagePolicy.base(current) }
        if automatic { return "auto" }
        let system = LanguagePolicy.base(preferred)
        return languages.contains(system) ? system : (languages.contains("en") ? "en" : languages.sorted().first ?? "en")
    }
}
