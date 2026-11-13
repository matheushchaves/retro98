import AppKit
import Retro98UI

/// Draws glyphs without antialiasing or font smoothing, so the VGA font's pixels land whole on the screen.
private final class CrispLayoutManager: NSLayoutManager {
    override func drawGlyphs(forGlyphRange glyphsToShow: NSRange, at origin: NSPoint) {
        guard let context = NSGraphicsContext.current?.cgContext else {
            super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
            return
        }
        context.saveGState()
        context.setShouldAntialias(false)
        context.setShouldSmoothFonts(false)
        context.setAllowsFontSmoothing(false)
        super.drawGlyphs(forGlyphRange: glyphsToShow, at: origin)
        context.restoreGState()
    }
}

/// The Notepad's editing area: plain text in the VGA font, black on white, with a navy selection and none of
/// macOS's automatic substitutions (a text file must hold exactly what was typed).
final class NotepadTextView: NSTextView {
    static let selection = NSColor(srgbRed: 0, green: 0, blue: CGFloat(0x80) / 255, alpha: 1)
    /// The text system is built by hand to get the crisp layout manager; nothing else keeps the storage alive.
    private let storage = NSTextStorage()

    override init(frame: CGRect) {
        let layout = CrispLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(size: CGSize(width: frame.width, height: .greatestFiniteMagnitude))
        layout.addTextContainer(container)
        super.init(frame: frame, textContainer: container)
        configure()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func configure() {
        isRichText = false
        importsGraphics = false
        allowsUndo = true
        usesFontPanel = false
        usesFindBar = false
        isIncrementalSearchingEnabled = false
        isAutomaticQuoteSubstitutionEnabled = false
        isAutomaticDashSubstitutionEnabled = false
        isAutomaticTextReplacementEnabled = false
        isAutomaticSpellingCorrectionEnabled = false
        isAutomaticLinkDetectionEnabled = false
        isAutomaticDataDetectionEnabled = false
        isAutomaticTextCompletionEnabled = false
        isContinuousSpellCheckingEnabled = false
        isGrammarCheckingEnabled = false
        smartInsertDeleteEnabled = false
        font = VGAFont.make()
        textColor = .black
        backgroundColor = .white
        drawsBackground = true
        insertionPointColor = .black
        selectedTextAttributes = [.backgroundColor: Self.selection, .foregroundColor: NSColor.white]
        textContainerInset = NSSize(width: 2, height: 2)
        layoutManager?.allowsNonContiguousLayout = true
    }
}
