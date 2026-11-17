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
    let choices = Choices.standard.with(screensaver: .island).with(screensaverTimeout: 10)
    try file.save(choices)
    let back = file.load()
    #expect(back.screensaver == .island)
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
    #expect(all.contains(.island))
    #expect(all.count == 4)
}

@Test func screensaverSoundIsOffByDefault() {
    #expect(Choices.standard.screensaverSound == false)
}

@Test func screensaverSoundRoundTrips() throws {
    let file = ChoicesFile(url: url, files: InMemoryFileStore())
    try file.save(Choices.standard.with(screensaverSound: true))
    #expect(file.load().screensaverSound == true)
}

@Test func otherChoicesKeepScreensaverSound() {
    let choices = Choices.standard.with(screensaverSound: true)
        .with(soundsOn: false).with(screensaver: .island).with(screensaverTimeout: 2)
        .with(wallpaper: .standard).turning(.pointer, on: false)
    #expect(choices.screensaverSound == true)
}

@Test func missingScreensaverSoundKeyMeansOff() throws {
    let files = InMemoryFileStore()
    let plist: [String: Any] = ["screensaver": "island", "screensaverTimeout": 5]
    try files.write(try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0), to: url)
    #expect(ChoicesFile(url: url, files: files).load().screensaverSound == false)
}

@Test func islandIsSavedUnderItsOwnName() throws {
    let files = InMemoryFileStore()
    try ChoicesFile(url: url, files: files).save(Choices.standard.with(screensaver: .island))
    let data = try #require(try files.read(url))
    let plist = try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
    #expect(plist["screensaver"] as? String == "island")
}

@Test func choiceSavedBeforeTheRenameStillShowsTheIsland() throws {
    // Before 0.12.1 the island was saved as "johnny".
    let files = InMemoryFileStore()
    let plist: [String: Any] = ["screensaver": "johnny", "screensaverTimeout": 5]
    try files.write(try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0), to: url)
    #expect(ChoicesFile(url: url, files: files).load().screensaver == .island)
}
