import AppKit
import Testing
@testable import Enso

@MainActor
struct TerminalBackdropTests {
    @Test func focusRestoresMaterialWithoutReplacingIt() throws {
        let backdrop = TerminalBackdropView()
        let material = try #require(backdrop.subviews.compactMap { $0 as? NSVisualEffectView }.first)

        backdrop.update(isWindowActive: true, reduceTransparency: false)
        #expect(!backdrop.isOpaque)
        #expect(!material.isHidden)

        backdrop.update(isWindowActive: false, reduceTransparency: false)
        #expect(backdrop.isOpaque)
        #expect(material.isHidden)

        backdrop.update(isWindowActive: true, reduceTransparency: false)
        #expect(!backdrop.isOpaque)
        #expect(!material.isHidden)
        #expect(material.superview === backdrop)
    }

    @Test func reduceTransparencyKeepsActiveWindowOpaque() {
        let backdrop = TerminalBackdropView()
        backdrop.update(isWindowActive: true, reduceTransparency: true)
        #expect(backdrop.isOpaque)

        backdrop.update(isWindowActive: true, reduceTransparency: false)
        #expect(!backdrop.isOpaque)
    }

    @Test func backdropNeverInterceptsTerminalInput() {
        let backdrop = TerminalBackdropView()
        backdrop.frame = NSRect(x: 0, y: 0, width: 100, height: 100)
        for active in [true, false] {
            backdrop.update(isWindowActive: active, reduceTransparency: false)
            #expect(backdrop.hitTest(NSPoint(x: 50, y: 50)) == nil)
        }
    }

    @Test func detachedBackdropIsOpaque() {
        let backdrop = TerminalBackdropView()
        #expect(backdrop.isOpaque)

        let window = NSWindow()
        window.contentView = backdrop
        backdrop.update(isWindowActive: true, reduceTransparency: false)
        window.contentView = nil
        #expect(backdrop.isOpaque)
    }

    @Test func observesOnlyItsOwnWindow() {
        let backdrop = TerminalBackdropView()
        let owner = NSWindow()
        owner.contentView = backdrop
        let other = NSWindow()
        backdrop.update(isWindowActive: true, reduceTransparency: false)

        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: other)
        #expect(!backdrop.isOpaque)

        NotificationCenter.default.post(name: NSWindow.didResignKeyNotification, object: owner)
        #expect(backdrop.isOpaque)
    }
}
