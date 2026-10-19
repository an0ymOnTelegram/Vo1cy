import AppKit
import Carbon
import VoiceCore

@main enum ShortcutChecks {
    static func main() throws {
        var down = 0, up = 0
        let shortcut = GlobalShortcut()
        shortcut.pressed = { down += 1 }; shortcut.released = { up += 1 }
        defer { shortcut.unregister() }
        func send(_ kind: UInt32, signature: OSType = 0x564F3143) {
            var event: EventRef?
            precondition(CreateEvent(nil, OSType(kEventClassKeyboard), kind, GetCurrentEventTime(), EventAttributes(0), &event) == noErr)
            guard let event else { fatalError("Missing Carbon event") }
            defer { ReleaseEvent(event) }
            var id = EventHotKeyID(signature: signature, id: 1)
            precondition(SetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), MemoryLayout<EventHotKeyID>.size, &id) == noErr)
            _ = SendEventToEventTarget(event, GetApplicationEventTarget())
        }
        func drain() { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        // F19 is reserved only during this test; no keypresses are sent to other apps.
        try shortcut.register(key: 80, modifiers: 0)
        send(UInt32(kEventHotKeyPressed)); send(UInt32(kEventHotKeyPressed)); drain()
        precondition(down == 1 && up == 0)
        send(UInt32(kEventHotKeyReleased)); send(UInt32(kEventHotKeyReleased)); drain()
        precondition(down == 1 && up == 1)
        print("PASS: unmodified F19 registration and repeat-safe Carbon press/release")
        send(UInt32(kEventHotKeyPressed), signature: 0x41414141); drain()
        precondition(down == 1)
        print("PASS: unrelated Carbon hotkeys ignored")
        send(UInt32(kEventHotKeyPressed)); shortcut.unregister(); drain()
        precondition(down == 1)
        print("PASS: queued event discarded after rebinding")
        try shortcut.register(key: 80, modifiers: UInt32(cmdKey | optionKey))
        send(UInt32(kEventHotKeyPressed)); send(UInt32(kEventHotKeyReleased)); drain()
        precondition(down == 2 && up == 2)
        print("PASS: existing modifier combination still registers and dispatches")
        print("4 macOS shortcut checks passed")
    }
}
