import AppKit

/// An etched frame with a title breaking its top line, around related controls (added as subviews).
@MainActor
public final class RetroGroupBox: PixelView {
    static let frameTop: CGFloat = 7
    static let titleX: CGFloat = 8
    private let title: String

    public init(title: String) {
        self.title = title
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        // A shadow outline with a white one 1 pt right and down reads as a groove.
        outline(CGRect(x: 1, y: Self.frameTop + 1, width: size.width - 1, height: size.height - Self.frameTop - 1),
                color: .white, context: context)
        outline(CGRect(x: 0, y: Self.frameTop, width: size.width - 1, height: size.height - Self.frameTop - 1),
                color: Palette.shadow, context: context)
        let width = CGFloat(PixelText.width(of: title, font: .regular))
        Bevel.fillFace(CGRect(x: Self.titleX - 2, y: 0, width: width + 4, height: CGFloat(PixelText.lineHeight)), context: context)
        PixelText.draw(title, font: .regular, color: .black, at: CGPoint(x: Self.titleX, y: 0), context: context)
    }

    private func outline(_ rect: CGRect, color: PixelColor, context: CGContext) {
        Bevel.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1), color: color, context: context)
        Bevel.fill(CGRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1), color: color, context: context)
        Bevel.fill(CGRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height), color: color, context: context)
        Bevel.fill(CGRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height), color: color, context: context)
    }
}
