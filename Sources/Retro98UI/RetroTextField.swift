import AppKit

/// A white sunken field around a plain NSTextField (Tahoma), the one non-pixel exception.
@MainActor
public final class RetroTextField: PixelView, NSTextFieldDelegate {
    public static let height: CGFloat = 23
    private let field = NSTextField()
    /// Enter in the field.
    public var onSubmit: (() -> Void)?
    /// Every edit the person makes.
    public var onChange: (() -> Void)?
    /// Esc in the field; without it, Esc goes on to the window as usual.
    public var onCancel: (() -> Void)?

    override public init(frame: CGRect) {
        super.init(frame: frame)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = true
        field.backgroundColor = .white
        field.focusRingType = .none
        field.font = NSFont(name: "Tahoma", size: PixelFont.regular.size)
        field.frame = bounds.insetBy(dx: 3, dy: 3)
        field.autoresizingMask = [.width, .height]
        field.target = self
        field.action = #selector(submit)
        field.delegate = self
        addSubview(field)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public var text: String {
        get { field.stringValue }
        set { field.stringValue = newValue }
    }

    /// Makes the field the first responder with its text selected.
    public func focus(in window: NSWindow) {
        window.makeFirstResponder(field)
        field.currentEditor()?.selectAll(nil)
    }

    public func controlTextDidChange(_ notification: Notification) { onChange?() }

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        guard commandSelector == #selector(NSResponder.cancelOperation(_:)), let onCancel else { return false }
        onCancel()
        return true
    }

    @objc private func submit() { onSubmit?() }

    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.draw(.field, in: CGRect(origin: .zero, size: size), context: context)
    }
}
