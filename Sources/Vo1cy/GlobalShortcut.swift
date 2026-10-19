import AppKit
import Carbon
import ApplicationServices
import VoiceCore

struct ShortcutFailure: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

/// Carbon reserves ordinary keys; a narrow event tap handles standalone modifiers.
/// Every callback runs on the main run loop. No key contents are recorded or logged.
final class GlobalShortcut {
    private var hotkey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var sleepObserver: NSObjectProtocol?
    private var latch = ShortcutLatch()
    private var modifierCode: UInt32?
    private var registration: UInt64 = 0
    var pressed: (() -> Void)?
    var released: (() -> Void)?
    var interrupted: (() -> Void)?

    func register(key: UInt32, modifiers: UInt32) throws {
        unregister()
        guard key != 53, key != 57 else { throw ShortcutFailure(message: "Escape is reserved for cancelling. Caps Lock is not supported.") }
        if ShortcutKeys.modifier(key) != nil {
            guard modifiers == 0 else { throw ShortcutFailure(message: "Choose a modifier key on its own or combine it with a regular key.") }
            try registerModifier(key)
        } else {
            try registerCarbon(key: key, modifiers: modifiers)
        }
        sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            self?.interrupt()
        }
    }

    private func registerCarbon(key: UInt32, modifiers: UInt32) throws {
        var events = [EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
                      EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))]
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, event, pointer in
            guard let pointer, let event else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr,
                  id.signature == 0x564F3143, id.id == 1 else { return OSStatus(eventNotHandledErr) }
            let me = Unmanaged<GlobalShortcut>.fromOpaque(pointer).takeUnretainedValue()
            me.transition(down: GetEventKind(event) == UInt32(kEventHotKeyPressed))
            return noErr
        }, events.count, &events, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard status == noErr else { throw ShortcutFailure(message: "Could not register the keyboard shortcut.") }
        let id = EventHotKeyID(signature: 0x564F3143, id: 1)
        let registered = RegisterEventHotKey(key, modifiers, id, GetApplicationEventTarget(), 0, &hotkey)
        guard registered == noErr else {
            unregister()
            throw ShortcutFailure(message: "This key is reserved by the system or another app (\(registered)). Choose a different key.")
        }
    }

    private func registerModifier(_ key: UInt32) throws {
        guard AXIsProcessTrusted() else {
            throw ShortcutFailure(message: "Enable Accessibility and reopen Vo1cy to use standalone modifier keys.")
        }
        modifierCode = key
        let mask = CGEventMask(1) << CGEventType.flagsChanged.rawValue
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: { _, type, event, pointer in
            guard let pointer else { return Unmanaged.passUnretained(event) }
            let me = Unmanaged<GlobalShortcut>.fromOpaque(pointer).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                me.interrupt()
                if let tap = me.tap { CGEvent.tapEnable(tap: tap, enable: true) }
                return Unmanaged.passUnretained(event)
            }
            guard type == .flagsChanged, let key = me.modifierCode,
                  event.getIntegerValueField(.keyboardEventKeycode) == Int64(key) else { return Unmanaged.passUnretained(event) }
            me.transition(down: ShortcutKeys.isDown(key, flags: event.flags.rawValue))
            // Consume the dedicated modifier gesture (not other keyboard events).
            return nil
        }, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            modifierCode = nil
            throw ShortcutFailure(message: "Could not activate this modifier key. Check Accessibility and reopen Vo1cy.")
        }
        self.tap = tap
        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            unregister(); throw ShortcutFailure(message: "Could not start keyboard monitoring.")
        }
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func transition(down: Bool) {
        guard latch.update(down: down) else { return }
        let current = registration
        // Keep the event tap fast; model/audio work starts after returning to macOS.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.registration == current else { return }
            if down { self.pressed?() } else { self.released?() }
        }
    }
    private func interrupt() {
        latch.reset(); registration &+= 1
        let current = registration
        DispatchQueue.main.async { [weak self] in
            guard let self, self.registration == current else { return }
            self.interrupted?()
        }
    }
    func unregister() {
        registration &+= 1; latch.reset(); modifierCode = nil
        if let hotkey { UnregisterEventHotKey(hotkey) }; hotkey = nil
        if let handler { RemoveEventHandler(handler) }; handler = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false); CFMachPortInvalidate(tap) }; tap = nil
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }; source = nil
        if let sleepObserver { NSWorkspace.shared.notificationCenter.removeObserver(sleepObserver) }; sleepObserver = nil
    }
    deinit { unregister() }
}
