import AppKit
import Retro98UI

/// "Address", the field and the Go button. While the person is typing, the page doesn't overwrite the text.
@MainActor
final class AddressBar: PixelView {
    static let height: CGFloat = 27
    /// Enter or Go, with what was typed.
    var onSubmit: ((String) -> Void)?
    /// Esc: the window puts the page's address back.
    var onCancel: (() -> Void)?
    /// The person has typed something not yet submitted or cancelled.
    private(set) var isEditing = false
    private let label: String
    private let field = RetroTextField(frame: CGRect(x: 0, y: 0, width: 100, height: RetroTextField.height))
    private let goButton: RetroButton

    init(label: String, goTitle: String) {
        self.label = label
        var submit: (() -> Void)?
        goButton = RetroButton(title: goTitle) { submit?() }
        super.init(frame: CGRect(x: 0, y: 0, width: 400, height: Self.height))
        submit = { [weak self] in self?.submit() }
        field.onSubmit = { [weak self] in self?.submit() }
        field.onChange = { [weak self] in self?.isEditing = true }
        field.onCancel = { [weak self] in self?.cancel() }
        addSubview(field)
        addSubview(goButton)
        layoutParts()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// What the field shows; setting it is the page speaking, not the person.
    var text: String {
        get { field.text }
        set { field.text = newValue }
    }

    func focus(in window: NSWindow) { field.focus(in: window) }

    /// The person typed `text` (the field's own edits arrive here too).
    func typed(_ text: String) {
        field.text = text
        isEditing = true
    }

    func submit() {
        isEditing = false
        onSubmit?(field.text)
    }

    func cancel() {
        isEditing = false
        onCancel?()
    }

    /// Drops what was being typed without telling anyone (the window is about to show another address).
    func endEditing() { isEditing = false }

    private var labelWidth: CGFloat { CGFloat(PixelText.width(of: label, font: .regular)) + 16 }

    private func layoutParts() {
        let buttonWidth = goButton.frame.width
        goButton.frame.origin = CGPoint(x: bounds.width - buttonWidth - 4, y: ((bounds.height - RetroButton.height) / 2).rounded(.down))
        field.frame = CGRect(x: labelWidth, y: ((bounds.height - RetroTextField.height) / 2).rounded(.down),
                             width: max(goButton.frame.minX - 4 - labelWidth, 0), height: RetroTextField.height)
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        layoutParts()
    }

    override func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        let y = ((size.height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down)
        PixelText.draw(label, font: .regular, color: .black, at: CGPoint(x: 8, y: y), context: context)
    }
}
