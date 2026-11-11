import AppKit

@MainActor
public protocol RetroTreeDataSource: AnyObject {
    func tree(_ tree: RetroTreeView, childrenOf id: String) -> [String]
    func tree(_ tree: RetroTreeView, titleOf id: String) -> String
    func tree(_ tree: RetroTreeView, iconOf id: String) -> PixelIcon
    func tree(_ tree: RetroTreeView, isExpandable id: String) -> Bool
}

/// The folder tree: +/− boxes, dotted lines, 16-pt icons. Children load on expand.
/// Click the box to expand or collapse, click the title to select; ↑↓ move, → expands or goes down,
/// ← collapses or goes up.
@MainActor
public final class RetroTreeView: PixelView {
    static let rowHeight: CGFloat = 18
    static let indent: CGFloat = 18
    static let top: CGFloat = 2
    static let left: CGFloat = 4

    public weak var dataSource: RetroTreeDataSource?
    public var roots: [String] = [] { didSet { rebuild() } }
    public private(set) var expanded: Set<String> = []
    public private(set) var selected: String?
    public var onSelect: ((String) -> Void)?
    private var rows: [TreeRow] = []
    private var childrenCache: [String: [String]] = [:]
    private var parents: [String: String] = [:]

    // MARK: Data

    public func reloadData() {
        childrenCache = [:]
        rebuild()
    }

    /// Expands every id but the last and selects the last (without calling onSelect).
    public func reveal(path ids: [String]) {
        expanded.formUnion(ids.dropLast())
        selected = ids.last
        rebuild()
        if let selected, let row = rows.firstIndex(where: { $0.id == selected }) { scrollToVisible(rowRect(row)) }
    }

    private func children(of id: String) -> [String] {
        if let cached = childrenCache[id] { return cached }
        let loaded = dataSource?.tree(self, childrenOf: id) ?? []
        childrenCache[id] = loaded
        loaded.forEach { parents[$0] = id }
        return loaded
    }

    private func rebuild() {
        rows = TreeRows.flatten(roots: roots, children: children(of:), expanded: expanded)
        fitToClipView()
        needsDisplay = true
    }

    private func fitToClipView() {
        guard let clip = superview else { return }
        let widest = rows.map { row in
            Self.left + CGFloat(row.depth) * Self.indent + 34 + CGFloat(PixelText.width(of: dataSource?.tree(self, titleOf: row.id) ?? "", font: .regular))
        }.max() ?? 0
        setFrameSize(CGSize(width: max(clip.bounds.width, widest + 8),
                            height: max(clip.bounds.height, Self.top * 2 + CGFloat(rows.count) * Self.rowHeight)))
    }

    override public func resize(withOldSuperviewSize oldSize: NSSize) {
        fitToClipView()
    }

    private func rowRect(_ index: Int) -> CGRect {
        CGRect(x: 0, y: Self.top + CGFloat(index) * Self.rowHeight, width: bounds.width, height: Self.rowHeight)
    }

    private func boxRect(_ row: TreeRow, index: Int) -> CGRect {
        CGRect(x: Self.left + CGFloat(row.depth) * Self.indent, y: rowRect(index).minY + 4, width: 9, height: 9)
    }

    // MARK: Drawing

    override public func drawPixels(in context: CGContext, size: CGSize) {
        let clip = context.boundingBoxOfClipPath
        Bevel.fill(clip, color: .white, context: context)
        guard let dataSource, !rows.isEmpty else { return }
        let first = max(0, Int(((clip.minY - Self.top) / Self.rowHeight).rounded(.down)))
        let last = min(rows.count - 1, Int(((clip.maxY - Self.top) / Self.rowHeight).rounded(.up)))
        guard first <= last else { return }
        for index in first...last { drawRow(index, dataSource: dataSource, context: context) }
    }

