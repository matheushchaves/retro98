import AppKit

/// Sets a solid-color wallpaper on every screen through the public NSWorkspace API, and puts
/// back the wallpaper agent's store on restore.
public struct MacWallpaperSetter: WallpaperSetter {
    /// The picture macOS itself uses when no wallpaper was chosen (kept current by the system).
    static let systemDefaultPicture = URL(filePath: "/System/Library/CoreServices/DefaultDesktop.heic")

    /// How a picture covers the screen.
    public enum Fit: Sendable {
        /// Stretched to the screen (a solid color has no proportions to keep).
        case stretch
        /// Scaled to fill the screen, cropping what overflows.
        case fill
    }

    private let paths: Retro98Paths
    private let files: FileStore
    private let runner: CommandRunner
    private let setDesktopImage: (URL, Fit) throws -> Void

    public init(
        paths: Retro98Paths, files: FileStore, runner: CommandRunner = ProcessCommandRunner(),
        setDesktopImage: @escaping (URL, Fit) throws -> Void = Self.showOnEveryScreen
    ) {
        self.paths = paths
        self.files = files
        self.runner = runner
        self.setDesktopImage = setDesktopImage
    }

    public static func showOnEveryScreen(_ url: URL, fit: Fit) throws {
        let scaling: NSImageScaling = fit == .stretch ? .scaleAxesIndependently : .scaleProportionallyUpOrDown
        try MainActor.assumeIsolated {
            for screen in NSScreen.screens {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [
                    .imageScaling: scaling.rawValue,
                    .allowClipping: true,
                ])
            }
        }
    }

    public func setSolidColor(hex: String) throws {
        let url = paths.wallpaperImage(hex: hex)
        try files.write(try SolidColorImage.pngData(hex: hex), to: url)
        try setDesktopImage(url, .stretch)
    }

    public func setPicture(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: url.path]) }
        try setDesktopImage(url, .fill)
    }

    public func restoreIndex(_ original: Data?, at index: URL) throws -> WallpaperRestore {
        // Saved over an uninstall that left Retro98's color behind: writing it back would bring the color back.
        if let original, WallpaperIndex.showsRetro98Image(original, paths: paths) {
            try setDesktopImage(Self.systemDefaultPicture, .fill)
            return .systemDefault
        }
        guard (try? files.read(index)) != original else { return .original }
        // The agent rewrites its store from memory at any moment, so it would overwrite the restored file.
        // Freeze it while writing, then kill it (no exit handler runs) so launchd starts it again reading the file.
        _ = runner.run("/usr/bin/killall", ["-STOP", "WallpaperAgent"])
        defer { _ = runner.run("/usr/bin/killall", ["-KILL", "WallpaperAgent"]) }
        try files.write(original, to: index)
        return .original
    }
}
