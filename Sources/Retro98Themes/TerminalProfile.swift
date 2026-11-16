import AppKit
import Retro98UI

/// A profile for macOS's Terminal with the Retro98 Prompt's look: gray on black, the console colors and the
/// VGA font without smoothing, 80×25. Terminal imports the file when it is opened; its default profile stays.
public enum TerminalProfile {
    public static let name = "Retro98 Prompt"
    public static let fileName = "Retro98 Prompt.terminal"
    /// The names Terminal uses for ANSI 0–15, in order.
    public static let ansiKeys = ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"].map { "ANSI\($0)Color" }
        + ["Black", "Red", "Green", "Yellow", "Blue", "Magenta", "Cyan", "White"].map { "ANSIBright\($0)Color" }

    /// An XML property list Terminal imports as a profile. Colors and the font go in as Terminal stores them:
    /// keyed archives of NSColor and NSFont.
    public static func data(font: NSFont) throws -> Data {
        var profile: [String: Any] = [
            "name": name,
            "type": "Window Settings",
            "ProfileCurrentVersion": 2.07,
            "BackgroundColor": try archived(ConsolePalette.color(ConsolePalette.backgroundHex)),
            "TextColor": try archived(ConsolePalette.color(ConsolePalette.foregroundHex)),
            "TextBoldColor": try archived(ConsolePalette.color("FFFFFF")),
            "CursorColor": try archived(ConsolePalette.color(ConsolePalette.foregroundHex)),
            "SelectionColor": try archived(ConsolePalette.color(ConsolePalette.selectionHex)),
            "Font": try archived(font),
            "FontAntialias": false,
            "FontWidthSpacing": 1.0,
            "FontHeightSpacing": 1.0,
            "UseBoldFonts": false,
            "UseBrightBold": true,
            "CursorType": 1,
            "CursorBlink": true,
            "columnCount": 80,
            "rowCount": 25,
        ]
        for (key, hex) in zip(ansiKeys, ConsolePalette.ansiHex) {
            profile[key] = try archived(ConsolePalette.color(hex))
        }
        return try PropertyListSerialization.data(fromPropertyList: profile, format: .xml, options: 0)
    }

    private static func archived(_ object: Any) throws -> Data {
        try NSKeyedArchiver.archivedData(withRootObject: object, requiringSecureCoding: false)
    }
}
