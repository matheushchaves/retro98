import CoreGraphics

public enum IconGridStyle: Equatable, Sendable {
    case largeIcons, smallIcons, list, details
}

public enum MoveDirection: Sendable {
    case left, right, up, down
}

/// A Details column; the first one (the name) takes whatever width the others leave.
public struct GridColumn: Equatable, Sendable {
    public static let nameMinimum: CGFloat = 160

    public let title: String
    public let width: CGFloat
    public let alignsRight: Bool

    public init(title: String, width: CGFloat, alignsRight: Bool = false) {
        self.title = title
        self.width = width
        self.alignsRight = alignsRight
    }

    public static func widths(_ columns: [GridColumn], totalWidth: CGFloat) -> [CGFloat] {
        guard !columns.isEmpty else { return [] }
        let others = columns.dropFirst().map(\.width)
        return [max(nameMinimum, totalWidth - others.reduce(0, +))] + others
    }
}

/// Where each item goes in each view mode: large icons fill rows (88×76), small icons fill rows of
/// 150×20 cells, the list fills columns of 180×18 cells and scrolls sideways, details stack 18 pt rows.
public struct IconGridGeometry: Equatable, Sendable {
    public static let smallCell = CGSize(width: 150, height: 20)
    public static let listCell = CGSize(width: 180, height: 18)
    public static let rowHeight: CGFloat = 18
    static let inset: CGFloat = 8

    public let style: IconGridStyle
    public let visibleSize: CGSize
    public let count: Int

    public init(style: IconGridStyle, visibleSize: CGSize, count: Int) {
        self.style = style
        self.visibleSize = visibleSize
        self.count = count
    }

    /// Items per row (large and small icons).
    var columns: Int {
        switch style {
        case .largeIcons: IconGridLayout.columns(forWidth: visibleSize.width)
        case .smallIcons: max(1, Int(((visibleSize.width - Self.inset * 2) / Self.smallCell.width).rounded(.down)))
        case .list, .details: 1
        }
    }

    /// Items per column (list).
    var rows: Int { max(1, Int(((visibleSize.height - Self.inset * 2) / Self.listCell.height).rounded(.down))) }

    public var contentSize: CGSize {
        switch style {
        case .largeIcons:
            return CGSize(width: visibleSize.width,
                          height: max(IconGridLayout.contentHeight(count: count, columns: columns), visibleSize.height))
        case .smallIcons:
            let rowCount = (count + columns - 1) / columns
            return CGSize(width: visibleSize.width, height: max(Self.inset * 2 + CGFloat(rowCount) * Self.smallCell.height, visibleSize.height))
        case .list:
            let columnCount = (count + rows - 1) / rows
            return CGSize(width: max(Self.inset * 2 + CGFloat(columnCount) * Self.listCell.width, visibleSize.width), height: visibleSize.height)
        case .details:
            return CGSize(width: visibleSize.width, height: max(CGFloat(count) * Self.rowHeight, visibleSize.height))
        }
    }

    public func frame(of index: Int) -> CGRect {
        switch style {
        case .largeIcons:
            return IconGridLayout.frame(of: index, columns: columns)
        case .smallIcons:
            return CGRect(x: Self.inset + CGFloat(index % columns) * Self.smallCell.width,
                          y: Self.inset + CGFloat(index / columns) * Self.smallCell.height,
                          width: Self.smallCell.width, height: Self.smallCell.height)
        case .list:
            return CGRect(x: Self.inset + CGFloat(index / rows) * Self.listCell.width,
                          y: Self.inset + CGFloat(index % rows) * Self.listCell.height,
                          width: Self.listCell.width, height: Self.listCell.height)
        case .details:
            return CGRect(x: 0, y: CGFloat(index) * Self.rowHeight, width: visibleSize.width, height: Self.rowHeight)
        }
    }

