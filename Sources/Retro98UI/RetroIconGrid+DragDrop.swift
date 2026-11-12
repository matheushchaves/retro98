import AppKit

@MainActor
public protocol RetroIconGridDropDelegate: AnyObject {
    /// `index` is the item under the pointer (nil = the background).
    func grid(_ grid: RetroIconGrid, validateDrop info: NSDraggingInfo, onItem index: Int?) -> RetroIconGrid.DropResponse
    func grid(_ grid: RetroIconGrid, acceptDrop info: NSDraggingInfo, onItem index: Int?) -> Bool
}

extension RetroIconGrid: NSDraggingSource {
    public struct DropResponse: Equatable {
        public let operation: NSDragOperation
        /// The item under the pointer is the target (drawn selected while hovered).
        public let highlightsItem: Bool

        public init(operation: NSDragOperation, highlightsItem: Bool) {
            self.operation = operation
            self.highlightsItem = highlightsItem
        }
    }

    static let dragThreshold: CGFloat = 4
    static let autoscrollMargin: CGFloat = 16
    static let autoscrollStep: CGFloat = 8

    // MARK: Dragging out

    /// After mouse-down on an item: a drag past the threshold drags the selection; a click without
    /// a drag narrows a group to the clicked item.
    func trackItemDrag(from event: NSEvent, index: Int, narrowOnMouseUp: Bool) {
        let start = event.locationInWindow
        while let next = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if next.type == .leftMouseUp {
                if narrowOnMouseUp { setSelection([index]) }
                return
            }
            if hypot(next.locationInWindow.x - start.x, next.locationInWindow.y - start.y) > Self.dragThreshold {
                beginDrag(with: event)
                return
            }
        }
    }

    private func beginDrag(with event: NSEvent) {
        guard let dataSource else { return }
        let geometry = geometry
        let items = selection.sorted().compactMap { index -> NSDraggingItem? in
            guard let writer = dataSource.grid(self, pasteboardWriterAt: index) else { return nil }
            let icon = style == .largeIcons ? dataSource.grid(self, iconAt: index) : dataSource.grid(self, smallIconAt: index)
            let frame = geometry.iconFrame(of: index)
            let item = NSDraggingItem(pasteboardWriter: writer)
            item.setDraggingFrame(frame, contents: NSImage(cgImage: icon.image(), size: frame.size))
            return item
        }
        guard !items.isEmpty else { return }
        beginDraggingSession(with: items, event: event, source: self)
    }

    public func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        context == .withinApplication ? [.copy, .move, .generic] : [.copy, .move, .link, .generic]
    }

    // MARK: Dropping in

    func registerForDrops() {
        unregisterDraggedTypes()
        guard dropDelegate != nil else { return }
        registerForDraggedTypes([.fileURL] + NSFilePromiseReceiver.readableDraggedTypes.map { NSPasteboard.PasteboardType($0) })
    }

    private func dropIndex(_ info: NSDraggingInfo) -> Int? {
        itemIndex(at: convert(info.draggingLocation, from: nil))
    }

    private func updateDrop(_ info: NSDraggingInfo) -> NSDragOperation {
        autoscrollDuringDrag(at: convert(info.draggingLocation, from: nil))
        let index = dropIndex(info)
        let response = dropDelegate?.grid(self, validateDrop: info, onItem: index) ?? DropResponse(operation: [], highlightsItem: false)
        let target = response.highlightsItem ? index : nil
        if target != dropTargetIndex {
            dropTargetIndex = target
            needsDisplay = true
        }
        return response.operation
    }

    private func clearDropTarget() {
        guard dropTargetIndex != nil else { return }
        dropTargetIndex = nil
        needsDisplay = true
    }

    private func autoscrollDuringDrag(at point: CGPoint) {
        guard let clip = superview as? NSClipView else { return }
        let visible = clip.bounds
        var origin = visible.origin
        if point.y < visible.minY + Self.autoscrollMargin { origin.y -= Self.autoscrollStep }
        if point.y > visible.maxY - Self.autoscrollMargin { origin.y += Self.autoscrollStep }
        if style == .list {
            if point.x < visible.minX + Self.autoscrollMargin { origin.x -= Self.autoscrollStep }
            if point.x > visible.maxX - Self.autoscrollMargin { origin.x += Self.autoscrollStep }
            origin.x = min(max(origin.x, 0), max(bounds.width - visible.width, 0))
        }
        origin.y = min(max(origin.y, 0), max(bounds.height - visible.height, 0))
        if origin != visible.origin { clip.scroll(to: origin) }
    }

    override public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation { updateDrop(sender) }
    override public func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { updateDrop(sender) }
    override public func draggingExited(_ sender: NSDraggingInfo?) { clearDropTarget() }
    override public func concludeDragOperation(_ sender: NSDraggingInfo?) { clearDropTarget() }

    override public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let index = dropIndex(sender)
        clearDropTarget()
        return dropDelegate?.grid(self, acceptDrop: sender, onItem: index) ?? false
    }
}
