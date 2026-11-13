import Foundation

public struct Retro98Paths: Equatable, Sendable {
    /// Environment variable that relocates the support folder (tests and scripts).
    public static let supportOverrideVariable = "RETRO98_SUPPORT_DIR"
    /// Relocates the alert sound folder (tests and scripts).
    public static let soundsOverrideVariable = "RETRO98_SOUNDS_DIR"
    static let soundsSubpath = "Library/Sounds"
    /// Relocate the apps and the LaunchAgent (tests), like the scripts' variables of the same names.
    public static let appsOverrideVariable = "RETRO98_APPS_DIR"
    public static let launchAgentsOverrideVariable = "RETRO98_LAUNCH_AGENTS_DIR"
    static let alertSoundName = "Retro98.aiff"

    public let supportDirectory: URL
    public let wallpaperIndex: URL
    /// Where macOS looks for the person's own alert sounds.
    public let soundsDirectory: URL
    public let appsDirectory: URL
    public let launchAgentsDirectory: URL

    public var backupFile: URL { supportDirectory.appending(path: "backup.plist") }
    public var choicesFile: URL { supportDirectory.appending(path: "choices.plist") }
    public var alertSoundFile: URL { soundsDirectory.appending(path: Self.alertSoundName) }
    public var piecesFile: URL { supportDirectory.appending(path: "pieces") }
    public var shellApp: URL { appsDirectory.appending(path: "Retro98 Shell.app") }
    public var explorerApp: URL { appsDirectory.appending(path: "Retro98 Explorer.app") }
    public var controlPanelApp: URL { appsDirectory.appending(path: "Retro98 Control Panel.app") }
    public var launchAgentPlist: URL { launchAgentsDirectory.appending(path: "\(ShellAgent.label).plist") }

    /// One file per color, so the wallpaper agent never shows a stale cached image.
    public func wallpaperImage(hex: String) -> URL {
        let name = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")).lowercased()
        return supportDirectory.appending(path: "wallpaper-\(name).png")
    }

    public static func standard(home: URL, environment: [String: String]) -> Retro98Paths {
        let applicationSupport = home.appending(path: "Library/Application Support")
        let support = environment[supportOverrideVariable].map { URL(filePath: $0) }
            ?? applicationSupport.appending(path: "Retro98")
        return Retro98Paths(
            supportDirectory: support,
            wallpaperIndex: applicationSupport.appending(path: "com.apple.wallpaper/Store/Index.plist"),
            soundsDirectory: environment[soundsOverrideVariable].map { URL(filePath: $0) } ?? home.appending(path: soundsSubpath),
            appsDirectory: environment[appsOverrideVariable].map { URL(filePath: $0) } ?? home.appending(path: "Applications/Retro98"),
            launchAgentsDirectory: environment[launchAgentsOverrideVariable].map { URL(filePath: $0) }
                ?? home.appending(path: "Library/LaunchAgents")
        )
    }
}
