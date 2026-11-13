import AppKit

/// A classic push button: raised bevel, pressed bevel while held, black outline when default,
/// dotted focus rectangle when it has keyboard focus.
@MainActor
public final class RetroButton: PixelView {
    nonisolated public static let height: CGFloat = 23
    nonisolated static let minimumWidth: CGFloat = 75
    nonisolated static let horizontalPadding: CGFloat = 16
    nonisolated static let iconGap: CGFloat = 4

    public let title: String
    public let icon: PixelIcon?
    public let isDefault: Bool
    public var isBold: Bool { didSet { needsDisplay = true } }
    /// Pressed look, set while the mouse holds it or by an owner (e.g. Start while its menu is open).
    public var isPressed = false { didSet { needsDisplay = true } }
    /// Off: the title turns gray and clicks, Space and performClick do nothing.
    public var isEnabled = true { didSet { needsDisplay = true } }
    private let action: () -> Void

    public init(title: String, isDefault: Bool = false, icon: PixelIcon? = nil, bold: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isDefault = isDefault
        self.isBold = bold
        self.action = action
        super.init(frame: CGRect(origin: .zero, size: Self.preferredSize(title: title, icon: icon, bold: bold)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    nonisolated public static func preferredSize(title: String, icon: PixelIcon?, bold: Bool) -> CGSize {
        let textWidth = CGFloat(PixelText.width(of: title, font: bold ? .bold : .regular))
        let iconWidth = icon.map { CGFloat($0.width) + iconGap } ?? 0
        return CGSize(width: max(minimumWidth, textWidth + iconWidth + horizontalPadding), height: height)
    }

    public func performClick() {
        guard isEnabled else { return }
        action()
    }

    // MARK: Input

    override public var acceptsFirstResponder: Bool { isEnabled }

    override public func becomeFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override public func resignFirstResponder() -> Bool {
        needsDisplay = true
        return true
    }

    override public func mouseDown(with event: NSEvent) {
        isPressed = true
    }

    override public func mouseDragged(with event: NSEvent) {
        isPressed = bounds.contains(convert(event.locationInWindow, from: nil))
    }

    override public func mouseUp(with event: NSEvent) {
        let inside = bounds.contains(convert(event.locationInWindow, from: nil))
        isPressed = false
        if inside { performClick() }
    }

    override public func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " " {
            performClick()
        } else {
            super.keyDown(with: event)
        }
    }

    // MARK: Drawing

    override public func drawPixels(in context: CGContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        Bevel.fillFace(rect, context: context)
        let bevelRect = isDefault ? rect.insetBy(dx: 1, dy: 1) : rect
        if isDefault {
            Bevel.fill(CGRect(x: 0, y: 0, width: rect.width, height: 1), color: .black, context: context)
            Bevel.fill(CGRect(x: 0, y: 0, width: 1, height: rect.height), color: .black, context: context)
            Bevel.fill(CGRect(x: 0, y: rect.height - 1, width: rect.width, height: 1), color: .black, context: context)
            Bevel.fill(CGRect(x: rect.width - 1, y: 0, width: 1, height: rect.height), color: .black, context: context)
        }
        Bevel.draw(isPressed ? .buttonPressed : .raised, in: bevelRect, context: context)

        let font: PixelFont = isBold ? .bold : .regular
        let textWidth = CGFloat(PixelText.width(of: title, font: font))
        let iconWidth = icon.map { CGFloat($0.width) + Self.iconGap } ?? 0
        let shift: CGFloat = isPressed ? 1 : 0
        let contentX = ((size.width - textWidth - iconWidth) / 2).rounded(.down) + shift
        if let icon {
            icon.draw(at: CGPoint(x: contentX, y: ((size.height - CGFloat(icon.height)) / 2).rounded(.down) + shift),
                      context: context)
        }
        let textY = ((size.height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down) + shift
        PixelText.draw(title, font: font, color: isEnabled ? .black : Palette.shadow, at: CGPoint(x: contentX + iconWidth, y: textY),
                       context: context)

        if window?.firstResponder === self {
            drawFocusRectangle(in: bevelRect.insetBy(dx: 3, dy: 3), context: context)
        }
    }

    private func drawFocusRectangle(in rect: CGRect, context: CGContext) {
        let minX = Int(rect.minX), maxX = Int(rect.maxX) - 1, minY = Int(rect.minY), maxY = Int(rect.maxY) - 1
        for x in stride(from: minX, through: maxX, by: 2) {
            Bevel.fill(CGRect(x: x, y: minY, width: 1, height: 1), color: .black, context: context)
            Bevel.fill(CGRect(x: x, y: maxY, width: 1, height: 1), color: .black, context: context)
        }
        for y in stride(from: minY, through: maxY, by: 2) {
            Bevel.fill(CGRect(x: minX, y: y, width: 1, height: 1), color: .black, context: context)
            Bevel.fill(CGRect(x: maxX, y: y, width: 1, height: 1), color: .black, context: context)
        }
    }
}
