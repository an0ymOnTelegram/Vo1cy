import Foundation

/// The same product rules can be checked with Command Line Tools when XCTest is absent.
@main enum PortableChecks {
    static func main() throws {
        var count = 0
        func verify(_ condition: @autoclosure () -> Bool, _ name: String) {
            guard condition() else { fatalError("FAIL: \(name)") }
            count += 1; print("PASS: \(name)")
        }
        let text = "Nicht am 12.10., sondern um 14:30 Uhr. Betrag: 245,90 €."
        verify(TextRules.apply(text, language: "de", fillers: true, dictionary: []) == text, "Numbers, date and negation preserved")
        verify(TextRules.apply("ähm bitte um 14 Uhr", language: "de", fillers: true, dictionary: []) == "bitte um 14 Uhr", "German um is not a filler")
        verify(TextRules.apply("codex und codexical", language: "de", fillers: false, dictionary: [.init(heard: "codex", written: "$Codex")]) == "$Codex und codexical", "Literal replacement and word boundaries")
        verify(TextRules.apply("This is not 245 euros.", language: "en", fillers: true, dictionary: []) == "This is not 245 euros.", "English numbers and negation preserved")
        var generation = RunGeneration(); let first = generation.next(); generation.next()
        verify(!generation.accepts(first) && generation.accepts(generation.value), "Late results rejected after cancellation")
        var old = HistoryEntry(text: "old", raw: "old", model: "", language: "de", duration: 1, computeMS: 1)
        old.date = Date().addingTimeInterval(-40 * 86400)
        let fresh = HistoryEntry(text: "fresh", raw: "fresh", model: "", language: "de", duration: 1, computeMS: 1)
        verify(Retention.retained([old, fresh], limit: 1, days: 30).map(\.text) == ["fresh"], "Age and count retention")
        verify(Retention.retained([fresh], limit: 0, days: 30).isEmpty, "Disabled history keeps nothing")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("settings.json")
        var settings = Preferences(); settings.language = "en"; settings.warmMicrophone = true
        try Persistence.save(settings, to: url)
        let loaded = try Persistence.load(Preferences.self, from: url)
        verify(loaded == settings, "Preferences persist and reload")
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        verify((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600, "Private preference file permissions")
        try Data("invalid".utf8).write(to: url)
        var rejected = false
        do { _ = try Persistence.load(Preferences.self, from: url) } catch { rejected = true }
        verify(rejected, "Corrupt JSON rejected")
        var latch = ShortcutLatch()
        verify(latch.update(down: true), "First physical press starts once")
        verify(!latch.update(down: true), "Repeated press does not toggle recording twice")
        verify(latch.update(down: false) && !latch.update(down: false), "Release stops once")
        _ = latch.update(down: true); latch.reset()
        verify(!latch.held && !latch.update(down: false), "Interrupted shortcut rejects stale release")
        verify(ShortcutKeys.isDown(61, flags: 0x80040), "Right Option press is recognized")
        verify(!ShortcutKeys.isDown(61, flags: 0x80020), "Releasing right Option while left stays held stops correctly")
        verify(ShortcutKeys.isDown(58, flags: 0x80020), "Left Option remains independent")
        verify(ShortcutKeys.isDown(63, flags: 0x800000) && !ShortcutKeys.isDown(63, flags: 0), "Fn press and release recognized")
        verify(ShortcutKeys.otherModifiersDown(61, flags: 0x80060), "Both sides held count as a chord")
        var capture = ModifierCapture()
        verify(capture.change(code: 61, down: true, othersDown: false) == nil, "Modifier capture waits for release")
        verify(capture.change(code: 61, down: false, othersDown: false) == 61, "Standalone right Option can be assigned")
        capture = ModifierCapture()
        _ = capture.change(code: 58, down: true, othersDown: false)
        _ = capture.change(code: 55, down: true, othersDown: true)
        let firstRelease = capture.change(code: 55, down: false, othersDown: true)
        let lastRelease = capture.change(code: 58, down: false, othersDown: false)
        verify(firstRelease == nil && lastRelease == nil, "A modifier chord is never recorded as one side")
        _ = capture.change(code: 63, down: true, othersDown: false)
        verify(capture.change(code: 63, down: false, othersDown: false) == 63, "Capture recovers after a chord")
        verify(ShortcutKeys.carbonModifiers(flags: 0) == 0 && ShortcutKeys.carbonModifiers(flags: 0x180000) == 2304, "Single keys and existing Option Command chords retain their modifiers")
        verify(ShortcutKeys.label(code: 100, characters: nil) == "F8", "Function keys have readable labels")
        settings.shortcutCode = 61; settings.shortcutModifiers = 0; settings.shortcutLabel = "Rechte ⌥"
        let modifierSettings = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(settings))
        verify(modifierSettings == settings, "Single modifier survives preference round-trip")
        let inbox = CaptureInbox()
        inbox.append([1, 2]); inbox.append([3])
        verify(inbox.finish().flatMap { $0 } == [1, 2, 3], "Release preserves audio whose UI callbacks have not run")
        verify(inbox.drain().isEmpty && inbox.finish().isEmpty, "Late notifications cannot duplicate final audio")
        verify(!inbox.append([4]), "Late producer cannot append to a stopped recording")
        let nextInbox = CaptureInbox(); nextInbox.append([5])
        verify(nextInbox.drain() == [[5]], "New recording is isolated from old callbacks")
        let streamingInbox = CaptureInbox(); streamingInbox.append([1]); let firstChunks = streamingInbox.drain()
        streamingInbox.append([2, 3]); let finalChunks = streamingInbox.finish()
        verify((firstChunks + finalChunks).flatMap { $0 } == [1, 2, 3], "Streaming plus final drain preserves sample order exactly once")
        let delayedInbox = CaptureInbox()
        let group = DispatchGroup(); let producer = DispatchQueue(label: "test.capture")
        group.enter()
        producer.async { for i in 0..<1000 { delayedInbox.append([Float(i)]) }; group.leave() }
        group.wait()
        verify(delayedInbox.finish().flatMap { $0 } == (0..<1000).map(Float.init), "A delayed UI loses no samples from the concurrent producer")
        let phrase = CorrectionRules.suggestion(original: "Super, Gitter", corrected: "Super, geht das")!
        verify(phrase.heard == "Gitter" && phrase.written == "geht das" && phrase.wholeUtterance == false, "Correction suggests only the changed phrase")
        let word = CorrectionRules.suggestion(original: "Gitter.", corrected: "geht das?")!
        verify(word.heard == "Gitter" && word.written == "geht das?" && word.wholeUtterance == true, "Isolated ambiguous word defaults to whole dictation")
        verify(CorrectionRules.suggestion(original: "super", corrected: "super") == nil, "Unchanged text creates no rule")
        verify(CorrectionRules.suggestion(original: "Hallo", corrected: "Hallo Welt") == nil, "Insertion does not create an empty-source rule")
        verify(CorrectionRules.suggestion(original: "Hallo Welt", corrected: "Hallo") == nil, "Deletion does not silently create a deletion rule")
        verify(CorrectionRules.apply([word], to: "GITTER!") == "geht das?", "Whole dictation ignores case and respects corrected punctuation")
        verify(CorrectionRules.apply([Replacement(heard: "Gitter", written: "geht das", wholeUtterance: true)], to: "GITTER!") == "geht das!", "Existing punctuation survives when the correction has none")
        verify(CorrectionRules.apply([word], to: "Das Gitter am Fenster.") == "Das Gitter am Fenster.", "Scoped correction preserves the literal word in sentences")
        verify(CorrectionRules.apply([phrase], to: "Super, Gitter?") == "Super, geht das?", "Reviewed phrase rule works inside a sentence")
        verify(CorrectionRules.apply([phrase], to: "Gitterstäbe") == "Gitterstäbe", "Corrections preserve word boundaries")
        let overlap = [Replacement(heard: "geht", written: "läuft"), Replacement(heard: "geht das", written: "passt es")]
        verify(CorrectionRules.apply(overlap, to: "Geht das heute?") == "passt es heute?", "Longest matching phrase wins")
        let chain = [Replacement(heard: "Gitter", written: "geht das"), Replacement(heard: "geht das", written: "anders")]
        verify(CorrectionRules.apply(chain, to: "Gitter und geht das") == "geht das und anders", "Replacements never cascade")
        verify(CorrectionRules.apply([Replacement(heard: "mein name", written: "$Name\\Test")], to: "Mein\nName") == "$Name\\Test", "Whitespace variants match and replacement syntax stays literal")
        let revised = CorrectionRules.saving(Replacement(heard: " gitter ", written: "funktioniert es", wholeUtterance: true), in: [word])
        verify(revised.count == 1 && revised[0].id == word.id && revised[0].written == "funktioniert es", "Saving an existing rule updates it instead of duplicating")
        verify(CorrectionRules.saving(phrase, in: [word]).count == 2, "Whole-dictation and phrase scopes remain independent")
        let legacyData = Data("{\"id\":\"00000000-0000-0000-0000-000000000001\",\"heard\":\"Gitter\",\"written\":\"geht das\"}".utf8)
        let legacyRule = try JSONDecoder().decode(Replacement.self, from: legacyData)
        verify(legacyRule.wholeUtterance == nil && CorrectionRules.apply([legacyRule], to: "Super Gitter") == "Super geht das", "Legacy dictionary decodes with existing word scope")
        settings.dictionary = [word, phrase]
        try Persistence.save(settings, to: url)
        let correctionSettings = try Persistence.load(Preferences.self, from: url)
        verify(correctionSettings == settings, "Correction scopes survive settings save and reload")
        var correctedEntry = fresh; correctedEntry.text = "corrected"
        let historyURL = directory.appendingPathComponent("history.json")
        try Persistence.save([correctedEntry], to: historyURL)
        let restoredHistory = try Persistence.load([HistoryEntry].self, from: historyURL)
        verify(restoredHistory[0].text == "corrected" && restoredHistory[0].raw == fresh.raw && restoredHistory[0].id == fresh.id, "Corrected history preserves raw recognition and identity")
        print("\(count) portable checks passed")
    }
}
