import AppKit

@MainActor
public protocol RetroIconGridDataSource: AnyObject {
    func numberOfItems(in grid: RetroIconGrid) -> Int
    func grid(_ grid: RetroIconGrid, titleAt index: Int) -> String
    func grid(_ grid: RetroIconGrid, iconAt index: Int) -> PixelIcon
    /// The 16 pt icon for small icons, list and details. Default: the large icon scaled down.
    func grid(_ grid: RetroIconGrid, smallIconAt index: Int) -> PixelIcon
    /// The texts of the Details columns after the name. Default: none.
    func grid(_ grid: RetroIconGrid, detailsAt index: Int) -> [String]
    /// Ghosted icon (a cut item waiting to be pasted, or a hidden file). Default: false.
    func grid(_ grid: RetroIconGrid, isDimmedAt index: Int) -> Bool
    /// What a drag of this item carries; nil means it can't be dragged. Default: nil.
    func grid(_ grid: RetroIconGrid, pasteboardWriterAt index: Int) -> NSPasteboardWriting?
}

extension RetroIconGridDataSource {
    public func grid(_ grid: RetroIconGrid, smallIconAt index: Int) -> PixelIcon {
        let large = self.grid(grid, iconAt: index)
        return PixelIcon(width: 16, height: 16) { PixelIcon.drawUpright(large.image(), in: CGRect(x: 0, y: 0, width: 16, height: 16), context: $0) }
    }
    public func grid(_ grid: RetroIconGrid, detailsAt index: Int) -> [String] { [] }
    public func grid(_ grid: RetroIconGrid, isDimmedAt index: Int) -> Bool { false }
    public func grid(_ grid: RetroIconGrid, pasteboardWriterAt index: Int) -> NSPasteboardWriting? { nil }
}

/// What a plain or ⌘ click on an item does to the selection.
public enum IconGridClick {
    /// A plain click on an item of a multiple selection keeps the group (so it can be dragged)
    /// and narrows to that item only on mouse-up.
    public static func mouseDown(on index: Int, selection: IndexSet, extend: Bool) -> (selection: IndexSet, narrowOnMouseUp: Bool) {
        if extend {
            var toggled = selection
            if toggled.contains(index) { toggled.remove(index) } else { toggled.insert(index) }
            return (toggled, false)
        }
        if selection.contains(index) && selection.count > 1 { return (selection, true) }
        return ([index], false)
    }
}

/// Files and folders as a scroll view's document, in large icons, small icons, a list or details.
/// Only visible cells are drawn. Click selects, ⌘-click toggles, drag on the background draws a
/// selection rectangle and drag on an item drags it, double-click opens, Enter or F2 renames,
/// arrows move, ⌘A selects all, right-click shows the context menu.
@MainActor
public final class RetroIconGrid: PixelView, NSTextFieldDelegate {
    static let labelWidth = 84
    static let iconTop: CGFloat = 4
    static let labelTop: CGFloat = 40
    static let returnKeys: Set<UInt16> = [36, 76]
    static let f2Key: UInt16 = 120

    public weak var dataSource: RetroIconGridDataSource?
    public private(set) var selection = IndexSet()
    public var onOpen: ((Int) -> Void)?
    public var onSelectionChange: ((IndexSet) -> Void)?
    /// Consulted first on every key press; return true when handled (e.g. space for Quick Look).
    public var onKey: ((NSEvent) -> Bool)?
    /// Enter or F2 with one item selected.
    public var onRename: ((Int) -> Void)?
    /// Right-click or control-click; an item outside the selection becomes the selection first (nil = background).
    public var onContextMenu: ((Int?, NSEvent) -> Void)?
    /// The rename field closed: the typed text, or nil when cancelled.
    public var onEndEditing: ((Int, String?) -> Void)?
    /// Setting it makes the grid accept dropped files.
    public weak var dropDelegate: RetroIconGridDropDelegate? { didSet { registerForDrops() } }
    /// The view mode; changing it keeps the selection.
    public var style: IconGridStyle = .largeIcons {
        didSet {
            guard style != oldValue else { return }
            fitToClipView()
            if let editingIndex { placeEditor(at: editingIndex) }
            needsDisplay = true
        }
    }
    /// The Details columns: the name first, then the ones `detailsAt` fills.
    public var columns: [GridColumn] = [] {
        didSet {
            fitToClipView()
            needsDisplay = true
        }
    }
    public internal(set) var editingIndex: Int?
    public internal(set) var dropTargetIndex: Int?
    public internal(set) var editor: NSTextField?
    var focus: Int?
    private var rubberBand: CGRect?

