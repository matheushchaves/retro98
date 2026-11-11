import Foundation
import Retro98Settings

public enum ShellIdentity {
    public static let label = "io.github.matheushchaves.retro98.shell"
    public static let launchHistoryFileName = "shell-launches.plist"

    /// Disable first so launchd won't start the Shell again at the next login, then stop it now.
    /// The installer re-enables it.
    public static func giveUpCommands(uid: uid_t) -> [[String]] {
        let service = "gui/\(uid)/\(label)"
        return [["/bin/launchctl", "disable", service], ["/bin/launchctl", "bootout", service]]
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

    /// Records this launch; true when the Shell should give up
    /// (`maxLaunches` launches without a clean exit within `window` seconds).
    public func recordLaunch(now: Date) throws -> Bool {
        let recent = load().filter { now.timeIntervalSince($0) < Self.window } + [now]
        try files.write(try PropertyListEncoder().encode(recent), to: url)
        return recent.count >= Self.maxLaunches
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
