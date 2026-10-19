import AppKit
import VoiceCore

@main enum RecorderChecks {
    static func main() {
        if CommandLine.arguments.count > 1 {
            freopen(CommandLine.arguments[1], "w", stdout)
            dup2(fileno(stdout), fileno(stderr)); setbuf(stdout, nil)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.regular)
        app.finishLaunching()
        let window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 330, height: 90), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "Vo1cy · Tastenkürzelprüfung"
        let button = RecorderButton(frame: NSRect(x: 20, y: 30, width: 290, height: 30))
        window.contentView?.addSubview(button)
        window.makeKeyAndOrderFront(nil); app.activate(ignoringOtherApps: true)
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        precondition(window.isKeyWindow, "Test window must receive its own events")
        defer { window.orderOut(nil) }
        var results: [(UInt32, UInt32, String)] = []
        var editing = false
        button.onEditing = { editing = $0 }
        button.onRecorded = { results.append(($0, $1, $2)) }
        func send(_ type: NSEvent.EventType, code: UInt16, flags: UInt = 0, text: String = "", repeatKey: Bool = false) {
            let event = NSEvent.keyEvent(with: type, location: .zero, modifierFlags: .init(rawValue: flags), timestamp: 0, windowNumber: window.windowNumber, context: nil, characters: text, charactersIgnoringModifiers: text, isARepeat: repeatKey, keyCode: code)!
            app.sendEvent(event)
        }
        button.begin(); send(.keyDown, code: 100)
        precondition(results.last?.0 == 100 && results.last?.1 == 0 && results.last?.2 == "F8" && !editing)
        print("PASS: recorder captures standalone F8")
        button.begin(); send(.flagsChanged, code: 61, flags: 0x80040)
        precondition(editing && results.count == 1)
        send(.flagsChanged, code: 61)
        precondition(results.last?.0 == 61 && results.last?.1 == 0 && !editing)
        print("PASS: recorder captures right Option on release")
        button.begin(); send(.flagsChanged, code: 63, flags: 0x800000); send(.flagsChanged, code: 63)
        precondition(results.last?.0 == 63 && !editing)
        print("PASS: recorder captures Fn on release")
        button.begin(); send(.flagsChanged, code: 58, flags: 0x80020); send(.flagsChanged, code: 55, flags: 0x180028)
        send(.keyDown, code: 49, flags: 0x180028, text: " ")
        precondition(results.last?.0 == 49 && results.last?.1 == 2304 && !editing)
        print("PASS: recorder preserves Option Command Space combination")
        button.begin(); send(.keyDown, code: 0, text: "a")
        precondition(results.last?.0 == 0 && results.last?.1 == 0 && results.last?.2 == "A")
        print("PASS: recorder captures a single letter")
        button.begin(); send(.keyDown, code: 48, text: "\t")
        precondition(results.last?.0 == 48 && !editing)
        print("PASS: Tab recorded before focus navigation")
        let count = results.count
        button.begin(); send(.keyDown, code: 53)
        precondition(results.count == count && !editing)
        print("PASS: Escape cancels rebinding")
        button.begin(); window.makeFirstResponder(window.contentView)
        precondition(!editing && !button.recording)
        print("PASS: focus loss ends rebinding")
        button.begin()
        let otherWindow = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 200, height: 80), styleMask: [.titled], backing: .buffered, defer: false)
        otherWindow.makeKeyAndOrderFront(nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        precondition(!editing && !button.recording)
        otherWindow.orderOut(nil)
        print("PASS: window change restores normal shortcut handling")
        print("9 AppKit recorder checks passed")
    }
}
