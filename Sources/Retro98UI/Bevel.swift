import CoreGraphics

public enum BevelStyle: Sendable {
    case raised, sunken, buttonPressed, window, field, statusField
}

/// The classic 2-pixel 3D borders (outer line, then inner line), drawn in top-left coordinates.
public enum Bevel {
    private struct Colors {
        let outerTopLeft: PixelColor
        let innerTopLeft: PixelColor?
        let outerBottomRight: PixelColor
        let innerBottomRight: PixelColor?
    }

    private static func colors(for style: BevelStyle) -> Colors {
        switch style {
        case .raised:
            return Colors(outerTopLeft: Palette.light, innerTopLeft: Palette.face,
                          outerBottomRight: Palette.darkShadow, innerBottomRight: Palette.shadow)
        case .buttonPressed:
            return Colors(outerTopLeft: Palette.darkShadow, innerTopLeft: Palette.shadow,
                          outerBottomRight: Palette.light, innerBottomRight: Palette.face)
        case .window:
            return Colors(outerTopLeft: Palette.face, innerTopLeft: Palette.light,
                          outerBottomRight: Palette.darkShadow, innerBottomRight: Palette.shadow)
        case .sunken, .field:
            return Colors(outerTopLeft: Palette.shadow, innerTopLeft: Palette.darkShadow,
                          outerBottomRight: Palette.light, innerBottomRight: Palette.face)
        case .statusField:
            return Colors(outerTopLeft: Palette.shadow, innerTopLeft: nil,
                          outerBottomRight: Palette.light, innerBottomRight: nil)
        }
    }

    public static func draw(_ style: BevelStyle, in rect: CGRect, context: CGContext) {
        let colors = colors(for: style)
        frame(rect, topLeft: colors.outerTopLeft, bottomRight: colors.outerBottomRight, context: context)
        let inner = rect.insetBy(dx: 1, dy: 1)
        if let topLeft = colors.innerTopLeft, let bottomRight = colors.innerBottomRight {
            frame(inner, topLeft: topLeft, bottomRight: bottomRight, context: context)
        }
        if style == .field {
            fill(rect.insetBy(dx: 2, dy: 2), color: .white, context: context)
        }
    }

    public static func fillFace(_ rect: CGRect, context: CGContext) {
        fill(rect, color: Palette.face, context: context)
    }

    public static func fill(_ rect: CGRect, color: PixelColor, context: CGContext) {
        context.setFillColor(color.cgColor)
        context.fill(rect)
    }

    /// One-pixel frame: top and left lines stop one pixel short, so the corners
    /// at top-right and bottom-left belong to the bottom/right color.
    private static func frame(_ rect: CGRect, topLeft: PixelColor, bottomRight: PixelColor, context: CGContext) {
        guard rect.width >= 1, rect.height >= 1 else { return }
        fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width - 1, height: 1), color: topLeft, context: context)
        fill(CGRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height - 1), color: topLeft, context: context)
        fill(CGRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1), color: bottomRight, context: context)
        fill(CGRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height), color: bottomRight, context: context)
    }
}
