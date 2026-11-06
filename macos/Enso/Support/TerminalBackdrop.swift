import AppKit
import SwiftUI

/// An opaque backing would cancel Ghostty's configured transparency. Only
/// inactive windows cover the material, without dimming terminal glyphs.
final class TerminalBackdropView: NSView {
    private let material = NSVisualEffectView()
    private let opaqueFill = NSView()

    override var isOpaque: Bool { opaqueFill.alphaValue == 1 }

    init() {
        super.init(frame: .zero)
        material.material = .hudWindow
        material.blendingMode = .behindWindow
        material.state = .followsWindowActiveState
        material.appearance = NSAppearance(named:
            GhosttyRuntime.shared.terminalColorScheme == .dark ? .darkAqua : .aqua
        )
        opaqueFill.wantsLayer = true
        opaqueFill.layer?.backgroundColor = NSColor(GhosttyRuntime.shared.themeBackground).cgColor
        for view in [material, opaqueFill] {
            view.frame = bounds
            view.autoresizingMask = [.width, .height]
            addSubview(view)
        }
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(syncAppearance),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil
        )
        syncAppearance()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didResignKeyNotification] {
            center.removeObserver(self, name: name, object: nil)
            if let window {
                center.addObserver(self, selector: #selector(syncAppearance), name: name, object: window)
            }
        }
        syncAppearance()
    }

    @objc private func syncAppearance() {
        update(
            isWindowActive: window?.isKeyWindow == true,
            reduceTransparency: NSWorkspace.shared.accessibilityDisplayShouldReduceTransparency
        )
    }

    func update(isWindowActive: Bool, reduceTransparency: Bool) {
        let opaque = !isWindowActive || reduceTransparency
        opaqueFill.alphaValue = opaque ? 1 : 0
        material.isHidden = opaque
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}

struct TerminalBackdrop: NSViewRepresentable {
    func makeNSView(context: Context) -> TerminalBackdropView { TerminalBackdropView() }
    func updateNSView(_ nsView: TerminalBackdropView, context: Context) {}
}
