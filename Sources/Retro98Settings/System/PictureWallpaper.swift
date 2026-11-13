import AppKit

public enum PictureWallpaperError: Error, Equatable {
    case notAnImage
}

/// A picture chosen as the wallpaper is copied into the support folder, so it survives the original
/// being moved, and its `wallpaper-` name lets the uninstaller recognize it as Retro98's.
public enum PictureWallpaper {
    static let prefix = "wallpaper-picture-"

    public static func adopt(_ source: URL, paths: Retro98Paths, now: Date = Date()) throws -> WallpaperChoice {
        guard NSImage(contentsOf: source) != nil else { throw PictureWallpaperError.notAnImage }
        let fileManager = FileManager.default
        let folder = paths.supportDirectory
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let pathExtension = source.pathExtension.lowercased()
        let name = prefix + String(Int(now.timeIntervalSince1970)) + (pathExtension.isEmpty ? "" : ".\(pathExtension)")
        let copy = folder.appending(path: name)
        // A new name each time: the wallpaper agent caches images by path.
        for old in try fileManager.contentsOfDirectory(atPath: folder.path) where old.hasPrefix(prefix) && old != name {
            try fileManager.removeItem(at: folder.appending(path: old))
        }
        if fileManager.fileExists(atPath: copy.path) { try fileManager.removeItem(at: copy) }
        try fileManager.copyItem(at: source, to: copy)
        return .picture(path: copy.path, name: source.lastPathComponent)
    }
}
