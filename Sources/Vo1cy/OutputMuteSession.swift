import Foundation

struct OutputMuteControl: Codable, Equatable {
    let uid: String
    let selector: UInt32
    let channel: UInt32
    let original: Float
    let silent: Float
    var key: String { "\(uid)|\(selector)|\(channel)" }
}

protocol OutputMuteBackend {
    /// Enumerate all controllable outputs, requiring the active media/alert routes.
    func controls() throws -> [OutputMuteControl]
    /// Resolve by persistent UID, never by a possibly recycled device ID.
    func write(_ control: OutputMuteControl, value: Float) throws
}

struct OutputMuteError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Main-thread owned. Journal is written before touching hardware, so the next
/// launch can restore audio after a crash. Missing devices remain in the journal.
final class OutputMuteSession {
    private let backend: OutputMuteBackend
    private let journal: URL
    private(set) var active = false
    private(set) var pending: [OutputMuteControl] = []
    private var journalReadable = true

    init(backend: OutputMuteBackend, journal: URL) {
        self.backend = backend; self.journal = journal
        if FileManager.default.fileExists(atPath: journal.path) {
            do { pending = try JSONDecoder().decode([OutputMuteControl].self, from: Data(contentsOf: journal)) }
            catch { journalReadable = false }
        }
    }

    func begin() throws {
        guard !active else { return }
        guard journalReadable else { throw OutputMuteError(message: "The saved audio state could not be read. Check the audio output.") }
        restore()
        active = true
        do { try refresh() }
        catch { restore(); throw error }
    }

    func refresh() throws {
        guard active else { return }
        let controls = try backend.controls()
        let known = Set(pending.map(\.key))
        let added = controls.filter { !known.contains($0.key) }
        if !added.isEmpty {
            let updated = pending + added
            try persist(updated) // Never mute unless recovery information is durable.
            pending = updated
        }
        // Also reapply after a device reconnect without overwriting its original.
        let changed = Set(controls.filter { $0.original != $0.silent }.map(\.key))
        for control in pending where changed.contains(control.key) {
            try backend.write(control, value: control.silent)
        }
    }

    func restore() {
        active = false
        guard journalReadable else { return }
        var remaining: [OutputMuteControl] = []
        for control in pending {
            do { try backend.write(control, value: control.original) }
            catch { remaining.append(control) }
        }
        // Keep the old journal if persistence fails; replay is idempotent.
        do { try persist(remaining); pending = remaining } catch {}
    }

    private func persist(_ records: [OutputMuteControl]) throws {
        if records.isEmpty {
            if FileManager.default.fileExists(atPath: journal.path) { try FileManager.default.removeItem(at: journal) }
        } else {
            try FileManager.default.createDirectory(at: journal.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(records).write(to: journal, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: journal.path)
        }
    }
}
