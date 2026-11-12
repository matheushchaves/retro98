import AppKit

/// The Details header: a raised button per column; clicking one asks to sort by it, and a small
/// triangle marks the sorted column (up = ascending).
@MainActor
public final class RetroColumnHeader: PixelView {
    public static let height: CGFloat = 20

    public var columns: [GridColumn] = [] { didSet { needsDisplay = true } }
    public var sortedColumn: Int? { didSet { needsDisplay = true } }
    public var ascending = true { didSet { needsDisplay = true } }
    public var onClick: ((Int) -> Void)?
    /// The grid's width (columns are laid out on it, not on the header's own width, which includes the scroller).
    public var contentWidth: CGFloat? { didSet { needsDisplay = true } }
    /// How far the grid has scrolled sideways.
    public var scrollOffset: CGFloat = 0 { didSet { needsDisplay = true } }

    private var widths: [CGFloat] { GridColumn.widths(columns, totalWidth: contentWidth ?? bounds.width) }

    func column(at x: CGFloat) -> Int? {
        let x = x + scrollOffset
        var start: CGFloat = 0
        for (index, width) in widths.enumerated() {
            if x >= start && x < start + width { return index }
            start += width
        }
        return nil
    }

    override public func mouseDown(with event: NSEvent) {
        guard let index = column(at: convert(event.locationInWindow, from: nil).x) else { return }
        onClick?(index)
    }

    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        var x: CGFloat = -scrollOffset
        for (index, width) in widths.enumerated() {
            let rect = CGRect(x: x, y: 0, width: width, height: size.height)
            Bevel.draw(.raised, in: rect, context: context)
            let arrowRoom: CGFloat = index == sortedColumn ? 14 : 0
            let title = RetroText.fit(columns[index].title, maxWidth: Int(max(width - 12 - arrowRoom, 0)))
            PixelText.draw(title, font: .regular, color: .black,
                           at: CGPoint(x: x + 6, y: ((size.height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down)), context: context)
            if index == sortedColumn { drawTriangle(in: rect, context: context) }
            x += width
        }
        if x < size.width { Bevel.draw(.raised, in: CGRect(x: x, y: 0, width: size.width - x, height: size.height), context: context) }
    }

    /// 7×4, pointing up when ascending.
    private func drawTriangle(in rect: CGRect, context: CGContext) {
        let left = rect.maxX - 12, top = (rect.midY - 2).rounded(.down)
        for row in 0..<4 {
            let width = CGFloat(ascending ? 1 + row * 2 : 7 - row * 2)
            Bevel.fill(CGRect(x: left + (7 - width) / 2, y: top + CGFloat(row), width: width, height: 1), color: Palette.shadow, context: context)
        }
    }
}
