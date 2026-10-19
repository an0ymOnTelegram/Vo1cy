import AppKit
import QuartzCore
import VoiceCore

private final class RecordingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// A microphone-driven HUD. No transcript text or idle animation timer.
@MainActor
final class RecordingOverlay {
    private var panel: NSPanel?
    private var dismissal: DispatchWorkItem?
    private var screen: NSScreen?
    var position = OverlayPosition.bottomCenter {
        didSet { if panel?.isVisible == true { placePanel() } }
    }
    private var recording = false
    private let bubble = AudioBubbleView(frame: NSRect(x: 0, y: 0, width: 124, height: 44))
    private let label = NSTextField(labelWithString: "")
    private let noticeBackground = NSVisualEffectView()

    func startRecording() {
        cancelDismissal(); recording = true
        screen = NSScreen.main
        bubble.reset()
        show(content: bubble, size: NSSize(width: 124, height: 44))
    }
    func preview() {
        startRecording()
        dismiss(after: 3)
    }
    func updateLevel(_ level: Float) {
        guard recording, panel?.isVisible == true else { return }
        bubble.updateLevel(level)
    }
    func processing() {
        cancelDismissal(); recording = false
        bubble.processing()
        show(content: bubble, size: NSSize(width: 124, height: 44))
    }
    func notice(_ text: String) {
        cancelDismissal(); recording = false; bubble.stop()
        noticeBackground.material = .hudWindow; noticeBackground.state = .active
        noticeBackground.appearance = NSAppearance(named: .darkAqua)
        noticeBackground.wantsLayer = true; noticeBackground.layer?.cornerRadius = 14
        noticeBackground.layer?.masksToBounds = true
        label.frame = NSRect(x: 15, y: 10, width: 350, height: 32)
        label.textColor = .init(calibratedRed: 0.82, green: 0.73, blue: 1, alpha: 1)
        label.font = .systemFont(ofSize: 12, weight: .medium)
        label.maximumNumberOfLines = 2; label.lineBreakMode = .byTruncatingTail
        label.stringValue = text
        if label.superview == nil { noticeBackground.addSubview(label) }
        show(content: noticeBackground, size: NSSize(width: 380, height: 52))
        dismiss(after: 5)
    }
    func hide() {
        cancelDismissal(); recording = false; bubble.stop()
        panel?.orderOut(nil)
        screen = nil
    }
    private func dismiss(after seconds: Double) {
        let work = DispatchWorkItem { [weak self] in self?.hide() }
        dismissal = work
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: work)
    }
    private func cancelDismissal() { dismissal?.cancel(); dismissal = nil }
    private func show(content: NSView, size: NSSize) {
        if panel == nil {
            let p = RecordingPanel(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            p.level = .floating; p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            p.isOpaque = false; p.backgroundColor = .clear; p.hasShadow = true
            p.ignoresMouseEvents = true; p.hidesOnDeactivate = false
            panel = p
        }
        panel?.contentView = content
        panel?.setContentSize(size)
        content.frame = NSRect(origin: .zero, size: size)
        placePanel()
        panel?.orderFrontRegardless()
    }
    private func placePanel() {
        guard let panel, let target = screen ?? NSScreen.main else { return }
        // Edge positions overlay system chrome instead of moving above the Dock.
        // The panel remains non-activating and click-through.
        panel.level = position == .bottomCenter ? .floating : NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        panel.setFrameOrigin(position.origin(size: panel.frame.size, screen: target.frame,
            visible: target.visibleFrame, topSafeInset: target.safeAreaInsets.top))
    }
}

@MainActor
private final class AudioBubbleView: NSView {
    private let tint = NSColor(calibratedRed: 0.71, green: 0.53, blue: 1, alpha: 1)
    private let mic = NSImageView(frame: NSRect(x: 16, y: 13, width: 15, height: 18))
    private let spinner = NSProgressIndicator(frame: NSRect(x: 54, y: 14, width: 16, height: 16))
    private var bars: [CALayer] = []
    private var levels = [CGFloat](repeating: 0, count: 9)

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor(calibratedRed: 0.10, green: 0.075, blue: 0.14, alpha: 0.96).cgColor
        layer?.cornerRadius = 22
        layer?.borderWidth = 1; layer?.borderColor = tint.withAlphaComponent(0.4).cgColor
        mic.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)
        mic.contentTintColor = tint; addSubview(mic)
        for index in 0..<9 {
            let bar = CALayer()
            bar.backgroundColor = tint.cgColor; bar.cornerRadius = 2
            bar.frame = NSRect(x: 43 + CGFloat(index) * 7, y: 20, width: 4, height: 4)
            layer?.addSublayer(bar); bars.append(bar)
        }
        spinner.style = .spinning; spinner.controlSize = .small
        spinner.appearance = NSAppearance(named: .darkAqua)
        spinner.isDisplayedWhenStopped = false; addSubview(spinner)
        setAccessibilityElement(true); setAccessibilityRole(.group)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func reset() {
        stop(); mic.isHidden = false
        levels = Array(repeating: 0, count: bars.count)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        for bar in bars { bar.isHidden = false; bar.bounds.size.height = 4; bar.position.y = 22 }
        CATransaction.commit()
        setAccessibilityLabel("Recording in progress. Microphone level.")
    }
    func updateLevel(_ raw: Float) {
        // Capture RMS drives every bar; silence stays flat. Quiet speech becomes
        // visible without changing microphone gain or recognition input.
        let value = raw.isFinite ? CGFloat(min(1, max(0, raw))) : 0
        levels.removeFirst(); levels.append(value < 0.015 ? 0 : sqrt(value))
        CATransaction.begin()
        CATransaction.setAnimationDuration(NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? 0 : 0.08)
        for (index, bar) in bars.enumerated() {
            bar.bounds.size.height = 4 + levels[index] * 24
            bar.position.y = 22
        }
        CATransaction.commit()
    }
    func processing() {
        mic.isHidden = true
        for bar in bars { bar.removeAllAnimations(); bar.isHidden = true }
        spinner.startAnimation(nil)
        setAccessibilityLabel("Finalizing transcription.")
    }
    func stop() {
        spinner.stopAnimation(nil)
        for bar in bars { bar.removeAllAnimations() }
    }
}
