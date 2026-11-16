import Foundation
import Testing
@testable import Retro98Themes

@Test func writesEveryGeneratedFile() throws {
    let folder = try temporaryFolder().appending(path: "Themes")
    defer { try? FileManager.default.removeItem(at: folder.deletingLastPathComponent()) }
    try ThemeFiles.write(to: folder, fontURL: vgaFontURL)
    for path in ["Chrome/images/theme_frame.png", "Chrome/images/theme_frame_inactive.png", "Retro98 Prompt.terminal"] {
        #expect((try? Data(contentsOf: folder.appending(path: path)).isEmpty) == false, "\(path)")
    }
    let profile = try Data(contentsOf: folder.appending(path: "Retro98 Prompt.terminal"))
    #expect(try PropertyListSerialization.propertyList(from: profile, format: nil) is [String: Any])
    #expect(ThemeFiles.chromeImagePaths == ["images/theme_frame.png", "images/theme_frame_inactive.png"])
}

@Test func missingFontIsAnError() throws {
    let root = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: root) }
    let folder = root.appending(path: "Themes")
    #expect(throws: ThemeFiles.Failure.fontNotFound) {
        try ThemeFiles.write(to: folder, fontURL: root.appending(path: "nao-existe.ttf"))
    }
    #expect(!FileManager.default.fileExists(atPath: folder.path))
}