    var count: Int { dataSource?.numberOfItems(in: self) ?? 0 }
    var geometry: IconGridGeometry {
        IconGridGeometry(style: style, visibleSize: superview?.bounds.size ?? bounds.size, count: count,
                         minimumWidth: style == .details ? GridColumn.minimumTotal(columns) : 0)
    }

    public func itemFrame(_ index: Int) -> CGRect { geometry.frame(of: index) }

    public func scrollToItem(_ index: Int) {
        guard index < count else { return }
        scrollToVisible(geometry.frame(of: index))
    }

    /// The item under `point`: anywhere in a large icon's cell, but only on the icon or the name in the other
    /// modes, so the rest of a row stays background (to deselect, draw a selection rectangle, or get the menu).
    public func itemIndex(at point: CGPoint) -> Int? {
        let geometry = geometry
        guard let index = geometry.index(at: point) else { return nil }
        guard style != .largeIcons else { return index }
        return hitRect(of: index, geometry: geometry).contains(point) ? index : nil
    }

    /// Icon plus name (the one-line modes).
    private func hitRect(of index: Int, geometry: IconGridGeometry) -> CGRect {
        let label = lineLabel(index, geometry: geometry, widths: GridColumn.widths(columns, totalWidth: bounds.width))
        let cell = geometry.frame(of: index)
        return geometry.iconFrame(of: index).union(CGRect(x: label.rect.minX, y: cell.minY, width: label.rect.width, height: cell.height))
    }

