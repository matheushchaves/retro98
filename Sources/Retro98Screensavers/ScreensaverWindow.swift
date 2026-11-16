import AppKit

/// Full-screen borderless window at .screenSaver level. Presents a renderer and
/// dismisses on any mouse or keyboard event.
@MainActor
public final class ScreensaverWindow {
    private(set) var window: NSWindow?
    private var renderer: (any ScreensaverRenderer)?
    private var monitors: [Any] = []
    public var onDismiss: (() -> Void)?

    public init() {}

    public func present(renderer: any ScreensaverRenderer, presentsWindows: Bool = true) {
        guard window == nil else { return }
        self.renderer = renderer

        guard let screen = NSScreen.main else { return }
        let win = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: true,
            screen: screen
        )
        win.level = .screenSaver
        win.backgroundColor = .black
        win.isReleasedWhenClosed = false
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.window = win

        if let view = win.contentView {
            renderer.start(in: view)
        }

        if presentsWindows {
            win.makeKeyAndOrderFront(nil)
            installMonitors()
        }
    }

    public func dismiss() {
        renderer?.stop()
        renderer = nil
        removeMonitors()
        window?.close()
        window = nil
        onDismiss?()
    }

    private func installMonitors() {
        let mask: NSEvent.EventTypeMask = [.mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown,
                                           .otherMouseDown, .scrollWheel]
        let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] _ in
            Task { @MainActor in self?.dismiss() }
        }
        if let monitor { monitors.append(monitor) }
        let local = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.dismiss() }
            return event
        }
        if let local { monitors.append(local) }
    }

    private func removeMonitors() {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors.removeAll()
    }
}
