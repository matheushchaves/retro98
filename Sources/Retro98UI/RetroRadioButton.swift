import AppKit

/// A classic round option button with its label.
@MainActor
public final class RetroRadioButton: PixelView {
    static let circleSize: CGFloat = 12
    static let labelGap: CGFloat = 5

    private static let off = PixelIcon(rows: [
        "....DDDD....",
        "..DDKKKKDD..",
        ".DKKWWWWKKW.",
        ".DKWWWWWWGW.",
        "DKWWWWWWWWGW",
        "DKWWWWWWWWGW",
        "DKWWWWWWWWGW",
        "DKWWWWWWWWGW",
        ".DKWWWWWWGW.",
        ".DGGWWWWGGW.",
        "..WWGGGGWW..",
        "....WWWW....",
    ])

    private static let on = PixelIcon(rows: [
        "....DDDD....",
        "..DDKKKKDD..",
        ".DKKWWWWKKW.",
        ".DKWWWWWWGW.",
        "DKWWWKKWWWGW",
        "DKWWKKKKWWGW",
        "DKWWKKKKWWGW",
        "DKWWWKKWWWGW",
        ".DKWWWWWWGW.",
        ".DGGWWWWGGW.",
        "..WWGGGGWW..",
        "....WWWW....",
    ])

    public let title: String
    public var isSelected: Bool { didSet { needsDisplay = true } }
    private let onSelect: () -> Void

    public init(title: String, isSelected: Bool, onSelect: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.onSelect = onSelect
        let width = Self.circleSize + Self.labelGap + CGFloat(PixelText.width(of: title, font: .regular)) + 2
        super.init(frame: CGRect(x: 0, y: 0, width: width, height: CGFloat(PixelText.lineHeight)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public func select() {
        isSelected = true
        onSelect()
    }

    override public func mouseUp(with event: NSEvent) {
        if bounds.contains(convert(event.locationInWindow, from: nil)) { select() }
    }

    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        (isSelected ? Self.on : Self.off).draw(at: .zero, context: context)
        PixelText.draw(title, font: .regular, color: .black,
                       at: CGPoint(x: Self.circleSize + Self.labelGap, y: 0), context: context)
    }
}
