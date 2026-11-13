import AppKit
import Retro98UI
import Testing
@testable import Retro98Notepad

private func find(_ needle: String, in text: String, _ selection: NSRange, forward: Bool = true, matchCase: Bool = false) -> NSRange? {
    TextSearch.find(needle, in: text, selection: selection, forward: forward, matchCase: matchCase)
}

@Test func findsForwardFromTheSelectionEnd() {
    #expect(find("ab", in: "ab ab ab", NSRange(location: 0, length: 2)) == NSRange(location: 3, length: 2))
    #expect(find("ab", in: "ab ab ab", NSRange(location: 0, length: 0)) == NSRange(location: 0, length: 2))
}

@Test func findsBackwardBeforeTheSelection() {
    #expect(find("ab", in: "ab ab ab", NSRange(location: 6, length: 2), forward: false) == NSRange(location: 3, length: 2))
}

@Test func ignoresCaseUnlessAsked() {
    #expect(find("Ação", in: "uma ação", NSRange(location: 0, length: 0)) == NSRange(location: 4, length: 4))
    #expect(find("Ação", in: "uma ação", NSRange(location: 0, length: 0), matchCase: true) == nil)
}

@Test func neverWraps() {
    #expect(find("ab", in: "ab ab ab", NSRange(location: 6, length: 2)) == nil)
    #expect(find("ab", in: "ab ab ab", NSRange(location: 0, length: 2), forward: false) == nil)
}

@Test func emptyNeedleFindsNothing() {
    #expect(find("", in: "texto", NSRange(location: 0, length: 0)) == nil)
}

@Test func rangesAreUTF16() {
    #expect(find("a", in: "😀 a", NSRange(location: 0, length: 0)) == NSRange(location: 3, length: 1))
}

@MainActor private func findDialog(text: String) -> (FindDialog, NSTextView, ScriptedNotepadPrompter) {
    let view = NSTextView(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
    view.string = text
    view.setSelectedRange(NSRange(location: 0, length: 0))
    let prompter = ScriptedNotepadPrompter()
    return (FindDialog(languages: ["pt-BR"], prompter: prompter, target: { view }), view, prompter)
}

@MainActor @Test func findNextSelectsTheMatch() {
    let (dialog, view, prompter) = findDialog(text: "um dois um")
    dialog.field.text = "um"
    #expect(dialog.needle == "um")
    #expect(dialog.findNext())
    #expect(view.selectedRange() == NSRange(location: 0, length: 2))
    #expect(dialog.findNext())
    #expect(view.selectedRange() == NSRange(location: 8, length: 2))
    #expect(!dialog.findNext())
    #expect(prompter.told.last == "Não foi possível localizar \"um\"")
    #expect(view.selectedRange() == NSRange(location: 8, length: 2))
}

@MainActor @Test func upSearchesBackward() {
    let (dialog, view, _) = findDialog(text: "um dois um")
    view.setSelectedRange(NSRange(location: 10, length: 0))
    dialog.field.text = "UM"
    dialog.up.select()
    #expect(dialog.up.isSelected && !dialog.down.isSelected)
    #expect(dialog.findNext())
    #expect(view.selectedRange() == NSRange(location: 8, length: 2))
    #expect(dialog.findNext())
    #expect(view.selectedRange() == NSRange(location: 0, length: 2))
    dialog.matchCase.performClick()
    dialog.down.select()
    #expect(!dialog.findNext())
}

@MainActor @Test func findNextIsOffWhileTheFieldIsEmpty() {
    let (dialog, _, _) = findDialog(text: "um")
    #expect(!dialog.findNextButton.isEnabled)
    dialog.field.text = "u"
    dialog.field.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
    #expect(dialog.findNextButton.isEnabled)
    dialog.field.text = ""
    dialog.field.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
    #expect(!dialog.findNextButton.isEnabled)
}
