import AppKit
import Testing
@testable import Retro98UI

@MainActor @Test func textFieldReportsEdits() {
    let field = RetroTextField(frame: CGRect(x: 0, y: 0, width: 120, height: RetroTextField.height))
    var edits = 0
    field.onChange = { edits += 1 }
    field.text = "abc"
    field.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification))
    #expect(edits == 1)
    #expect(field.text == "abc")
}

@MainActor @Test func dropDownArrowSitsInsideTheBorder() {
    #expect(RetroDropDown.arrowFrame(in: CGRect(x: 0, y: 0, width: 200, height: 22)) == CGRect(x: 182, y: 2, width: 16, height: 18))
}

@MainActor @Test func dropDownDrawsItsText() {
    let box = RetroDropDown(items: { [] })
    box.frame = CGRect(x: 0, y: 0, width: 200, height: RetroDropDown.height)
    box.set(text: "Documentos", icon: nil)
    let image = renderView(box)
    let interior = (3..<19).flatMap { y in (3..<180).map { x in image.color(x: x, y: y) } }
    #expect(box.text == "Documentos")
    #expect(interior.contains(.white) && interior.contains(.black))
    #expect(image.color(x: 185, y: 5) == Palette.face)
}

@MainActor @Test func groupBoxDrawsAnEtchedFrame() {
    let box = RetroGroupBox(title: "Direção")
    box.frame = CGRect(x: 0, y: 0, width: 120, height: 60)
    let image = renderView(box)
    #expect(image.color(x: 0, y: 30) == Palette.shadow)
    #expect(image.color(x: 1, y: 30) == .white)
    #expect(image.color(x: 100, y: 7) == Palette.shadow)
    #expect(image.color(x: 12, y: 7) != Palette.shadow)
}

@MainActor @Test func disabledButtonDoesNothing() {
    var clicks = 0
    let button = RetroButton(title: "OK") { clicks += 1 }
    button.performClick()
    button.isEnabled = false
    button.performClick()
    #expect(clicks == 1)
    #expect(!button.acceptsFirstResponder)
    let image = renderView(button)
    let inside = (4..<19).flatMap { y in (4..<71).map { x in image.color(x: x, y: y) } }
    #expect(inside.contains(Palette.shadow) && !inside.contains(.black))
}
