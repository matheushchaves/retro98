import AppKit
import Retro98UI

/// Build-time helpers for the app bundles.
///   retro98-tools iconset <explorer|shell> <output.iconset>
/// Writes every standard iconset PNG (16 to 1024, @1x and @2x), enlarging the pixel art without smoothing.

let iconsetSizes: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

/// The most detailed art that fits: the 32-px drawing from 32 px up, the 16-px one below.
@MainActor func art(for icon: String, pixels: Int) -> PixelIcon? {
    switch icon {
    case "explorer": pixels >= 32 ? FileIcons.explorerApp : FileIcons.explorerAppSmall
    case "shell": Icons.startLogo
    default: nil
    }
}

@MainActor func png(_ icon: PixelIcon, pixels: Int) -> Data? {
    let source = PixelCanvas.render(width: icon.width, height: icon.height) { icon.draw(at: .zero, context: $0) }
    guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return nil }
    context.interpolationQuality = .none
    context.draw(source.cgImage, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
    return context.makeImage().flatMap { NSBitmapImageRep(cgImage: $0).representation(using: .png, properties: [:]) }
}

@MainActor func writeIconset(icon: String, to folder: URL) -> Int32 {
    guard art(for: icon, pixels: 16) != nil else {
        FileHandle.standardError.write(Data("retro98-tools: unknown icon '\(icon)' (explorer or shell)\n".utf8))
        return 2
    }
    do {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for size in iconsetSizes {
            guard let art = art(for: icon, pixels: size.pixels), let data = png(art, pixels: size.pixels) else {
                FileHandle.standardError.write(Data("retro98-tools: could not draw \(size.name)\n".utf8))
                return 1
            }
            try data.write(to: folder.appending(path: "\(size.name).png"))
        }
        return 0
    } catch {
        FileHandle.standardError.write(Data("retro98-tools: \(error.localizedDescription)\n".utf8))
        return 1
    }
}

let arguments = CommandLine.arguments.dropFirst()
guard arguments.count == 3, arguments.first == "iconset" else {
    FileHandle.standardError.write(Data("usage: retro98-tools iconset <explorer|shell> <output.iconset>\n".utf8))
    exit(2)
}
let status = MainActor.assumeIsolated {
    writeIconset(icon: arguments[arguments.startIndex + 1], to: URL(filePath: arguments[arguments.startIndex + 2]))
}
exit(status)
