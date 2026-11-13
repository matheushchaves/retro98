import Foundation
import Retro98Settings

public enum ShellIdentity {
    public static let label = ShellAgent.label
    public static let launchHistoryFileName = "shell-launches.plist"

    /// Disable first so launchd won't start the Shell again at the next login, then stop it now.
    /// The installer re-enables it.
    public static func giveUpCommands(uid: uid_t) -> [[String]] {
        let service = "gui/\(uid)/\(label)"
        return [["/bin/launchctl", "disable", service], ["/bin/launchctl", "bootout", service]]
    }

    /// Starts the LaunchAgent's copy if it isn't running (a no-op when it is).
    public static func handOverCommand(uid: uid_t) -> [String] {
        ["/bin/launchctl", "kickstart", "gui/\(uid)/\(label)"]
    }
}

/// Who draws the taskbar. Only the copy launchd starts from the LaunchAgent does: uninstall can stop it,
/// crash recovery watches it, and there is never a second taskbar. A copy opened any other way
/// (System Settings' "Quit & Reopen" after a permission change, Finder, the Start menu) hands over and quits.
public enum ShellLaunch {
    public enum Role: Equatable, Sendable {
        case runTaskbar, handOverToLaunchAgent, quitAsDuplicate
    }

    /// `serviceName` is the XPC_SERVICE_NAME launchd sets: the agent's label for the LaunchAgent's copy.
    public static func role(serviceName: String?, agentInstalled: Bool, otherCopyRunning: Bool) -> Role {
        if serviceName == ShellIdentity.label { return .runTaskbar }
        if agentInstalled { return .handOverToLaunchAgent }
        // Not installed (run from a build folder): fine, as long as it's the only taskbar.
        return otherCopyRunning ? .quitAsDuplicate : .runTaskbar
    }
}

/// Counts Shell launches that were not followed by a clean exit, to detect crash loops.
public struct LaunchHistory {
    public static let window: TimeInterval = 60
    public static let maxLaunches = 3

    private let url: URL
    private let files: FileStore

    public init(url: URL, files: FileStore) {
        self.url = url
        self.files = files
    }

    /// Records this launch; true when the Shell should give up: more than `maxLaunches` launches
    /// without a clean exit within `window` seconds, i.e. the normal launch plus `maxLaunches` crashes.
    public func recordLaunch(now: Date) throws -> Bool {
        let recent = load().filter { now.timeIntervalSince($0) < Self.window } + [now]
        try files.write(try PropertyListEncoder().encode(recent), to: url)
        return recent.count > Self.maxLaunches
    }

    public func recordCleanExit() throws {
        try files.write(nil, to: url)
    }

    /// A missing or unreadable history counts as empty.
    private func load() -> [Date] {
        guard let data = try? files.read(url) else { return [] }
        return (try? PropertyListDecoder().decode([Date].self, from: data)) ?? []
    }
}
