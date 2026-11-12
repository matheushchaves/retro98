import AppKit

/// A small original pixel-art image, defined as ASCII rows or drawn at 1x by code.
public struct PixelIcon: @unchecked Sendable {
    /// The 16-color VGA palette used by ASCII icon rows; "." is transparent.
    static let asciiPalette: [Character: PixelColor] = [
        "K": .black, "W": .white,
        "G": PixelColor(red: 0xC0, green: 0xC0, blue: 0xC0), "D": PixelColor(red: 0x80, green: 0x80, blue: 0x80),
        "N": PixelColor(red: 0x00, green: 0x00, blue: 0x80), "B": PixelColor(red: 0x00, green: 0x00, blue: 0xFF),
        "T": PixelColor(red: 0x00, green: 0x80, blue: 0x80), "C": PixelColor(red: 0x00, green: 0xFF, blue: 0xFF),
        "E": PixelColor(red: 0x00, green: 0x80, blue: 0x00), "L": PixelColor(red: 0x00, green: 0xFF, blue: 0x00),
        "O": PixelColor(red: 0x80, green: 0x80, blue: 0x00), "Y": PixelColor(red: 0xFF, green: 0xFF, blue: 0x00),
        "M": PixelColor(red: 0x80, green: 0x00, blue: 0x00), "R": PixelColor(red: 0xFF, green: 0x00, blue: 0x00),
        "P": PixelColor(red: 0x80, green: 0x00, blue: 0x80),
    ]

    public let width: Int
    public let height: Int
    private let cgImage: CGImage

    /// Rows of palette characters, all the same length.
    public init(rows: [String]) {
        let width = rows.first?.count ?? 0
        precondition(rows.allSatisfy { $0.count == width }, "PixelIcon rows must have equal length")
        self.init(width: width, height: rows.count) { context in
            for (y, row) in rows.enumerated() {
                for (x, character) in row.enumerated() {
                    guard let color = Self.asciiPalette[character] else { continue }
                    Bevel.fill(CGRect(x: x, y: y, width: 1, height: 1), color: color, context: context)
                }
            }
        }
    }

    /// Drawn by code in a top-left 1x canvas without anti-aliasing.
    public init(width: Int, height: Int, draw: (CGContext) -> Void) {
        self.width = width
        self.height = height
        self.cgImage = PixelCanvas.render(width: width, height: height, draw).cgImage
    }

    public func image() -> CGImage { cgImage }

    /// Draws the icon with its top-left corner at `origin` in a top-left (flipped) canvas.
    public func draw(at origin: CGPoint, context: CGContext) {
        Self.drawUpright(cgImage, in: CGRect(x: origin.x, y: origin.y, width: CGFloat(width), height: CGFloat(height)),
                         context: context)
    }

    /// Disabled look: the icon's shape in light shifted by (1,1), then in shadow on top.
    public func drawEmbossed(at origin: CGPoint, context: CGContext) {
        let pixels = PixelCanvas.render(width: width, height: height) { draw(at: .zero, context: $0) }
        for (color, offset) in [(Palette.light, CGFloat(1)), (Palette.shadow, CGFloat(0))] {
            for y in 0..<height {
                for x in 0..<width where pixels.alpha(x: x, y: y) > 0 {
                    Bevel.fill(CGRect(x: origin.x + CGFloat(x) + offset, y: origin.y + CGFloat(y) + offset, width: 1, height: 1),
                               color: color, context: context)
                }
            }
        }
    }

    /// Selected look: the icon with a 1-pixel navy checkerboard over its opaque pixels.
    public func drawSelected(at origin: CGPoint, context: CGContext) {
        draw(at: origin, context: context)
        let pixels = PixelCanvas.render(width: width, height: height) { draw(at: .zero, context: $0) }
        for y in 0..<height {
            for x in stride(from: y % 2, to: width, by: 2) where pixels.alpha(x: x, y: y) > 0 {
                Bevel.fill(CGRect(x: origin.x + CGFloat(x), y: origin.y + CGFloat(y), width: 1, height: 1),
                           color: Palette.selection, context: context)
            }
        }
    }

    /// Cut look (waiting to be pasted): the icon with a 1-pixel white checkerboard over its opaque pixels.
    public func drawDimmed(at origin: CGPoint, context: CGContext) {
        draw(at: origin, context: context)
        let pixels = PixelCanvas.render(width: width, height: height) { draw(at: .zero, context: $0) }
        for y in 0..<height {
            for x in stride(from: (y + 1) % 2, to: width, by: 2) where pixels.alpha(x: x, y: y) > 0 {
                Bevel.fill(CGRect(x: origin.x + CGFloat(x), y: origin.y + CGFloat(y), width: 1, height: 1),
                           color: .white, context: context)
            }
        }
    }

    /// CGContext.draw assumes a bottom-left origin; flip locally so images stay upright in top-left canvases.
    public static func drawUpright(_ image: CGImage, in rect: CGRect, context: CGContext) {
        context.saveGState()
        context.interpolationQuality = .none
        context.translateBy(x: rect.minX, y: rect.maxY)
        context.scaleBy(x: 1, y: -1)
        context.draw(image, in: CGRect(x: 0, y: 0, width: rect.width, height: rect.height))
        context.restoreGState()
    }

    /// A Mac app's real icon reduced to `size`×`size` at 1x, to be shown scaled up without smoothing.
    public static func appIcon(for url: URL, size: Int) -> CGImage {
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let context = CGContext(
            data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
            space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.interpolationQuality = .high
        var rect = CGRect(x: 0, y: 0, width: size, height: size)
        if let source = icon.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            context.draw(source, in: CGRect(x: 0, y: 0, width: size, height: size))
        }
        return context.makeImage()!
    }
}
