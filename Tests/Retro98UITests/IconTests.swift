import CoreGraphics
import Foundation
import Testing
@testable import Retro98UI

@Test func iconMapsPaletteCharacters() {
    let image = render(PixelIcon(rows: ["KW", "T."]))
    #expect(image.color(x: 0, y: 0) == .black)
    #expect(image.color(x: 1, y: 0) == .white)
    #expect(image.color(x: 0, y: 1) == Palette.desktop)
    #expect(image.alpha(x: 1, y: 1) == 0)
    #expect(image.alpha(x: 0, y: 0) == 255)
}

@Test func drawnIconsHaveRequestedSize() {
    let icon = PixelIcon(width: 4, height: 3) { context in
        Bevel.fill(CGRect(x: 0, y: 0, width: 4, height: 3), color: .black, context: context)
    }
    #expect(icon.width == 4 && icon.height == 3)
    #expect(render(icon).color(x: 3, y: 2) == .black)
}

@Test func everyBuiltInIconHasDeclaredSize() {
    let small = [Icons.startLogo, Icons.folder, Icons.document, Icons.application, Icons.systemSettings,
                 Icons.batteryFull, Icons.batteryHalf, Icons.batteryLow, Icons.batteryCharging,
                 Icons.volume, Icons.volumeMuted]
    let large = [Icons.programs, Icons.documents, Icons.settings, Icons.help, Icons.run, Icons.shutDown,
                 Icons.info, Icons.warning, Icons.error, Icons.question]
    #expect(small.allSatisfy { $0.width == 16 && $0.height == 16 })
    #expect(large.allSatisfy { $0.width == 32 && $0.height == 32 })
}

@Test func builtInIconsAreNotBlank() {
    let all = [Icons.startLogo, Icons.folder, Icons.programs, Icons.info, Icons.shutDown, Icons.volumeMuted]
    for icon in all {
        let image = render(icon)
        let opaque = (0..<image.height).flatMap { y in (0..<image.width).map { x in image.alpha(x: x, y: y) } }
            .filter { $0 == 255 }.count
        #expect(opaque > icon.width * icon.height / 8)
    }
}

@Test func appIconIsPixelatedAtRequestedSize() {
    let image = PixelIcon.appIcon(for: URL(filePath: "/System/Applications/Calculator.app"), size: 16)
    #expect(image.width == 16 && image.height == 16)
}