    /// The fitted name and its highlight rectangle in small icons, list and details.
    private func lineLabel(_ index: Int, geometry: IconGridGeometry, widths: [CGFloat]) -> (text: String, rect: CGRect) {
        let cell = geometry.frame(of: index)
        let nameWidth = style == .details ? (widths.first ?? cell.width) : cell.width
        let name = RetroText.fit(dataSource?.grid(self, titleAt: index) ?? "", maxWidth: Int(max(nameWidth - 26, 0)))
        let textY = cell.minY + ((cell.height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down)
        let rect = CGRect(x: geometry.labelX(of: index) - 2, y: textY, width: CGFloat(PixelText.width(of: name, font: .regular)) + 4,
                          height: CGFloat(PixelText.lineHeight))
        return (name, rect)
    }

    public func reloadData() {
        selection = selection.filteredIndexSet { $0 < count }
        focus = focus.flatMap { $0 < count ? $0 : nil }
        fitToClipView()
        needsDisplay = true
    }

    public func setSelection(_ indexes: IndexSet) {
        selection = indexes
        focus = indexes.first
        needsDisplay = true
        onSelectionChange?(selection)
    }

    /// Fills the clip view; grows with the content (down, or sideways for the list).
    public func fitToClipView() {
        guard superview != nil else { return }
        setFrameSize(geometry.contentSize)
    }

    override public func resize(withOldSuperviewSize oldSize: NSSize) {
        fitToClipView()
        if let editingIndex { placeEditor(at: editingIndex) }
    }

    /// Items whose cells meet `rect` (the selection rectangle).
    func items(touching rect: CGRect) -> IndexSet {
        let geometry = geometry
        return IndexSet(geometry.indices(in: rect).filter { index in
            let area = style == .largeIcons ? geometry.frame(of: index).insetBy(dx: 12, dy: 4) : hitRect(of: index, geometry: geometry)
            return area.intersects(rect)
        })
    }

    // MARK: Drawing

    override public func drawPixels(in context: CGContext, size: CGSize) {
        let clip = context.boundingBoxOfClipPath
        Bevel.fill(clip, color: .white, context: context)
        guard let dataSource else { return }
        let geometry = geometry
        let widths = GridColumn.widths(columns, totalWidth: size.width)
        for index in geometry.indices(in: clip) {
            let selected = selection.contains(index) || index == dropTargetIndex
            let dimmed = dataSource.grid(self, isDimmedAt: index)
            if style == .largeIcons {
                drawLargeItem(index, cell: geometry.frame(of: index), selected: selected, dimmed: dimmed, context: context)
            } else {
                drawLineItem(index, geometry: geometry, widths: widths, selected: selected, dimmed: dimmed, context: context)
            }
        }
        if let rubberBand { drawDottedRect(rubberBand, context: context) }
    }

    private var hasFocusRing: Bool { window?.isKeyWindow ?? false }

    private func drawIcon(_ icon: PixelIcon, at origin: CGPoint, selected: Bool, dimmed: Bool, context: CGContext) {
        if selected {
            icon.drawSelected(at: origin, context: context)
        } else if dimmed {
            icon.drawDimmed(at: origin, context: context)
        } else {
            icon.draw(at: origin, context: context)
        }
    }

    private func drawLargeItem(_ index: Int, cell: CGRect, selected: Bool, dimmed: Bool, context: CGContext) {
        guard let dataSource else { return }
        let icon = dataSource.grid(self, iconAt: index)
        let iconOrigin = CGPoint(x: (cell.midX - CGFloat(icon.width) / 2).rounded(.down), y: cell.minY + Self.iconTop)
        drawIcon(icon, at: iconOrigin, selected: selected, dimmed: dimmed, context: context)
        guard index != editingIndex else { return }
        let lines = RetroText.label(dataSource.grid(self, titleAt: index), maxWidth: Self.labelWidth, maxLines: 2)
        let widest = CGFloat(lines.map { PixelText.width(of: $0, font: .regular) }.max() ?? 0)
        let labelRect = CGRect(x: (cell.midX - widest / 2).rounded(.down) - 2, y: cell.minY + Self.labelTop,
                               width: widest + 4, height: CGFloat(lines.count * PixelText.lineHeight))
        if selected { Bevel.fill(labelRect, color: Palette.selection, context: context) }
        for (line, text) in lines.enumerated() {
            let width = CGFloat(PixelText.width(of: text, font: .regular))
            PixelText.draw(text, font: .regular, color: selected ? .white : .black,
                           at: CGPoint(x: (cell.midX - width / 2).rounded(.down), y: labelRect.minY + CGFloat(line * PixelText.lineHeight)),
                           context: context)
        }
        if hasFocusRing, index == focus { drawDottedRect(labelRect, context: context) }
    }

    /// Small icons, list and details: a 16 pt icon and a one-line name (plus columns in details).
    private func drawLineItem(_ index: Int, geometry: IconGridGeometry, widths: [CGFloat], selected: Bool, dimmed: Bool,
                              context: CGContext) {
        guard let dataSource else { return }
        drawIcon(dataSource.grid(self, smallIconAt: index), at: geometry.iconFrame(of: index).origin, selected: selected,
                 dimmed: dimmed, context: context)
        let label = lineLabel(index, geometry: geometry, widths: widths)
        let textY = label.rect.minY
        if index != editingIndex {
            if selected { Bevel.fill(label.rect, color: Palette.selection, context: context) }
            PixelText.draw(label.text, font: .regular, color: selected ? .white : .black, at: CGPoint(x: label.rect.minX + 2, y: textY),
                           context: context)
            if hasFocusRing, index == focus { drawDottedRect(label.rect, context: context) }
        }
        guard style == .details else { return }
        var x = widths.first ?? 0
        for (column, text) in dataSource.grid(self, detailsAt: index).enumerated() where column + 1 < widths.count {
            let width = widths[column + 1]
            let fitted = RetroText.fit(text, maxWidth: Int(max(width - 12, 0)))
            let textWidth = CGFloat(PixelText.width(of: fitted, font: .regular))
            let alignsRight = columns.indices.contains(column + 1) && columns[column + 1].alignsRight
            PixelText.draw(fitted, font: .regular, color: .black,
                           at: CGPoint(x: alignsRight ? x + width - 6 - textWidth : x + 6, y: textY), context: context)
            x += width
        }
    }

    private func drawDottedRect(_ rect: CGRect, context: CGContext) {
        let minX = Int(rect.minX), maxX = Int(rect.maxX) - 1, minY = Int(rect.minY), maxY = Int(rect.maxY) - 1
        guard maxX > minX, maxY > minY else { return }
        for x in stride(from: minX, through: maxX, by: 2) {
            Bevel.fill(CGRect(x: x, y: minY, width: 1, height: 1), color: .black, context: context)
            Bevel.fill(CGRect(x: x, y: maxY, width: 1, height: 1), color: .black, context: context)
        }
        for y in stride(from: minY, through: maxY, by: 2) {
            Bevel.fill(CGRect(x: minX, y: y, width: 1, height: 1), color: .black, context: context)
            Bevel.fill(CGRect(x: maxX, y: y, width: 1, height: 1), color: .black, context: context)
        }
    }

    // MARK: Mouse

    override public var acceptsFirstResponder: Bool { true }

    func index(at event: NSEvent) -> Int? {
        itemIndex(at: convert(event.locationInWindow, from: nil))
    }

    override public func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            showContextMenu(for: event)
            return
        }
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let extend = event.modifierFlags.contains(.command)
        if let index = itemIndex(at: point) {
            if event.clickCount == 2 { onOpen?(index); return }
            let click = IconGridClick.mouseDown(on: index, selection: selection, extend: extend)
            setSelection(click.selection)
            focus = index
            trackItemDrag(from: event, index: index, narrowOnMouseUp: click.narrowOnMouseUp)
            return
        }
        if !extend { setSelection([]) }
        trackRubberBand(from: point, keeping: extend ? selection : IndexSet())
    }

    override public func rightMouseDown(with event: NSEvent) {
        showContextMenu(for: event)
    }

    private func showContextMenu(for event: NSEvent) {
        window?.makeFirstResponder(self)
        let index = index(at: event)
        if let index {
            if !selection.contains(index) { setSelection([index]) }
            focus = index
        } else {
            setSelection([])
        }
        onContextMenu?(index, event)
    }

    private func trackRubberBand(from start: CGPoint, keeping base: IndexSet) {
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            autoscroll(with: next)
            let point = convert(next.locationInWindow, from: nil)
            let rect = CGRect(x: min(start.x, point.x), y: min(start.y, point.y),
                              width: abs(point.x - start.x), height: abs(point.y - start.y))
            rubberBand = next.type == .leftMouseUp ? nil : rect
            setSelection(base.union(items(touching: rect)))
            if next.type == .leftMouseUp { break }
        }
        rubberBand = nil
        needsDisplay = true
    }

    // MARK: Keyboard

    override public func keyDown(with event: NSEvent) {
        if onKey?(event) == true { return }
        let direction: MoveDirection
        switch event.keyCode {
        case 123: direction = .left
        case 124: direction = .right
        case 125: direction = .down
        case 126: direction = .up
        case _ where Self.returnKeys.contains(event.keyCode) || event.keyCode == Self.f2Key:
            if let focus, selection == [focus] { onRename?(focus) }
            return
        default:
            super.keyDown(with: event)
            return
        }
        guard let target = geometry.move(from: focus, direction) else { return }
        setSelection([target])
        scrollToVisible(geometry.frame(of: target))
    }

    override public func selectAll(_ sender: Any?) {
        setSelection(IndexSet(integersIn: 0..<count))
    }
}
