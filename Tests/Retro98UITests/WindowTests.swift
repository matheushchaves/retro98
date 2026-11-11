import AppKit
import Testing
@testable import Retro98UI

private func gradient(active: Bool) -> PixelImage {
    PixelCanvas.render(width: 200, height: 18) { context in
        RetroWindow.drawTitleGradient(active: active, in: CGRect(x: 0, y: 0, width: 200, height: 18), context: context)
    }
}

@Test func titleBarUsesActiveGradientEnds() {
    let image = gradient(active: true)
    #expect(image.color(x: 0, y: 8) == Palette.activeTitle.start)
    #expect(image.color(x: 199, y: 8) == Palette.activeTitle.end)
}

@Test func inactiveTitleUsesGrayGradient() {
    let image = gradient(active: false)
    #expect(image.color(x: 0, y: 8) == Palette.inactiveTitle.start)
    #expect(image.color(x: 199, y: 8) == Palette.inactiveTitle.end)
}

@MainActor @Test func escapeCallsOnCancel() {
    let window = RetroWindow(title: "Executar", contentSize: CGSize(width: 200, height: 100))
    var cancelled = false
    window.onCancel = { cancelled = true }
    window.cancelOperation(nil)
    #expect(cancelled)
}

@MainActor @Test func enterTriggersDefaultButton() throws {
    let window = RetroWindow(title: "Executar", contentSize: CGSize(width: 200, height: 100))
    var pressed = false
    window.defaultButton = RetroButton(title: "OK", isDefault: true) { pressed = true }
    let enter = try #require(NSEvent.keyEvent(
        with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
        characters: "\r", charactersIgnoringModifiers: "\r", isARepeat: false, keyCode: 36
    ))
    window.keyDown(with: enter)
    #expect(pressed)
}

@MainActor @Test func contentContainerSitsBelowTitleBar() {
    let window = RetroWindow(title: "Executar", contentSize: CGSize(width: 200, height: 100))
    #expect(window.contentContainer.frame.size == CGSize(width: 200, height: 100))
    #expect(window.contentContainer.frame.minY >= 21)
}

@Test func messageBoxLayoutFitsLongText() {
    let short = RetroMessageBox.layout(message: "Pronto.", buttons: ["OK"])
    let long = RetroMessageBox.layout(message: String(repeating: "Não foi possível encontrar o arquivo. ", count: 8),
                                      buttons: ["OK"])
    #expect(short.lines == ["Pronto."])
    #expect(long.lines.count > 2)
    #expect(long.lines.allSatisfy { PixelText.width(of: $0, font: .regular) <= RetroMessageBox.maxTextWidth })
    #expect(long.contentSize.height > short.contentSize.height)
    #expect(short.contentSize.width >= 75 + 24)
}

@Test func messageBoxKeepsExplicitLineBreaks() {
    #expect(RetroMessageBox.layout(message: "Linha 1\nLinha 2", buttons: ["OK"]).lines == ["Linha 1", "Linha 2"])
}
