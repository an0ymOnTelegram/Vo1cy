import AppKit
import Carbon
import ApplicationServices
import ServiceManagement
import Sparkle

@MainActor
final class UpdateService: ObservableObject {
    private var controller: SPUStandardUpdaterController?
    let configured: Bool
    init() {
        let feed = Bundle.main.object(forInfoDictionaryKey: "SUFeedURL") as? String ?? ""
        let key = Bundle.main.object(forInfoDictionaryKey: "SUPublicEDKey") as? String ?? ""
        configured = feed.hasPrefix("https://") && !key.isEmpty
        if configured { controller = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil) }
    }
    func check() {
        if let controller { controller.checkForUpdates(nil) }
        else { NSWorkspace.shared.open(URL(string: "https://github.com/an0ymOnTelegram/Vo1cy/releases")!) }
    }
}

enum AppVersion {
    static var display: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }
}
