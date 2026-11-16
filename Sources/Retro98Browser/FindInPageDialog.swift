import AppKit
import Retro98UI

/// The Find window: what to look for and Find Next, Find Previous, Close. It floats over the Browser's
/// windows without blocking them and searches the active tab's page.
@MainActor
final class FindInPageDialog {
    static let margin: CGFloat = 8
    static let buttonWidth: CGFloat = 124
    static let contentSize = CGSize(width: 400, height: 96)

    let window: RetroWindow
    let field: RetroTextField
    private let languages: [String]
    private let prompter: BrowserPrompter
    private let page: () -> BrowserPage?

    var needle: String { field.text }

    init(languages l: [String], prompter: BrowserPrompter, page: @escaping () -> BrowserPage?) {
        languages = l
        self.prompter = prompter
        self.page = page
        window = RetroWindow(title: BrowserText.findTitle(l), contentSize: Self.contentSize)
        window.level = .floating
        window.hidesOnDeactivate = true
        let margin = Self.margin
        let buttonX = Self.contentSize.width - margin - Self.buttonWidth
        let labelText = BrowserText.findWhat(l)
        let labelWidth = CGFloat(PixelText.width(of: labelText, font: .regular))
        let label = RetroLabel(lines: [labelText])
        label.frame = CGRect(x: margin, y: margin + 4, width: labelWidth, height: CGFloat(PixelText.lineHeight))
        let fieldX = margin + labelWidth + 8
        field = RetroTextField(frame: CGRect(x: fieldX, y: margin, width: buttonX - 8 - fieldX, height: RetroTextField.height))
        let content = window.contentContainer
        content.addSubview(label)
        content.addSubview(field)

        let actions: [(String, Bool, () -> Void)] = [
            (BrowserText.findNext(l), true, { [weak self] in self?.findNext() }),
            (BrowserText.findPrevious(l), false, { [weak self] in self?.findPrevious() }),
            (BrowserText.close(l), false, { [weak self] in self?.window.orderOut(nil) }),
        ]
        for (index, action) in actions.enumerated() {
            let button = RetroButton(title: action.0, isDefault: action.1, action: action.2)
            button.frame = CGRect(x: buttonX, y: margin + CGFloat(index) * (RetroButton.height + 4), width: Self.buttonWidth,
                                  height: RetroButton.height)
            content.addSubview(button)
            if action.1 { window.defaultButton = button }
        }
        window.onCancel = { [weak self] in self?.window.orderOut(nil) }
        field.onSubmit = { [weak self] in self?.findNext() }
    }

    /// Modeless and floating; focuses the field with its text selected.
    func show() {
        if !window.isVisible { window.showCentered() }
        window.makeKeyAndOrderFront(nil)
        field.focus(in: window)
    }

    func findNext() { find(backwards: false) }
    func findPrevious() { find(backwards: true) }

    /// Asks the active page; tells when the text isn't there.
    private func find(backwards: Bool) {
        let needle = needle
        guard !needle.isEmpty, let page = page() else { return }
        let prompter = prompter, languages = languages
        page.find(needle, backwards: backwards) { found in
            if !found { prompter.tell(BrowserText.notFound(needle, languages), icon: .info, languages: languages) }
        }
    }
}
