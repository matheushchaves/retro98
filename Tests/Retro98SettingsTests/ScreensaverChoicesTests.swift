import Foundation
import Testing
@testable import Retro98Settings

private let url = URL(filePath: "/home/Library/Application Support/Retro98/choices.plist")

@Test func screensaverDefaultIsPipes() {
    #expect(Choices.standard.screensaver == .pipes)
    #expect(Choices.standard.screensaverTimeout == 5)
}

@Test func screensaverRoundTrips() throws {
    let file = ChoicesFile(url: url, files: InMemoryFileStore())
    let choices = Choices.standard.with(screensaver: .johnny).with(screensaverTimeout: 10)
    try file.save(choices)
    let back = file.load()
    #expect(back.screensaver == .johnny)
    #expect(back.screensaverTimeout == 10)
}

@Test func screensaverNoneRoundTrips() throws {
    let file = ChoicesFile(url: url, files: InMemoryFileStore())
    let choices = Choices.standard.with(screensaver: .none).with(screensaverTimeout: 1)
    try file.save(choices)
    let back = file.load()
    #expect(back.screensaver == .none)
    #expect(back.screensaverTimeout == 1)
}

@Test func missingScreensaverKeyFallsBackToDefault() throws {
    let files = InMemoryFileStore()
    let plist: [String: Any] = [
        "wallpaper": ["kind": "color", "hex": "#008080"],
        "turnedOff": [String](),
        "soundsOn": true,
    ]
    try files.write(try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0), to: url)
    let back = ChoicesFile(url: url, files: files).load()
    #expect(back.screensaver == .pipes)
    #expect(back.screensaverTimeout == 5)
}

@Test func allScreensaverKindsCaseIterable() {
    let all = ScreensaverKind.allCases
    #expect(all.contains(.none))
    #expect(all.contains(.pipes))
    #expect(all.contains(.text3d))
    #expect(all.contains(.johnny))
    #expect(all.count == 4)
}
