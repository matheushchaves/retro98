import AppKit

/// Horizontal etched separator (shadow over light), under a window's menu bar and toolbars.
public final class EtchedLine: PixelView {
    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fill(CGRect(x: 0, y: 0, width: size.width, height: 1), color: Palette.shadow, context: context)
        Bevel.fill(CGRect(x: 0, y: 1, width: size.width, height: 1), color: Palette.light, context: context)
    }
}
