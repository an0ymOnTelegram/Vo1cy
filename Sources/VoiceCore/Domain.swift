import Foundation

public struct Preferences: Codable, Equatable {
    public var language = "auto"
    public var allowedLanguages: [String]? // nil: DE/EN; []: explicitly unrestricted
    public var translate = false
    public var modelPath = ""
    public var keepModelLoaded = true
    public var warmMicrophone = false
    public var deviceID: UInt32 = 0
    public var removeFillers = false
    public var cleanRestarts: Bool?
    public var normalizeSpellings: Bool?
    public var formatSentences: Bool? // nil enables local sentence formatting
    public var formatLists: Bool? // nil enables explicit spoken-list formatting
    public var cleanPunctuation: Bool? // nil enables cleanup for older preferences
    public var dictionary: [Replacement] = []
    public var historyLimit = 100
    public var retentionDays = 30
    public var saveAudio = false
    public var pasteAutomatically = true
    public var pasteDelayMS = 80
    public var restoreDelayMS = 300
    public var trailingSpace = false
    public var playSounds = false
    public var muteOutput: Bool? // nil preserves output muting in older installations
    public var soundVolume: Double? // nil preserves the original cue volume
    public var showOverlay = true
    // Optional so existing preferences decode without migration.
    public var overlayPosition: String?
    public var shortcutCode: UInt32 = 49
    public var shortcutModifiers: UInt32 = 2304 // command + option (Carbon)
    public var shortcutLabel = "⌥ ⌘ Space"
    public var shortcutMode = "hold"
    public var theme = "dark"
    public var onboardingComplete = false
    public var useCPU = false
    public init() { allowedLanguages = [] }
}

public struct Replacement: Codable, Identifiable, Equatable {
    public var id = UUID()
    public var heard: String
    public var written: String
    // Optional so dictionaries from earlier builds decode without migration.
    public var wholeUtterance: Bool?
    public var protectLiterals: Bool?
    public init(heard: String, written: String, wholeUtterance: Bool? = nil) {
        self.heard = heard; self.written = written; self.wholeUtterance = wholeUtterance
    }
}

public struct HistoryEntry: Codable, Identifiable {
    public var id = UUID()
    public var date = Date()
    public var text: String
    public var raw: String
    public var model: String
    public var language: String
    public var duration: Double
    public var computeMS: Double
    public var audioFile: String?
    public var languageWarning: String? // A flagged result is retained, never auto-pasted.
    public init(text: String, raw: String, model: String, language: String, duration: Double, computeMS: Double, audioFile: String? = nil) {
        self.text = text; self.raw = raw; self.model = model; self.language = language
        self.duration = duration; self.computeMS = computeMS; self.audioFile = audioFile
    }
}

public enum TextRules {
    /// A single detected locale cannot describe a code-switched dictation.
    public static func formattingLanguage(requested: String, detected: String) -> String {
        if requested == "auto" { return "auto" }
        return detected.isEmpty ? requested : detected
    }

    public static func apply(_ input: String, language: String, fillers: Bool, dictionary: [Replacement], punctuation: Bool = false, sentences: Bool = false, lists: Bool = false, restarts: Bool = false, spellings: Bool = false) -> String {
        var result = input.trimmingCharacters(in: .whitespacesAndNewlines)
        result = SpeechCleanup.apply(result, language: language, fillers: fillers, restarts: restarts, spellings: spellings)
        if punctuation { result = PunctuationRules.apply(result, language: language) }
        result = DictationFormatter.apply(result, language: language, sentences: sentences, lists: lists)
        result = CorrectionRules.apply(dictionary, to: result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

public enum Retention {
    public static func retained(_ entries: [HistoryEntry], limit: Int, days: Int, now: Date = Date()) -> [HistoryEntry] {
        let cutoff = days > 0 ? now.addingTimeInterval(-Double(days) * 86400) : Date.distantPast
        return Array(entries.filter { $0.date >= cutoff }.sorted { $0.date > $1.date }.prefix(max(0, limit)))
    }
}

/// A generation token prevents delayed model results from a cancelled run being pasted.
public struct RunGeneration {
    public private(set) var value: UInt64 = 0
    public init() {}
    @discardableResult public mutating func next() -> UInt64 { value &+= 1; return value }
    public func accepts(_ candidate: UInt64) -> Bool { candidate == value }
}

public enum Persistence {
    public static func save<T: Encodable>(_ value: T, to url: URL) throws {
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try encoder.encode(value).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
    public static func load<T: Decodable>(_ type: T.Type, from url: URL) throws -> T { try JSONDecoder().decode(type, from: Data(contentsOf: url)) }
}
