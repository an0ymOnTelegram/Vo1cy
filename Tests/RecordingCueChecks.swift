import Foundation

@MainActor final class CueDelayGate {
    var pending: [(UInt64, CheckedContinuation<Void, Never>)] = []
    func wait(_ nanoseconds: UInt64) async {
        // Deliberately ignore task cancellation: the generation check must still
        // reject a late completion after release or a subsequent recording.
        await withCheckedContinuation { pending.append((nanoseconds, $0)) }
    }
    func ready(_ count: Int) async throws {
        for _ in 0..<1000 {
            if pending.count >= count { return }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        preconditionFailure("Cue delay did not start")
    }
}

@main enum RecordingCueChecks {
    @MainActor static func main() async throws {
        let gate = CueDelayGate()
        let cue = RecordingCue(wait: { await gate.wait($0) })
        var muted = 0; var failed = 0
        let mute = { muted += 1 }
        let failure: (Error) -> Void = { _ in failed += 1 }
        cue.schedule(after: 0, action: mute, onFailure: failure)
        precondition(muted == 1, "Disabled sounds must mute immediately")
        muted = 0
        cue.schedule(after: 0.065, action: mute, onFailure: failure)
        try await gate.ready(1)
        precondition(muted == 0, "Output must remain audible during the cue")
        cue.cancel()
        gate.pending[0].1.resume()
        try await Task.sleep(nanoseconds: 5_000_000)
        precondition(muted == 0, "Release must prevent late muting")
        cue.schedule(after: 0.065, action: mute, onFailure: failure)
        try await gate.ready(2)
        cue.schedule(after: 0.065, action: mute, onFailure: failure)
        try await gate.ready(3)
        gate.pending[1].1.resume()
        try await Task.sleep(nanoseconds: 5_000_000)
        precondition(muted == 0, "An old cue must not mute a new recording")
        gate.pending[2].1.resume()
        try await Task.sleep(nanoseconds: 5_000_000)
        precondition(muted == 1 && failed == 0)
        struct MuteFailure: Error {}
        cue.schedule(after: 0.065, action: { throw MuteFailure() }, onFailure: failure)
        try await gate.ready(4)
        gate.pending[3].1.resume()
        try await Task.sleep(nanoseconds: 5_000_000)
        precondition(failed == 1, "Mute failure must cancel/report through the caller")
        cue.cancel()
        print("PASS: start cue ordering, immediate mute without sound, quick release, replaced recording, and mute failure")
    }
}
