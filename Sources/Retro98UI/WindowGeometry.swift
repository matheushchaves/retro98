import CoreGraphics

/// Which window edges a resize drag moves.
public struct ResizeEdge: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let left = ResizeEdge(rawValue: 1 << 0)
    public static let right = ResizeEdge(rawValue: 1 << 1)
    public static let top = ResizeEdge(rawValue: 1 << 2)
    public static let bottom = ResizeEdge(rawValue: 1 << 3)
}

/// Pure geometry of retro app windows.
public enum WindowGeometry {
    public static let border: CGFloat = 4
    public static let titleHeight: CGFloat = 18
    public static let cornerGrip: CGFloat = 12
    public static let minimumSize = CGSize(width: 320, height: 240)

    /// Maximize area in AppKit coordinates (y up): the visible frame minus the taskbar at the bottom.
    public static func maximizedFrame(visibleFrame: CGRect, taskbarHeight: CGFloat) -> CGRect {
        CGRect(x: visibleFrame.minX, y: visibleFrame.minY + taskbarHeight,
               width: visibleFrame.width, height: visibleFrame.height - taskbarHeight)
    }

    /// Edges under `point` (flipped window coordinates); within 12 pt of a corner both edges count.
    public static func edge(at point: CGPoint, windowSize size: CGSize) -> ResizeEdge? {
        let nearLeft = point.x < border
        let nearRight = point.x >= size.width - border
        let nearTop = point.y < border
        let nearBottom = point.y >= size.height - border
        guard nearLeft || nearRight || nearTop || nearBottom else { return nil }
        let onHorizontalSide = nearTop || nearBottom
        let onVerticalSide = nearLeft || nearRight
        var edge: ResizeEdge = []
        if nearLeft || (onHorizontalSide && point.x < cornerGrip) { edge.insert(.left) }
        if nearRight || (onHorizontalSide && point.x >= size.width - cornerGrip) { edge.insert(.right) }
        if nearTop || (onVerticalSide && point.y < cornerGrip) { edge.insert(.top) }
        if nearBottom || (onVerticalSide && point.y >= size.height - cornerGrip) { edge.insert(.bottom) }
        return edge
    }

    /// New frame (AppKit, y up) after dragging `edge` by `delta` (AppKit, y up), never below `minimumSize`.
    public static func resized(_ frame: CGRect, edge: ResizeEdge, delta: CGVector, minimumSize: CGSize) -> CGRect {
        var minX = frame.minX, maxX = frame.maxX, minY = frame.minY, maxY = frame.maxY
        if edge.contains(.left) { minX = min(frame.minX + delta.dx, maxX - minimumSize.width) }
        if edge.contains(.right) { maxX = max(frame.maxX + delta.dx, minX + minimumSize.width) }
        if edge.contains(.bottom) { minY = min(frame.minY + delta.dy, maxY - minimumSize.height) }
        if edge.contains(.top) { maxY = max(frame.maxY + delta.dy, minY + minimumSize.height) }
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
}
