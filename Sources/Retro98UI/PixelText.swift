import CoreText
import Foundation

/// Tahoma drawn without smoothing reads as the classic UI font: 13 pt for text, 12 pt bold for titles
/// (bold 13 spaces some letter pairs unevenly).
public enum PixelFont: Sendable {
    case regular, bold

    public var size: CGFloat {
        switch self {
        case .regular: 13
        case .bold: 12
        }
    }

    var ctFont: CTFont {
        CTFontCreateWithName((self == .bold ? "Tahoma-Bold" : "Tahoma") as CFString, size, nil)
    }
}

public enum PixelText {
    public static let lineHeight = 16

    public static func width(of text: String, font: PixelFont) -> Int {
        guard !text.isEmpty else { return 0 }
        return Int(CTLineGetTypographicBounds(line(text, font: font, color: .black), nil, nil, nil).rounded(.up))
    }

    /// Draws one line; `origin` is the top-left corner of the line box in a top-left canvas.
    public static func draw(_ text: String, font: PixelFont, color: PixelColor, at origin: CGPoint, context: CGContext) {
        guard !text.isEmpty else { return }
        let ascent = CTFontGetAscent(font.ctFont).rounded()
        context.saveGState()
        context.setShouldAntialias(false)
        context.setShouldSmoothFonts(false)
        // The canvas is flipped; flip glyphs back so text is upright.
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: origin.x, y: origin.y + ascent)
        CTLineDraw(line(text, font: font, color: color), context)
        context.restoreGState()
    }

    private static func line(_ text: String, font: PixelFont, color: PixelColor) -> CTLine {
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font.ctFont,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    }
}
