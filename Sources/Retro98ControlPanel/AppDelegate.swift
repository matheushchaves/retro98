import AppKit
import Retro98Settings

/// One Control Panel window; closing it quits, like a settings app.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let services: ControlPanelServices
    let prompter: ControlPanelPrompter
    /// Tests build the window without putting it on screen.
    var presentsWindows = true
    private(set) var controller: ControlPanelWindowController?

    init(services: ControlPanelServices? = nil, prompter: ControlPanelPrompter = RetroControlPanelPrompter()) {
        self.services = services ?? LiveControlPanelServices()
        self.prompter = prompter
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        showWindow(nil)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWindow(nil) }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    /// Settings… (⌘,) and reopening bring the window back.
    @objc func showWindow(_ sender: Any?) {
        let controller = controller ?? makeController()
        if presentsWindows { controller.show() }
    }

    private func makeController() -> ControlPanelWindowController {
        let controller = ControlPanelWindowController(services: services, prompter: prompter)
        controller.onClose = { [weak self] in self?.controller = nil }
        self.controller = controller
        return controller
    }

    @objc func showAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [.applicationName: ControlPanelText.appName])
        NSApp.activate()
    }

    @objc func openHelp(_ sender: Any?) { NSWorkspace.shared.open(ControlPanelMenus.helpURL) }
}
