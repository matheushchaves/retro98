import Foundation
import Testing
@testable import Retro98Settings

private let choicesURL = URL(filePath: "/home/Library/Application Support/Retro98/choices.plist")

@Test func missingOrBrokenChoicesFileGivesStandard() throws {
    let files = InMemoryFileStore()
    #expect(ChoicesFile(url: choicesURL, files: files).load() == .standard)
    try files.write(Data("lixo".utf8), to: choicesURL)
    #expect(ChoicesFile(url: choicesURL, files: files).load() == .standard)
}

@Test func choicesRoundTrip() throws {
    let file = ChoicesFile(url: choicesURL, files: InMemoryFileStore())
    let choices = Choices.standard
        .with(wallpaper: .picture(path: "/s/wallpaper-picture-1.png", name: "praia.png"))
        .turning(.pointer, on: false)
        .with(soundsOn: false)
    try file.save(choices)
    #expect(file.load() == choices)
    #expect(file.load().turnedOff == [.pointer])
    #expect(file.load().turning(.pointer, on: true).turnedOff.isEmpty)
}

@Test func unknownTurnedOffNamesAreIgnored() throws {
    let files = InMemoryFileStore()
    let data = try PropertyListSerialization.data(
        fromPropertyList: ["turnedOff": ["pointer", "naoExiste"]], format: .xml, options: 0
    )
    try files.write(data, to: choicesURL)
    let choices = ChoicesFile(url: choicesURL, files: files).load()
    #expect(choices.turnedOff == [.pointer])
    #expect(choices.wallpaper == .standard)
    #expect(choices.soundsOn)
}

@Test func defaultApplySkipsTurnedOff() {
    let catalog = TweakCatalog.all(osMajorVersion: 27, homeDirectory: URL(filePath: "/Users/test"))
    let selected = TweakSelection.defaultApply(catalog: catalog, choices: .standard.turning(.pointer, on: false))
    let base = Set(catalog.filter { $0.group == .base }.map(\.id))
    #expect(selected == base.subtracting([.pointer]))
    #expect(!selected.contains(.dockUnderTaskbar))
    #expect(!selected.contains(.explorerFileViewer))
}

@Test func catalogUsesChosenWallpaper() {
    let home = URL(filePath: "/Users/test")
    let color = TweakCatalog.phase1(osMajorVersion: 27, homeDirectory: home, wallpaper: .color(hex: "#800000"))
    #expect(color.first { $0.id == .wallpaper }?.special == .solidWallpaper(hex: "#800000"))
    let picture = TweakCatalog.phase1(
        osMajorVersion: 27, homeDirectory: home, wallpaper: .picture(path: "/x/wallpaper-picture-1.png", name: "a.png")
    )
    #expect(picture.first { $0.id == .wallpaper }?.special == .pictureWallpaper(path: "/x/wallpaper-picture-1.png"))
    #expect(TweakCatalog.phase1(osMajorVersion: 27, homeDirectory: home).first { $0.id == .wallpaper }?.special
        == .solidWallpaper(hex: "#008080"))
}

@Test func choicesFileLivesInSupportFolder() {
    let paths = Retro98Paths.standard(home: URL(filePath: "/Users/ana"), environment: [:])
    #expect(paths.choicesFile.path == "/Users/ana/Library/Application Support/Retro98/choices.plist")
}
