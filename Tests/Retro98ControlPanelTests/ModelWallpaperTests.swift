import Foundation
import Testing
@testable import Retro98ControlPanel
import Retro98Settings

@MainActor @Test func macOSWallpaperWhenNotManaged() throws {
    #expect(try ControlPanelModel(services: TestServices()).wallpaper() == nil)
}

@MainActor @Test func choosingColorSavesThenApplies() throws {
    let services = TestServices()
    try services.choices.save(Choices.standard.turning(.wallpaper, on: false))
    let model = ControlPanelModel(services: services)

    #expect(model.setWallpaper(.color(hex: "#800000")).isEmpty)

    #expect(services.wallpaper.hexes == ["#800000"])
    #expect(services.choices.load().wallpaper == .color(hex: "#800000"))
    #expect(try model.wallpaper() == .color(hex: "#800000"))
    #expect(!services.choices.load().turnedOff.contains(.wallpaper))
}

@MainActor @Test func changingColorKeepsFirstOriginal() throws {
    let services = TestServices()
    let model = ControlPanelModel(services: services)
    _ = model.setWallpaper(.color(hex: "#800000"))
    try services.files.write(Data("changed by macOS".utf8), to: services.paths.wallpaperIndex)
    _ = model.setWallpaper(.color(hex: "#000080"))

    #expect(services.wallpaper.hexes == ["#800000", "#000080"])
    let backup = try BackupFile(url: services.paths.backupFile, files: services.files).load()
    #expect(backup.files.map(\.original) == [originalIndex])
}

@MainActor @Test func macOSRestoresAndRemembers() throws {
    let services = TestServices()
    let model = ControlPanelModel(services: services)
    _ = model.setWallpaper(.color(hex: "#800000"))

    #expect(model.setWallpaper(nil).isEmpty)

    #expect(services.wallpaper.restoredIndexes == [originalIndex])
    #expect(services.choices.load().turnedOff.contains(.wallpaper))
    #expect(try model.wallpaper() == nil)
}

@MainActor @Test func pictureChoiceIsApplied() throws {
    let services = TestServices()
    let model = ControlPanelModel(services: services)
    #expect(model.setWallpaper(.picture(path: "/s/wallpaper-picture-1.png", name: "praia.png")).isEmpty)
    #expect(services.wallpaper.pictures == [URL(filePath: "/s/wallpaper-picture-1.png")])
    #expect(try model.wallpaper() == .picture(path: "/s/wallpaper-picture-1.png", name: "praia.png"))
}
