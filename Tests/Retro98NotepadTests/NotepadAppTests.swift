import AppKit
import Retro98UI
import Testing
@testable import Retro98Notepad

private let pt = ["pt-BR"]

/// The app wired to scripted dialogs and questions, with a throwaway home folder; windows never go on screen.
@MainActor private final class Bench {
    let home: URL
    let prompter = ScriptedNotepadPrompter()
    let dialogs = ScriptedNotepadDialogs()
    let preferences = NotepadPreferences.memory()
    let app: AppDelegate

    init() throws {
        VGAFont.register(at: vgaFontURL)
        home = try temporaryFolder()
        app = AppDelegate(preferences: preferences, dialogs: dialogs, prompter: prompter, home: home, languages: pt)
        app.presentsWindows = false
    }

    func file(_ path: String, _ text: String = "oi") throws -> URL {
        let url = home.appending(path: path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(text.utf8).write(to: url)
        return url
    }

    func launch() { app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification)) }

    func type(_ text: String, in index: Int = 0) {
        let view = app.windowControllers[index].textView
        view.insertText(text, replacementRange: view.selectedRange())
    }

    deinit { try? FileManager.default.removeItem(at: home) }
}

@MainActor @Test func launchOpensOneUntitledWindow() throws {
    let bench = try Bench()
    bench.launch()
    #expect(bench.app.windowControllers.count == 1)
    #expect(bench.app.windowControllers[0].fileURL == nil)
}

@MainActor @Test func openingAFileReusesTheUntouchedWindow() throws {
    let bench = try Bench()
    bench.launch()
    let url = try bench.file("a.txt")
    #expect(bench.app.open(url))
    #expect(bench.app.windowControllers.count == 1)
    #expect(bench.app.windowControllers[0].fileURL == url)
}

@MainActor @Test func openingAgainBringsTheSameWindow() throws {
    let bench = try Bench()
    let url = try bench.file("a.txt")
    #expect(bench.app.open(url))
    #expect(bench.app.open(url))
    #expect(bench.app.windowControllers.count == 1)
}

@MainActor @Test func openingWithAModifiedWindowMakesANewOne() throws {
    let bench = try Bench()
    bench.launch()
    bench.type("rascunho")
    #expect(bench.app.open(try bench.file("a.txt")))
    #expect(bench.app.windowControllers.count == 2)
    #expect(bench.app.windowControllers[0].textView.string == "rascunho")
    let (first, second) = (bench.app.windowControllers[0].window.frame, bench.app.windowControllers[1].window.frame)
    #expect(second.minX == first.minX + 22 && second.maxY == first.maxY - 22)
}

@MainActor @Test func filesFromOutsideOpenBeforeOrAfterLaunchFinishes() throws {
    let before = try Bench()
    before.app.application(NSApplication.shared, open: [try before.file("a.txt"), try before.file("b.txt")])
    before.launch()
    #expect(before.app.windowControllers.compactMap { $0.fileURL?.lastPathComponent } == ["a.txt", "b.txt"])
    #expect(before.app.windowControllers.count == 2)

    let after = try Bench()
    after.launch()
    after.app.application(NSApplication.shared, open: [try after.file("a.txt"), try after.file("b.txt")])
    #expect(after.app.windowControllers.compactMap { $0.fileURL?.lastPathComponent } == ["a.txt", "b.txt"])
    #expect(after.app.windowControllers.count == 2)
}

@MainActor @Test func unreadableFileOpensNoWindow() throws {
    let bench = try Bench()
    let binary = bench.home.appending(path: "prog.bin")
    try Data([0x00, 0x01, 0x02]).write(to: binary)
    #expect(!bench.app.open(binary))
    #expect(bench.app.windowControllers.isEmpty)
    #expect(bench.prompter.told.last == "Não foi possível abrir prog.bin: o arquivo não parece ser texto.")
}

@MainActor @Test func quittingAsksForEachModifiedWindow() throws {
    let bench = try Bench()
    bench.app.openWindow()
    bench.app.openWindow()
    bench.app.openWindow()
    bench.type("um", in: 0)
    bench.type("dois", in: 2)
    bench.prompter.answers = [.cancel]
    #expect(bench.app.applicationShouldTerminate(NSApplication.shared) == .terminateCancel)
    #expect(bench.prompter.asked.count == 1)
    bench.prompter.answers = [.discard, .discard]
    #expect(bench.app.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
    #expect(bench.prompter.asked.count == 3)
}

@MainActor @Test func wordWrapTogglesEveryWindow() throws {
    let bench = try Bench()
    bench.app.openWindow()
    bench.app.openWindow()
    bench.app.toggleWordWrap(nil)
    #expect(bench.preferences.wordWrap)
    #expect(bench.app.windowControllers.map(\.wordWrap) == [true, true])
    #expect(bench.app.openWindow().wordWrap)
    let format = bench.app.windowControllers[0].menuBar.menus[3]
    #expect(format.title == "Formatar" && format.items().first?.mark == .check)
    bench.app.toggleWordWrap(nil)
    #expect(format.items().first?.mark == RetroMenuItem.Mark.none)
}