    /// The 16 or 32 pt icon inside the item's cell.
    public func iconFrame(of index: Int) -> CGRect {
        let cell = frame(of: index)
        switch style {
        case .largeIcons: return CGRect(x: (cell.midX - 16).rounded(.down), y: cell.minY + 4, width: 32, height: 32)
        case .smallIcons: return CGRect(x: cell.minX + 2, y: cell.minY + 2, width: 16, height: 16)
        case .list, .details: return CGRect(x: cell.minX + 2, y: cell.minY + 1, width: 16, height: 16)
        }
    }

    /// Where the one-line label starts (small icons, list and details).
    public func labelX(of index: Int) -> CGFloat { frame(of: index).minX + 22 }

    public func index(at point: CGPoint) -> Int? {
        let found: Int?
        switch style {
        case .largeIcons:
            return IconGridLayout.index(at: point, columns: columns, count: count)
        case .smallIcons:
            guard point.x >= Self.inset, point.y >= Self.inset else { return nil }
            let column = Int(((point.x - Self.inset) / Self.smallCell.width).rounded(.down))
            guard column < columns else { return nil }
            found = Int(((point.y - Self.inset) / Self.smallCell.height).rounded(.down)) * columns + column
        case .list:
            guard point.x >= Self.inset, point.y >= Self.inset else { return nil }
            let row = Int(((point.y - Self.inset) / Self.listCell.height).rounded(.down))
            guard row < rows else { return nil }
            found = Int(((point.x - Self.inset) / Self.listCell.width).rounded(.down)) * rows + row
        case .details:
            guard point.y >= 0, point.x >= 0 else { return nil }
            found = Int((point.y / Self.rowHeight).rounded(.down))
        }
        return found.flatMap { $0 < count ? $0 : nil }
    }

    /// Items whose cells meet `rect` (only the visible part is ever asked for).
    public func indices(in rect: CGRect) -> [Int] {
        switch style {
        case .largeIcons:
            return Array(IconGridLayout.indices(in: rect, columns: columns, count: count))
        case .smallIcons:
            let rows = lines(from: rect.minY - Self.inset, to: rect.maxY - Self.inset, step: Self.smallCell.height)
            return clamp(rows.lowerBound * columns..<rows.upperBound * columns)
        case .list:
            let columnRange = lines(from: rect.minX - Self.inset, to: rect.maxX - Self.inset, step: Self.listCell.width)
            let rowRange = lines(from: rect.minY - Self.inset, to: rect.maxY - Self.inset, step: Self.listCell.height)
            let visibleRows = rowRange.clamped(to: 0..<rows)
            return columnRange.flatMap { column in visibleRows.map { column * rows + $0 } }.filter { $0 < count }
        case .details:
            let rows = lines(from: rect.minY, to: rect.maxY, step: Self.rowHeight)
            return clamp(rows)
        }
    }

    /// Arrow keys: by item along the flow, by a row or column across it; details move only up and down.
    public func move(from index: Int?, _ direction: MoveDirection) -> Int? {
        guard count > 0 else { return nil }
        guard let index else { return 0 }
        let step: Int?
        switch (style, direction) {
        case (.largeIcons, .left), (.smallIcons, .left), (.list, .up), (.details, .up): step = -1
        case (.largeIcons, .right), (.smallIcons, .right), (.list, .down), (.details, .down): step = 1
        case (.largeIcons, .up), (.smallIcons, .up): step = -columns
        case (.largeIcons, .down), (.smallIcons, .down): step = columns
        case (.list, .left): step = -rows
        case (.list, .right): step = rows
        case (.details, .left), (.details, .right): step = nil
        }
        return step.map { min(max(index + $0, 0), count - 1) }
    }

    private func lines(from start: CGFloat, to end: CGFloat, step: CGFloat) -> Range<Int> {
        let first = max(0, Int((start / step).rounded(.down)))
        return first..<max(first, Int((end / step).rounded(.up)))
    }

    private func clamp(_ range: Range<Int>) -> [Int] {
        Array(min(range.lowerBound, count)..<min(range.upperBound, count))
    }
}
