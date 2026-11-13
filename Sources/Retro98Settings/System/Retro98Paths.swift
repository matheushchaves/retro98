import Foundation

public struct Retro98Paths: Equatable, Sendable {
    /// Environment variable that relocates the support folder (tests and scripts).
    public static let supportOverrideVariable = "RETRO98_SUPPORT_DIR"

    public let supportDirectory: URL
    public let wallpaperIndex: URL

    public var backupFile: URL { supportDirectory.appending(path: "backup.plist") }
    public var choicesFile: URL { supportDirectory.appending(path: "choices.plist") }

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
            wallpaperIndex: applicationSupport.appending(path: "com.apple.wallpaper/Store/Index.plist")
        )
    }
}
