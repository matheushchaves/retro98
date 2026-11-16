import AppKit

/// The classic console colors, shared by the Prompt and by the Terminal profile that copies its look.
public enum ConsolePalette {
    public static let foregroundHex = "C0C0C0"
    public static let backgroundHex = "000000"
    public static let selectionHex = "000080"
    /// ANSI 0–15: black, red, green, yellow, blue, magenta, cyan, white, then their bright versions.
    public static let ansiHex = [
        "000000", "800000", "008000", "808000", "000080", "800080", "008080", "C0C0C0",
        "808080", "FF0000", "00FF00", "FFFF00", "0000FF", "FF00FF", "00FFFF", "FFFFFF",
    ]

    public static func components(_ hex: String) -> (red: UInt8, green: UInt8, blue: UInt8) {
        let value = UInt32(hex, radix: 16) ?? 0
        return (UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF))
    }

    /// "RRGGBB" as an sRGB color.
    public static func color(_ hex: String) -> NSColor {
        let (red, green, blue) = components(hex)
        return NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }
}
