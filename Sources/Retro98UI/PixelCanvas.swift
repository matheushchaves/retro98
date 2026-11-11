import AppKit

/// A 1x RGBA bitmap produced by `PixelCanvas.render`.
public struct PixelImage: @unchecked Sendable {
    public let cgImage: CGImage
    private let bytes: [UInt8]
    private let bytesPerRow: Int

    init(cgImage: CGImage, bytes: [UInt8], bytesPerRow: Int) {
        self.cgImage = cgImage
        self.bytes = bytes
        self.bytesPerRow = bytesPerRow
    }

    public var width: Int { cgImage.width }
    public var height: Int { cgImage.height }

    /// Color at (x, y), origin at the top-left corner.
    public func color(x: Int, y: Int) -> PixelColor {
        let offset = y * bytesPerRow + x * 4
        return PixelColor(red: bytes[offset], green: bytes[offset + 1], blue: bytes[offset + 2])
    }

    public func alpha(x: Int, y: Int) -> UInt8 {
        bytes[y * bytesPerRow + x * 4 + 3]
    }
}

public enum PixelCanvas {
    /// Renders at 1x into a context whose origin is the top-left corner, with
    /// anti-aliasing and font smoothing off, so every pixel is a pure color.
    public static func render(width: Int, height: Int, _ draw: (CGContext) -> Void) -> PixelImage {
        let width = max(width, 1)
        let height = max(height, 1)
        let bytesPerRow = width * 4
        var bytes = [UInt8](repeating: 0, count: bytesPerRow * height)
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let image = bytes.withUnsafeMutableBytes { buffer -> CGImage in
            let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: bytesPerRow, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
            context.setShouldAntialias(false)
            context.setAllowsAntialiasing(false)
            context.setShouldSmoothFonts(false)
            context.setAllowsFontSmoothing(false)
            context.interpolationQuality = .none
            draw(context)
            return context.makeImage()!
        }
        return PixelImage(cgImage: image, bytes: bytes, bytesPerRow: bytesPerRow)
    }
}

/// Base view for retro controls: subclasses draw at 1x in `drawPixels`, and the result
/// is scaled to the screen without interpolation, so pixels stay crisp on Retina.
open class PixelView: NSView {
    override open var isFlipped: Bool { true }

    open func drawPixels(in context: CGContext, size: CGSize) {}

    override open func draw(_ dirtyRect: NSRect) {
        guard let target = NSGraphicsContext.current?.cgContext else { return }
        let size = bounds.size
        let image = PixelCanvas.render(width: Int(size.width.rounded(.up)), height: Int(size.height.rounded(.up))) {
            drawPixels(in: $0, size: size)
        }
        target.saveGState()
        target.interpolationQuality = .none
        // The view is flipped; CGContext.draw expects a bottom-left origin.
        target.translateBy(x: 0, y: CGFloat(image.height))
        target.scaleBy(x: 1, y: -1)
        target.draw(image.cgImage, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        target.restoreGState()
    }
}
