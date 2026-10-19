import Foundation

final class FakeOutput: OutputMuteBackend {
    var values: [String: Float] = ["speaker": 0, "usb": 0.7]
    var absent = Set<String>()
    var failMute = false
    var failRestore = false
    var writes = 0
    var beforeWrite: (() -> Void)?
    func controls() throws -> [OutputMuteControl] {
        values.keys.sorted().filter { !absent.contains($0) }.map {
            OutputMuteControl(uid: $0, selector: $0 == "speaker" ? 1 : 2, channel: 0, original: values[$0]!, silent: $0 == "speaker" ? 1 : 0)
        }
    }
    func write(_ c: OutputMuteControl, value: Float) throws {
        beforeWrite?()
        if absent.contains(c.uid) || (failMute && c.uid == "usb" && value == c.silent) || (failRestore && value != c.silent) {
            throw OutputMuteError(message: "test failure")
        }
        values[c.uid] = value; writes += 1
    }
}

@main struct Checks {
    static func main() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("vo1cy-mute-checks-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var count = 0
        func check(_ condition: Bool, _ message: String) { precondition(condition, message); count += 1 }
        func fixture(_ name: String) -> (FakeOutput, OutputMuteSession, URL) {
            let b = FakeOutput(), path = dir.appendingPathComponent(name + ".json")
            return (b, OutputMuteSession(backend: b, journal: path), path)
        }
        do {
            let (b, s, path) = fixture("basic")
            b.beforeWrite = { precondition(FileManager.default.fileExists(atPath: path.path), "persist before mutation") }
            try s.begin()
            check(b.values == ["speaker": 1, "usb": 0], "mute all outputs")
            check(s.active, "active")
            let writes = b.writes
            try s.begin(); try s.refresh()
            check(b.writes == writes, "repeat begin and notifications do not loop")
            b.values["speaker"] = 0; try s.refresh()
            check(b.values["speaker"] == 1, "volume key unmute suppressed")
            s.restore()
            check(b.values == ["speaker": 0, "usb": 0.7], "exact prior mute and volume")
            check(!s.active && !FileManager.default.fileExists(atPath: path.path), "journal cleared")
            s.restore(); check(b.values["usb"] == 0.7, "restore idempotent")
        }
        do {
            let (b, s, _) = fixture("premuted"); b.values["speaker"] = 1
            try s.begin(); b.values["speaker"] = 0; try s.refresh(); s.restore()
            check(b.values["speaker"] == 1, "previously muted stays muted")
        }
        do {
            let (b, s, _) = fixture("rollback"); b.failMute = true
            do { try s.begin(); preconditionFailure("expected failure") } catch {}
            check(!s.active && b.values == ["speaker": 0, "usb": 0.7], "partial failure rollback")
        }
        do {
            let (b, s, path) = fixture("crash"); try s.begin()
            let recovered = OutputMuteSession(backend: b, journal: path); recovered.restore()
            check(b.values == ["speaker": 0, "usb": 0.7], "restart recovers without device IDs")
        }
        do {
            let (b, s, path) = fixture("disconnect"); try s.begin(); b.absent.insert("usb"); s.restore()
            check(s.pending.count == 1 && FileManager.default.fileExists(atPath: path.path), "disconnected output retained")
            b.absent.remove("usb"); s.restore()
            check(b.values["usb"] == 0.7 && s.pending.isEmpty, "reconnected output restored")
        }
        do {
            let (b, s, _) = fixture("newdevice"); try s.begin(); b.values["headphones"] = 0.43; try s.refresh()
            check(b.values["headphones"] == 0, "new device muted")
            s.restore(); check(b.values["headphones"] == 0.43, "new device restored")
        }
        do {
            let (b, s, _) = fixture("restorefail"); try s.begin(); b.failRestore = true; s.restore()
            check(!s.pending.isEmpty, "failed restore retains journal")
            b.failRestore = false; s.restore(); check(s.pending.isEmpty, "restore retry")
        }
        do {
            let (b, s, _) = fixture("reconnectActive"); try s.begin(); b.absent.insert("usb"); try s.refresh()
            b.absent.remove("usb"); try s.refresh(); s.restore()
            check(b.values["usb"] == 0.7, "reconnect during recording retains original")
        }
        do {
            let path = dir.appendingPathComponent("corrupt.json"); try Data("invalid".utf8).write(to: path)
            let b = FakeOutput(), s = OutputMuteSession(backend: b, journal: path)
            do { try s.begin(); preconditionFailure("expected failure") } catch {}
            check(b.writes == 0, "corrupt recovery state prevents mutation")
        }
        do {
            let blocked = dir.appendingPathComponent("file"); try Data().write(to: blocked)
            let b = FakeOutput(), s = OutputMuteSession(backend: b, journal: blocked.appendingPathComponent("state.json"))
            do { try s.begin(); preconditionFailure("expected failure") } catch {}
            check(b.writes == 0, "journal write failure prevents mute")
        }
        print("\(count) output mute checks passed")
    }
}
