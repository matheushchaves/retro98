import AppKit

/// A fixed-size 98-style dialog: window bevel, gradient title bar with bold white title,
/// a close (×) button, Enter for the default button and Esc / × for cancel.
@MainActor
public final class RetroWindow: NSPanel {
    static let border: CGFloat = 3
    static let titleHeight: CGFloat = 18
    static let titleGap: CGFloat = 2

    public let contentContainer: NSView
    public var defaultButton: RetroButton?
    public var onCancel: (() -> Void)?
    private let frameView: FrameView

    public init(title: String, contentSize: CGSize) {
        let size = CGSize(
            width: contentSize.width + Self.border * 2,
            height: contentSize.height + Self.border * 2 + Self.titleHeight + Self.titleGap
        )
        frameView = FrameView(frame: CGRect(origin: .zero, size: size), title: title)
        contentContainer = FlippedView(frame: CGRect(
            x: Self.border, y: Self.border + Self.titleHeight + Self.titleGap,
            width: contentSize.width, height: contentSize.height
        ))
        super.init(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: true)
        level = .modalPanel
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        hasShadow = true
        contentView = frameView
        frameView.addSubview(contentContainer)
        frameView.onClose = { [weak self] in self?.cancel() }
    }

    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }

    /// Centers on the main screen and brings the dialog to the front.
    public func showCentered() {
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            setFrameOrigin(CGPoint(x: (visible.midX - frame.width / 2).rounded(), y: (visible.midY - frame.height / 2).rounded()))
        }
        NSApp.activate()
        makeKeyAndOrderFront(nil)
    }

    override public func cancelOperation(_ sender: Any?) {
        cancel()
    }

    override public func keyDown(with event: NSEvent) {
        let returnKeys: Set<UInt16> = [36, 76]
        if returnKeys.contains(event.keyCode), let defaultButton {
            defaultButton.performClick()
        } else {
            super.keyDown(with: event)
        }
    }

    override public func becomeKey() {
        super.becomeKey()
        frameView.needsDisplay = true
    }

    override public func resignKey() {
        super.resignKey()
        frameView.needsDisplay = true
    }

    private func cancel() {
        onCancel?()
    }

    /// Horizontal gradient whose first and last columns are exactly the palette's start and end colors.
    nonisolated public static func drawTitleGradient(active: Bool, in rect: CGRect, context: CGContext) {
        let (start, end) = active ? Palette.activeTitle : Palette.inactiveTitle
        let columns = max(Int(rect.width), 1)
        for column in 0..<columns {
            let t = columns == 1 ? 0 : Double(column) / Double(columns - 1)
            let mix = { (a: UInt8, b: UInt8) in UInt8((Double(a) + (Double(b) - Double(a)) * t).rounded()) }
            let color = PixelColor(red: mix(start.red, end.red), green: mix(start.green, end.green), blue: mix(start.blue, end.blue))
            Bevel.fill(CGRect(x: rect.minX + CGFloat(column), y: rect.minY, width: 1, height: rect.height),
                       color: color, context: context)
        }
    }

    // MARK: Frame

    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    private final class FrameView: PixelView {
        static let closeSize = CGSize(width: 16, height: 14)
        static let closeGlyph = PixelIcon(rows: [
            "KK....KK",
            ".KK..KK.",
            "..KKKK..",
            "...KK...",
            "..KKKK..",
            ".KK..KK.",
            "KK....KK",
        ])

        let title: String
        var onClose: (() -> Void)?
        private var isClosePressed = false { didSet { needsDisplay = true } }

        init(frame: CGRect, title: String) {
            self.title = title
            super.init(frame: frame)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        private var titleRect: CGRect {
            CGRect(x: RetroWindow.border, y: RetroWindow.border,
                   width: bounds.width - RetroWindow.border * 2, height: RetroWindow.titleHeight)
        }

        private var closeRect: CGRect {
            CGRect(x: titleRect.maxX - 2 - Self.closeSize.width, y: titleRect.minY + 2,
                   width: Self.closeSize.width, height: Self.closeSize.height)
        }

        override func drawPixels(in context: CGContext, size: CGSize) {
            let rect = CGRect(origin: .zero, size: size)
            Bevel.fillFace(rect, context: context)
            Bevel.draw(.window, in: rect, context: context)
            RetroWindow.drawTitleGradient(active: window?.isKeyWindow ?? true, in: titleRect, context: context)
            PixelText.draw(title, font: .bold, color: .white,
                           at: CGPoint(x: titleRect.minX + 3, y: titleRect.minY + 2), context: context)
            Bevel.fillFace(closeRect, context: context)
            Bevel.draw(isClosePressed ? .buttonPressed : .raised, in: closeRect, context: context)
            let shift: CGFloat = isClosePressed ? 1 : 0
            Self.closeGlyph.draw(at: CGPoint(x: closeRect.minX + 4 + shift, y: closeRect.minY + 3 + shift), context: context)
        }

        override func mouseDown(with event: NSEvent) {
            let point = convert(event.locationInWindow, from: nil)
            if closeRect.contains(point) {
                isClosePressed = true
            } else if titleRect.contains(point) {
                window?.performDrag(with: event)
            }
        }

        override func mouseUp(with event: NSEvent) {
            guard isClosePressed else { return }
            isClosePressed = false
            if closeRect.contains(convert(event.locationInWindow, from: nil)) { onClose?() }
        }
    }
}
