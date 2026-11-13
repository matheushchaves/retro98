import Foundation
import Testing
@testable import Retro98Settings

private func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "retro98-picture-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func adoptCopiesWithStampAndRemovesOldCopies() throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let support = root.appending(path: "support")
    try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
    try Data("old".utf8).write(to: support.appending(path: "wallpaper-picture-5.png"))
    try Data("teal".utf8).write(to: support.appending(path: "wallpaper-008080.png"))
    let source = root.appending(path: "Praia.PNG")
    let png = try SolidColorImage.pngData(hex: "#336699")
    try png.write(to: source)
    let paths = Retro98Paths.standard(home: root, environment: [Retro98Paths.supportOverrideVariable: support.path])

    let choice = try PictureWallpaper.adopt(source, paths: paths, now: Date(timeIntervalSince1970: 100))

    let copy = support.appending(path: "wallpaper-picture-100.png")
    #expect(choice == .picture(path: copy.path, name: "Praia.PNG"))
    #expect(try Data(contentsOf: copy) == png)
    #expect(!FileManager.default.fileExists(atPath: support.appending(path: "wallpaper-picture-5.png").path))
    #expect(FileManager.default.fileExists(atPath: support.appending(path: "wallpaper-008080.png").path))
}

@Test func notAnImageIsRefused() throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let support = root.appending(path: "support")
    try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
    let source = root.appending(path: "notas.txt")
    try Data("não sou imagem".utf8).write(to: source)
    let paths = Retro98Paths.standard(home: root, environment: [Retro98Paths.supportOverrideVariable: support.path])

    #expect(throws: PictureWallpaperError.notAnImage) {
        try PictureWallpaper.adopt(source, paths: paths, now: Date(timeIntervalSince1970: 100))
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: support.path).isEmpty)
}
