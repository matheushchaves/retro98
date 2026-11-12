import AppKit

/// The progress dialog of a long file operation: animation, the item, "from … to …", a bar, the
/// time left and Cancel. It is a normal window, so the rest of the app keeps working meanwhile.
@MainActor
public final class RetroProgressDialog {
    static let contentSize = CGSize(width: 360, height: 176)
    static let margin: CGFloat = 12
    static let textWidth: CGFloat = 336

    public let window: RetroWindow
    public var onCancel: (() -> Void)?
    private let animation: FileOperationAnimation
    private let itemLine = ProgressLine(), detailLine = ProgressLine(), remainingLine = ProgressLine()
    private let bar = RetroProgressBar()

    public init(title: String, style: FileOperationAnimation.Style, cancelTitle: String) {
        window = RetroWindow(title: title, contentSize: Self.contentSize)
        window.level = .normal
        animation = FileOperationAnimation(style: style)
        let content = window.contentContainer
        let margin = Self.margin, width = Self.textWidth
        animation.frame = CGRect(x: margin, y: 8, width: width, height: 48)
        itemLine.frame = CGRect(x: margin, y: 64, width: width, height: CGFloat(PixelText.lineHeight))
        detailLine.frame = CGRect(x: margin, y: 80, width: width, height: CGFloat(PixelText.lineHeight))
        bar.frame = CGRect(x: margin, y: 100, width: width, height: 18)
        remainingLine.frame = CGRect(x: margin, y: 124, width: width, height: CGFloat(PixelText.lineHeight))
        for view in [animation, itemLine, detailLine, bar, remainingLine] as [NSView] { content.addSubview(view) }
        let cancel = RetroButton(title: cancelTitle) { [weak self] in self?.onCancel?() }
        cancel.frame.origin = CGPoint(x: Self.contentSize.width - margin - cancel.frame.width,
                                      y: Self.contentSize.height - margin - RetroButton.height)
        content.addSubview(cancel)
        window.defaultButton = cancel
        window.onCancel = { [weak self] in self?.onCancel?() }
    }

    public func update(item: String, detail: String, fraction: Double, remaining: String) {
        itemLine.text = item
        detailLine.text = detail
        bar.fraction = fraction
        remainingLine.text = remaining
    }

    public func show() {
        window.showCentered()
        animation.start()
    }

    public func close() {
        animation.stop()
        window.orderOut(nil)
    }
}

/// One line of black text on the face color, cut with "…" to fit.
@MainActor
private final class ProgressLine: PixelView {
    var text = "" { didSet { needsDisplay = true } }

    override func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        PixelText.draw(RetroText.fit(text, maxWidth: Int(size.width)), font: .regular, color: .black, at: .zero, context: context)
    }
}
