import AppKit
import Retro98Settings
import Retro98ShellCore
import Retro98UI

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
    static let buttonsGap: CGFloat = 4
    nonisolated static let dockBundleID = "com.apple.dock"

    private let languages: [String]
    private let panel = AboveDockPanel()
    private let view = TaskbarView()
    private let startButton: RetroButton
    private let quickLaunch: QuickLaunchView
    private let tray: TrayView
    private let startMenu: StartMenuController
    private let windowButtons: TaskButtonsView
    private let windowModel: TaskButtonsView.Model
    private let windowMonitor: WindowChangeMonitor
    private let guardian: WorkAreaGuardian
    private var observers: [NSObjectProtocol] = []

    init(languages: [String]) {
        self.languages = languages
        tray = TrayView(languages: languages)
        quickLaunch = QuickLaunchView(languages: languages)
        var toggle: (() -> Void)?
        startButton = RetroButton(
            title: LocalizedTitle.start.resolve(for: languages), icon: Icons.startLogo, bold: true
        ) { toggle?() }
        startMenu = StartMenuController(languages: languages)
        let model = TaskButtonsView.Model(source: AXWindowSource(), commands: AXWindowCommands())
        windowModel = model
        windowButtons = TaskButtonsView(model: model, languages: languages)
        windowMonitor = WindowChangeMonitor { model.refresh() }
        let panel = self.panel
        guardian = WorkAreaGuardian { panel.frame.height }
        windowMonitor.onWindowGeometry = { [guardian] window in guardian.windowChanged(window) }
        toggle = { [weak self] in self?.toggleStartMenu() }
        panel.contentView = view
        view.addSubview(startButton)
        view.addSubview(quickLaunch)
        view.addSubview(windowButtons)
        view.addSubview(tray)
        tray.postsFrameChangedNotifications = true
    }

    /// Window buttons need the Accessibility permission; the gate turns them on and off.
    func setWindowButtons(enabled: Bool) {
        windowButtons.isHidden = !enabled
        guardian.isEnabled = enabled
        if enabled {
            windowMonitor.start()
            windowModel.refresh()
            guardian.sweep()
        } else {
            windowMonitor.stop()
        }
    }

    func show() {
        layout()
        panel.orderFrontRegardless()
        tray.start()
        let center = NotificationCenter.default
        // The clock or battery can change the tray's width; the window buttons take what's left.
        observers.append(center.addObserver(forName: NSView.frameDidChangeNotification, object: tray, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.layoutWindowButtons() }
        })
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
        // Only a click on Start itself is left to Start's toggle; tray and empty taskbar clicks close the menu.
        startMenu.open(at: CGPoint(x: frame.minX + Self.startMargin, y: frame.maxY), ignoresClick: { [weak self] event in
            guard let self, event.window === self.panel else { return false }
            return self.startButton.frame.contains(self.view.convert(event.locationInWindow, from: nil))
        }) { [weak self] in
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
        // Hidden until the Explorer is installed (install.sh restarts the Shell after installing it).
        quickLaunch.isHidden = !QuickLaunch.isAvailable { NSWorkspace.shared.urlForApplication(toOpen: $0) != nil }
        quickLaunch.frame = CGRect(x: startButton.frame.maxX + Self.buttonsGap - 2, y: 0, width: QuickLaunchView.width, height: frame.height)
        tray.relayout(height: TrayView.height)
        tray.setFrameOrigin(CGPoint(x: frame.width - tray.frame.width - Self.startMargin,
                                    y: ((frame.height - tray.frame.height) / 2).rounded(.down) + 1))
        layoutWindowButtons()
        guardian.sweep()
    }

    private func layoutWindowButtons() {
        let minX = (quickLaunch.isHidden ? startButton.frame.maxX : quickLaunch.frame.maxX) + Self.buttonsGap
        let maxX = tray.frame.minX - Self.buttonsGap
        windowButtons.frame = CGRect(x: minX, y: 0, width: max(maxX - minX, 0), height: view.bounds.height)
        windowButtons.needsDisplay = true
    }
}

enum LocalizedTitle {
    static let start = LocalizedText(en: "Start", ptBR: "Iniciar")
}
