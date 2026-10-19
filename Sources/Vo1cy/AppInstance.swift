import AppKit

enum AppInstance {
    private static var lease: InstanceLease?

    /// Run before SwiftUI constructs AppState, microphones, hotkeys or models.
    static func prepare() -> Bool {
        do {
            let support = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            lease = try InstanceLease.acquire(at: support.appendingPathComponent("Vo1cy/gui-instance.lock"))
            guard lease != nil else {
                // Launch Services reopens the existing app, including its closed
                // singleton window. Never use createsNewApplicationInstance here.
                if let peer = NSRunningApplication.runningApplications(withBundleIdentifier: "app.vo1cy.mac")
                    .first(where: { $0.processIdentifier != getpid() }), let url = peer.bundleURL {
                    peer.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
                    let config = NSWorkspace.OpenConfiguration()
                    config.createsNewApplicationInstance = false
                    NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in exit(0) }
                    // The main queue must run for the completion, but no AppState
                    // is constructed in this losing process.
                    dispatchMain()
                }
                return false
            }
            NSWindow.allowsAutomaticWindowTabbing = false
            return true
        } catch {
            // Fail closed instead of risking two hotkeys/audio owners.
            let alert = NSAlert()
            alert.messageText = "Vo1cy could not secure a single app instance."
            alert.informativeText = "Restart Vo1cy. \(error.localizedDescription)"
            alert.runModal()
            return false
        }
    }
}
