import SwiftUI
import Carbon
import VoiceCore

struct ShortcutRecorder: NSViewRepresentable {
    let label: String
    let onEditing: (Bool) -> Void
    let onRecorded: (UInt32, UInt32, String) -> Void
    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton(); button.bezelStyle = .rounded
        button.target = button; button.action = #selector(RecorderButton.begin)
        button.setAccessibilityLabel("Change activation key")
        return button
    }
    func updateNSView(_ view: RecorderButton, context: Context) {
        view.onEditing = onEditing; view.onRecorded = onRecorded; view.savedTitle = label
        view.isEnabled = context.environment.isEnabled
        if !view.recording { view.title = label }
    }
}

final class RecorderButton: NSButton {
    var onEditing: ((Bool) -> Void)?
    var onRecorded: ((UInt32, UInt32, String) -> Void)?
    var savedTitle = "Change keyboard shortcut"
    private(set) var recording = false
    private var monitor: Any?
    private var focusObserver: NSObjectProtocol?
    private var capture = ModifierCapture()
    override var acceptsFirstResponder: Bool { true }
    @objc func begin() {
        guard !recording else { end(); return }
        recording = true; capture = ModifierCapture()
        title = "Press a key · Esc to cancel"; onEditing?(true)
        window?.makeFirstResponder(self)
        focusObserver = NotificationCenter.default.addObserver(forName: NSWindow.didResignKeyNotification, object: window, queue: .main) { [weak self] _ in self?.end() }
        // Capture before normal focus navigation/menu equivalents consume Tab or ⌘ keys.
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { [weak self] event in
            guard let self, self.recording, self.window?.isKeyWindow == true else { return event }
            if event.type == .flagsChanged { self.captureModifier(event) }
            else { self.captureKey(event) }
            return nil
        }
    }
    private func captureKey(_ event: NSEvent) {
        if event.keyCode == 53 { end(); return }
        guard !event.isARepeat, event.keyCode != 57 else { return }
        let carbon = ShortcutKeys.carbonModifiers(flags: UInt64(event.modifierFlags.rawValue))
        var symbols = ""
        for (mask, symbol) in [(UInt32(controlKey), "⌃ "), (UInt32(optionKey), "⌥ "), (UInt32(shiftKey), "⇧ "), (UInt32(cmdKey), "⌘ ")] {
            if carbon & mask != 0 { symbols += symbol }
        }
        let key = ShortcutKeys.label(code: UInt32(event.keyCode), characters: event.charactersIgnoringModifiers)
        finish(code: UInt32(event.keyCode), modifiers: carbon, label: symbols + key)
    }
    private func captureModifier(_ event: NSEvent) {
        let code = UInt32(event.keyCode)
        guard let key = ShortcutKeys.modifier(code) else {
            title = "Caps Lock is not supported"; return
        }
        let down = ShortcutKeys.isDown(code, flags: UInt64(event.modifierFlags.rawValue))
        let others = ShortcutKeys.otherModifiersDown(code, flags: UInt64(event.modifierFlags.rawValue))
        if let selected = capture.change(code: code, down: down, othersDown: others) {
            finish(code: selected, modifiers: 0, label: key.label)
        } else if down {
            title = "Release or add another key"
        }
    }
    private func finish(code: UInt32, modifiers: UInt32, label: String) {
        savedTitle = label
        onRecorded?(code, modifiers, label)
        end()
    }
    override func resignFirstResponder() -> Bool { end(); return super.resignFirstResponder() }
    override func viewWillMove(toWindow newWindow: NSWindow?) { if newWindow == nil { end() }; super.viewWillMove(toWindow: newWindow) }
    private func end() {
        guard recording else { return }
        recording = false
        if let monitor { NSEvent.removeMonitor(monitor) }; monitor = nil
        if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }; focusObserver = nil
        title = savedTitle; onEditing?(false)
    }
    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        if let focusObserver { NotificationCenter.default.removeObserver(focusObserver) }
    }
}
