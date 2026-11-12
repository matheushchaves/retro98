import AppKit

@MainActor
public protocol RetroIconGridDataSource: AnyObject {
    func numberOfItems(in grid: RetroIconGrid) -> Int
    func grid(_ grid: RetroIconGrid, titleAt index: Int) -> String
    func grid(_ grid: RetroIconGrid, iconAt index: Int) -> PixelIcon
    /// Ghosted icon (a cut item waiting to be pasted). Default: false.
    func grid(_ grid: RetroIconGrid, isDimmedAt index: Int) -> Bool
    /// What a drag of this item carries; nil means it can't be dragged. Default: nil.
    func grid(_ grid: RetroIconGrid, pasteboardWriterAt index: Int) -> NSPasteboardWriting?
}

extension RetroIconGridDataSource {
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

/// Large icons on white, as a scroll view's document. Only visible cells are drawn.
/// Click selects, ⌘-click toggles, drag on the background draws a selection rectangle and drag on an
/// item drags it, double-click opens, Enter or F2 renames, arrows move, ⌘A selects all, right-click
/// shows the context menu.
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
    public internal(set) var editingIndex: Int?
    public internal(set) var dropTargetIndex: Int?
    public internal(set) var editor: NSTextField?
    var focus: Int?
    private var rubberBand: CGRect?

    var count: Int { dataSource?.numberOfItems(in: self) ?? 0 }
    var columns: Int { IconGridLayout.columns(forWidth: bounds.width) }

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

    /// Width follows the clip view; height grows with the content (at least the visible height).
    public func fitToClipView() {
        guard let clip = superview else { return }
        let height = max(IconGridLayout.contentHeight(count: count, columns: IconGridLayout.columns(forWidth: clip.bounds.width)),
                         clip.bounds.height)
        setFrameSize(CGSize(width: clip.bounds.width, height: height))
    }

    override public func resize(withOldSuperviewSize oldSize: NSSize) {
        fitToClipView()
        if let editingIndex { placeEditor(at: editingIndex) }
    }

    // MARK: Drawing

    override public func drawPixels(in context: CGContext, size: CGSize) {
        let clip = context.boundingBoxOfClipPath
        Bevel.fill(clip, color: .white, context: context)
        guard let dataSource else { return }
        let isKey = window?.isKeyWindow ?? false
        for index in IconGridLayout.indices(in: clip, columns: columns, count: count) {
            let cell = IconGridLayout.frame(of: index, columns: columns)
            let selected = selection.contains(index) || index == dropTargetIndex
            let icon = dataSource.grid(self, iconAt: index)
            let iconOrigin = CGPoint(x: (cell.midX - CGFloat(icon.width) / 2).rounded(.down), y: cell.minY + Self.iconTop)
            if selected {
                icon.drawSelected(at: iconOrigin, context: context)
            } else if dataSource.grid(self, isDimmedAt: index) {
                icon.drawDimmed(at: iconOrigin, context: context)
            } else {
                icon.draw(at: iconOrigin, context: context)
            }
            guard index != editingIndex else { continue }
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
            if isKey, index == focus { drawDottedRect(labelRect, context: context) }
        }
        if let rubberBand { drawDottedRect(rubberBand, context: context) }
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
        IconGridLayout.index(at: convert(event.locationInWindow, from: nil), columns: columns, count: count)
    }

    override public func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) {
            showContextMenu(for: event)
            return
        }
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let extend = event.modifierFlags.contains(.command)
        if let index = IconGridLayout.index(at: point, columns: columns, count: count) {
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
            var picked = base
            for index in IconGridLayout.indices(in: rect, columns: columns, count: count)
            where IconGridLayout.frame(of: index, columns: columns).insetBy(dx: 12, dy: 4).intersects(rect) {
                picked.insert(index)
            }
            setSelection(picked)
            if next.type == .leftMouseUp { break }
        }
        rubberBand = nil
        needsDisplay = true
    }

    // MARK: Keyboard

    override public func keyDown(with event: NSEvent) {
        if onKey?(event) == true { return }
        let current = focus ?? -1
        let target: Int?
        switch event.keyCode {
        case 123: target = current - 1
        case 124: target = current + 1
        case 125: target = current < 0 ? 0 : current + columns
        case 126: target = current - columns
        case _ where Self.returnKeys.contains(event.keyCode) || event.keyCode == Self.f2Key:
            if let focus, selection == [focus] { onRename?(focus) }
            return
        default:
            super.keyDown(with: event)
            return
        }
        guard let target, count > 0 else { return }
        let clamped = min(max(target, 0), count - 1)
        setSelection([clamped])
        scrollToVisible(IconGridLayout.frame(of: clamped, columns: columns))
    }

    override public func selectAll(_ sender: Any?) {
        setSelection(IndexSet(integersIn: 0..<count))
    }
}
