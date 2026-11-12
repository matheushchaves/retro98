import Foundation

/// What a restored wallpaper shows.
public enum WallpaperRestore: Equatable, Sendable {
    /// The wallpaper saved before Retro98 changed it.
    case original
    /// macOS's own picture: the saved wallpaper was Retro98's color, so it could not be put back.
    case systemDefault
}

public protocol WallpaperSetter {
    func setSolidColor(hex: String) throws
    /// Puts back the wallpaper agent's store as it was before the first apply (nil: there was none).
    func restoreIndex(_ original: Data?, at index: URL) throws -> WallpaperRestore
}

public protocol SystemRefresher {
    /// Called before preference writes. Returns false when the live switch was not possible.
    func switchAppearance(toDark dark: Bool) -> Bool
    /// Called once, after preference writes.
    func perform(_ effects: Set<RefreshEffect>)
}
