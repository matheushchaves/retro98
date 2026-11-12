import Foundation
import Testing
@testable import Retro98ShellCore

private let safari = URL(filePath: "/Applications/Safari.app")

@Test func startMenuItemsFollowTopLevelOrder() {
    let items = StartMenuItems.build(programs: [.app(name: "Safari", url: safari)], documents: [], languages: ["pt-BR"])
    #expect(items.map { $0?.title } == ["Programas", "Documentos", "Configurações", "Ajuda", "Executar…", nil, "Desligar…"])
    #expect(items[0]?.children?.first?.action == .open(safari))
    #expect(items[1]?.children == [StartMenuNode(title: "(Vazio)", iconURL: nil, action: nil, children: nil)])
    #expect(items[2]?.children?.first?.action == .open(StartMenuModel.systemSettingsURL))
    #expect(items[3]?.action == .open(StartMenuModel.helpURL))
    #expect(items[4]?.action == .run)
    #expect(items[6]?.action == .shutDown)
}

@Test func topLevelEntriesCarryTheirSymbols() {
    let items = StartMenuItems.build(programs: [], documents: [], languages: ["en"])
    #expect(items.map { $0?.symbol } == [.programs, .documents, .settings, .help, .run, nil, .shutDown])
}

@Test func programFoldersBecomeSubmenusAndDocumentsOpen() {
    let doc = RecentDocument(name: "Relatório.pdf", url: URL(filePath: "/Users/t/Relatório.pdf"))
    let items = StartMenuItems.build(
        programs: [.folder(name: "Utilitários", children: [.app(name: "Terminal", url: URL(filePath: "/T.app"))])],
        documents: [doc], languages: ["pt-BR"]
    )
    let folder = items[0]?.children?.first
    #expect(folder?.title == "Utilitários")
    #expect(folder?.symbol == .folder)
    #expect(folder?.children?.first?.action == .open(URL(filePath: "/T.app")))
    #expect(items[1]?.children == [StartMenuNode(title: "Relatório.pdf", iconURL: doc.url, action: .open(doc.url), children: nil)])
}

@Test func findEntryAppearsOnlyWithTheExplorer() throws {
    let find = URL(string: "retro98-explorer://search")!
    let items = StartMenuItems.build(programs: [], documents: [], languages: ["pt-BR"], findURL: find)
    #expect(items.map { $0?.title } == ["Programas", "Documentos", "Configurações", "Localizar…", "Ajuda", "Executar…", nil, "Desligar…"])
    let entry = try #require(items[3])
    #expect(entry.action == .open(find))
    #expect(entry.symbol == .find)
    #expect(StartMenuItems.build(programs: [], documents: [], languages: ["en"], findURL: find)[3]?.title == "Find…")
    #expect(!StartMenuItems.build(programs: [], documents: [], languages: ["pt-BR"]).contains { $0?.title == "Localizar…" })
}
