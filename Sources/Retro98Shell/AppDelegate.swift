import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var taskbar: TaskbarController?
    private var hotKey: HotKey?
    private var accessibility: AccessibilityGate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let languages = Locale.preferredLanguages
        Recovery.handleTermination()
        guard Recovery.shouldStart(languages: languages) else { return }
        let taskbar = TaskbarController(languages: languages)
        taskbar.show()
        let gate = AccessibilityGate(languages: languages) { [weak taskbar] trusted in
            taskbar?.setWindowButtons(enabled: trusted)
        }
        accessibility = gate
        hotKey = HotKey { [weak taskbar] in taskbar?.toggleStartMenu() }
        self.taskbar = taskbar
        gate.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        Recovery.recordCleanExit()
    }
}
