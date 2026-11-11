import Foundation
import Testing
@testable import Retro98ShellCore

private struct Fixture {
    let first: TempTree
    let second: TempTree
    let home: TempTree
    var roots: [URL] { [first.root, second.root] }

    init() throws {
        first = try TempTree(["Safari.app", "Música.app", "Utilities/Terminal.app"])
        second = try TempTree(["Safari.app"])
        home = try TempTree(["Downloads"])
    }

    func resolve(_ input: String) -> RunTarget? {
        RunTarget.resolve(input, appRoots: roots, home: home.root)
    }
}

@Test func emptyInputResolvesToNil() throws {
    let fixture = try Fixture()
    #expect(fixture.resolve("") == nil)
    #expect(fixture.resolve("   ") == nil)
}

@Test func urlsAndWebAddresses() throws {
    let fixture = try Fixture()
    #expect(fixture.resolve("https://example.com") == .url(URL(string: "https://example.com")!))
    #expect(fixture.resolve("mailto:a@b.com") == .url(URL(string: "mailto:a@b.com")!))
    #expect(fixture.resolve("www.example.com") == .url(URL(string: "https://www.example.com")!))
}

@Test func tildePathsExpandAndMustExist() throws {
    let fixture = try Fixture()
    #expect(fixture.resolve(" ~/Downloads ") == .path(fixture.home.root.appending(path: "Downloads", directoryHint: .notDirectory)))
    #expect(fixture.resolve("~/nada") == .notFound("~/nada"))
    #expect(fixture.resolve(fixture.home.root.path) == .path(URL(filePath: fixture.home.root.path)))
}

@Test func appNamesIgnoreCaseAccentsAndExtension() throws {
    let fixture = try Fixture()
    let safari = fixture.first.url("Safari.app")
    #expect(fixture.resolve("safari") == .app(safari))
    #expect(fixture.resolve("Safari.app") == .app(safari))
    #expect(fixture.resolve("musica") == .app(fixture.first.url("Música.app")))
    #expect(fixture.resolve("TERMINAL") == .app(fixture.first.url("Utilities/Terminal.app")))
}

@Test func unknownNameIsNotFound() throws {
    #expect(try Fixture().resolve("xyz") == .notFound("xyz"))
}
