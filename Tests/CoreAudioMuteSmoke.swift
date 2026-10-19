import AppKit
import CoreAudio

/// Explicit live hardware check. Briefly mutes output and restores every value.
@main struct CoreAudioMuteSmoke {
    @MainActor static func main() throws {
        guard CommandLine.arguments.contains("--live") else {
            print("Pass --live to briefly mute the actual Mac output."); return
        }
        let backend = CoreAudioMuteBackend()
        let before = try backend.controls()
        guard !before.isEmpty else { throw OutputMuteError(message: "No controllable output") }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("vo1cy-live-mute-" + UUID().uuidString)
        let controller = SystemOutputMute(root: root)
        var callbackError: Error?
        controller.onFailure = { callbackError = $0 }
        defer {
            controller.shutdown()
            for c in before { try? backend.write(c, value: c.original) }
            try? FileManager.default.removeItem(at: root)
        }
        func pump() { RunLoop.main.run(until: Date().addingTimeInterval(0.15)) }
        func require(_ value: Bool, _ label: String) throws {
            guard value else { throw OutputMuteError(message: label) }
        }
        func matchesOriginal() throws -> Bool {
            let current = Dictionary(uniqueKeysWithValues: try backend.controls().map { ($0.key, $0.original) })
            return before.allSatisfy { abs((current[$0.key] ?? -10) - $0.original) < 0.0001 }
        }
        let start = DispatchTime.now().uptimeNanoseconds
        try controller.begin()
        let muteMS = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e6
        pump()
        try require(try backend.controls().allSatisfy { $0.original == $0.silent }, "Output not muted")
        if let audible = before.first(where: { $0.original != $0.silent }) {
            try backend.write(audible, value: audible.original)
            pump()
            try require(try backend.controls().allSatisfy { $0.original == $0.silent }, "Unmute was not suppressed during capture")
        }
        controller.restore(); pump()
        try require(try matchesOriginal(), "Original output values not restored")
        try controller.begin(); pump(); controller.shutdown(); pump()
        try require(try matchesOriginal(), "Shutdown did not restore output")
        try require(callbackError == nil, "CoreAudio listener error")
        try require(!FileManager.default.fileExists(atPath: root.appendingPathComponent("audio-output-restore.json").path), "Restore journal not cleared")
        print("Live CoreAudio passed: \(before.count) controls muted; unmute suppressed; stop and shutdown restored original state; begin \(String(format: "%.2f", muteMS)) ms.")
    }
}
