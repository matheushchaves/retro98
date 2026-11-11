import AppKit
import Retro98Settings
import Retro98ShellCore
import Retro98UI

/// Crash-loop protection: launchd relaunches the Shell after a crash; after 3 crashes
/// within a minute the Shell gives the Dock back, says so, and turns itself off.
@MainActor
enum Recovery {
    private static var terminationSource: DispatchSourceSignal?

    static var history: LaunchHistory {
        let paths = SystemEngine.make().paths
        return LaunchHistory(url: paths.supportDirectory.appending(path: ShellIdentity.launchHistoryFileName),
                             files: LocalFileStore())
    }

    /// Returns false when the Shell must not start (it has given up).
    static func shouldStart(languages: [String]) -> Bool {
        let givesUp = (try? history.recordLaunch(now: Date())) ?? false
        if givesUp { giveUp(languages: languages) }
        return !givesUp
    }

    static func recordCleanExit() {
        try? history.recordCleanExit()
    }

    /// launchctl bootout and logout send SIGTERM; treat it as a clean exit so it never counts as a crash.
    static func handleTermination() {
        signal(SIGTERM, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
        source.setEventHandler {
            MainActor.assumeIsolated { recordCleanExit() }
            exit(0)
        }
        source.resume()
        terminationSource = source
    }

    private static func giveUp(languages: [String]) {
        _ = try? SystemEngine.make().engine.restore([.dockUnderTaskbar])
        recordCleanExit()
        _ = RetroMessageBox.run(
            title: "Retro98 Shell",
            message: LocalizedText(
                en: "Retro98 Shell stopped working several times and was turned off. The Dock is back to normal. "
                    + "To turn it on again, run ./install.sh.",
                ptBR: "O Retro98 Shell parou de funcionar várias vezes e foi desligado. O Dock voltou ao normal. "
                    + "Para ligar de novo, rode ./install.sh."
            ).resolve(for: languages),
            icon: .warning, buttons: ["OK"]
        )
        _ = ProcessCommandRunner().run("/bin/launchctl", ["bootout", "gui/\(getuid())/\(ShellIdentity.label)"])
        exit(0)
    }
}
