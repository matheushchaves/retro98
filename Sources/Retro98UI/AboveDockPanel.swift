import AppKit

/// A borderless panel above the Dock (e.g. the taskbar): bottom of the main screen, above the Dock, on every Space,
/// hidden in full-screen apps, never taking focus.
public final class AboveDockPanel: NSPanel {
    public init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        // Don't set isFloatingPanel: it resets `level` to .floating, below the Dock.
        hasShadow = false
        isReleasedWhenClosed = false
    }

    override public var canBecomeKey: Bool { false }
    override public var canBecomeMain: Bool { false }
}
