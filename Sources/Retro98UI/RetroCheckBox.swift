import AppKit

/// A classic check box: a sunken white 13×13 square with a check, and its label; click or space toggles.
@MainActor
public final class RetroCheckBox: PixelView {
    static let boxSize: CGFloat = 13
    static let labelGap: CGFloat = 6
    static let check = PixelIcon(rows: [
        "......K",
        ".....KK",
        "K...KKK",
        "KK.KKK.",
        "KKKKK..",
        ".KKK...",
        "..K....",
    ])

    public let title: String
    public var isOn: Bool { didSet { needsDisplay = true } }
    /// A disabled box ignores clicks and the keyboard, and draws its label gray.
    public var isEnabled = true { didSet { needsDisplay = true } }
    private let onChange: (Bool) -> Void

    public init(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        self.title = title
        self.isOn = isOn
        self.onChange = onChange
        super.init(frame: CGRect(origin: .zero, size: Self.preferredSize(title: title)))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public static func preferredSize(title: String) -> CGSize {
        CGSize(width: boxSize + labelGap + CGFloat(PixelText.width(of: title, font: .regular)) + 4, height: 16)
    }

    public func performClick() {
        guard isEnabled else { return }
        isOn.toggle()
        onChange(isOn)
    }

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
        window?.makeFirstResponder(self)
        performClick()
    }

    override public func keyDown(with event: NSEvent) {
        if event.characters == " " { performClick() } else { super.keyDown(with: event) }
    }

    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        let box = CGRect(x: 0, y: ((size.height - Self.boxSize) / 2).rounded(.down), width: Self.boxSize, height: Self.boxSize)
        Bevel.fill(box, color: .white, context: context)
        Bevel.draw(.field, in: box, context: context)
        if isOn { Self.check.draw(at: CGPoint(x: box.minX + 3, y: box.minY + 3), context: context) }
        let labelX = Self.boxSize + Self.labelGap
        let labelY = ((size.height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down)
        PixelText.draw(title, font: .regular, color: isEnabled ? .black : Palette.shadow, at: CGPoint(x: labelX, y: labelY), context: context)
        if window?.firstResponder === self {
            let width = CGFloat(PixelText.width(of: title, font: .regular))
            let rect = CGRect(x: labelX - 1, y: labelY, width: width + 2, height: CGFloat(PixelText.lineHeight))
            for x in stride(from: Int(rect.minX), to: Int(rect.maxX), by: 2) {
                Bevel.fill(CGRect(x: x, y: Int(rect.minY), width: 1, height: 1), color: .black, context: context)
                Bevel.fill(CGRect(x: x, y: Int(rect.maxY) - 1, width: 1, height: 1), color: .black, context: context)
            }
        }
    }
}
