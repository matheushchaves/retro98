import AppKit
import Testing
@testable import Retro98Explorer
@testable import Retro98FilesCore
import Retro98UI

private let pt = ["pt-BR"]

/// Collects calls made from @Sendable service closures.
private final class Calls<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: [Value] = []
    var values: [Value] { lock.withLock { stored } }
    func add(_ value: Value) { lock.withLock { stored.append(value) } }
}

private let pen = VolumeInfo(url: URL(filePath: "/Volumes/PEN"), name: "PEN", kind: .removable, totalBytes: 1000, freeBytes: 250,
                             isEjectable: true)
private let disk = VolumeInfo(url: URL(filePath: "/"), name: "Macintosh HD", kind: .internal, totalBytes: 2000, freeBytes: 1000,
                              isEjectable: false)

@MainActor private func controller(_ ops: OperationsHarness, at location: Location) -> ExplorerWindowController {
    ExplorerWindowController(start: location, languages: pt, environment: ops.operations.environment, operations: ops.operations)
}

@MainActor private func select(_ controller: ExplorerWindowController, _ names: String...) {
    controller.grid.setSelection(IndexSet(names.compactMap { name in controller.model.entries.firstIndex { $0.name == name } }))
}

@MainActor @Test func propertiesShowFolderTotals() async throws {
    let ops = try OperationsHarness(["A/Pasta/f1.txt", "A/Pasta/f2.txt", "A/Pasta/f3.txt", "A/Pasta/Sub"])
    let window = controller(ops, at: .folder(ops.url("A")))
    select(window, "Pasta")
    window.showProperties(nil)
    let properties = try #require(window.propertiesWindows.last)
    await properties.measuring?.value
    #expect(properties.title == "Propriedades de Pasta")
    #expect(properties.text(of: "Contém:") == "3 arquivos, 1 pasta")
    #expect(properties.text(of: "Tamanho:")?.contains("bytes") == true)
    #expect(properties.text(of: "Local:") == (ops.url("A").path as NSString).abbreviatingWithTildeInPath)
    #expect(properties.text(of: "Criado:") != nil)
}

@MainActor @Test func propertiesForSeveralItems() throws {
    let ops = try OperationsHarness(["A/a.txt", "A/b.txt"])
    let window = controller(ops, at: .folder(ops.url("A")))
    select(window, "a.txt", "b.txt")
    window.showProperties(nil)
    let properties = try #require(window.propertiesWindows.last)
    #expect(properties.title == "2 itens")
    #expect(properties.text(of: "Criado:") == nil)
    #expect(properties.text(of: "Contém:") == "2 arquivos, 0 pastas")
}

@MainActor @Test func propertiesOfAVolumeShowSpace() throws {
    let ops = try OperationsHarness([], volumes: [disk, pen])
    let window = controller(ops, at: .myComputer)
    select(window, "PEN")
    window.showProperties(nil)
    let properties = try #require(window.propertiesWindows.last)
    #expect(properties.text(of: "Espaço usado:")?.contains("750 bytes") == true)
    #expect(properties.text(of: "Espaço livre:")?.contains("250 bytes") == true)
    #expect(properties.usage == 0.75)
}

@MainActor @Test func closingPropertiesStopsMeasuring() throws {
    let ops = try OperationsHarness((0..<200).map { "A/Pasta/f\($0).txt" })
    let window = controller(ops, at: .folder(ops.url("A")))
    select(window, "Pasta")
    window.showProperties(nil)
    let properties = try #require(window.propertiesWindows.last)
    properties.close()
    #expect(properties.measuring?.isCancelled == true)
    #expect(window.propertiesWindows.isEmpty)
}

@MainActor @Test func openWithListsTheDefaultFirst() throws {
    let a = URL(filePath: "/Apps/A.app"), b = URL(filePath: "/Apps/B.app"), c = URL(filePath: "/Apps/C.app")
    let opened = Calls<([URL], URL)>()
    let ops = try OperationsHarness(["A/a.txt"], services: .fake(applications: { _ in (b, [c, b, a]) }, open: { opened.add(($0, $1)) }))
    let window = controller(ops, at: .folder(ops.url("A")))
    let items = window.openWithItems(for: [ops.url("A/a.txt")])
    #expect(items.map(\.title) == ["B (padrão)", "A", "C", "", "Outro…"])
    guard case .action(let open) = items[1].kind else {
        Issue.record("expected an action")
        return
    }
    open()
    #expect(opened.values.map { $0.0.map(\.path) } == [[ops.url("A/a.txt").path]])
    #expect(opened.values.map(\.1) == [a])
}

@MainActor @Test func ejectRunsOnlyForEjectableVolumes() async throws {
    let ejected = Calls<URL>()
    let ops = try OperationsHarness([], volumes: [disk, pen], services: .fake(eject: { ejected.add($0) }))
    let window = controller(ops, at: .myComputer)
    select(window, "Macintosh HD")
    #expect(!window.isEnabled(#selector(ExplorerWindowController.ejectSelection(_:))))
    select(window, "PEN")
    #expect(window.isEnabled(#selector(ExplorerWindowController.ejectSelection(_:))))
    window.ejectSelection(nil)
    await window.lastTask?.value
    #expect(ejected.values == [pen.url])
}

@MainActor @Test func ejectFailureIsReported() async throws {
    let busy = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteUnknownError, userInfo: [NSLocalizedDescriptionKey: "Em uso."])
    let ops = try OperationsHarness([], volumes: [disk, pen], services: .fake(eject: { _ in throw busy }))
    let window = controller(ops, at: .myComputer)
    select(window, "PEN")
    window.ejectSelection(nil)
    await window.lastTask?.value
    #expect(ops.prompter.asked.last == Prompts.ejectFailed(name: "PEN", reason: "Em uso.", languages: pt))
}

@MainActor @Test func menusHaveThePropertiesAndEjectShortcuts() throws {
    let items = ExplorerMenus.mainMenu(languages: pt).items.flatMap { $0.submenu?.items ?? [] }
    func has(_ key: String, _ action: String) -> Bool {
        items.contains { $0.keyEquivalent == key && $0.keyEquivalentModifierMask == .command && $0.action.map(NSStringFromSelector) == action }
    }
    #expect(has("i", "showProperties:"))
    #expect(has("e", "ejectSelection:"))
    #expect(items.contains { $0.action.map(NSStringFromSelector) == "openWith:" })
    let ops = try OperationsHarness(["A/a.txt"])
    let window = controller(ops, at: .folder(ops.url("A")))
    #expect(!window.isEnabled(#selector(ExplorerWindowController.showProperties(_:))))
    select(window, "a.txt")
    #expect(window.isEnabled(#selector(ExplorerWindowController.showProperties(_:))))
}
