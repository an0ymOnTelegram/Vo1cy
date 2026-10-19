import Foundation
@main enum CleanupChecks {
 static func main() throws {
  var count = 0
  func check(_ raw: String, _ expected: String, language: String = "auto", fillers: Bool = true, restarts: Bool = true, spellings: Bool = true) {
   let actual = TextRules.apply(raw, language: language, fillers: fillers, dictionary: [], punctuation: true, sentences: true, lists: true, restarts: restarts, spellings: spellings)
   precondition(actual == expected, "Input: \(raw)\nExpected: \(expected)\nActual: \(actual)")
   let repeated = TextRules.apply(actual, language: language, fillers: fillers, dictionary: [], punctuation: true, sentences: true, lists: true, restarts: restarts, spellings: spellings)
   precondition(repeated == actual, "Not idempotent: \(actual)")
   count += 1
  }
  check("Ähm. Die Einstellungen.", "Die Einstellungen.")
  check("Ich möchte das. Ähm. Danach habe ich Zeit.", "Ich möchte das. Danach habe ich Zeit.")
  check("Ähm. Ähm.", "")
  check("Deswegen soll es die Option geben, ähm.", "Deswegen soll es die Option geben.")
  check("Option geben, ähm!", "Option geben!")
  check("die nicht ähm die nicht verschwinden", "Die nicht verschwinden")
  check("die nicht ähm die nicht äh die nicht", "Die nicht")
  check("von der äh von der Firma", "Von der Firma")
  check("in den ähm in den Notizen", "In den Notizen")
  check("I want um I want this", "I want this.")
  check("ganz ganz wichtig", "Ganz ganz wichtig")
  check("richtig äh richtig", "Richtig richtig")
  check("fünf äh fünf Euro", "Fünf fünf Euro")
  check("die die Regeln prüfen", "Die die Regeln prüfen")
  check("nicht äh doch", "Nicht doch")
  check("Ich habe um vierzehn Uhr Zeit", "Ich habe um vierzehn Uhr Zeit.")
  check("U S B Angebote und K I Chat", "USB Angebote und KI Chat")
  check("E Mail und U S B", "E-Mail und USB")
  check("U S Bideo und K Igel", "U S Bideo und K Igel")
  check("Kannst du alle Nachrichten, die du heute rausgeschickt hast verbessern.", "Kannst du alle Nachrichten, die du heute rausgeschickt hast verbessern?")
  check("Kannst du das nicht verbessern, dann mache ich es.", "Kannst du das nicht verbessern, dann mache ich es.")
  check("Kannst du heute nicht, komme ich morgen.", "Kannst du heute nicht, komme ich morgen.")
  check("I need this. Uh. We have time.", "I need this. We have time.")
  check("`ähm. U S B flowwer`", "`ähm. U S B flowwer`")
  check("\"die nicht ähm die nicht\"", "\"die nicht ähm die nicht\"")
  check("https://example.com/ähm und user@example.com", "https://example.com/ähm und user@example.com")
  check("Die Zahl ist 1.5 und nicht 15. Version 1.2.3.", "Die Zahl ist 1.5 und nicht 15. Version 1.2.3.")
  check("die nicht ähm die nicht", "Die nicht die nicht", restarts: false)
  check("U S B", "U S B", spellings: false)
  check("ähm", "Ähm", fillers: false)
  check("bonjour", "bonjour", language: "fr")
  var rule = Replacement(heard: "flowwer", written: "Flower"); rule.protectLiterals = true
  precondition(CorrectionRules.apply([rule], to: "flowwer, flowwerlike, `flowwer`, \"flowwer\", https://x.com/flowwer") == "Flower, flowwerlike, `flowwer`, \"flowwer\", https://x.com/flowwer")
  let edited = CorrectionRules.saving(Replacement(heard: "flowwer", written: "Flower"), in: [rule])
  precondition(edited.first?.protectLiterals == true, "Editing a protected rule lost its protection")
  rule.written = "Flowers"
  precondition(CorrectionRules.apply([rule], to: "flowwer") == "Flowers", "Cache stale after edit")
  precondition(CorrectionRules.apply([], to: "flowwer") == "flowwer", "Cache stale after removal")
  let literal = TextRules.apply("alias", language: "auto", fillers: true, dictionary: [Replacement(heard: "alias", written: "ähm U S B")], punctuation: true, sentences: true, lists: true, restarts: true, spellings: true)
  precondition(literal == "ähm U S B", "User correction must run last")
  let data = try JSONEncoder().encode(rule)
  let saved = try JSONDecoder().decode(Replacement.self, from: data)
  precondition(saved.protectLiterals == true)
  let legacy = try JSONDecoder().decode(Replacement.self, from: JSONSerialization.data(withJSONObject: ["id": UUID().uuidString,"heard":"x","written":"y"]))
  precondition(legacy.protectLiterals == nil)
  var preferences = Preferences(); preferences.cleanRestarts = false; preferences.normalizeSpellings = false
  let restored = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(preferences))
  precondition(restored == preferences)
  print("\(count) cleanup/idempotence cases passed; literal protection, cache invalidation, dictionary order and persistence passed.")
 }
}
