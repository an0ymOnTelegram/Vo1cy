import XCTest
@testable import VoiceCore

final class CoreTests: XCTestCase {
    func testGermanNumbersAndNegationRemainUnchanged() {
        let text = "Nicht am 12.10., sondern um 14:30 Uhr. Betrag: 245,90 €."
        XCTAssertEqual(TextRules.apply(text, language: "de", fillers: true, dictionary: []), text)
    }
    func testGermanUmIsNotAnEnglishFiller() {
        XCTAssertEqual(TextRules.apply("ähm bitte um 14 Uhr", language: "de", fillers: true, dictionary: []), "bitte um 14 Uhr")
    }
    func testDictionaryIsLiteralAndWholeWord() {
        XCTAssertEqual(TextRules.apply("codex und codexical", language: "de", fillers: false, dictionary: [.init(heard: "codex", written: "$Codex")]), "$Codex und codexical")
    }
    func testCancellationRejectsLateResult() {
        var state = RunGeneration(); let first = state.next(); state.next()
        XCTAssertFalse(state.accepts(first)); XCTAssertTrue(state.accepts(state.value))
    }
    func testRetentionHonorsBothAgeAndCount() {
        let now = Date(); var old = HistoryEntry(text: "old", raw: "old", model: "", language: "de", duration: 1, computeMS: 1)
        old.date = now.addingTimeInterval(-40 * 86400)
        let fresh = HistoryEntry(text: "new", raw: "new", model: "", language: "de", duration: 1, computeMS: 1)
        XCTAssertEqual(Retention.retained([old, fresh], limit: 1, days: 30, now: now).map(\.text), ["new"])
        XCTAssertTrue(Retention.retained([fresh], limit: 0, days: 30).isEmpty)
    }
    func testPreferencesRoundTrip() throws {
        var settings = Preferences(); settings.language = "en"; settings.warmMicrophone = true
        let data = try JSONEncoder().encode(settings)
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: data), settings)
    }
}
