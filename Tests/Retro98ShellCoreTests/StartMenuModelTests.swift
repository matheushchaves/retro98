import Foundation
import Testing
@testable import Retro98ShellCore

@Test func buildsTreeFromNestedFolders() throws {
    let first = try TempTree(["Safari.app", "Utilities/Terminal.app", "Utilities/Disk Utility.app"])
    let second = try TempTree(["Utilities/Console.app", "Zed.app"])

    let tree = ProgramsTreeBuilder.build(roots: [first.root, second.root])

    #expect(tree == [
        .folder(name: "Utilities", children: [
            .app(name: "Console", url: second.url("Utilities/Console.app")),
            .app(name: "Disk Utility", url: first.url("Utilities/Disk Utility.app")),
            .app(name: "Terminal", url: first.url("Utilities/Terminal.app")),
        ]),
        .app(name: "Safari", url: first.url("Safari.app")),
        .app(name: "Zed", url: second.url("Zed.app")),
    ])
}

@Test func doesNotLookInsideAppBundles() throws {
    let tree = try TempTree(["Big.app/Contents/Helpers/Helper.app"])
    #expect(ProgramsTreeBuilder.build(roots: [tree.root]) == [.app(name: "Big", url: tree.url("Big.app"))])
}

@Test func dropsFoldersWithoutApps() throws {
    let tree = try TempTree(["Docs/readme.txt", "Empty", "Calc.app"])
    #expect(ProgramsTreeBuilder.build(roots: [tree.root]) == [.app(name: "Calc", url: tree.url("Calc.app"))])
}

@Test func skipsUnreadableFolders() throws {
    let tree = try TempTree(["Locked/Secret.app", "Open.app"])
    let locked = tree.root.appending(path: "Locked").path
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked) }

    #expect(ProgramsTreeBuilder.build(roots: [tree.root]) == [.app(name: "Open", url: tree.url("Open.app"))])
}

@Test func keepsSameNamedAppsFromDifferentRootsOnce() throws {
    let first = try TempTree(["Notes.app"])
    let second = try TempTree(["Notes.app"])
    #expect(ProgramsTreeBuilder.build(roots: [first.root, second.root]) == [.app(name: "Notes", url: first.url("Notes.app"))])
}

@Test func missingRootIsIgnored() {
    #expect(ProgramsTreeBuilder.build(roots: [URL(filePath: "/nonexistent-\(UUID().uuidString)")]).isEmpty)
}

@Test func standardRootsCoverSystemAndUserApps() {
    #expect(ProgramsTreeBuilder.standardRoots(URL(filePath: "/Users/t")).map(\.path)
            == ["/Applications", "/System/Applications", "/Users/t/Applications"])
}

@Test func topLevelOrderAndTitles() {
    #expect(StartMenuModel.topLevel == [.programs, .documents, .settings, .find, .help, .run, .separator, .shutDown])
    #expect(StartMenuModel.title(.find, languages: ["pt-BR"]) == "Localizar…")
    #expect(StartMenuModel.title(.programs, languages: ["pt-BR"]) == "Programas")
    #expect(StartMenuModel.title(.run, languages: ["pt-BR"]) == "Executar…")
    #expect(StartMenuModel.title(.shutDown, languages: ["en"]) == "Shut Down…")
    #expect(StartMenuModel.helpURL.absoluteString == "https://github.com/matheushchaves/retro98#readme")
    #expect(StartMenuModel.systemSettingsURL.path == "/System/Applications/System Settings.app")
}

@Test func spotlightRecentDocumentsRespectsLimit() {
    #expect(SpotlightRecentDocuments().recent(limit: 3).count <= 3)
}
