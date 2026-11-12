import AppKit
import SwiftTerm

/// The classic console look: light gray on black, the 16-color console palette, a blinking underline cursor
/// and the VGA font drawn without smoothing, so every glyph pixel is a whole screen pixel.
enum PromptStyle {
    static let foreground = color("C0C0C0")
    static let background = color("000000")
    /// SwiftTerm 1.11 keeps the text color when selecting, so the selection is navy behind the gray text.
    static let selection = color("000080")
    /// ANSI 0–15: black, red, green, yellow, blue, magenta, cyan, white, then their bright versions.
    static let ansiHex = [
        "000000", "800000", "008000", "808000", "000080", "800080", "008080", "C0C0C0",
        "808080", "FF0000", "00FF00", "FFFF00", "0000FF", "FF00FF", "00FFFF", "FFFFFF",
    ]
    static let scrollbackLines = 10_000
    static let columns = 80, rows = 25
    static let cellSize = CGSize(width: 8, height: 16)

    /// The palette in SwiftTerm's 16-bit components (0xC0 → 0xC0C0).
    static var palette: [SwiftTerm.Color] {
        ansiHex.map { hex in
            let (red, green, blue) = components(hex)
            return SwiftTerm.Color(red: UInt16(red) * 0x101, green: UInt16(green) * 0x101, blue: UInt16(blue) * 0x101)
        }
    }

    /// The font goes first: it resizes the terminal to the frame. The history size and cursor go last.
    @MainActor static func apply(to view: TerminalView) {
        view.font = PromptFont.make()
        view.nativeForegroundColor = foreground
        view.nativeBackgroundColor = background
        view.installColors(palette)
        view.selectedTextBackgroundColor = selection
        view.caretColor = foreground
        view.optionAsMetaKey = false
        view.fontSmoothing = false
        view.customBlockGlyphs = false
        // The window shows a retro scroll bar instead; hidden, SwiftTerm's own bar takes no width.
        view.subviews.compactMap { $0 as? NSScroller }.forEach { $0.isHidden = true }
        view.getTerminal().changeHistorySize(scrollbackLines)
        view.getTerminal().setCursorStyle(.blinkUnderline)
    }

    private static func components(_ hex: String) -> (UInt8, UInt8, UInt8) {
        let value = UInt32(hex, radix: 16) ?? 0
        return (UInt8(value >> 16 & 0xFF), UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF))
    }

    private static func color(_ hex: String) -> NSColor {
        let (red, green, blue) = components(hex)
        return NSColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }
}
