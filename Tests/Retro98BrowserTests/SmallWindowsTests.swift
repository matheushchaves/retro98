import AppKit
import Testing
import Retro98UI
@testable import Retro98Browser

private let a = web("https://a.example/"), b = web("https://b.example/"), c = web("https://c.example/")
private let pt = ["pt-BR"]

// MARK: Favorites

@MainActor private func favoritesWindow(_ browser: TestBrowser) -> FavoritesWindow {
    browser.favorites.add(title: "A", url: a)
    browser.favorites.add(title: "B", url: b)
    return FavoritesWindow(favorites: browser.favorites, languages: pt)
}

@MainActor @Test func listsFavoritesWithNameAndAddress() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = favoritesWindow(browser)
    #expect(window.numberOfItems(in: window.grid) == 2)
    #expect(window.grid(window.grid, titleAt: 1) == "B")
    #expect(window.grid(window.grid, detailsAt: 1) == ["https://b.example/"])
    #expect(window.grid.columns.map(\.title) == ["Nome", "Endereço"])
}

@MainActor @Test func openSendsTheSelectedAddress() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = favoritesWindow(browser)
    var opened: [URL] = []
    window.onOpen = { opened.append($0) }
    window.open()
    #expect(opened.isEmpty)
    window.grid.setSelection([1])
    window.open()
    window.grid.onOpen?(0)
    #expect(opened == [b, a])
}

@MainActor @Test func removeDeletesTheSelectionAndKeepsARowSelected() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = favoritesWindow(browser)
    browser.favorites.add(title: "C", url: c)
    window.grid.setSelection([1])
    window.remove()
    #expect(browser.favorites.items.map(\.title) == ["A", "C"])
    #expect(window.grid.selection == [1])
    window.remove()
    #expect(window.grid.selection == [0])
    window.remove()
    #expect(browser.favorites.items.isEmpty && window.grid.selection.isEmpty)
    window.remove()
}

@MainActor @Test func moveUpAndDownFollowTheItem() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = favoritesWindow(browser)
    window.grid.setSelection([1])
    window.moveUp()
    #expect(browser.favorites.items.map(\.title) == ["B", "A"])
    #expect(window.grid.selection == [0])
    window.moveUp()
    #expect(browser.favorites.items.map(\.title) == ["B", "A"])
    window.moveDown()
    #expect(browser.favorites.items.map(\.title) == ["A", "B"] && window.grid.selection == [1])
    window.moveDown()
    #expect(browser.favorites.items.map(\.title) == ["A", "B"])
}

@MainActor @Test func renameFromTheGridChangesTheTitle() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = favoritesWindow(browser)
    window.grid.onEndEditing?(0, "Novo")
    #expect(browser.favorites.items[0].title == "Novo")
    window.grid.onEndEditing?(0, nil)
    window.grid.onEndEditing?(0, "   ")
    #expect(browser.favorites.items[0].title == "Novo")
}

@MainActor @Test func listFollowsTheStore() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = favoritesWindow(browser)
    browser.favorites.add(title: "C", url: c)
    #expect(window.numberOfItems(in: window.grid) == 3)
    #expect(window.grid(window.grid, titleAt: 2) == "C")
}

@MainActor @Test func hostileFavoriteTitleIsOneLine() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    browser.favorites.add(title: "a\nb", url: a)
    let window = FavoritesWindow(favorites: browser.favorites, languages: pt)
    #expect(window.grid(window.grid, titleAt: 0) == "a b")
}

// MARK: History

private let saoPaulo = TimeZone(identifier: "America/Sao_Paulo")!

@MainActor private func historyWindow(_ browser: TestBrowser) -> HistoryWindow {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = saoPaulo
    let visited = calendar.date(from: DateComponents(year: 2026, month: 11, day: 16, hour: 14, minute: 5))!
    browser.history.record(url: a, title: "Pão de Queijo", at: visited.addingTimeInterval(-60))
    browser.history.record(url: b, title: "Outra", at: visited)
    return HistoryWindow(history: browser.history, languages: pt, locale: Locale(identifier: "pt_BR"), timeZone: saoPaulo)
}

@MainActor @Test func listsNewestFirst() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = historyWindow(browser)
    #expect(window.shown.map(\.title) == ["Outra", "Pão de Queijo"])
    #expect(window.grid.columns.map(\.title) == ["Título", "Endereço", "Visitado"])
    #expect(window.grid(window.grid, titleAt: 0) == "Outra")
}

