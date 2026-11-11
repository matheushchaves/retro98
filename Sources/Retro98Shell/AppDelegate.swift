import AppKit
import Retro98Settings
import Retro98ShellCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var taskbar: TaskbarController?
    private var hotKey: HotKey?
    private var accessibility: AccessibilityGate?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let languages = Locale.preferredLanguages
        Recovery.handleTermination()
        guard Self.isTheTaskbarCopy() else { exit(0) }
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

    /// Decided before anything is drawn or counted as a launch (see ShellLaunch).
    private static func isTheTaskbarCopy() -> Bool {
        let agent = FileManager.default.homeDirectoryForCurrentUser
            .appending(path: "Library/LaunchAgents/\(ShellIdentity.label).plist")
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: ShellIdentity.label)
            .filter { $0.processIdentifier != ownPID }
        let role = ShellLaunch.role(serviceName: ProcessInfo.processInfo.environment["XPC_SERVICE_NAME"],
                                    agentInstalled: FileManager.default.fileExists(atPath: agent.path),
                                    otherCopyRunning: !others.isEmpty)
        switch role {
        case .runTaskbar:
            return true
        case .handOverToLaunchAgent:
            let command = ShellIdentity.handOverCommand(uid: getuid())
            _ = ProcessCommandRunner().run(command[0], Array(command.dropFirst()))
            return false
        case .quitAsDuplicate:
            return false
        }
    }
}
