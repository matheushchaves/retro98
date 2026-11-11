import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var taskbar: TaskbarController?
    private var hotKey: HotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let languages = Locale.preferredLanguages
        Recovery.handleTermination()
        guard Recovery.shouldStart(languages: languages) else { return }
        let taskbar = TaskbarController(languages: languages)
        taskbar.show()
        hotKey = HotKey { [weak taskbar] in taskbar?.toggleStartMenu() }
        self.taskbar = taskbar
    }

    func applicationWillTerminate(_ notification: Notification) {
        Recovery.recordCleanExit()
    }
}
