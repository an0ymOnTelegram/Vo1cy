import AppKit
import AVFoundation

/// Custom sounds are local preferences and are never included in release packages.
@MainActor
final class InteractionSounds {
    private var startPlayer: AVAudioPlayer?
    private var stopPlayer: AVAudioPlayer?
    private var enabled = false
    private var volume: Float = 1
    private let directory: URL
    private var startSoundFile: URL { directory.appendingPathComponent("start.wav") }
    private var soundFile: URL { directory.appendingPathComponent("stop.wav") }

    init(root: URL) { directory = root.appendingPathComponent("SoundEffects", isDirectory: true) }

    func configure(enabled: Bool, volume: Double) {
        self.volume = Float(min(1, max(0, volume.isFinite ? volume : 1)))
        startPlayer?.volume = self.volume
        stopPlayer?.volume = self.volume
        guard self.enabled != enabled else { return }
        self.enabled = enabled
        if enabled { reload() }
        else { silence(); startPlayer = nil; stopPlayer = nil }
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
        startPlayer?.stop(); startPlayer = nil
        stopPlayer?.stop(); stopPlayer = nil
        guard enabled else { return }
        // Preserve local start cues from previous versions. Limit their length
        // so output muting never cuts the cue off or waits on a long audio file.
        let customStart: AVAudioPlayer? = {
            guard let size = try? startSoundFile.resourceValues(forKeys: [.fileSizeKey]).fileSize,
                  size > 0, size <= 10_000_000,
                  let data = try? Data(contentsOf: startSoundFile),
                  let player = try? AVAudioPlayer(data: data),
                  player.duration > 0, player.duration <= 0.2 else { return nil }
            return player
        }()
        if let player = customStart ?? (try? AVAudioPlayer(data: Self.startTone())) {
            player.volume = volume
            if player.prepareToPlay() { startPlayer = player }
        }
        guard let data = try? Data(contentsOf: soundFile), let player = try? AVAudioPlayer(data: data),
              player.duration > 0, player.duration <= 2 else { return }
        player.volume = volume
        if player.prepareToPlay() { stopPlayer = player }
    }

    func silence() {
        startPlayer?.stop()
        stopPlayer?.stop()
        NSSound(named: "Tink")?.stop(); NSSound(named: "Pop")?.stop()
    }

    /// Return a bounded cue duration only when playback actually starts.
    func start() -> TimeInterval {
        guard enabled, volume > 0, let startPlayer else { return 0 }
        startPlayer.currentTime = 0
        return startPlayer.play() ? startPlayer.duration + 0.015 : 0
    }

    /// A tiny original 50 ms cue, generated once when sounds are enabled.
    /// No microphone, bundled third-party sound, or background audio engine.
    private static func startTone() -> Data {
        let rate = 24_000
        let frames = 1_200
        var data = Data()
        func word<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8); word(UInt32(36 + frames * 2))
        data.append(contentsOf: "WAVEfmt ".utf8); word(UInt32(16))
        word(UInt16(1)); word(UInt16(1)); word(UInt32(rate)); word(UInt32(rate * 2))
        word(UInt16(2)); word(UInt16(16))
        data.append(contentsOf: "data".utf8); word(UInt32(frames * 2))
        for index in 0..<frames {
            let t = Double(index) / Double(rate)
            let envelope = pow(sin(.pi * Double(index) / Double(frames - 1)), 2)
            let phase = 2 * Double.pi * (880 * t + 4400 * t * t)
            word(Int16(0.22 * 32767 * envelope * sin(phase)))
        }
        return data
    }

    func stop() {
        guard enabled else { return }
        if let stopPlayer { stopPlayer.currentTime = 0; if stopPlayer.play() { return } }
        if let sound = NSSound(named: "Pop") { sound.volume = volume; sound.play() }
    }
}