    private func drawRow(_ index: Int, dataSource: RetroTreeDataSource, context: CGContext) {
        let row = rows[index]
        let rect = rowRect(index)
        let box = boxRect(row, index: index)
        drawGuides(for: index, row: row, box: box, rect: rect, context: context)
        if dataSource.tree(self, isExpandable: row.id) {
            Bevel.fill(box, color: Palette.shadow, context: context)
            Bevel.fill(box.insetBy(dx: 1, dy: 1), color: .white, context: context)
            Bevel.fill(CGRect(x: box.minX + 2, y: box.midY.rounded(.down), width: 5, height: 1), color: .black, context: context)
            if !expanded.contains(row.id) {
                Bevel.fill(CGRect(x: box.midX.rounded(.down), y: box.minY + 2, width: 1, height: 5), color: .black, context: context)
            }
        }
        let iconX = box.maxX + 3
        dataSource.tree(self, iconOf: row.id).draw(at: CGPoint(x: iconX, y: rect.minY + 1), context: context)
        let title = dataSource.tree(self, titleOf: row.id)
        let titleX = iconX + 19
        let width = CGFloat(PixelText.width(of: title, font: .regular))
        let isSelected = row.id == selected
        if isSelected { Bevel.fill(CGRect(x: titleX - 2, y: rect.minY, width: width + 4, height: rect.height), color: Palette.selection, context: context) }
        PixelText.draw(title, font: .regular, color: isSelected ? .white : .black,
                       at: CGPoint(x: titleX, y: rect.minY + 1), context: context)
    }

    /// Dotted connector lines: from the parent's column to this row, continuing down while siblings follow.
    private func drawGuides(for index: Int, row: TreeRow, box: CGRect, rect: CGRect, context: CGContext) {
        let dot = { (x: CGFloat, y: CGFloat) in
            if (Int(x) + Int(y)) % 2 == 0 { Bevel.fill(CGRect(x: x, y: y, width: 1, height: 1), color: Palette.shadow, context: context) }
        }
        let midY = box.midY.rounded(.down)
        if row.depth > 0 {
            let parentX = (box.minX - Self.indent + 4)
            for x in stride(from: parentX, to: box.minX, by: 1) { dot(x, midY) }
        }
        for depth in 1...max(row.depth, 1) where row.depth > 0 {
            let x = Self.left + CGFloat(depth - 1) * Self.indent + 4
            let continues = hasLaterSibling(atDepth: depth, after: index)
            let endY = depth == row.depth && !continues ? midY : rect.maxY
            if depth == row.depth || continues {
                for y in stride(from: rect.minY, to: endY, by: 1) { dot(x, y) }
            }
        }
    }

    private func hasLaterSibling(atDepth depth: Int, after index: Int) -> Bool {
        for next in rows.dropFirst(index + 1) {
            if next.depth < depth { return false }
            if next.depth == depth { return true }
        }
        return false
    }

    // MARK: Input

    override public var acceptsFirstResponder: Bool { true }

    override public func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let index = Int(((point.y - Self.top) / Self.rowHeight).rounded(.down))
        guard rows.indices.contains(index) else { return }
        let row = rows[index]
        if boxRect(row, index: index).insetBy(dx: -2, dy: -2).contains(point) || event.clickCount == 2 {
            toggle(row.id)
        } else {
            select(row.id)
        }
    }

    override public func keyDown(with event: NSEvent) {
        guard let selected, let index = rows.firstIndex(where: { $0.id == selected }) else {
            if let first = rows.first { select(first.id) }
            return
        }
        switch event.keyCode {
        case 125 where index + 1 < rows.count: select(rows[index + 1].id)
        case 126 where index > 0: select(rows[index - 1].id)
        case 124:
            if dataSource?.tree(self, isExpandable: selected) == true && !expanded.contains(selected) {
                toggle(selected)
            } else if index + 1 < rows.count, rows[index + 1].depth > rows[index].depth {
                select(rows[index + 1].id)
            }
        case 123:
            if expanded.contains(selected) {
                toggle(selected)
            } else if let parent = parents[selected] {
                select(parent)
            }
        default: super.keyDown(with: event)
        }
    }

    private func toggle(_ id: String) {
        guard dataSource?.tree(self, isExpandable: id) == true else { return }
        if expanded.contains(id) { expanded.remove(id) } else { expanded.insert(id) }
        rebuild()
    }

    private func select(_ id: String) {
        selected = id
        needsDisplay = true
        if let index = rows.firstIndex(where: { $0.id == id }) { scrollToVisible(rowRect(index)) }
        onSelect?(id)
    }
}
