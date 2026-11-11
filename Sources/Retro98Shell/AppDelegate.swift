import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var taskbar: TaskbarController?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let taskbar = TaskbarController(languages: Locale.preferredLanguages)
        taskbar.show()
        hotKey = HotKey { [weak taskbar] in taskbar?.toggleStartMenu() }
        self.taskbar = taskbar
    }
}
