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

@MainActor func renderView(_ view: PixelView) -> PixelImage {
    PixelCanvas.render(width: Int(view.bounds.width), height: Int(view.bounds.height)) {
        view.drawPixels(in: $0, size: view.bounds.size)
    }
}

/// Share of an icon's pixels that are drawn (not transparent).
func opaqueRatio(_ icon: PixelIcon) -> Double {
    let image = render(icon)
    let opaque = (0..<image.height).flatMap { y in (0..<image.width).map { x in image.alpha(x: x, y: y) } }.filter { $0 > 0 }.count
    return Double(opaque) / Double(icon.width * icon.height)
}
