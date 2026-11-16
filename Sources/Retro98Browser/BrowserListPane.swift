import AppKit
import Retro98UI

/// A details list for the small windows: column titles over a scrolling grid, in a sunken frame.
@MainActor
final class BrowserListPane: NSView {
    let grid = RetroIconGrid()
    private let header = RetroColumnHeader()
    private let scroll: NSScrollView

    init(frame: CGRect, columns: [GridColumn]) {
        scroll = RetroScroller.makeScrollView(document: grid)
        super.init(frame: frame)
        grid.style = .details
        grid.columns = columns
        header.columns = columns
        scroll.hasHorizontalScroller = false
        let inner = NSView(frame: CGRect(origin: .zero, size: frame.size))
        inner.addSubview(header)
        inner.addSubview(scroll)
        addSubview(FieldFrame(wrapping: inner))
        // The frame shrank the inner view by its border: the header and the list are laid out in what is left.
        header.frame = CGRect(x: 0, y: inner.bounds.height - RetroColumnHeader.height, width: inner.bounds.width, height: RetroColumnHeader.height)
        scroll.frame = CGRect(x: 0, y: 0, width: inner.bounds.width, height: inner.bounds.height - RetroColumnHeader.height)
        header.contentWidth = scroll.contentSize.width
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }
}
