import CoreGraphics
import Foundation
import ImageIO

public enum SolidColorImageError: Error, Equatable {
    case invalidHex(String)
    case encodingFailed
}

/// Builds a small single-color PNG; the wallpaper is stretched, so size does not matter.
public enum SolidColorImage {
    public static func pngData(hex: String, size: Int = 16) throws(SolidColorImageError) -> Data {
        let components = try rgbComponents(hex) + [1]
        guard
            let space = CGColorSpace(name: CGColorSpace.sRGB),
            let color = CGColor(colorSpace: space, components: components),
            let context = CGContext(
                data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
        else { throw .encodingFailed }

        context.setFillColor(color)
        context.fill(CGRect(x: 0, y: 0, width: size, height: size))

        let data = NSMutableData()
        guard
            let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithData(data, "public.png" as CFString, 1, nil)
        else { throw .encodingFailed }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw .encodingFailed }
        return data as Data
    }

    /// Parses "#RRGGBB" into sRGB components in 0...1.
    static func rgbComponents(_ hex: String) throws(SolidColorImageError) -> [CGFloat] {
        let digits = hex.dropFirst()
        guard hex.hasPrefix("#"), digits.count == 6, digits.allSatisfy(\.isHexDigit),
              let value = UInt32(digits, radix: 16)
        else { throw .invalidHex(hex) }
        return [16, 8, 0].map { CGFloat((value >> $0) & 0xFF) / 255 }
    }
}
