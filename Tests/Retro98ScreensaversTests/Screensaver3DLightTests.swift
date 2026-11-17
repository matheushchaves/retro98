import AppKit
import SceneKit
import Testing
@testable import Retro98Screensavers

private let hasGPU = MTLCreateSystemDefaultDevice() != nil

/// How bright the lit things look: lit things on the screen saver should read clearly against the black.
private let brightEnough = 0.4

@MainActor @Test(.enabled(if: hasGPU))
func pipesAreLitBrightly() throws {
    let pipes = PipesRenderer()
    pipes.startForTesting()
    for _ in 0..<80 { pipes.tickForTesting() }
    let brightness = try litBrightness(of: rendered(try #require(pipes.sceneForTesting), size: CGSize(width: 320, height: 180)))
    #expect(brightness > brightEnough)
}

@MainActor @Test(.enabled(if: hasGPU))
func textIsLitBrightly() throws {
    let text = TextRenderer()
    text.buildSceneForTesting()
    let node = try #require(text.textNode)
    node.removeAllActions()
    node.eulerAngles = SCNVector3(-0.25, 0.45, 0.05)
    let brightness = try litBrightness(of: rendered(try #require(text.sceneForTesting), size: CGSize(width: 320, height: 180)))
    #expect(brightness > brightEnough)
}

@MainActor @Test(.enabled(if: hasGPU))
func pipesSpreadAcrossAWideScreen() throws {
    let pipes = PipesRenderer()
    pipes.startForTesting()
    pipes.fillGridForTesting()
    let image = rendered(try #require(pipes.sceneForTesting), size: CGSize(width: 320, height: 180))
    let (left, right) = try litSpan(of: image)
    // Pipes reach most of the way across a 16:9 screen, not a box in the middle with black bands either side.
    #expect(Double(right - left) / 320 > 0.8)
}

/// Renders a SceneKit scene off screen through its camera.
@MainActor func rendered(_ scene: SCNScene, size: CGSize) -> NSImage {
    let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
    renderer.scene = scene
    renderer.pointOfView = scene.rootNode.childNodes.first { $0.camera != nil }
    return renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
}

/// The average of each non-black pixel's strongest channel, from 0 to 1: how bright the lit parts of a picture are,
/// whatever their color.
private func litBrightness(of image: NSImage) throws -> Double {
    let lit = try litPixels(of: image)
    try #require(!lit.isEmpty, "nothing on screen")
    return Double(lit.map(\.strength).reduce(0, +)) / Double(lit.count) / 255
}

/// The leftmost and rightmost columns with anything lit in them.
private func litSpan(of image: NSImage) throws -> (left: Int, right: Int) {
    let columns = try litPixels(of: image).map(\.x)
    return (try #require(columns.min(), "nothing on screen"), try #require(columns.max()))
}

/// Every pixel brighter than the black background, give or take the antialiasing, with its strongest channel.
private func litPixels(of image: NSImage) throws -> [(x: Int, strength: Int)] {
    let pixels = try #require(image.cgImage(forProposedRect: nil, context: nil, hints: nil))
    let context = try #require(CGContext(
        data: nil, width: pixels.width, height: pixels.height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
    ))
    context.draw(pixels, in: CGRect(x: 0, y: 0, width: pixels.width, height: pixels.height))
    let bytes = try #require(context.data).bindMemory(to: UInt8.self, capacity: context.bytesPerRow * pixels.height)
    var lit: [(x: Int, strength: Int)] = []
    for y in 0..<pixels.height {
        for x in 0..<pixels.width {
            let p = y * context.bytesPerRow + x * 4
            let strongest = Int(max(bytes[p], bytes[p + 1], bytes[p + 2]))
            if strongest > 8 { lit.append((x, strongest)) }
        }
    }
    return lit
}
