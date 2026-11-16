import AppKit
import Retro98UI
import SwiftTerm

/// The classic console look: light gray on black, the 16-color console palette, a blinking underline cursor
/// and the VGA font drawn without smoothing, so every glyph pixel is a whole screen pixel.
enum PromptStyle {
    static let foreground = ConsolePalette.color(ConsolePalette.foregroundHex)
    static let background = ConsolePalette.color(ConsolePalette.backgroundHex)
    /// SwiftTerm 1.11 keeps the text color when selecting, so the selection is navy behind the gray text.
    static let selection = ConsolePalette.color(ConsolePalette.selectionHex)
    /// ANSI 0–15, shared with the Terminal profile.
    static let ansiHex = ConsolePalette.ansiHex
    static let scrollbackLines = 10_000
    static let columns = 80, rows = 25
    static let cellSize = CGSize(width: 8, height: 16)

    /// The palette in SwiftTerm's 16-bit components (0xC0 → 0xC0C0).
    static var palette: [SwiftTerm.Color] {
        ansiHex.map { hex in
            let (red, green, blue) = ConsolePalette.components(hex)
            return SwiftTerm.Color(red: UInt16(red) * 0x101, green: UInt16(green) * 0x101, blue: UInt16(blue) * 0x101)
        }
    }

    /// The font goes first: it resizes the terminal to the frame. The history size and cursor go last.
    @MainActor static func apply(to view: TerminalView) {
        view.font = VGAFont.make()
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
}
