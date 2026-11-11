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
        render(region: CGRect(x: 0, y: 0, width: width, height: height), draw)
    }

    /// Renders only `region` (view coordinates, y down): drawing keeps using view coordinates,
    /// pixel (0,0) of the image is `region.origin`, and the context is clipped to the region,
    /// so large views can skip whatever lies outside `boundingBoxOfClipPath`.
    public static func render(region: CGRect, _ draw: (CGContext) -> Void) -> PixelImage {
        let region = region.integral
        let width = max(Int(region.width), 1)
        let height = max(Int(region.height), 1)
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
            context.translateBy(x: -region.minX, y: -region.minY)
            context.clip(to: CGRect(x: region.minX, y: region.minY, width: CGFloat(width), height: CGFloat(height)))
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

    /// Retro controls react to the first click even when their app is in the background
    /// (the taskbar never activates the Shell).
    override open func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    open func drawPixels(in context: CGContext, size: CGSize) {}

    override open func draw(_ dirtyRect: NSRect) {
        guard let target = NSGraphicsContext.current?.cgContext else { return }
        let region = dirtyRect.integral.intersection(bounds.integral)
        guard !region.isEmpty else { return }
        let size = bounds.size
        let image = PixelCanvas.render(region: region) { drawPixels(in: $0, size: size) }
        PixelIcon.drawUpright(image.cgImage, in: CGRect(x: region.minX, y: region.minY,
                                                         width: CGFloat(image.width), height: CGFloat(image.height)),
                              context: target)
    }
}
