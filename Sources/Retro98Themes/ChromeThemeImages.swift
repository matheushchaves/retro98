import AppKit
import Retro98UI

/// The window-frame pictures of the Chrome theme: the classic title gradient, original like every Retro98 image.
public enum ChromeThemeImages {
    public static let size = (width: 3200, height: 64)

    /// The title gradient up to the middle column, then mirrored back: Chrome repeats the picture sideways,
    /// and a mirrored one repeats without a seam on wide screens.
    public static func frame(active: Bool) -> PixelImage {
        let half = size.width / 2
        let gradient = PixelCanvas.render(width: half, height: 1) { context in
            RetroWindow.drawTitleGradient(active: active, in: CGRect(x: 0, y: 0, width: half, height: 1), context: context)
        }
        return PixelCanvas.render(width: size.width, height: size.height) { context in
            for column in 0..<half {
                let color = gradient.color(x: column, y: 0)
                for x in [column, size.width - 1 - column] {
                    Bevel.fill(CGRect(x: x, y: 0, width: 1, height: size.height), color: color, context: context)
                }
            }
        }
    }

    public static func png(_ image: PixelImage) -> Data? {
        NSBitmapImageRep(cgImage: image.cgImage).representation(using: .png, properties: [:])
    }
}
