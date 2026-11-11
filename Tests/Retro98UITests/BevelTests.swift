import CoreGraphics
import Testing
@testable import Retro98UI

private let white = PixelColor(red: 255, green: 255, blue: 255)
private let black = PixelColor(red: 0, green: 0, blue: 0)

private func bevel(_ style: BevelStyle) -> PixelImage {
    PixelCanvas.render(width: 10, height: 10) { context in
        Bevel.fillFace(CGRect(x: 0, y: 0, width: 10, height: 10), context: context)
        Bevel.draw(style, in: CGRect(x: 0, y: 0, width: 10, height: 10), context: context)
    }
}

@Test func paletteMatchesSpec() {
    #expect(Palette.face == PixelColor(red: 0xC0, green: 0xC0, blue: 0xC0))
    #expect(Palette.shadow == PixelColor(red: 0x80, green: 0x80, blue: 0x80))
    #expect(Palette.light == white)
    #expect(Palette.darkShadow == black)
    #expect(Palette.selection == PixelColor(red: 0, green: 0, blue: 0x80))
    #expect(Palette.desktop == PixelColor(red: 0, green: 0x80, blue: 0x80))
    #expect(Palette.tooltip == PixelColor(red: 0xFF, green: 0xFF, blue: 0xE1))
    #expect(Palette.activeTitle.start == PixelColor(red: 0, green: 0, blue: 0x80))
    #expect(Palette.activeTitle.end == PixelColor(red: 0x10, green: 0x84, blue: 0xD0))
    #expect(Palette.inactiveTitle.start == Palette.shadow)
    #expect(Palette.inactiveTitle.end == Palette.face)
}

@Test func raisedBevelHasLightTopLeftAndDarkBottomRight() {
    let image = bevel(.raised)
    #expect(image.color(x: 0, y: 0) == Palette.light)
    #expect(image.color(x: 1, y: 1) == Palette.face)
    #expect(image.color(x: 9, y: 9) == Palette.darkShadow)
    #expect(image.color(x: 8, y: 8) == Palette.shadow)
    #expect(image.color(x: 9, y: 0) == Palette.darkShadow)
    #expect(image.color(x: 0, y: 9) == Palette.darkShadow)
}

@Test func sunkenFieldIsInverseWithWhiteInterior() {
    let image = bevel(.field)
    #expect(image.color(x: 0, y: 0) == Palette.shadow)
    #expect(image.color(x: 1, y: 1) == Palette.darkShadow)
    #expect(image.color(x: 9, y: 9) == Palette.light)
    #expect(image.color(x: 8, y: 8) == Palette.face)
    #expect(image.color(x: 5, y: 5) == white)
}

@Test func pressedButtonInvertsRaised() {
    let image = bevel(.buttonPressed)
    #expect(image.color(x: 0, y: 0) == Palette.darkShadow)
    #expect(image.color(x: 1, y: 1) == Palette.shadow)
    #expect(image.color(x: 9, y: 9) == Palette.light)
}

@Test func windowBevelStartsWithFaceThenLight() {
    let image = bevel(.window)
    #expect(image.color(x: 0, y: 0) == Palette.face)
    #expect(image.color(x: 1, y: 1) == Palette.light)
    #expect(image.color(x: 9, y: 9) == Palette.darkShadow)
    #expect(image.color(x: 8, y: 8) == Palette.shadow)
}

@Test func statusFieldIsOnePixelSunken() {
    let image = bevel(.statusField)
    #expect(image.color(x: 0, y: 0) == Palette.shadow)
    #expect(image.color(x: 9, y: 9) == Palette.light)
    #expect(image.color(x: 1, y: 1) == Palette.face)
}

@Test func canvasHasTopLeftOriginAndNoAntialiasing() {
    let image = PixelCanvas.render(width: 10, height: 10) { context in
        Bevel.fillFace(CGRect(x: 0, y: 0, width: 10, height: 10), context: context)
        context.setFillColor(black.cgColor)
        context.fill(CGRect(x: 0, y: 0, width: 3, height: 1))
        context.setStrokeColor(black.cgColor)
        context.setLineWidth(1)
        context.strokeLineSegments(between: [CGPoint(x: 0, y: 3), CGPoint(x: 9, y: 9)])
    }
    #expect((0..<3).allSatisfy { image.color(x: $0, y: 0) == black })
    #expect(image.color(x: 0, y: 1) == Palette.face)
    let all = (0..<10).flatMap { y in (0..<10).map { x in image.color(x: x, y: y) } }
    #expect(all.allSatisfy { $0 == black || $0 == Palette.face })
}
