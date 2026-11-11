import CoreGraphics

/// Large-icon grid geometry: 88×76 cells filled row by row, 8 pt inset.
public enum IconGridLayout {
    public static let cell = CGSize(width: 88, height: 76)
    public static let inset: CGFloat = 8

    public static func columns(forWidth width: CGFloat) -> Int {
        max(1, Int(((width - inset * 2) / cell.width).rounded(.down)))
    }

    public static func frame(of index: Int, columns: Int) -> CGRect {
        CGRect(x: inset + CGFloat(index % columns) * cell.width, y: inset + CGFloat(index / columns) * cell.height,
               width: cell.width, height: cell.height)
    }

    public static func contentHeight(count: Int, columns: Int) -> CGFloat {
        let rows = (count + columns - 1) / columns
        return inset * 2 + CGFloat(rows) * cell.height
    }

    /// Indices whose cells intersect `rect` (rows that touch it, clamped to `count`).
    public static func indices(in rect: CGRect, columns: Int, count: Int) -> Range<Int> {
        let firstRow = max(0, Int(((rect.minY - inset) / cell.height).rounded(.down)))
        let endRow = max(firstRow, Int(((rect.maxY - inset) / cell.height).rounded(.up)))
        let start = min(firstRow * columns, count)
        return start..<min(endRow * columns, count)
    }

    public static func index(at point: CGPoint, columns: Int, count: Int) -> Int? {
        guard point.x >= inset, point.y >= inset else { return nil }
        let column = Int(((point.x - inset) / cell.width).rounded(.down))
        let row = Int(((point.y - inset) / cell.height).rounded(.down))
        guard column < columns else { return nil }
        let index = row * columns + column
        return index < count ? index : nil
    }
}

public struct TreeRow: Equatable, Sendable {
    public let id: String
    public let depth: Int

    public init(id: String, depth: Int) {
        self.id = id
        self.depth = depth
    }
}

public enum TreeRows {
    /// Depth-first rows of the visible tree: children appear only under expanded ids.
    public static func flatten(roots: [String], children: (String) -> [String], expanded: Set<String>) -> [TreeRow] {
        func visit(_ id: String, depth: Int) -> [TreeRow] {
            let row = TreeRow(id: id, depth: depth)
            guard expanded.contains(id) else { return [row] }
            return [row] + children(id).flatMap { visit($0, depth: depth + 1) }
        }
        return roots.flatMap { visit($0, depth: 0) }
    }
}
