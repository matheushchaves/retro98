import Testing
@testable import Retro98UI

@Test func everyKindHasBothSizes() {
    for kind in FileIconKind.allCases {
        for size in [16, 32] {
            let icon = FileIcons.icon(kind, size: size)
            #expect(icon.width == size && icon.height == size, "\(kind) \(size)")
            #expect(opaqueRatio(icon) > 1.0 / 8.0, "\(kind) \(size) looks empty")
        }
    }
}

@Test func kindsAreDistinct() {
    let renders = FileIconKind.allCases.map { kind -> [PixelColor] in allPixels(render(FileIcons.icon(kind, size: 32))) }
    for (i, a) in renders.enumerated() {
        for b in renders.dropFirst(i + 1) { #expect(a != b) }
    }
}

@Test func toolbarIconsAre16() {
    let icons = [FileIcons.back, FileIcons.forward, FileIcons.up, FileIcons.cut, FileIcons.copy, FileIcons.paste,
                 FileIcons.undo, FileIcons.delete, FileIcons.properties, FileIcons.views]
    #expect(icons.allSatisfy { $0.width == 16 && $0.height == 16 && opaqueRatio($0) > 0.05 })
    #expect(FileIcons.explorerApp.width == 32 && opaqueRatio(FileIcons.explorerApp) > 1.0 / 8.0)
}

/// The grid asks for an icon per visible cell on every draw; drawing it again each time makes scrolling stutter.
@Test func fileIconsAreDrawnOncePerKindAndSize() {
    #expect(FileIcons.icon(.folder, size: 32).image() === FileIcons.icon(.folder, size: 32).image())
    #expect(FileIcons.icon(.folder, size: 16).image() !== FileIcons.icon(.folder, size: 32).image())
}

@Test func promptAppIsOriginalPixelArt() {
    #expect(FileIcons.promptApp.width == 32 && FileIcons.promptApp.height == 32 && opaqueRatio(FileIcons.promptApp) > 1.0 / 8.0)
    #expect(FileIcons.promptAppSmall.width == 16 && FileIcons.promptAppSmall.height == 16
        && opaqueRatio(FileIcons.promptAppSmall) > 1.0 / 8.0)
}

@Test func notepadIconIsAPageWithBlueLines() {
    #expect(FileIcons.notepadApp.width == 32 && FileIcons.notepadApp.height == 32)
    let small = allPixels(render(FileIcons.notepadAppSmall))
    #expect(small.count == 256)
    #expect(small.contains(.white) && small.contains(PixelColor(red: 0x00, green: 0x00, blue: 0xFF)))
}
