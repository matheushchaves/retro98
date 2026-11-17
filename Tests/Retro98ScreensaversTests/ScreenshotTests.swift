import AppKit
import SceneKit
import Testing
@testable import Retro98Screensavers

// The screen savers have no words to translate, so their pictures go once into docs/images/screensavers/.

/// Where `scripts/make-screenshots.sh` wants the README images; unset in normal test runs, which skip these.
private let screenshotFolder = ProcessInfo.processInfo.environment["RETRO98_SCREENSHOTS"].map { URL(filePath: $0) }

/// The pictures' size: 16:9, four real pixels for each of Johnny's.
private let pictureSize = CGSize(width: 1280, height: 720)

/// 3D Pipes about a minute in, when a few pipes cross the screen.
@MainActor @Test(.enabled(if: screenshotFolder != nil))
func screenshotScreensaverPipes() throws {
    let pipes = PipesRenderer()
    pipes.startForTesting()
    for _ in 0..<700 { pipes.tickForTesting() }
    let scene = try #require(pipes.sceneForTesting)
    try savePicture(snapshot(of: scene), as: "pipes")
}

/// 3D Text turned a little toward the light, so the letters show their depth.
@MainActor @Test(.enabled(if: screenshotFolder != nil))
func screenshotScreensaverText() throws {
    let text = TextRenderer()
    text.buildSceneForTesting()
    let node = try #require(text.textNode)
    node.removeAllActions()
    node.eulerAngles = SCNVector3(-0.25, 0.45, 0.05)
    let scene = try #require(text.sceneForTesting)
    try savePicture(snapshot(of: scene), as: "text")
}

/// Johnny's island at a telling moment of a scene.
@MainActor @Test(.enabled(if: screenshotFolder != nil), arguments: ["fishing", "sleeping", "shark", "gull"])
func screenshotScreensaverJohnny(moment: String) throws {
    let (scene, clock): (JohnnySceneKind, JohnnyClock) = switch moment {
    // The fish on the hook.
    case "fishing": (.fishing, JohnnyClock(frame: 2, sceneTick: 45, worldTick: 310))
    // All three Z up.
    case "sleeping": (.sleeping, JohnnyClock(frame: 0, sceneTick: 20, worldTick: 120))
    // The fin past the island, Johnny in a panic.
    case "shark": (.shark, JohnnyClock(frame: 1, sceneTick: 30, worldTick: 540))
    default: (.bird, JohnnyClock(frame: 0, sceneTick: 24, worldTick: 760))
    }
    let canvas = JohnnyScene.render(scene, clock: clock, width: Int(JohnnyScene.vw), height: Int(JohnnyScene.vh))
    let pixels = try #require(canvas.makeImage())
    try savePicture(enlarged(pixels), as: "johnny-\(moment)")
}

/// Renders a SceneKit scene off screen through its camera.
@MainActor private func snapshot(of scene: SCNScene) -> NSImage {
    let renderer = SCNRenderer(device: MTLCreateSystemDefaultDevice(), options: nil)
    renderer.scene = scene
    renderer.pointOfView = scene.rootNode.childNodes.first { $0.camera != nil }
    return renderer.snapshot(atTime: 0, with: pictureSize, antialiasingMode: .multisampling4X)
}

/// Johnny's 320×180 pixels blown up to the picture's size, each one a sharp square.
private func enlarged(_ pixels: CGImage) throws -> NSImage {
    let context = try #require(CGContext(
        data: nil, width: Int(pictureSize.width), height: Int(pictureSize.height), bitsPerComponent: 8,
        bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.interpolationQuality = .none
    context.draw(pixels, in: CGRect(origin: .zero, size: pictureSize))
    let image = try #require(context.makeImage())
    return NSImage(cgImage: image, size: pictureSize)
}

private func savePicture(_ image: NSImage, as name: String) throws {
    guard let screenshotFolder else { return }
    let folder = screenshotFolder.appending(path: "screensavers")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let tiff = try #require(image.tiffRepresentation)
    let png = try #require(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
    try png.write(to: folder.appending(path: "\(name).png"))
}
