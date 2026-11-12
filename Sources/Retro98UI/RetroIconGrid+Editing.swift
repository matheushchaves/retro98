import AppKit

/// Renaming in place: a white field with a black border over the item's label.
/// Enter confirms, Esc cancels, and clicking elsewhere confirms.
extension RetroIconGrid {
    static let editorMinWidth: CGFloat = 84
    static let editorMaxWidth: CGFloat = 168

    public func beginEditing(at index: Int, text: String, selecting range: NSRange) {
        if editingIndex != nil { endEditing(commit: true) }
        guard index < count else { return }
        let field = NSTextField(string: text)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = true
        field.backgroundColor = .white
        field.focusRingType = .none
        field.font = NSFont(name: "Tahoma", size: PixelFont.regular.size)
        field.cell?.usesSingleLineMode = true
        field.cell?.isScrollable = true
        field.wantsLayer = true
        field.layer?.borderWidth = 1
        field.layer?.borderColor = NSColor.black.cgColor
        field.delegate = self
        editor = field
        editingIndex = index
        addSubview(field)
        placeEditor(at: index)
        scrollToVisible(geometry.frame(of: index))
        window?.makeFirstResponder(field)
        (field.currentEditor() as? NSTextView)?.setSelectedRange(range)
        needsDisplay = true
    }

    /// Closes the field and reports the text (commit) or nil (cancel).
    public func endEditing(commit: Bool) {
        guard let index = editingIndex, let field = editor else { return }
        let text = field.stringValue
        editingIndex = nil
        editor = nil
        field.delegate = nil
        if window?.firstResponder === field.currentEditor() { window?.makeFirstResponder(self) }
        field.removeFromSuperview()
        if window?.firstResponder == nil || window?.firstResponder === window { window?.makeFirstResponder(self) }
        needsDisplay = true
        onEndEditing?(index, commit ? text : nil)
    }

    /// The edited item moved (the folder reloaded); nil means it is gone, which cancels.
    public func moveEditing(to index: Int?) {
        guard editingIndex != nil else { return }
        guard let index, index < count else {
            endEditing(commit: false)
            return
        }
        editingIndex = index
        placeEditor(at: index)
        needsDisplay = true
    }

    /// Over the label: centered under a large icon, or starting at the one-line label in the other modes.
    func placeEditor(at index: Int) {
        guard let field = editor else { return }
        let geometry = geometry
        let cell = geometry.frame(of: index)
        let textWidth = CGFloat(PixelText.width(of: field.stringValue, font: .regular)) + 8
        let width = min(max(Self.editorMinWidth, textWidth), Self.editorMaxWidth)
        let height = CGFloat(PixelText.lineHeight + 4)
        if style == .largeIcons {
            field.frame = CGRect(x: (cell.midX - width / 2).rounded(.down), y: cell.minY + Self.labelTop - 2, width: width, height: height)
        } else {
            field.frame = CGRect(x: geometry.labelX(of: index) - 2, y: cell.minY + ((cell.height - height) / 2).rounded(.down),
                                 width: width, height: height)
        }
    }

    // MARK: NSTextFieldDelegate

    public func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.insertNewline(_:)):
            endEditing(commit: true)
            return true
        case #selector(NSResponder.cancelOperation(_:)):
            endEditing(commit: false)
            return true
        default:
            return false
        }
    }

    /// Focus left the field (a click elsewhere): keep what was typed.
    public func controlTextDidEndEditing(_ notification: Notification) {
        guard (notification.object as? NSTextField) === editor else { return }
        endEditing(commit: true)
    }
}
