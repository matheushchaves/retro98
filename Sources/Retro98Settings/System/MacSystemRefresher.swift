import Foundation

public protocol CommandRunner {
    /// Runs a command to completion and returns its exit status (-1 if it could not start).
    func run(_ executable: String, _ arguments: [String]) -> Int32
}

public struct ProcessCommandRunner: CommandRunner {
    public init() {}

    public func run(_ executable: String, _ arguments: [String]) -> Int32 {
        let process = Process()
        process.executableURL = URL(filePath: executable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
        } catch {
            return -1
        }
        process.waitUntilExit()
        return process.terminationStatus
    }
}

/// Makes running apps pick up changed preferences: restarts Finder or the wallpaper agent,
/// broadcasts the system's own change notifications and switches appearance live.
public struct MacSystemRefresher: SystemRefresher {
    private let runner: CommandRunner
    private let post: (String) -> Void

    public init(runner: CommandRunner = ProcessCommandRunner(), post: @escaping (String) -> Void = postDistributed) {
        self.runner = runner
        self.post = post
    }

    public static func postDistributed(_ name: String) {
        DistributedNotificationCenter.default().postNotificationName(
            Notification.Name(name), object: nil, userInfo: nil, deliverImmediately: true
        )
    }

    public func switchAppearance(toDark dark: Bool) -> Bool {
        let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to \(dark)"
        return runner.run("/usr/bin/osascript", ["-e", script]) == 0
    }

    public func perform(_ effects: Set<RefreshEffect>) {
        for effect in effects {
            switch effect {
            case .restartFinder:
                _ = runner.run("/usr/bin/killall", ["Finder"])
            case .restartWallpaperAgent:
                _ = runner.run("/usr/bin/killall", ["WallpaperAgent"])
            case .notifyColorChange:
                post("AppleColorPreferencesChangedNotification")
                post("AppleAquaColorVariantChanged")
            case .notifyScrollBarChange:
                post("AppleShowScrollBarsSettingChanged")
            case .syncAppearance:
                break // handled before writes by switchAppearance(toDark:)
            }
        }
    }
}
