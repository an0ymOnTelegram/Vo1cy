import AppKit
import ApplicationServices

@MainActor
final class TextOutput {
    private let board: NSPasteboard
    private let modifiers: (CGEventSourceStateID) -> CGEventFlags
    private let frontmost: () -> pid_t?
    private let isTrusted: () -> Bool
    private let post: (CGEvent, CGEvent) -> Void
    init(board: NSPasteboard = .general,
         modifiers: @escaping (CGEventSourceStateID) -> CGEventFlags = { CGEventSource.flagsState($0) },
         frontmost: @escaping () -> pid_t? = { NSWorkspace.shared.frontmostApplication?.processIdentifier },
         isTrusted: @escaping () -> Bool = { AXIsProcessTrusted() },
         post: @escaping (CGEvent, CGEvent) -> Void = { down, up in down.post(tap: .cghidEventTap); up.post(tap: .cghidEventTap) }) {
        self.board = board; self.modifiers = modifiers; self.frontmost = frontmost
        self.isTrusted = isTrusted; self.post = post
    }
    static var trusted: Bool { AXIsProcessTrusted() }
    static func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        // A stale grant may suppress the system prompt after a development update.
        // Always provide a route to the actual macOS permission controls.
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    static func copy(_ text: String) {
        NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string)
    }
    /// Restores every original clipboard flavor only while we still own the clipboard.
    func deliver(_ text: String, to target: NSRunningApplication?, beforeMS: Int, restoreMS: Int,
                 valid: @escaping () -> Bool) async -> String {
        guard valid() else { return "Cancelled" }
        guard isTrusted() else { return "Text is in History. Allow Accessibility for automatic insertion, or choose Copy." }
        guard let target, !target.isTerminated, target.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            return "Text is in History. Use the shortcut while the target app is active."
        }
        guard frontmost() == target.processIdentifier else {
            return "Focus changed. Text remains in Vo1cy for copying."
        }
        try? await Task.sleep(nanoseconds: UInt64(max(30, beforeMS)) * 1_000_000)
        for _ in 0..<25 {
            let held = modifiers(.hidSystemState).intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift])
            if held.isEmpty { break }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        guard modifiers(.hidSystemState).intersection([.maskCommand, .maskAlternate, .maskControl, .maskShift]).isEmpty else {
            return "Keys are still held down. Text remains in Vo1cy for copying."
        }
        guard valid(), frontmost() == target.processIdentifier else {
            return "Focus changed. Text is in History and was not inserted."
        }
        let snapshot = (board.pasteboardItems ?? []).map { item in
            item.types.compactMap { type in item.data(forType: type).map { (type, $0) } }
        }
        board.clearContents(); board.setString(text, forType: .string)
        let ownership = board.changeCount
        func restore() {
            guard board.changeCount == ownership else { return }
            board.clearContents()
            let items = snapshot.map { pairs -> NSPasteboardItem in
                let item = NSPasteboardItem(); pairs.forEach { item.setData($0.1, forType: $0.0) }; return item
            }
            if !items.isEmpty { board.writeObjects(items) }
        }
        guard valid(), let source = CGEventSource(stateID: .combinedSessionState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) else {
            restore(); return "Could not insert text. It is available in History."
        }
        down.flags = .maskCommand
        // Release the synthetic chord as well as V; do not leave Command in the
        // combined session state for the next dictation or the foreground app.
        up.flags = []
        post(down, up)
        try? await Task.sleep(nanoseconds: UInt64(max(150, restoreMS)) * 1_000_000)
        restore()
        return "Paste requested · text saved to history"
    }
}

