import Foundation
import Testing
@testable import Retro98Settings

@Test func fileViewerTweakIsItsOwnGroup() throws {
    let all = TweakCatalog.all(osMajorVersion: 26, homeDirectory: URL(filePath: "/Users/t"))
    let tweak = try #require(all.first { $0.id == .explorerFileViewer })
    #expect(tweak.group == .fileViewer)
    #expect(tweak.changes == [PreferenceChange(key: PreferenceKey(domain: .global, name: "NSFileViewer"),
                                               target: .string("io.github.matheushchaves.retro98.explorer"))])
    #expect(!all.filter { $0.group == .base }.contains { $0.id == .explorerFileViewer })
    #expect(tweak.title.resolve(for: ["pt-BR"]) == "Explorer no lugar do Finder em \"Mostrar no Finder\"")
}
