import AppKit
import Testing
import Retro98UI
@testable import Retro98Browser

private let example = web("https://example.com/")

/// The app wired to fake pages, scripted questions and throwaway folders; windows never go on screen.
@MainActor private final class Bench {
    let browser: TestBrowser
    let downloadsFolder: URL
    let downloads: DownloadCenter
    let app: AppDelegate
    var websiteDataClears = 0
    var openedFolders: [URL] = []

    init() throws {
        browser = try TestBrowser()
        downloadsFolder = browser.folder.appending(path: "Downloads")
        downloads = DownloadCenter(folder: downloadsFolder, prompter: browser.prompter, languages: ["pt-BR"])
        downloads.presentsDialogs = false
        var cleared: () -> Void = {}
        var opened: (URL) -> Void = { _ in }
        app = AppDelegate(services: browser.services, downloads: downloads,
                          clearWebsiteData: { done in cleared(); done() }, openFolder: { opened($0) }, languages: ["pt-BR"])
        app.presentsWindows = false
        cleared = { [unowned self] in websiteDataClears += 1 }
        opened = { [unowned self] in openedFolders.append($0) }
    }

    func launch() { app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification)) }
    var windows: [BrowserWindowController] { app.windowControllers }
    func cleanUp() { browser.cleanUp() }
}

// MARK: Windows

@MainActor @Test func launchOpensOneWindowOnTheHomePage() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.launch()
    #expect(bench.windows.count == 1 && bench.windows[0].tabs.count == 1)
    #expect(bench.browser.pages[0].loads == [.home])
}

@MainActor @Test func newWindowCascades() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.launch()
    bench.app.newWindow(nil)
    #expect(bench.windows.count == 2)
    let first = bench.windows[0].window.frame, second = bench.windows[1].window.frame
    #expect(second.minX == first.minX + 22 && second.maxY == first.maxY - 22)
}

@MainActor @Test func addressesFromOutsideOpenInANewTab() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.launch()
    bench.app.open(example)
    #expect(bench.windows.count == 1 && bench.windows[0].tabs.count == 2 && bench.windows[0].selectedIndex == 1)
    #expect(bench.browser.pages[1].loads == [.url(example)])
}

@MainActor @Test func addressFromOutsideWithNoWindowOpensOne() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.app.application(NSApplication.shared, open: [example])
    bench.launch()
    #expect(bench.windows.count == 1 && bench.windows[0].tabs.count == 1)
    #expect(bench.browser.pages.count == 1 && bench.browser.pages[0].loads == [.url(example)])
}

@MainActor @Test func onlyWebAndFileAddressesAreOpened() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.launch()
    bench.app.application(NSApplication.shared, open: [web("mailto:a@b.c"), web("javascript:alert(1)"), web("retro98://home/")])
    #expect(bench.windows[0].tabs.count == 1)
    let file = bench.browser.folder.appending(path: "a.html")
    bench.app.application(NSApplication.shared, open: [file])
    #expect(bench.browser.pages.last?.loads == [.url(file)])
}

@MainActor @Test func reopenWithNoWindowsOpensOne() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.launch()
    bench.windows[0].window.close()
    #expect(bench.windows.isEmpty)
    #expect(!bench.app.applicationShouldTerminateAfterLastWindowClosed(NSApplication.shared))
    _ = bench.app.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: false)
    #expect(bench.windows.count == 1)
}

// MARK: Quitting

@MainActor @Test func quittingWithNoDownloadsJustQuits() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.launch()
    #expect(bench.app.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
    #expect(bench.browser.prompter.asked.isEmpty)
}

@MainActor @Test func quittingWithDownloadsAsks() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.launch()
    let transfer = FakeTransfer()
    try Data("meio".utf8).write(to: bench.downloads.begin(transfer, suggestedName: "a.zip", host: "example.com"))
    #expect(bench.app.applicationShouldTerminate(NSApplication.shared) == .terminateCancel)
    #expect(transfer.cancels == 0 && bench.downloads.activeCount == 1)
    #expect(bench.browser.prompter.asked.count == 1)
    bench.browser.prompter.answers = [true]
    #expect(bench.app.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
    #expect(transfer.cancels == 1)
    #expect(try FileManager.default.contentsOfDirectory(atPath: bench.downloadsFolder.path).isEmpty)
}

// MARK: Favorites and history

