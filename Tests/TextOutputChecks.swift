import AppKit

@main enum TextOutputChecks {
    @MainActor static func main() async throws {
        guard let target = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first else {
            fatalError("Requires a logged-in macOS desktop with Finder running")
        }
        let board = NSPasteboard(name: NSPasteboard.Name("app.vo1cy.checks.\(UUID())"))
        defer { board.releaseGlobally() }
        var count = 0
        func verify(_ condition: Bool, _ name: String) {
            precondition(condition, name); count += 1; print("PASS: \(name)")
        }
        board.setString("original clipboard", forType: .string)
        var posted = 0; var postedFlags: [(CGEventFlags, CGEventFlags)] = []
        let output = TextOutput(board: board,
            modifiers: { source in source == .hidSystemState ? [] : .maskCommand },
            frontmost: { target.processIdentifier }, isTrusted: { true },
            post: { down, up in
                precondition(board.string(forType: .string) == "test text")
                posted += 1; postedFlags.append((down.flags, up.flags))
            })
        for _ in 0..<3 {
            let message = await output.deliver("test text", to: target, beforeMS: 30, restoreMS: 150, valid: { true })
            verify(message.hasPrefix("Einfügen ausgelöst"), "Repeated paste ignores synthetic Command state")
        }
        verify(posted == 3 && postedFlags.allSatisfy { $0.0 == .maskCommand && $0.1.isEmpty }, "Each paste releases the synthetic chord")
        verify(board.string(forType: .string) == "original clipboard", "Original private test clipboard is restored")
        let listText = "Meine Aufgaben:\n- E-Mails beantworten\n- Nicht vor 14:30 senden\n\nDanach habe ich Zeit."
        var listPosted = false
        let listOutput = TextOutput(board: board, modifiers: { _ in [] }, frontmost: { target.processIdentifier }, isTrusted: { true }, post: { down, up in
            precondition(board.string(forType: .string) == listText, "List/paragraph line breaks changed")
            precondition(down.getIntegerValueField(.keyboardEventKeycode) == 9 && up.getIntegerValueField(.keyboardEventKeycode) == 9, "List paste must not type Enter")
            listPosted = true
        })
        let listMessage = await listOutput.deliver(listText, to: target, beforeMS: 30, restoreMS: 150, valid: { true })
        verify(listPosted && listMessage.hasPrefix("Einfügen ausgelöst"), "Multiline lists/paragraphs paste unchanged without Enter events")
        verify(board.string(forType: .string) == "original clipboard", "List paste restores original private clipboard")
        let held = TextOutput(board: board, modifiers: { _ in .maskShift }, frontmost: { target.processIdentifier }, isTrusted: { true }, post: { _,_ in fatalError("Must not paste with a physical modifier held") })
        let heldMessage = await held.deliver("test", to: target, beforeMS: 30, restoreMS: 150, valid: { true })
        verify(heldMessage.hasPrefix("Tasten sind noch gedrückt") && board.string(forType: .string) == "original clipboard", "Real held modifiers still block paste safely")
        let changed = TextOutput(board: board, frontmost: { nil }, isTrusted: { true }, post: { _,_ in fatalError("Must not paste into changed focus") })
        let focusMessage = await changed.deliver("test", to: target, beforeMS: 30, restoreMS: 150, valid: { true })
        verify(focusMessage.hasPrefix("Fokus hat gewechselt"), "Changed foreground app is not pasted into")
        let copied = TextOutput(board: board, modifiers: { _ in [] }, frontmost: { target.processIdentifier }, isTrusted: { true }, post: { _,_ in
            board.clearContents(); board.setString("new copy", forType: .string)
        })
        _ = await copied.deliver("test", to: target, beforeMS: 30, restoreMS: 150, valid: { true })
        verify(board.string(forType: .string) == "new copy", "A newer clipboard owner is never overwritten")
        print("\(count) text-output checks passed; no events sent to other apps or general clipboard changes")
    }
}
