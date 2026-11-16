import AppKit
import Retro98UI
import Testing
@testable import Retro98Themes

@Test func frameIsTheTitleGradientMirrored() {
    let image = ChromeThemeImages.frame(active: true)
    #expect(image.width == 3200 && image.height == 64)
    #expect(image.color(x: 0, y: 0) == hex("000080"))
    #expect(image.color(x: 1599, y: 0) == hex("1084D0"))
    #expect(image.color(x: 1600, y: 0) == hex("1084D0"))
    #expect(image.color(x: 3199, y: 0) == hex("000080"))
    #expect(image.color(x: 400, y: 10) == image.color(x: 2799, y: 10))
    for x in [0, 800, 1599] { #expect(image.color(x: x, y: 0) == image.color(x: x, y: 63)) }
}

@Test func inactiveFrameIsGray() {
    let image = ChromeThemeImages.frame(active: false)
    #expect(image.color(x: 0, y: 0) == hex("808080"))
    #expect(image.color(x: 1599, y: 0) == hex("C0C0C0"))
    #expect(image.color(x: 3199, y: 63) == hex("808080"))
}

@Test func pngKeepsTheSize() throws {
    let data = try #require(ChromeThemeImages.png(ChromeThemeImages.frame(active: true)))
    let rep = try #require(NSBitmapImageRep(data: data))
    #expect(rep.pixelsWide == 3200 && rep.pixelsHigh == 64)
}