@MainActor @Test func favoritesMenuListsTheStore() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    let main = BrowserMenus.mainMenu(languages: ["pt-BR"])
    let menu = try #require(BrowserMenus.favoritesMenu(in: main, languages: ["pt-BR"]))
    bench.app.menuNeedsUpdate(menu)
    #expect(menu.items.map(\.title) == ["Adicionar a Favoritos", "Organizar Favoritos…", "", "(vazio)"])
    #expect(menu.items.last?.isEnabled == false)
    bench.browser.favorites.add(title: String(repeating: "t", count: 200), url: example)
    bench.browser.favorites.add(title: "B", url: web("https://b.example/"))
    bench.app.menuNeedsUpdate(menu)
    bench.app.menuNeedsUpdate(menu)
    #expect(menu.items.count == 5)
    #expect(menu.items[3].title.count == 60)
    #expect(menu.items[3].representedObject as? URL == example)
    #expect(menu.items[4].title == "B" && menu.items[4].action == #selector(AppDelegate.openFavorite(_:)))
}

@MainActor @Test func openFavoriteLoadsInTheActiveTab() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.launch()
    let item = NSMenuItem(title: "x", action: nil, keyEquivalent: "")
    item.representedObject = example
    bench.app.openFavorite(item)
    #expect(bench.windows[0].tabs.count == 1)
    #expect(bench.browser.pages[0].loads == [.home, .url(example)])
}

@MainActor @Test func historyWindowOpensInANewTab() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.launch()
    bench.app.historyWindow.onOpen?(example)
    #expect(bench.windows[0].tabs.count == 2 && bench.windows[0].selectedIndex == 1)
    #expect(bench.browser.pages[1].loads == [.url(example)])
    bench.app.favoritesWindow.onOpen?(web("https://b.example/"))
    #expect(bench.windows[0].tabs.count == 2)
    #expect(bench.browser.pages[1].loads.last == .url(web("https://b.example/")))
}

@MainActor @Test func clearBrowsingDataAsksFirst() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.launch()
    bench.browser.favorites.add(title: "A", url: example)
    bench.browser.history.record(url: example, title: "A", at: Date())
    bench.app.clearBrowsingData(nil)
    #expect(bench.browser.history.entries.count == 1 && bench.websiteDataClears == 0)
    bench.browser.prompter.answers = [true]
    bench.app.clearBrowsingData(nil)
    #expect(bench.browser.history.entries.isEmpty && bench.websiteDataClears == 1)
    #expect(bench.browser.favorites.items.count == 1)
    #expect(bench.browser.prompter.asked.count == 2)
}

// MARK: Downloads

@MainActor @Test func finishedDownloadShowsInEveryWindow() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.launch()
    bench.app.newWindow(nil)
    bench.downloads.onFinish?("a.zip")
    #expect(bench.windows.allSatisfy { $0.statusText == "Download concluído: a.zip" })
}

@MainActor @Test func downloadsFolderOpens() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.app.openDownloadsFolder(nil)
    #expect(bench.openedFolders == [bench.downloadsFolder])
}

// MARK: Menus

@MainActor @Test func retroMenusMatchTheSpec() throws {
    let menus = BrowserMenus.retroMenus(languages: ["pt-BR"]) { [] }
    #expect(menus.map(\.title) == ["Arquivo", "Editar", "Exibir", "Ir", "Favoritos", "Ajuda"])
    #expect(menus[0].items().map(\.title) == ["Nova janela", "Nova guia", "Abrir endereço…", "Abrir arquivo…", "",
                                              "Abrir a pasta Downloads", "", "Fechar guia", "Fechar janela"])
    #expect(menus[3].items().map(\.title) == ["Voltar", "Avançar", "Página inicial", "", "Próxima guia", "Guia anterior", "",
                                              "Histórico…", "Limpar dados de navegação…", "",
                                              "Usar a página atual como inicial", "Voltar à página inicial padrão"])
}

