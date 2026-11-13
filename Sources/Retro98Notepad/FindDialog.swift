import AppKit
import Retro98UI

/// The Find window: what to look for, the direction and whether case matters. It floats over the Notepad
/// windows without blocking them and searches whichever one is active.
@MainActor
final class FindDialog {
    static let margin: CGFloat = 8
    static let buttonWidth: CGFloat = 104

    let window: RetroWindow
    let field: RetroTextField
    let matchCase: RetroCheckBox
    let up: RetroRadioButton
    let down: RetroRadioButton
    let findNextButton: RetroButton
    private let languages: [String]
    private let prompter: NotepadPrompter
    private let target: () -> NSTextView?
    private let wiring = Wiring()

    /// Lets the controls, created before `self` is complete, call back into the dialog.
    private final class Wiring {
        var findNext: () -> Void = {}
        var cancel: () -> Void = {}
        var choseUp: (Bool) -> Void = { _ in }
    }

    var needle: String { field.text }

    init(languages l: [String], prompter: NotepadPrompter, target: @escaping () -> NSTextView?) {
        languages = l
        self.prompter = prompter
        self.target = target
        let wiring = wiring
        matchCase = RetroCheckBox(title: NotepadText.matchCase(l), isOn: false) { _ in }
        up = RetroRadioButton(title: NotepadText.up(l), isSelected: false) { wiring.choseUp(true) }
        down = RetroRadioButton(title: NotepadText.down(l), isSelected: true) { wiring.choseUp(false) }
        findNextButton = RetroButton(title: NotepadText.findNext(l), isDefault: true) { wiring.findNext() }

        // Find what: [field] [Find Next] / [Direction: Up Down] [Match case] [Cancel]
        let margin = Self.margin
        let labelWidth = CGFloat(PixelText.width(of: NotepadText.findWhat(l), font: .regular))
        let groupWidth = 16 + up.frame.width + 12 + down.frame.width + 8
        let checkSize = RetroCheckBox.preferredSize(title: NotepadText.matchCase(l))
        let fieldX = margin + labelWidth + 8
        let leftWidth = max(fieldX + 180, margin + groupWidth + 10 + checkSize.width)
        let buttonX = leftWidth + 8
        let contentSize = CGSize(width: buttonX + Self.buttonWidth + margin, height: 96)
        window = RetroWindow(title: NotepadText.findTitle(l), contentSize: contentSize)
        window.level = .floating
        window.hidesOnDeactivate = true
        field = RetroTextField(frame: CGRect(x: fieldX, y: margin, width: leftWidth - fieldX, height: RetroTextField.height))

        let content = window.contentContainer
        let label = RetroLabel(lines: [NotepadText.findWhat(l)])
        label.frame = CGRect(x: margin, y: margin + 4, width: labelWidth, height: CGFloat(PixelText.lineHeight))
        let group = RetroGroupBox(title: NotepadText.direction(l))
        group.frame = CGRect(x: margin, y: 38, width: groupWidth, height: 50)
        up.frame.origin = CGPoint(x: 8, y: 24)
        down.frame.origin = CGPoint(x: 8 + up.frame.width + 12, y: 24)
        group.addSubview(up)
        group.addSubview(down)
        matchCase.frame = CGRect(origin: CGPoint(x: margin + groupWidth + 10, y: 64), size: checkSize)
        findNextButton.frame = CGRect(x: buttonX, y: margin, width: Self.buttonWidth, height: RetroButton.height)
        let cancel = RetroButton(title: NotepadText.cancel(l)) { wiring.cancel() }
        cancel.frame = CGRect(x: buttonX, y: margin + RetroButton.height + 6, width: Self.buttonWidth, height: RetroButton.height)
        for view in [label, field, group, matchCase, findNextButton, cancel] { content.addSubview(view) }

        window.defaultButton = findNextButton
        findNextButton.isEnabled = false
        wiring.findNext = { [weak self] in self?.findNext() }
        wiring.cancel = { [weak self] in self?.window.orderOut(nil) }
        wiring.choseUp = { [weak self] isUp in
            self?.up.isSelected = isUp
            self?.down.isSelected = !isUp
        }
        window.onCancel = wiring.cancel
        field.onSubmit = wiring.findNext
        field.onChange = { [weak self] in
            guard let self else { return }
            self.findNextButton.isEnabled = !self.needle.isEmpty
        }
    }

    /// Modeless and floating; focuses the field with its text selected.
    func show() {
        if !window.isVisible { window.showCentered() }
        window.makeKeyAndOrderFront(nil)
        field.focus(in: window)
        findNextButton.isEnabled = !needle.isEmpty
    }

    /// Selects and scrolls to the next match in the active Notepad window; tells when there is none.
    @discardableResult
    func findNext() -> Bool {
        guard let view = target(), !needle.isEmpty else { return false }
        guard let match = TextSearch.find(needle, in: view.string, selection: view.selectedRange(), forward: down.isSelected,
                                          matchCase: matchCase.isOn) else {
            prompter.tell(NotepadText.notFound(needle, languages), icon: .info, languages: languages)
            return false
        }
        view.setSelectedRange(match)
        view.scrollRangeToVisible(match)
        return true
    }
}
