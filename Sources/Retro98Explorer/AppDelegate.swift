import AppKit
import Retro98FilesCore

/// Opens one window per `retro98-explorer://` URL, or a Desktop window when launched or reopened plainly.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controllers: [ExplorerWindowController] = []
    let languages = Locale.preferredLanguages

    var active: ExplorerWindowController? {
        controllers.first { $0.window.isKeyWindow } ?? controllers.first { $0.window.isMainWindow } ?? controllers.last
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // URLs that launched the app arrive right after this; only open the Desktop if none did.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.controllers.isEmpty else { return }
            self.openWindow(at: .desktop)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        urls.compactMap(ExplorerURL.location(from:)).forEach { openWindow(at: $0) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openWindow(at: .desktop) }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func openWindow(at location: Location) {
        let controller = ExplorerWindowController(start: location, languages: languages)
        controller.onClose = { [weak self, weak controller] in
            self?.controllers.removeAll { $0 === controller }
        }
        controllers.append(controller)
        controller.show()
    }

    // MARK: Menu actions (both menu bars send these up the responder chain)

    @objc func newWindow(_ sender: Any?) { openWindow(at: active?.model.history.current ?? .desktop) }
    @objc func closeWindow(_ sender: Any?) { active?.window.performClose(nil) }
    @objc func goBack(_ sender: Any?) { active?.model.back() }
    @objc func goForward(_ sender: Any?) { active?.model.forward() }
    @objc func goUp(_ sender: Any?) { active?.model.up() }
    @objc func refresh(_ sender: Any?) { active?.model.reload() }
    @objc func goDesktop(_ sender: Any?) { active?.model.go(to: .desktop) }
    @objc func goMyComputer(_ sender: Any?) { active?.model.go(to: .myComputer) }
    @objc func goDocuments(_ sender: Any?) { active?.go(toHomeFolder: "Documents") }
    @objc func goDownloads(_ sender: Any?) { active?.go(toHomeFolder: "Downloads") }
    @objc func goApplications(_ sender: Any?) { active?.model.go(to: .folder(URL(filePath: "/Applications"))) }
    @objc func openHelp(_ sender: Any?) { NSWorkspace.shared.open(ExplorerMenus.helpURL) }
}
