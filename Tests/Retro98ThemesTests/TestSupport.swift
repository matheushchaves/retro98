import AppKit
import Retro98UI

/// The repository root, from this file's location.
let repoRoot = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
let vgaFontURL = repoRoot.appending(path: "Resources/Fonts/PxPlus_IBM_VGA_8x16.ttf")

/// A fresh folder under the system's temporary directory; tests remove it when done.
func temporaryFolder() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "retro98-themes-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

func hex(_ value: String) -> PixelColor {
    let number = UInt32(value, radix: 16) ?? 0
    return PixelColor(red: UInt8(number >> 16 & 0xFF), green: UInt8(number >> 8 & 0xFF), blue: UInt8(number & 0xFF))
}

/// "RRGGBB" of an archived NSColor (as Terminal stores colors), or nil when the data isn't one.
func archivedColorHex(_ value: Any?) -> String? {
    guard let data = value as? Data,
          let color = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data)?.usingColorSpace(.sRGB) else { return nil }
    let parts = [color.redComponent, color.greenComponent, color.blueComponent].map { Int(($0 * 255).rounded()) }
    return parts.map { String(format: "%02X", $0) }.joined()
}
