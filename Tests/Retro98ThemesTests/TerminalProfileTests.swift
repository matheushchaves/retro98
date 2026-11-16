import AppKit
import Retro98UI
import Testing
@testable import Retro98Themes

private func profile() throws -> [String: Any] {
    VGAFont.register(at: vgaFontURL)
    let data = try TerminalProfile.data(font: VGAFont.make())
    return try #require(try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
}

@Test func profileHasTheBasics() throws {
    let profile = try profile()
    #expect(profile["name"] as? String == "Retro98 Prompt")
    #expect(profile["type"] as? String == "Window Settings")
    #expect(profile["columnCount"] as? Int == 80 && profile["rowCount"] as? Int == 25)
    #expect(profile["FontAntialias"] as? Bool == false)
    #expect(profile["CursorType"] as? Int == 1 && profile["CursorBlink"] as? Bool == true)
    #expect(profile["UseBoldFonts"] as? Bool == false && profile["UseBrightBold"] as? Bool == true)
    #expect(TerminalProfile.fileName == "Retro98 Prompt.terminal")
}

@Test func colorsAreArchivedNSColors() throws {
    let profile = try profile()
    #expect(archivedColorHex(profile["BackgroundColor"]) == "000000")
    #expect(archivedColorHex(profile["TextColor"]) == "C0C0C0")
    #expect(archivedColorHex(profile["SelectionColor"]) == "000080")
    #expect(archivedColorHex(profile["CursorColor"]) == "C0C0C0")
    #expect(archivedColorHex(profile["TextBoldColor"]) == "FFFFFF")
}

@Test func fontIsTheVGAFont() throws {
    let data = try #require(try profile()["Font"] as? Data)
    let font = try #require(try NSKeyedUnarchiver.unarchivedObject(ofClass: NSFont.self, from: data))
    #expect(font.fontName == VGAFont.postScriptName && font.pointSize == 16)
}

@Test func ansiColorsFollowThePrompt() throws {
    let profile = try profile()
    #expect(TerminalProfile.ansiKeys.count == 16)
    #expect(TerminalProfile.ansiKeys.first == "ANSIBlackColor" && TerminalProfile.ansiKeys.last == "ANSIBrightWhiteColor")
    #expect(TerminalProfile.ansiKeys[1] == "ANSIRedColor" && TerminalProfile.ansiKeys[12] == "ANSIBrightBlueColor")
    for (key, expected) in zip(TerminalProfile.ansiKeys, ConsolePalette.ansiHex) {
        #expect(archivedColorHex(profile[key]) == expected, "\(key)")
    }
}