@MainActor @Test func dialogsStartInTheLastFolderUsed() throws {
    let bench = try Bench()
    bench.launch()
    bench.app.openDocument(nil)
    #expect(bench.dialogs.openFolders.last?.path == bench.home.appending(path: "Documents").path)
    #expect(bench.app.open(try bench.file("x/a.txt")))
    let fresh = bench.app.openWindow()
    fresh.textView.insertText("novo", replacementRange: NSRange(location: 0, length: 0))
    fresh.saveAs()
    #expect(bench.dialogs.saveRequests.last?.folder.path == bench.home.appending(path: "x").path)
}

@MainActor @Test func openCommandOpensTheChosenFile() throws {
    let bench = try Bench()
    bench.launch()
    bench.dialogs.opens = [try bench.file("a.txt", "conteúdo")]
    bench.app.openDocument(nil)
    #expect(bench.app.windowControllers.count == 1)
    #expect(bench.app.windowControllers[0].textView.string == "conteúdo")
}

@MainActor @Test func closingAWindowForgetsIt() throws {
    let bench = try Bench()
    bench.app.openWindow()
    bench.app.windowControllers[0].window.close()
    #expect(bench.app.windowControllers.isEmpty)
}

@MainActor @Test func findNextWithoutATextOpensNothingToSearch() throws {
    let bench = try Bench()
    bench.app.openWindow()
    bench.type("um dois um")
    bench.app.windowControllers[0].textView.setSelectedRange(NSRange(location: 0, length: 0))
    bench.app.findDialog.field.text = "dois"
    bench.app.findNext(nil)
    #expect(bench.app.windowControllers[0].textView.selectedRange() == NSRange(location: 3, length: 4))
}

@MainActor @Test func retroMenusMatchTheSpec() {
    let groups = NotepadMenus.groups(pt)
    let menus = NotepadMenus.retroMenus(languages: pt, wordWrap: { false })
    #expect(menus.map(\.title) == ["Arquivo", "Editar", "Pesquisar", "Formatar", "Ajuda"])
    for (menu, group) in zip(menus, groups) {
        #expect(menu.items().map(\.title) == group.commands.map { $0?.title ?? "" })
    }
    #expect(groups[0].commands.compactMap { $0?.title } == ["Novo", "Abrir…", "Salvar", "Salvar como…", "Fechar"])
    #expect(groups[1].commands.compactMap { $0?.title }
        == ["Desfazer", "Refazer", "Recortar", "Copiar", "Colar", "Excluir", "Selecionar tudo", "Hora/data"])
    #expect(groups[2].commands.compactMap { $0?.title } == ["Localizar…", "Localizar próxima"])
    #expect(groups[3].commands.compactMap { $0?.title } == ["Quebra automática de linha"])
    #expect(NotepadMenus.groups(["en"]).map(\.title) == ["File", "Edit", "Search", "Format", "Help"])
}

@MainActor @Test func macMenuBarHasShortcuts() {
    let main = NotepadMenus.mainMenu(languages: pt)
    #expect(main.items.map(\.title) == ["Retro98 Notepad", "Arquivo", "Editar", "Pesquisar", "Formatar", "Janela", "Ajuda"])
    let items = main.items.flatMap { $0.submenu?.items ?? [] }
    func has(_ key: String, _ modifiers: NSEvent.ModifierFlags, _ action: String) -> Bool {
        items.contains { $0.keyEquivalent == key && $0.keyEquivalentModifierMask == modifiers && $0.action.map(NSStringFromSelector) == action }
    }
    #expect(has("n", .command, "newDocument:"))
    #expect(has("o", .command, "openDocument:"))
    #expect(has("s", .command, "saveDocument:"))
    #expect(has("s", [.command, .shift], "saveDocumentAs:"))
    #expect(has("w", .command, "closeWindow:"))
    #expect(has("z", .command, "undo:"))
    #expect(has("z", [.command, .shift], "redo:"))
    #expect(has("x", .command, "cut:") && has("c", .command, "copy:") && has("v", .command, "paste:") && has("a", .command, "selectAll:"))
    #expect(has(String(UnicodeScalar(NSF5FunctionKey)!), [], "insertTimeDate:"))
    #expect(has("f", .command, "showFind:"))
    #expect(has("g", .command, "findNext:"))
    #expect(has("q", .command, "terminate:"))
    #expect(has("m", .command, "miniaturize:"))
    #expect(NotepadMenus.windowMenu(in: main, languages: pt)?.title == "Janela")
}

@MainActor @Test func windowControllerTakesTheDocumentCommands() throws {
    let bench = try Bench()
    let controller = bench.app.openWindow()
    for action in ["saveDocument:", "saveDocumentAs:", "insertTimeDate:"] {
        #expect(controller.responds(to: NSSelectorFromString(action)))
    }
    for action in ["newDocument:", "openDocument:", "closeWindow:", "toggleWordWrap:", "showFind:", "findNext:", "showAbout:", "openHelp:"] {
        #expect(bench.app.responds(to: NSSelectorFromString(action)))
    }
}
