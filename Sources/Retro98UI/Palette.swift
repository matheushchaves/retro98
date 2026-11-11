import CoreGraphics

public struct PixelColor: Equatable, Hashable, Sendable {
    public let red: UInt8
    public let green: UInt8
    public let blue: UInt8

    public init(red: UInt8, green: UInt8, blue: UInt8) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public static let black = PixelColor(red: 0, green: 0, blue: 0)
    public static let white = PixelColor(red: 255, green: 255, blue: 255)

    public var cgColor: CGColor {
        CGColor(srgbRed: CGFloat(red) / 255, green: CGFloat(green) / 255, blue: CGFloat(blue) / 255, alpha: 1)
    }
}

/// The classic 98-style system colors (spec section 5).
public enum Palette {
    public static let face = PixelColor(red: 0xC0, green: 0xC0, blue: 0xC0)
    public static let shadow = PixelColor(red: 0x80, green: 0x80, blue: 0x80)
    public static let light = PixelColor.white
    public static let darkShadow = PixelColor.black
    public static let selection = PixelColor(red: 0x00, green: 0x00, blue: 0x80)
    public static let selectionText = PixelColor.white
    public static let desktop = PixelColor(red: 0x00, green: 0x80, blue: 0x80)
    public static let tooltip = PixelColor(red: 0xFF, green: 0xFF, blue: 0xE1)
    public static let activeTitle = (start: PixelColor(red: 0x00, green: 0x00, blue: 0x80),
                                     end: PixelColor(red: 0x10, green: 0x84, blue: 0xD0))
    public static let inactiveTitle = (start: shadow, end: face)
}
