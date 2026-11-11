public protocol WallpaperSetter {
    func setSolidColor(hex: String) throws
}

public protocol SystemRefresher {
    /// Called before preference writes. Returns false when the live switch was not possible.
    func switchAppearance(toDark dark: Bool) -> Bool
    /// Called once, after preference writes.
    func perform(_ effects: Set<RefreshEffect>)
}
