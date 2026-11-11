import CoreGraphics
@testable import Retro98UI

func allPixels(_ image: PixelImage) -> [PixelColor] {
    (0..<image.height).flatMap { y in (0..<image.width).map { x in image.color(x: x, y: y) } }
}

func render(_ icon: PixelIcon) -> PixelImage {
    PixelCanvas.render(width: icon.width, height: icon.height) { context in
        icon.draw(at: .zero, context: context)
    }
}
