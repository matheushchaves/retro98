import AppKit

public enum ShellAgentError: Error, Equatable {
    case notInstalled
    case launchctlFailed(Int32)
}

/// The taskbar's on/off switch, for whoever turns it on and off besides the installer.
public protocol ShellSwitch {
    var isInstalled: Bool { get }
    var isOn: Bool { get }
    func turnOn() throws
    func turnOff()
}

/// Turns the Retro98 Shell's LaunchAgent on and off the way install.sh does, without rebuilding anything.
/// The Dock tweak is the caller's business.
public struct ShellAgent: ShellSwitch {
    public static let label = "io.github.matheushchaves.retro98.shell"
    static let quitTimeout: TimeInterval = 5

    private let paths: Retro98Paths
    private let files: FileStore
    private let runner: CommandRunner
    private let uid: uid_t
    private let exists: (URL) -> Bool
    private let stopCopies: () -> Void

    public init(
        paths: Retro98Paths, files: FileStore, runner: CommandRunner, uid: uid_t = getuid(),
        exists: @escaping (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) },
        stopCopies: @escaping () -> Void = ShellAgent.terminateRunningCopies
    ) {
        self.paths = paths
        self.files = files
        self.runner = runner
        self.uid = uid
        self.exists = exists
        self.stopCopies = stopCopies
    }

    public var isInstalled: Bool { exists(paths.shellApp) }
    public var isOn: Bool { ((try? files.read(paths.launchAgentPlist)) ?? nil) != nil }

    /// Same keys as the heredoc in install.sh; keep the two in step.
    public static func plist(executable: String) throws -> Data {
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [executable],
            "RunAtLoad": true,
            "KeepAlive": ["SuccessfulExit": false],
            "ThrottleInterval": 5,
            "ProcessType": "Interactive",
        ]
        return try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
    }

    /// Enables first: a Shell that gave up after crashing disabled itself.
    public func turnOn() throws {
        guard isInstalled else { throw ShellAgentError.notInstalled }
        let executable = paths.shellApp.appending(path: "Contents/MacOS/Retro98Shell").path
        try files.write(try Self.plist(executable: executable), to: paths.launchAgentPlist)
        _ = runner.run("/bin/launchctl", ["enable", service])
        let status = runner.run("/bin/launchctl", ["bootstrap", "gui/\(uid)", paths.launchAgentPlist.path])
        // The plist stays: the next login starts the taskbar anyway.
        guard status == 0 else { throw ShellAgentError.launchctlFailed(status) }
    }

    /// Stops the LaunchAgent's copy and any copy opened outside launchd, then removes the agent.
    public func turnOff() {
        _ = runner.run("/bin/launchctl", ["bootout", service])
        stopCopies()
        try? files.write(nil, to: paths.launchAgentPlist)
    }

    private var service: String { "gui/\(uid)/\(Self.label)" }

    /// Asks every running Shell to quit, then forces the ones still running after `quitTimeout`.
    public static func terminateRunningCopies() {
        MainActor.assumeIsolated {
            let copies = NSRunningApplication.runningApplications(withBundleIdentifier: label)
            copies.forEach { $0.terminate() }
            let deadline = Date().addingTimeInterval(quitTimeout)
            while copies.contains(where: { !$0.isTerminated }) && Date() < deadline {
                RunLoop.current.run(until: Date().addingTimeInterval(0.1))
            }
            copies.filter { !$0.isTerminated }.forEach { $0.forceTerminate() }
        }
    }
}