@MainActor @Test func visitedColumnUsesTheLocale() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = historyWindow(browser)
    #expect(window.grid(window.grid, detailsAt: 0) == ["https://b.example/", "16/11/2026 14:05"])
}

@MainActor @Test func filterNarrowsTheList() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = historyWindow(browser)
    window.filter.text = "pao"
    window.filter.onChange?()
    #expect(window.shown.map(\.title) == ["Pão de Queijo"])
    #expect(window.numberOfItems(in: window.grid) == 1)
    window.filter.text = ""
    window.filter.onChange?()
    #expect(window.shown.count == 2)
}

@MainActor @Test func historyOpenSendsTheAddress() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = historyWindow(browser)
    var opened: [URL] = []
    window.onOpen = { opened.append($0) }
    window.open()
    window.grid.setSelection([1])
    window.open()
    window.grid.onOpen?(0)
    #expect(opened == [a, b])
}

@MainActor @Test func removeForgetsTheEntry() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = historyWindow(browser)
    window.filter.text = "pao"
    window.filter.onChange?()
    window.grid.setSelection([0])
    window.remove()
    #expect(browser.history.entries.map(\.url) == [b])
    #expect(window.shown.isEmpty)
    window.remove()
}

@MainActor @Test func historyListFollowsTheStore() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = historyWindow(browser)
    browser.history.record(url: c, title: "C", at: Date())
    #expect(window.shown.first?.title == "C")
}

// MARK: Find

@MainActor @Test func findNextAsksThePage() throws {
    let prompter = ScriptedBrowserPrompter()
    let page = FakePage()
    let dialog = FindInPageDialog(languages: pt, prompter: prompter) { page }
    dialog.field.text = "abc"
    dialog.findNext()
    dialog.findPrevious()
    #expect(page.finds.map(\.text) == ["abc", "abc"])
    #expect(page.finds.map(\.backwards) == [false, true])
    #expect(prompter.told.isEmpty)
    #expect(dialog.needle == "abc")
}

@MainActor @Test func notFoundTells() throws {
    let prompter = ScriptedBrowserPrompter()
    let page = FakePage()
    page.findsText = false
    let dialog = FindInPageDialog(languages: pt, prompter: prompter) { page }
    dialog.field.text = "abc"
    dialog.findNext()
    #expect(prompter.told.count == 1 && prompter.told[0].contains("abc"))
}

@MainActor @Test func emptyNeedleOrNoPageDoesNothing() throws {
    let prompter = ScriptedBrowserPrompter()
    let page = FakePage()
    let dialog = FindInPageDialog(languages: pt, prompter: prompter) { page }
    dialog.findNext()
    #expect(page.finds.isEmpty)
    let orphan = FindInPageDialog(languages: pt, prompter: prompter) { nil }
    orphan.field.text = "abc"
    orphan.findNext()
    #expect(prompter.told.isEmpty)
}

// MARK: Drawing

/// How many different colors the view draws: a list with rows has its text, icon and background.
@MainActor private func distinctColors(_ view: NSView) -> Int {
    guard let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return 0 }
    view.cacheDisplay(in: view.bounds, to: rep)
    guard let data = rep.bitmapData else { return 0 }
    var colors = Set<UInt32>()
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            let i = y * rep.bytesPerRow + x * (rep.bitsPerPixel / 8)
            colors.insert(UInt32(data[i]) << 16 | UInt32(data[i + 1]) << 8 | UInt32(data[i + 2]))
        }
    }
    return colors.count
}

@MainActor @Test func listsDrawTheirRows() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let empty = FavoritesWindow(favorites: browser.favorites, languages: pt)
    #expect(distinctColors(empty.grid) == 1)
    let window = favoritesWindow(browser)
    #expect(window.grid.frame.width > 300 && window.grid.frame.height > 200)
    #expect(window.grid.enclosingScrollView.map { $0.frame.maxY <= ($0.superview?.bounds.height ?? 0) - 20 } == true)
    #expect(distinctColors(window.grid) > 2)
    // Held in a constant: the grid only keeps a weak reference to the window that feeds it.
    let history = historyWindow(browser)
    #expect(distinctColors(history.grid) > 2)
}
