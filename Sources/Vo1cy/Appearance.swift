import SwiftUI
import AppKit

// Shared by every app page; deliberately independent of the inference pipeline.
enum Vo1cyStyle {
    static let background = Color(red: 0.075, green: 0.067, blue: 0.094)
    static let sidebar = Color(red: 0.094, green: 0.082, blue: 0.118)
    static let surface = Color(red: 0.118, green: 0.106, blue: 0.145)
    static let raised = Color(red: 0.157, green: 0.137, blue: 0.192)
    static let accent = Color(red: 0.71, green: 0.53, blue: 1.0)
    static let border = Color.white.opacity(0.075)
    static let muted = Color(red: 0.66, green: 0.63, blue: 0.72)
}

struct SettingsCard<Content: View>: View {
    var title: String
    var content: Content
    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title; self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !title.isEmpty {
                Text(title.uppercased()).font(.system(size: 10, weight: .semibold))
                    .tracking(1.1).foregroundStyle(Vo1cyStyle.muted).padding(.leading, 2)
            }
            VStack(alignment: .leading, spacing: 0) { content }
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Vo1cyStyle.surface, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Vo1cyStyle.border, lineWidth: 1))
        }
    }
}

struct SettingRow<Control: View>: View {
    let title: String
    var detail: String?
    let control: Control
    init(_ title: String, detail: String? = nil, @ViewBuilder control: () -> Control) {
        self.title = title; self.detail = detail; self.control = control()
    }
    var body: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title).fontWeight(.medium)
                if let detail { Text(detail).font(.system(size: 11)).foregroundStyle(Vo1cyStyle.muted).fixedSize(horizontal: false, vertical: true) }
            }.frame(maxWidth: .infinity, alignment: .leading)
            control.frame(maxWidth: 216, alignment: .trailing)
        }.padding(.horizontal, 13).padding(.vertical, 8)
    }
}

struct SettingToggle: View {
    var title: String
    var detail: String? = nil
    @Binding var isOn: Bool
    var body: some View {
        SettingRow(title, detail: detail) {
            Toggle(title, isOn: $isOn).labelsHidden().toggleStyle(.switch)
                .accessibilityLabel(title)
        }
    }
}

struct CardDivider: View {
    var body: some View { Rectangle().fill(Vo1cyStyle.border).frame(height: 1).padding(.horizontal, 13) }
}

struct AccentBadge: View {
    let text: String
    var body: some View {
        Text(text).font(.system(size: 10, weight: .semibold)).foregroundStyle(Vo1cyStyle.accent)
            .padding(.horizontal, 7).padding(.vertical, 4)
            .background(Vo1cyStyle.accent.opacity(0.12), in: Capsule())
    }
}

struct CompactButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 11).padding(.vertical, 7)
            .foregroundStyle(prominent ? Color(red: 0.12, green: 0.07, blue: 0.21) : .white.opacity(0.9))
            .background(prominent ? Vo1cyStyle.accent : Vo1cyStyle.raised, in: RoundedRectangle(cornerRadius: 6))
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Vo1cyStyle.border, lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

/// Apply the new compact default once per window; resizing remains under user control.
struct CompactWindow: NSViewRepresentable {
    final class Coordinator { var configured = false }
    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeNSView(context: Context) -> NSView { NSView() }
    func updateNSView(_ view: NSView, context: Context) {
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            guard !coordinator.configured, let window = view.window else { return }
            coordinator.configured = true
            window.tabbingMode = .disallowed
            window.titlebarAppearsTransparent = true
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = NSColor(Vo1cyStyle.background)
            window.setContentSize(NSSize(width: 820, height: 620))
            window.contentMinSize = NSSize(width: 760, height: 540)
        }
    }
}

/// Plain external links: no embedded web content, tracking, or background requests.
struct CommunityLinks: View {
    var body: some View {
        HStack(spacing: 10) {
            Link(destination: URL(string: "https://t.me/an0ym")!) {
                Label("@an0ym", systemImage: "paperplane")
            }.help("Open @an0ym on Telegram").accessibilityLabel("Creator on Telegram: @an0ym")
            Link(destination: URL(string: "https://t.me/jailbreakall")!) {
                Label("Group", systemImage: "person.2")
            }.help("Join the Telegram community").accessibilityLabel("Join the Telegram group")
        }
        .font(.system(size: 9, weight: .medium))
        .foregroundStyle(Vo1cyStyle.accent.opacity(0.85))
        .buttonStyle(.plain)
        .lineLimit(1)
        .fixedSize()
    }
}
