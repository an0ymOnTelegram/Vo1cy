import AppKit
import CoreAudio

struct CoreAudioMuteBackend: OutputMuteBackend {
    private func address(_ selector: UInt32, channel: UInt32 = 0, scope: UInt32 = kAudioDevicePropertyScopeOutput) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: channel)
    }

    private func devices() -> [AudioDeviceID] {
        var a = address(kAudioHardwarePropertyDevices, scope: kAudioObjectPropertyScopeGlobal)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard !ids.isEmpty, AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &ids) == noErr else { return [] }
        return ids
    }

    private func uid(_ id: AudioDeviceID) -> String? {
        var a = address(kAudioDevicePropertyDeviceUID, scope: kAudioObjectPropertyScopeGlobal)
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(id, &a, 0, nil, &size, $0)
        }
        return status == noErr ? value as String : nil
    }

    private func channelCount(_ id: AudioDeviceID) -> UInt32 {
        var a = address(kAudioDevicePropertyStreamConfiguration)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &a, 0, nil, &size) == noErr, size >= MemoryLayout<AudioBufferList>.size else { return 0 }
        let memory = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { memory.deallocate() }
        guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, memory) == noErr else { return 0 }
        return UnsafeMutableAudioBufferListPointer(memory.assumingMemoryBound(to: AudioBufferList.self)).reduce(0) { $0 + $1.mNumberChannels }
    }

    private func control(_ id: AudioDeviceID, uid: String, selector: UInt32, channel: UInt32) -> OutputMuteControl? {
        var a = address(selector, channel: channel)
        var settable: DarwinBoolean = false
        guard AudioObjectHasProperty(id, &a), AudioObjectIsPropertySettable(id, &a, &settable) == noErr, settable.boolValue else { return nil }
        var size: UInt32 = 4
        let value: Float
        if selector == kAudioDevicePropertyMute {
            var mute: UInt32 = 0
            guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &mute) == noErr else { return nil }
            value = mute == 0 ? 0 : 1
        } else {
            var volume: Float = 0
            guard AudioObjectGetPropertyData(id, &a, 0, nil, &size, &volume) == noErr, volume.isFinite, (0...1).contains(volume) else { return nil }
            value = volume
        }
        return OutputMuteControl(uid: uid, selector: selector, channel: channel, original: value, silent: selector == kAudioDevicePropertyMute ? 1 : 0)
    }

    func controls() throws -> [OutputMuteControl] {
        var required = Set<AudioDeviceID>()
        for selector in [kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDefaultSystemOutputDevice] {
            var a = address(selector, scope: kAudioObjectPropertyScopeGlobal)
            var id: AudioDeviceID = 0; var size: UInt32 = 4
            guard AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &a, 0, nil, &size, &id) == noErr else {
                throw OutputMuteError(message: "Could not identify the Mac audio output.")
            }
            if id != 0 { required.insert(id) }
        }
        var result: [OutputMuteControl] = []
        var covered = Set<AudioDeviceID>()
        for id in devices() {
            let count = channelCount(id)
            guard count > 0, let uid = uid(id) else { continue }
            var selected: [OutputMuteControl] = []
            // Prefer master mute, then master volume, then every output channel.
            for selector in [kAudioDevicePropertyMute, kAudioDevicePropertyVolumeScalar] {
                if let c = control(id, uid: uid, selector: selector, channel: 0) { selected = [c]; break }
            }
            if selected.isEmpty {
                for channel in 1...count {
                    if let c = control(id, uid: uid, selector: kAudioDevicePropertyMute, channel: channel)
                        ?? control(id, uid: uid, selector: kAudioDevicePropertyVolumeScalar, channel: channel) { selected.append(c) }
                }
                if selected.count != Int(count) { selected = [] }
            }
            if !selected.isEmpty { result += selected; covered.insert(id) }
        }
        guard required.isSubset(of: covered) else {
            throw OutputMuteError(message: "This audio output cannot be muted automatically. Choose an output with software volume control, such as Mac speakers or headphones, or disable output muting.")
        }
        return result
    }

    func deviceID(for control: OutputMuteControl) -> AudioDeviceID? {
        devices().first(where: { uid($0) == control.uid })
    }

    func write(_ control: OutputMuteControl, value: Float) throws {
        guard [kAudioDevicePropertyMute, kAudioDevicePropertyVolumeScalar].contains(control.selector),
              value.isFinite, (0...1).contains(value),
              let id = deviceID(for: control) else {
            throw OutputMuteError(message: "Audio output unavailable.")
        }
        var a = address(control.selector, channel: control.channel)
        let status: OSStatus
        if control.selector == kAudioDevicePropertyMute {
            var mute: UInt32 = value == 0 ? 0 : 1
            status = AudioObjectSetPropertyData(id, &a, 0, nil, 4, &mute)
        } else {
            var volume = value
            status = AudioObjectSetPropertyData(id, &a, 0, nil, 4, &volume)
        }
        guard status == noErr else { throw OutputMuteError(message: "Could not change the Mac audio output (\(status)).") }
    }
}

@MainActor
final class SystemOutputMute {
    private let session: OutputMuteSession
    private var listener: AudioObjectPropertyListenerBlock?
    private var listening: [AudioObjectPropertyAddress] = []
    private var controlListeners: [(AudioDeviceID, AudioObjectPropertyAddress)] = []
    var onFailure: ((Error) -> Void)?

    init(root: URL) {
        session = OutputMuteSession(backend: CoreAudioMuteBackend(), journal: root.appendingPathComponent("audio-output-restore.json"))
        session.restore()
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            // CoreAudio delivers on the registered main queue.
            MainActor.assumeIsolated {
                guard let self else { return }
                if self.session.active {
                    do { try self.session.refresh(); self.watchControls() }
                    catch { self.restore(); self.onFailure?(error) }
                } else { self.session.restore() }
            }
        }
        listener = block
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice, kAudioHardwarePropertyDefaultSystemOutputDevice] {
            var a = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain)
            if AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, .main, block) == noErr { listening.append(a) }
        }
    }

    func begin() throws { try session.begin(); watchControls() }
    func restore() {
        unwatchControls()
        session.restore()
    }
    private func watchControls() {
        guard let listener else { return }
        let backend = CoreAudioMuteBackend()
        // Include already-muted devices so a volume key cannot unmute capture.
        guard let controls = try? backend.controls() else { return }
        for control in controls {
            guard let id = backend.deviceID(for: control),
                  !controlListeners.contains(where: { $0.0 == id && $0.1.mSelector == control.selector && $0.1.mElement == control.channel }) else { continue }
            var a = AudioObjectPropertyAddress(mSelector: control.selector, mScope: kAudioDevicePropertyScopeOutput, mElement: control.channel)
            if AudioObjectAddPropertyListenerBlock(id, &a, .main, listener) == noErr { controlListeners.append((id, a)) }
        }
    }
    private func unwatchControls() {
        if let listener {
            for (id, var a) in controlListeners { AudioObjectRemovePropertyListenerBlock(id, &a, .main, listener) }
        }
        controlListeners = []
    }
    func shutdown() {
        restore()
        if let listener {
            for var a in listening { AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &a, .main, listener) }
        }
        listening = []; listener = nil
    }
}
