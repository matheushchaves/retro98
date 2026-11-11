import AppKit

/// Sets a solid-color wallpaper on every screen through the public NSWorkspace API.
public struct MacWallpaperSetter: WallpaperSetter {
    private let paths: Retro98Paths
    private let files: FileStore

    public init(paths: Retro98Paths, files: FileStore) {
        self.paths = paths
        self.files = files
    }

    public func setSolidColor(hex: String) throws {
        let url = paths.wallpaperImage(hex: hex)
        try files.write(try SolidColorImage.pngData(hex: hex), to: url)
        try MainActor.assumeIsolated {
            for screen in NSScreen.screens {
                try NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [
                    .imageScaling: NSImageScaling.scaleAxesIndependently.rawValue,
                    .allowClipping: true,
                ])
            }
        }
    }
}
