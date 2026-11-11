import CoreGraphics
import Foundation
import ImageIO
import Testing
@testable import Retro98Settings

private final class RecordingRunner: CommandRunner {
    var runs: [[String]] = []
    var exitCode: Int32 = 0

    func run(_ executable: String, _ arguments: [String]) -> Int32 {
        runs.append([executable] + arguments)
        return exitCode
    }
}

@Test func solidColorPngHasExactPixels() throws {
    let data = try SolidColorImage.pngData(hex: "#008080")
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    #expect(image.width == 16)
    #expect(image.height == 16)

    var pixel = [UInt8](repeating: 0, count: 4)
    let context = try #require(CGContext(
        data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ))
    context.draw(image, in: CGRect(x: 0, y: 0, width: 1, height: 1))
    #expect(Array(pixel.prefix(3)) == [0, 128, 128])
}

@Test func invalidHexThrows() {
    #expect(throws: SolidColorImageError.invalidHex("#GG0000")) { try SolidColorImage.pngData(hex: "#GG0000") }
    #expect(throws: SolidColorImageError.invalidHex("008080")) { try SolidColorImage.pngData(hex: "008080") }
}

@Test func pathsHonorSupportDirOverride() {
    let paths = Retro98Paths.standard(home: URL(filePath: "/Users/t"), environment: ["RETRO98_SUPPORT_DIR": "/tmp/r98"])
    #expect(paths.backupFile.path == "/tmp/r98/backup.plist")
    #expect(paths.wallpaperImage(hex: "#008080").lastPathComponent == "wallpaper-008080.png")
    #expect(paths.wallpaperIndex.path == "/Users/t/Library/Application Support/com.apple.wallpaper/Store/Index.plist")
}

@Test func pathsDefaultToApplicationSupport() {
    let paths = Retro98Paths.standard(home: URL(filePath: "/Users/t"), environment: [:])
    #expect(paths.supportDirectory.path == "/Users/t/Library/Application Support/Retro98")
}

@Test func refresherMapsEffectsToCommandsAndNotifications() {
    let runner = RecordingRunner()
    var posted: [String] = []
    let refresher = MacSystemRefresher(runner: runner, post: { posted.append($0) })

    refresher.perform([.restartFinder, .notifyColorChange, .notifyScrollBarChange, .restartWallpaperAgent, .syncAppearance])

    #expect(Set(runner.runs) == [["/usr/bin/killall", "Finder"], ["/usr/bin/killall", "WallpaperAgent"]])
    #expect(Set(posted) == [
        "AppleColorPreferencesChangedNotification", "AppleAquaColorVariantChanged", "AppleShowScrollBarsSettingChanged",
    ])
}

@Test func switchAppearanceRunsAppleScriptAndReportsFailure() {
    let runner = RecordingRunner()
    runner.exitCode = 1
    let refresher = MacSystemRefresher(runner: runner, post: { _ in })

    #expect(refresher.switchAppearance(toDark: false) == false)
    #expect(runner.runs == [[
        "/usr/bin/osascript", "-e",
        "tell application \"System Events\" to tell appearance preferences to set dark mode to false",
    ]])
}
