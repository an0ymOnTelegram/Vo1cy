import AVFoundation
import CoreAudio

struct InputDevice: Identifiable {
    let id: UInt32
    let name: String
    static func available() -> [InputDevice] {
        var a = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDevices, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.compactMap { id in
            var streams = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyStreams, mScope: kAudioDevicePropertyScopeInput, mElement: kAudioObjectPropertyElementMain)
            var bytes: UInt32 = 0
            guard AudioObjectGetPropertyDataSize(id, &streams, 0, nil, &bytes) == noErr, bytes > 0 else { return nil }
            var nameAddress = AudioObjectPropertyAddress(mSelector: kAudioObjectPropertyName, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            var name: CFString = "Microphone" as CFString; var length = UInt32(MemoryLayout<CFString>.size)
            let status = withUnsafeMutablePointer(to: &name) { AudioObjectGetPropertyData(id, &nameAddress, 0, nil, &length, $0) }
            guard status == noErr else { return nil }
            return InputDevice(id: id, name: name as String)
        }
    }
}

/// The input engine exists only during an explicit recording.
final class AudioCapture {
    private var engine: AVAudioEngine?
    private var converter: AVAudioConverter?
    private let lock = NSLock()
    private var accepting = false
    private var sink: (([Float]) -> Void)?
    private var deviceID: UInt32 = 0
    var onDeviceChange: (() -> Void)?
    private var observer: NSObjectProtocol?

    private func prepare(device: UInt32) throws {
        if engine?.isRunning == true && deviceID == device { return }
        shutdown()
        let e = AVAudioEngine(); let input = e.inputNode
        if device != 0, let unit = input.audioUnit {
            var selected = device
            let status = AudioUnitSetProperty(unit, kAudioOutputUnitProperty_CurrentDevice, kAudioUnitScope_Global, 0, &selected, UInt32(MemoryLayout<UInt32>.size))
            guard status == noErr else { throw EngineFailure(message: "Microphone unavailable (\(status)).") }
        }
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0,
              let target = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: format, to: target) else {
            throw EngineFailure(message: "No usable microphone input.")
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            // Stop waits for an in-flight conversion/delivery before draining.
            self.lock.lock(); defer { self.lock.unlock() }
            guard self.accepting, let callback = self.sink else { return }
            let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 16000 / format.sampleRate) + 64)
            guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else { return }
            var given = false; var error: NSError?
            converter.convert(to: output, error: &error) { _, status in
                if given { status.pointee = .noDataNow; return nil }
                given = true; status.pointee = .haveData; return buffer
            }
            guard error == nil, output.frameLength > 0, let channel = output.floatChannelData?[0] else { return }
            callback(Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength))))
        }
        do { try e.start() } catch { input.removeTap(onBus: 0); throw error }
        engine = e; self.converter = converter; deviceID = device
        observer = NotificationCenter.default.addObserver(forName: .AVAudioEngineConfigurationChange, object: e, queue: .main) { [weak self] _ in self?.onDeviceChange?() }
    }

    func start(device: UInt32, sink: @escaping ([Float]) -> Void) throws {
        try prepare(device: device)
        lock.lock(); converter?.reset(); self.sink = sink; accepting = true; lock.unlock()
    }
    func stop() { shutdown() }
    func shutdown() {
        lock.lock(); accepting = false; sink = nil; lock.unlock()
        if let observer { NotificationCenter.default.removeObserver(observer) }
        observer = nil
        if let engine { engine.stop(); engine.inputNode.removeTap(onBus: 0) }
        engine = nil; converter = nil
    }

    static func readFile(_ url: URL, maxSeconds: Double = 600) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard Double(file.length) / file.processingFormat.sampleRate <= maxSeconds else {
            throw EngineFailure(message: "The audio file is too long (maximum \(Int(maxSeconds)) seconds).")
        }
        guard let input = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)),
              let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: file.processingFormat, to: format) else { throw EngineFailure(message: "Cannot read this audio format.") }
        try file.read(into: input)
        let count = AVAudioFrameCount(ceil(Double(input.frameLength) * 16000 / input.format.sampleRate) + 256)
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count) else { throw EngineFailure(message: "Audio memory allocation failed.") }
        var consumed = false; var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if consumed { status.pointee = .endOfStream; return nil }
            consumed = true; status.pointee = .haveData; return input
        }
        if let error { throw error }
        guard let data = output.floatChannelData?[0] else { return [] }
        return Array(UnsafeBufferPointer(start: data, count: Int(output.frameLength)))
    }

    static func writeWAV(_ samples: [Float], to url: URL) throws {
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count)) else { throw EngineFailure(message: "Audio memory allocation failed.") }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress { buffer.floatChannelData?[0].update(from: base, count: samples.count) }
        }
        let file = try AVAudioFile(forWriting: url, settings: format.settings)
        try file.write(from: buffer)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }
}
