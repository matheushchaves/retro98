import AppKit
import Testing
@testable import Retro98UI

@MainActor @Test func buttonHasClassicPreferredSize() {
    #expect(RetroButton.preferredSize(title: "OK", icon: nil, bold: false) == CGSize(width: 75, height: 23))
    #expect(RetroButton.preferredSize(title: String(repeating: "W", count: 20), icon: nil, bold: false).width > 75)
}

@MainActor @Test func buttonNormalUsesRaisedBevel() {
    let image = renderView(RetroButton(title: "OK") {})
    #expect(image.color(x: 0, y: 0) == Palette.light)
    #expect(image.color(x: 74, y: 22) == Palette.darkShadow)
}

@MainActor @Test func buttonPressedUsesPressedBevel() {
    let button = RetroButton(title: "OK") {}
    button.isPressed = true
    #expect(renderView(button).color(x: 0, y: 0) == Palette.darkShadow)
}

@MainActor @Test func defaultButtonHasExtraBlackBorder() {
    let image = renderView(RetroButton(title: "OK", isDefault: true) {})
    #expect(image.color(x: 0, y: 0) == Palette.darkShadow)
    #expect(image.color(x: 1, y: 1) == Palette.light)
    #expect(image.color(x: 74, y: 22) == Palette.darkShadow)
}

@MainActor @Test func buttonTriggersActionOnSpaceKey() throws {
    var pressed = 0
    let button = RetroButton(title: "OK") { pressed += 1 }
    let space = try #require(NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        characters: " ", charactersIgnoringModifiers: " ", isARepeat: false, keyCode: 49
    ))
    button.keyDown(with: space)
    #expect(pressed == 1)
}

@MainActor @Test func radioSelectedShowsCenterDot() {
    // The 12×12 circle is centered vertically in the 16-pt line.
    let radio = RetroRadioButton(title: "Desligar", isSelected: true) {}
    #expect(radio.frame.height == CGFloat(PixelText.lineHeight))
    #expect(renderView(radio).color(x: 6, y: 8) == .black)
    radio.isSelected = false
    #expect(renderView(radio).color(x: 6, y: 8) == .white)
}

@MainActor @Test func radioClickSelects() {
    var selected = false
    let radio = RetroRadioButton(title: "Reiniciar", isSelected: false) { selected = true }
    radio.select()
    #expect(selected)
    #expect(radio.isSelected)
}
