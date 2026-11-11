import AppKit

/// A vertical split view with a plain 4-pt face-colored divider.
@MainActor
public final class RetroSplitView: NSSplitView {
    public override init(frame: NSRect) {
        super.init(frame: frame)
        isVertical = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override public var dividerThickness: CGFloat { 4 }

    override public func drawDivider(in rect: NSRect) {
        Palette.face.nsColor.setFill()
        rect.fill()
    }
}
