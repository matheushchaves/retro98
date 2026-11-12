import Foundation
import Testing
@testable import Retro98FilesCore

private final class Collected: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [FileEntry] = []
    private var batchCount = 0
    var entries: [FileEntry] { lock.withLock { stored } }
    var batches: Int { lock.withLock { batchCount } }
    func add(_ batch: [FileEntry]) { lock.withLock { stored += batch; batchCount += 1 } }
}

private func search(_ root: URL, _ text: String, hidden: Bool = false, limit: Int = FileSearch.resultLimit,
                    control: OperationControl = OperationControl(),
                    onBatch: (@Sendable ([FileEntry]) -> Void)? = nil) -> (SearchEnd, [FileEntry]) {
    let collected = Collected()
    let end = FileSearch.run(SearchQuery(text: text, root: root, includeSubfolders: true, showHidden: hidden), limit: limit,
                             control: control) { batch in
        collected.add(batch)
        onBatch?(batch)
    }
    return (end, collected.entries)
}

@Test func matchesIgnoringCaseAndAccents() {
    #expect(FileSearch.matches("Relatório Final.pdf", "relatorio"))
    #expect(FileSearch.matches("Relatório Final.pdf", "FINAL"))
    #expect(!FileSearch.matches("Relatório Final.pdf", "x"))
    #expect(FileSearch.matches("qualquer", ""))
}

@Test func filterKeepsOrder() {
    let entries = ["b rel", "a", "c rel"].map {
        FileEntry(url: URL(filePath: "/T/\($0)"), name: $0, kind: .document, size: nil, modified: nil, location: nil)
    }
    #expect(FileSearch.filter(entries, text: "REL").map(\.name) == ["b rel", "c rel"])
}

@Test func searchFindsInSubfolders() throws {
    let tree = try TempTree(["A/rel1.txt", "A/B/C/rel2.txt", "A/outro.txt"])
    let (end, found) = search(tree.url("A"), "rel")
    #expect(end == .finished)
    #expect(Set(found.map(\.url.path)) == [tree.url("A/rel1.txt").path, tree.url("A/B/C/rel2.txt").path])
}

@Test func searchSkipsPackagesHiddenAndUnreadable() throws {
    let tree = try TempTree(["A/Calc.app/Contents/rel.txt", "A/.escondido/rel.txt", "A/Trancada/rel.txt", "A/rel.txt"])
    let locked = tree.url("A/Trancada").path
    try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: locked)
    defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locked) }
    let (end, found) = search(tree.url("A"), "rel")
    #expect(end == .finished)
    #expect(found.map(\.url.path) == [tree.url("A/rel.txt").path])
    let (_, withHidden) = search(tree.url("A"), "rel", hidden: true)
    #expect(Set(withHidden.map(\.url.path)) == [tree.url("A/rel.txt").path, tree.url("A/.escondido/rel.txt").path])
}

@Test func searchDoesNotFollowLinkLoops() throws {
    let tree = try TempTree(["A/rel.txt"])
    try FileManager.default.createSymbolicLink(atPath: tree.url("A/volta").path, withDestinationPath: tree.url("A").path)
    let (end, found) = search(tree.url("A"), "rel")
    #expect(end == .finished)
    #expect(found.map(\.url.path) == [tree.url("A/rel.txt").path])
}

@Test func searchStopsWhenCancelled() throws {
    let tree = try TempTree((0..<300).map { "A/rel\($0).txt" })
    let control = OperationControl()
    let (end, found) = search(tree.url("A"), "rel", control: control, onBatch: { _ in control.cancel() })
    #expect(end == .cancelled)
    #expect(found.count <= FileSearch.batchSize)
}

@Test func searchStopsAtTheLimit() throws {
    let tree = try TempTree((0..<30).map { "A/rel\($0).txt" })
    let (end, found) = search(tree.url("A"), "rel", limit: 10)
    #expect(end == .limitReached)
    #expect(found.count == 10)
}

@Test func searchURLsRoundTrip() {
    let folder = URL(filePath: "/Users/t/Meus Arquivos")
    #expect(ExplorerURL.request(from: ExplorerURL.searchURL(in: nil)) == .search(nil))
    #expect(ExplorerURL.request(from: ExplorerURL.searchURL(in: .folder(folder))) == .search(.folder(folder)))
    #expect(ExplorerURL.request(from: ExplorerURL.url(for: .desktop)) == .open(.desktop))
    #expect(ExplorerURL.request(from: URL(string: "https://example.com")!) == nil)
}

@MainActor @Test func modelSearchState() throws {
    let tree = try TempTree(["A/rel.txt", "A/outro.txt", "A/Sub/rel2.txt", ".Trash"])
    let environment = ExplorerEnvironment(home: tree.root, languages: ["pt-BR"], showHidden: false, volumes: { [] },
                                          trash: tree.url(".Trash"))
    let model = ExplorerModel(start: .folder(tree.url("A")), environment: environment)
    model.beginSearch(SearchQuery(text: "rel", root: tree.url("A"), includeSubfolders: false, showHidden: false))
    #expect(model.entries.map(\.name) == ["rel.txt"])
    #expect(model.searchEnd == .finished)

    model.beginSearch(SearchQuery(text: "rel", root: tree.url("A"), includeSubfolders: true, showHidden: false))
    #expect(model.entries.isEmpty)
    #expect(model.searchEnd == nil)
    let nested = FolderListing.entry(for: tree.url("A/Sub/rel2.txt"), in: tree.url("A/Sub"))
    let top = FolderListing.entry(for: tree.url("A/rel.txt"), in: tree.url("A"))
    model.addResults([nested])
    model.addResults([top])
    #expect(model.entries.map(\.name) == ["rel.txt", "rel2.txt"])
    model.finishSearch(.finished)
    #expect(model.searchEnd == .finished)

    model.endSearch()
    #expect(model.search == nil)
    #expect(model.entries.map(\.name) == ["Sub", "outro.txt", "rel.txt"])

    model.beginSearch(SearchQuery(text: "rel", root: tree.url("A"), includeSubfolders: false, showHidden: false))
    model.go(to: .folder(tree.url("A/Sub")))
    #expect(model.search == nil)
    #expect(model.entries.map(\.name) == ["rel2.txt"])
}
