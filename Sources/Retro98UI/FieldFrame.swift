import AppKit

/// A sunken 2-pt field border around a pane (the Explorer's tree and icons, the Control Panel's icons).
@MainActor
public final class FieldFrame: PixelView {
    public init(wrapping content: NSView) {
        super.init(frame: content.frame)
        content.frame = bounds.insetBy(dx: 2, dy: 2)
        content.autoresizingMask = [.width, .height]
        addSubview(content)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.draw(.sunken, in: CGRect(origin: .zero, size: size), context: context)
    }
}
