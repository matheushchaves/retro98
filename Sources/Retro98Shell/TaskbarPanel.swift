import AppKit
import Retro98Settings
import Retro98ShellCore
import Retro98UI

/// The taskbar window: bottom of the main screen, above the Dock, on every Space,
/// hidden in full-screen apps, never taking focus.
final class TaskbarPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isFloatingPanel = true
        hasShadow = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// Face color with the raised top edge of the classic taskbar.
final class TaskbarView: PixelView {
    override func drawPixels(in context: CGContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        Bevel.fillFace(rect, context: context)
        Bevel.fill(CGRect(x: 0, y: 0, width: size.width, height: 1), color: Palette.face, context: context)
        Bevel.fill(CGRect(x: 0, y: 1, width: size.width, height: 1), color: Palette.light, context: context)
    }
}

@MainActor
final class TaskbarController {
    static let startMargin: CGFloat = 2
    nonisolated static let dockBundleID = "com.apple.dock"

    private let languages: [String]
    private let panel = TaskbarPanel()
    private let view = TaskbarView()
    private let startButton: RetroButton
    private let tray: TrayView
    private let startMenu: StartMenuController
    private var observers: [NSObjectProtocol] = []

    init(languages: [String]) {
        self.languages = languages
        tray = TrayView(languages: languages)
        var toggle: (() -> Void)?
        startButton = RetroButton(
            title: LocalizedTitle.start.resolve(for: languages), icon: Icons.startLogo, bold: true
        ) { toggle?() }
        startMenu = StartMenuController(languages: languages)
        toggle = { [weak self] in self?.toggleStartMenu() }
        panel.contentView = view
        view.addSubview(startButton)
        view.addSubview(tray)
    }

    func show() {
        layout()
        panel.orderFrontRegardless()
        tray.start()
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.layout() }
        })
        // The Dock reserves its space again after it restarts (e.g. when its size tweak is applied).
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == Self.dockBundleID else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { MainActor.assumeIsolated { self?.layout() } }
        })
    }

    func toggleStartMenu() {
        if startMenu.isOpen {
            startMenu.close()
            return
        }
        startButton.isPressed = true
        let frame = panel.frame
        startMenu.open(at: CGPoint(x: frame.minX + Self.startMargin, y: frame.maxY), ignoring: [panel]) { [weak self] in
            self?.startButton.isPressed = false
        }
    }

    private func layout() {
        guard let screen = NSScreen.screens.first else { return }   // the main (menu bar) screen
        let frame = TaskbarGeometry.frame(screenFrame: screen.frame, visibleFrame: screen.visibleFrame)
        panel.setFrame(frame, display: true)
        view.frame = CGRect(origin: .zero, size: frame.size)
        let buttonY = ((frame.height - startButton.frame.height) / 2).rounded(.down) + 1
        startButton.setFrameOrigin(CGPoint(x: Self.startMargin, y: buttonY))
        tray.relayout(height: TrayView.height)
        tray.setFrameOrigin(CGPoint(x: frame.width - tray.frame.width - Self.startMargin,
                                    y: ((frame.height - tray.frame.height) / 2).rounded(.down) + 1))
    }
}

enum LocalizedTitle {
    static let start = LocalizedText(en: "Start", ptBR: "Iniciar")
}
