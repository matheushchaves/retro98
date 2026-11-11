import CoreGraphics

/// Keeps windows that reach the bottom of the main screen out from under the taskbar,
/// since the hidden Dock no longer makes macOS reserve that space.
/// Coordinates are Accessibility's: origin at the main screen's top-left, y growing down.
public enum WorkAreaGuard {
    public static let bottomTolerance: CGFloat = 6
    /// Only events where the size changed (zoom, Fill, tiling) or a window appeared. Moves are ignored
    /// so the guard never fights a window being dragged.
    public static let checkedNotifications: Set<String> = ["AXWindowCreated", "AXWindowResized"]

    public static func shouldCheck(notification: String) -> Bool {
        checkedNotifications.contains(notification)
    }

    /// The new size for a window that touches (or passes) the bottom of the screen and covers the taskbar;
    /// nil when the window must be left alone. Only the height changes.
    /// Full-screen windows are never touched (the taskbar is hidden there anyway).
    public static func adjustedSize(window: CGRect, screen: CGRect, taskbarHeight: CGFloat, isFullScreen: Bool = false) -> CGSize? {
        let workBottom = screen.maxY - taskbarHeight
        guard !isFullScreen,
              window.intersects(screen),
              window.maxY >= screen.maxY - bottomTolerance,
              window.maxY > workBottom + 1,
              window.minY < workBottom
        else { return nil }
        return CGSize(width: window.width, height: workBottom - window.minY)
    }
}
