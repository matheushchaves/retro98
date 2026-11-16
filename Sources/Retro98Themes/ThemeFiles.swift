import AppKit
import Retro98UI

/// Writes the theme files that are generated rather than kept as text in the repository.
public enum ThemeFiles {
    public enum Failure: Error, Equatable {
        case fontNotFound, imageNotDrawn
    }

    /// The pictures the Chrome manifest points to, relative to the theme's folder.
    public static let chromeImagePaths = ["images/theme_frame.png", "images/theme_frame_inactive.png"]

    /// Writes Chrome/images/theme_frame.png, Chrome/images/theme_frame_inactive.png and the Terminal profile
    /// into `folder` (created if needed). The VGA font at `fontURL` is registered first, because the profile
    /// carries it; without the font nothing is written.
    public static func write(to folder: URL, fontURL: URL) throws {
        guard VGAFont.register(at: fontURL) else { throw Failure.fontNotFound }
        let chrome = folder.appending(path: "Chrome")
        try FileManager.default.createDirectory(at: chrome.appending(path: "images"), withIntermediateDirectories: true)
        for (path, active) in zip(chromeImagePaths, [true, false]) {
            guard let png = ChromeThemeImages.png(ChromeThemeImages.frame(active: active)) else { throw Failure.imageNotDrawn }
            try png.write(to: chrome.appending(path: path), options: .atomic)
        }
        try TerminalProfile.data(font: VGAFont.make()).write(to: folder.appending(path: TerminalProfile.fileName), options: .atomic)
    }
}