@MainActor @Test func macMenuBarHasShortcuts() throws {
    let main = BrowserMenus.mainMenu(languages: ["pt-BR"])
    #expect(main.items.map(\.title) == ["Retro98 Browser", "Arquivo", "Editar", "Exibir", "Ir", "Favoritos", "Janela", "Ajuda"])
    func item(_ title: String) throws -> NSMenuItem {
        let all = main.items.flatMap { $0.submenu?.items ?? [] }
        return try #require(all.first { $0.title == title }, "\(title)")
    }
    #expect(try item("Nova guia").keyEquivalent == "t")
    #expect(try item("Fechar guia").keyEquivalent == "w")
    let closeWindow = try item("Fechar janela")
    #expect(closeWindow.keyEquivalent == "w" && closeWindow.keyEquivalentModifierMask == [.command, .shift])
    #expect(try item("Atualizar").keyEquivalent == "r")
    #expect(try item("Parar").keyEquivalent == ".")
    #expect(try item("Voltar").keyEquivalent == "[")
    #expect(try item("Avançar").keyEquivalent == "]")
    let home = try item("Página inicial")
    #expect(home.keyEquivalent == "h" && home.keyEquivalentModifierMask == [.command, .shift])
    #expect(try item("Histórico…").keyEquivalent == "y")
    #expect(try item("Adicionar a Favoritos").keyEquivalent == "d")
    #expect(try item("Abrir endereço…").keyEquivalent == "l")
    let downloads = try item("Abrir a pasta Downloads")
    #expect(downloads.keyEquivalent == "l" && downloads.keyEquivalentModifierMask == [.command, .option])
    let next = try item("Próxima guia")
    #expect(next.keyEquivalent == "\t" && next.keyEquivalentModifierMask == [.control])
    let previous = try item("Guia anterior")
    #expect(previous.keyEquivalentModifierMask == [.control, .shift])
    #expect(try item("Localizar nesta página…").keyEquivalent == "f")
    #expect(try item("Aumentar").keyEquivalent == "+")
}

@MainActor @Test func tabNumberShortcutsExist() throws {
    let main = BrowserMenus.mainMenu(languages: ["pt-BR"])
    let window = try #require(BrowserMenus.windowMenu(in: main, languages: ["pt-BR"]))
    let numbered = window.items.filter { $0.action == #selector(BrowserWindowController.selectTabByNumber(_:)) }
    #expect(numbered.map(\.tag) == Array(1...9))
    #expect(numbered.map(\.keyEquivalent) == (1...9).map(String.init))
    #expect(numbered.allSatisfy { $0.isHidden && $0.allowsKeyEquivalentWhenHidden })
}

@MainActor @Test func windowsGetTheRetroMenus() throws {
    let bench = try Bench()
    defer { bench.cleanUp() }
    bench.launch()
    #expect(bench.windows[0].menuBar.menus.map(\.title) == ["Arquivo", "Editar", "Exibir", "Ir", "Favoritos", "Ajuda"])
    bench.browser.favorites.add(title: "A", url: example)
    #expect(bench.windows[0].menuBar.menus[4].items().last?.title == "A")
}

// MARK: Review fixes

@MainActor @Test func favoriteThatCannotBeSavedIsTold() throws {
    let bench = try Bench()
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: bench.browser.folder.appending(path: "Browser").path)
        bench.cleanUp()
    }
    bench.launch()
    bench.browser.favorites.add(title: "A", url: example)
    #expect(bench.browser.prompter.told.isEmpty)
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: bench.browser.folder.appending(path: "Browser").path)
    bench.browser.pages[0].url = web("https://b.example/")
    bench.windows[0].addFavorite(nil)
    #expect(bench.browser.prompter.told.count == 1)
    #expect(bench.browser.prompter.told[0].contains("Favoritos"))
}

@MainActor @Test func damagedFilesAreToldAtLaunch() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let data = browser.folder.appending(path: "Dados")
    try FileManager.default.createDirectory(at: data, withIntermediateDirectories: true)
    try Data("{not json".utf8).write(to: data.appending(path: "favorites.json"))
    var services = browser.services
    services.favorites = FavoritesStore(file: data.appending(path: "favorites.json"))
    let downloads = DownloadCenter(folder: browser.folder.appending(path: "Downloads"), prompter: browser.prompter, languages: ["pt-BR"])
    let app = AppDelegate(services: services, downloads: downloads, clearWebsiteData: { $0() }, openFolder: { _ in }, languages: ["pt-BR"])
    app.presentsWindows = false
    app.applicationDidFinishLaunching(Notification(name: NSApplication.didFinishLaunchingNotification))
    #expect(app.windowControllers.count == 1)
    #expect(browser.prompter.told.count == 1)
    #expect(browser.prompter.told[0].contains("favorites-damaged.json"))
    _ = app.applicationShouldHandleReopen(NSApplication.shared, hasVisibleWindows: true)
    #expect(browser.prompter.told.count == 1)
}
