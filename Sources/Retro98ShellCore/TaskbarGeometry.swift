import CoreGraphics

public enum TaskbarGeometry {
    public static let minimumHeight: CGFloat = 28

    /// Bottom of the screen, full width, tall enough to cover whatever the Dock reserves.
    public static func frame(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        let dockReserved = visibleFrame.minY - screenFrame.minY
        return CGRect(x: screenFrame.minX, y: screenFrame.minY,
                      width: screenFrame.width, height: max(minimumHeight, dockReserved))
    }
}
