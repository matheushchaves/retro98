import AppKit
import Foundation
import Testing
@testable import Retro98Settings

private let support = URL(filePath: "/Users/test/Library/Application Support/Retro98")
private let paths = Retro98Paths(supportDirectory: support, wallpaperIndex: indexURL, soundsDirectory: URL(filePath: "/home/Library/Sounds"))

/// Commands, file writes and pictures shown, in the order they happened.
private final class Steps: CommandRunner, FileStore {
    let files: InMemoryFileStore
    var steps: [String] = []
    var failWrites = false

    init(_ files: [URL: Data]) {
        self.files = InMemoryFileStore(files)
    }

    func run(_ executable: String, _ arguments: [String]) -> Int32 {
        steps.append(([executable] + arguments).joined(separator: " "))
        return 0
    }

    func read(_ url: URL) throws -> Data? { try files.read(url) }

    func write(_ data: Data?, to url: URL) throws {
        steps.append("write \(url.lastPathComponent)")
        if failWrites { throw FakeError() }
        try files.write(data, to: url)
    }
}

private func setter(_ steps: Steps) -> MacWallpaperSetter {
    MacWallpaperSetter(paths: paths, files: steps, runner: steps, setDesktopImage: { url, _ in steps.steps.append("show \(url.path)") })
}

/// A store shaped like the agent's: each choice carries its configuration as a nested property list.
private func index(showing image: String) throws -> Data {
    let configuration = try PropertyListSerialization.data(
        fromPropertyList: ["type": "imageFile", "url": ["relative": image]], format: .binary, options: 0
    )
    let choice: [String: Any] = ["Provider": "com.apple.wallpaper.choice.image", "Configuration": configuration]
    let desktop: [String: Any] = ["Content": ["Choices": [choice]]]
    return try PropertyListSerialization.data(
        fromPropertyList: ["AllSpacesAndDisplays": ["Type": "individual", "Desktop": desktop]], format: .binary, options: 0
    )
}

@Test func restoringTheIndexFreezesTheAgentWhileWriting() throws {
    let original = try index(showing: "file:///System/Library/Desktop%20Pictures/Sonoma.heic")
    let steps = Steps([indexURL: Data("teal".utf8)])

    let result = try setter(steps).restoreIndex(original, at: indexURL)

    #expect(result == .original)
    #expect(steps.steps == ["/usr/bin/killall -STOP WallpaperAgent", "write Index.plist", "/usr/bin/killall -KILL WallpaperAgent"])
    #expect(steps.files.snapshot[indexURL] == original)
}

@Test func aFailedWriteStillLetsTheAgentGo() throws {
    let original = try index(showing: "file:///Users/test/Pictures/praia.jpg")
    let steps = Steps([indexURL: Data("teal".utf8)])
    steps.failWrites = true

    #expect(throws: FakeError.self) { try setter(steps).restoreIndex(original, at: indexURL) }
    #expect(steps.steps.last == "/usr/bin/killall -KILL WallpaperAgent")
}

@Test func restoringAnIndexAlreadyInPlaceTouchesNothing() throws {
    let original = try index(showing: "file:///Users/test/Pictures/praia.jpg")
    let steps = Steps([indexURL: original])

    #expect(try setter(steps).restoreIndex(original, at: indexURL) == .original)
    #expect(steps.steps.isEmpty)
}

@Test func anOriginalShowingRetro98PutsBackTheSystemPicture() throws {
    // Saved over an uninstall that left Retro98's color behind: writing it back would bring the color back.
    let original = try index(showing: support.appending(path: "wallpaper-008080.png").absoluteString)
    let steps = Steps([indexURL: original])

    let result = try setter(steps).restoreIndex(original, at: indexURL)

    #expect(result == .systemDefault)
    #expect(steps.steps == ["show /System/Library/CoreServices/DefaultDesktop.heic"])
}
