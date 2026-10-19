import AppKit
import AVFoundation

/// Custom sounds are local preferences and are never included in release packages.
@MainActor
final class InteractionSounds {
    private var stopPlayer: AVAudioPlayer?
    private var enabled = false
    private var volume: Float = 1
    private let directory: URL
    private var soundFile: URL { directory.appendingPathComponent("stop.wav") }

    init(root: URL) { directory = root.appendingPathComponent("SoundEffects", isDirectory: true) }

    func configure(enabled: Bool, volume: Double) {
        self.volume = Float(min(1, max(0, volume.isFinite ? volume : 1)))
        stopPlayer?.volume = self.volume
        guard self.enabled != enabled else { return }
        self.enabled = enabled
        if enabled { reload() }
        else { stopPlayer?.stop(); stopPlayer = nil }
    }

    func importStopSound(_ url: URL) throws {
        let size = try url.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
        guard size > 0, size <= 10_000_000 else { throw invalidSound() }
        let data = try Data(contentsOf: url)
        let candidate = try AVAudioPlayer(data: data)
        guard candidate.duration > 0, candidate.duration <= 2 else { throw invalidSound() }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: soundFile, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: soundFile.path)
        reload()
    }

    func reset() throws {
        if FileManager.default.fileExists(atPath: soundFile.path) { try FileManager.default.removeItem(at: soundFile) }
        reload()
    }

    private func invalidSound() -> NSError {
        NSError(domain: "Vo1cy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Choose an audio file up to 2 seconds and 10 MB."])
    }

    private func reload() {
        stopPlayer?.stop(); stopPlayer = nil
        guard enabled, let data = try? Data(contentsOf: soundFile), let player = try? AVAudioPlayer(data: data),
              player.duration > 0, player.duration <= 2 else { return }
        player.volume = volume
        if player.prepareToPlay() { stopPlayer = player }
    }

    func silence() {
        stopPlayer?.stop()
        NSSound(named: "Tink")?.stop(); NSSound(named: "Pop")?.stop()
    }

    func stop() {
        guard enabled else { return }
        if let stopPlayer { stopPlayer.currentTime = 0; if stopPlayer.play() { return } }
        if let sound = NSSound(named: "Pop") { sound.volume = volume; sound.play() }
    }
}
