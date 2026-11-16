import AppKit
import Testing
import Retro98UI
@testable import Retro98Browser

private let example = web("https://example.com/")

// MARK: Opening

@MainActor @Test func opensOneTabOnTheHomePage() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    #expect(window.tabs.count == 1)
    #expect(browser.pages[0].loads == [.home])
    #expect(window.addressBar.text == "about:home")
    #expect(browser.pages[0].view.superview != nil)
}

@MainActor @Test func homePageSettingIsUsed() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    browser.preferences.homePage = "https://example.com"
    _ = browser.window()
    #expect(browser.pages[0].loads == [.url(web("https://example.com"))])
}

@MainActor @Test func firstTargetWins() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    _ = BrowserWindowController(services: browser.services, languages: ["pt-BR"], first: .url(example))
    #expect(browser.pages[0].loads == [.url(example)])
}

@MainActor @Test func newTabGoesToTheEndAndIsSelected() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.openTab()
    window.openTab()
    #expect(window.tabs.count == 3 && window.selectedIndex == 2)
    #expect(window.tabStrip.titles.count == 3 && window.tabStrip.selected == 2)
    #expect(browser.pages[2].view.superview != nil && browser.pages[0].view.superview == nil)
}

@MainActor @Test func backgroundTabKeepsTheSelection() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.openTab(.url(example), inBackground: true)
    #expect(window.tabs.count == 2 && window.selectedIndex == 0)
    #expect(browser.pages[1].loads == [.url(example)])
}

@MainActor @Test func pageOpenedByAPageSitsRightAfterIt() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.openTab()
    window.selectTab(at: 0)
    let child = FakePage()
    browser.pages[0].onNewPage?(child, false)
    #expect(window.tabs.map { $0.page === child } == [false, true, false])
    #expect(window.selectedIndex == 1)
    let quiet = FakePage()
    window.selectTab(at: 0)
    browser.pages[0].onNewPage?(quiet, true)
    #expect(window.tabs[1].page === quiet && window.selectedIndex == 0)
    #expect(window.tabs.count == 4)
}

// MARK: Closing

@MainActor @Test func closingTheSelectedTabSelectsTheRightNeighbor() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.openTab()
    window.openTab()
    window.selectTab(at: 1)
    window.closeTab(at: 1)
    #expect(window.tabs.count == 2 && window.selectedIndex == 1)
    #expect(window.selectedTab.page === browser.pages[2])
    #expect(browser.pages[2].view.superview != nil)
}

@MainActor @Test func closingTheLastPositionSelectsTheLeft() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.openTab()
    window.closeTab(at: 1)
    #expect(window.selectedIndex == 0 && window.selectedTab.page === browser.pages[0])
}

@MainActor @Test func closingATabBeforeTheSelectedKeepsThePage() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.openTab()
    window.openTab()
    window.closeTab(at: 0)
    #expect(window.selectedIndex == 1 && window.selectedTab.page === browser.pages[2])
}

@MainActor @Test func closingATabClosesItsPage() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.openTab()
    browser.pages[1].isLoading = true
    window.closeTab(at: 1)
    #expect(browser.pages[1].closes == 1)
    #expect(browser.pages[1].view.superview == nil)
    #expect(browser.pages[0].closes == 0)
    window.closeTab(at: 7)
    #expect(window.tabs.count == 1)
}

@MainActor @Test func closingTheOnlyTabClosesTheWindow() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    var closed = 0
    window.onClose = { closed += 1 }
    window.closeTab(at: 0)
    #expect(closed == 1)
    #expect(browser.pages[0].closes == 1)
}

@MainActor @Test func closingTheWindowClosesEveryPage() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.openTab()
    window.openTab()
    var closed = 0
    window.onClose = { closed += 1 }
    window.window.close()
    window.window.close()
    #expect(browser.pages.map(\.closes) == [1, 1, 1])
    #expect(closed == 1)
}

@MainActor @Test func pageAskingToCloseClosesItsTab() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.openTab()
    browser.pages[0].onClose?()
    #expect(window.tabs.count == 1 && window.selectedTab.page === browser.pages[1])
    #expect(browser.pages[0].closes == 1)
}

// MARK: Address

@MainActor @Test func goLoadsWhatWasTyped() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.go("example.com")
    window.go("pão")
    window.go("  ")
    #expect(browser.pages[0].loads == [.home, .url(web("https://example.com")), .url(web("https://duckduckgo.com/?q=p%C3%A3o"))])
}

@MainActor @Test func addressFollowsThePage() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    browser.pages[0].url = example
    #expect(window.addressBar.text == "https://example.com/")
    window.addressBar.typed("exem")
    browser.pages[0].url = web("https://example.com/outra")
    #expect(window.addressBar.text == "exem")
    window.addressBar.cancel()
    #expect(window.addressBar.text == "https://example.com/outra")
    window.addressBar.typed("example.org")
    window.addressBar.submit()
    #expect(browser.pages[0].loads.last == .url(web("https://example.org")))
    #expect(!window.addressBar.isEditing)
}

@MainActor @Test func switchingTabsShowsThatTabsAddress() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    browser.pages[0].url = example
    window.openTab(.url(web("https://b.example/")))
    #expect(window.addressBar.text == "https://b.example/")
    window.addressBar.typed("meio digitado")
    window.selectTab(at: 0)
    #expect(window.addressBar.text == "https://example.com/")
}

// MARK: Toolbar and status

@MainActor @Test func toolbarHasTheSevenButtons() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let items = browser.window().toolbarItems
    #expect(items.map { $0?.title } == ["Voltar", "Avançar", "Parar", "Atualizar", "Página inicial", nil, "Favoritos", "Histórico"])
}

@MainActor @Test func buttonsFollowThePage() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    func enabled(_ title: String) -> Bool { window.toolbarItems.compactMap { $0 }.first { $0.title == title }?.isEnabled ?? false }
    #expect(!enabled("Voltar") && !enabled("Avançar") && !enabled("Parar") && enabled("Atualizar") && enabled("Página inicial"))
    browser.pages[0].canGoBack = true
    browser.pages[0].canGoForward = true
    browser.pages[0].isLoading = true
    #expect(enabled("Voltar") && enabled("Avançar") && enabled("Parar"))
}

@MainActor @Test func buttonsDriveThePage() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    let page = browser.pages[0]
    page.canGoBack = true
    page.canGoForward = true
    page.isLoading = true
    for title in ["Voltar", "Avançar", "Parar", "Atualizar", "Página inicial"] {
        window.toolbarItems.compactMap { $0 }.first { $0.title == title }?.action()
    }
    #expect(page.backs == 1 && page.forwards == 1 && page.stops == 1 && page.reloads == 1)
    #expect(page.loads == [.home, .home])
}

@MainActor @Test func statusShowsLoadingThenDone() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    browser.pages[0].isLoading = true
    browser.pages[0].progress = 0.4
    #expect(window.statusText == "Abrindo página…")
    #expect(!window.progressBar.isHidden && window.progressBar.fraction == 0.4)
    browser.pages[0].isLoading = false
    #expect(window.statusText == "Concluído")
    #expect(window.progressBar.isHidden)
    #expect(window.statusBar.fields.first?.text == "Concluído")
}

@MainActor @Test func statusShowsTheHoveredLink() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    browser.pages[0].onHover?("https://example.com/x")
    #expect(window.statusText == "https://example.com/x")
    browser.pages[0].onHover?(nil)
    #expect(window.statusText == "Concluído")
}

@MainActor @Test func hoverFromABackgroundTabIsIgnored() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.openTab()
    browser.pages[0].onHover?("https://example.com/x")
    #expect(window.statusText == "Concluído")
}

@MainActor @Test func hostileHoverTextIsOneShortLine() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    browser.pages[0].onHover?(String(repeating: "linha\n", count: 2_000))
    #expect(!window.statusText.contains("\n"))
    #expect(window.statusText.count <= 300)
    #expect(window.statusText.hasPrefix("linha linha"))
}

@MainActor @Test func noticeShowsUntilTheNextLoad() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.notice = "Download concluído: a.zip"
    #expect(window.statusText == "Download concluído: a.zip")
    browser.pages[0].title = "ainda aqui"
    #expect(window.statusText == "Download concluído: a.zip")
    browser.pages[0].isLoading = true
    #expect(window.statusText == "Abrindo página…")
    window.notice = "outra"
    browser.pages[0].onHover?("https://example.com/")
    browser.pages[0].onHover?(nil)
    #expect(window.statusText == "Abrindo página…")
}

// MARK: Titles

@MainActor @Test func windowAndTabFollowTheTitle() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    #expect(window.window.title == "Navegador")
    browser.pages[0].title = "Exemplo"
    #expect(window.window.title == "Exemplo - Navegador")
    #expect(window.tabStrip.titles == ["Exemplo"])
    window.openTab(.url(example))
    #expect(window.tabStrip.titles == ["Exemplo", "example.com"])
    #expect(window.window.title == "Navegador")
}

@MainActor @Test func titleWithMarkupAndBreaksIsPlainText() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    browser.pages[0].title = "<b>a</b>\nb"
    #expect(window.tabStrip.titles == ["<b>a</b> b"])
    #expect(window.window.title == "<b>a</b> b - Navegador")
    browser.pages[0].title = String(repeating: "x", count: 10_000)
    #expect(window.window.title.count <= 320)
}

// MARK: History and favorites

@MainActor @Test func visitsAreRecorded() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    _ = browser.window()
    browser.pages[0].onVisit?(example, "Exemplo")
    #expect(browser.history.entries == [HistoryEntry(url: example, title: "Exemplo", lastVisited: browser.now)])
    browser.pages[0].url = example
    browser.pages[0].title = "Exemplo novo"
    #expect(browser.history.entries.first?.title == "Exemplo novo")
}

@MainActor @Test func addFavoriteUsesThePage() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.addFavorite(nil)
    #expect(browser.favorites.items.isEmpty)
    browser.pages[0].url = example
    browser.pages[0].title = "Exemplo"
    window.addFavorite(nil)
    window.addFavorite(nil)
    #expect(browser.favorites.items == [Favorite(title: "Exemplo", url: example)])
    #expect(window.statusText.contains("Favoritos"))
}

@MainActor @Test func currentPageBecomesTheHomePage() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.useCurrentPageAsHome(nil)
    #expect(browser.preferences.homePage == "about:home")
    browser.pages[0].url = example
    window.useCurrentPageAsHome(nil)
    #expect(browser.preferences.homePage == "https://example.com/")
    window.useDefaultHome(nil)
    #expect(browser.preferences.homePage == "about:home")
}

@MainActor @Test func openFileLoadsTheChosenFile() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.openFile(nil)
    #expect(browser.pages[0].loads == [.home])
    let file = browser.folder.appending(path: "a.html")
    browser.dialogs.opens = [file]
    window.openFile(nil)
    #expect(browser.pages[0].loads.last == .url(file))
}

// MARK: Tabs by keyboard and zoom

@MainActor @Test func nextAndPreviousWrapAround() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.openTab()
    window.openTab()
    window.showNextTab(nil)
    #expect(window.selectedIndex == 0)
    window.showPreviousTab(nil)
    #expect(window.selectedIndex == 2)
    window.showPreviousTab(nil)
    #expect(window.selectedIndex == 1)
}

@MainActor @Test func tabNumberNineIsTheLast() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    for _ in 0..<3 { window.openTab() }
    window.selectTab(number: 2)
    #expect(window.selectedIndex == 1)
    window.selectTab(number: 9)
    #expect(window.selectedIndex == 3)
    window.selectTab(number: 7)
    #expect(window.selectedIndex == 3)
}

@MainActor @Test func zoomStepsAndResets() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.zoomPageIn(nil)
    #expect(abs(browser.pages[0].zoom - 1.1) < 0.0001)
    for _ in 0..<40 { window.zoomPageIn(nil) }
    #expect(browser.pages[0].zoom == 3)
    for _ in 0..<80 { window.zoomPageOut(nil) }
    #expect(browser.pages[0].zoom == 0.5)
    window.zoomPageReset(nil)
    #expect(browser.pages[0].zoom == 1)
}

@MainActor @Test func tabStripDrivesTheTabs() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    window.tabStrip.onNew?()
    #expect(window.tabs.count == 2 && window.selectedIndex == 1)
    window.tabStrip.onSelect?(0)
    #expect(window.selectedIndex == 0)
    window.tabStrip.onClose?(1)
    #expect(window.tabs.count == 1)
}

// MARK: Layout

@MainActor @Test func progressFieldStaysInsideTheStatusBar() throws {
    let browser = try TestBrowser()
    defer { browser.cleanUp() }
    let window = browser.window()
    func check() {
        let bar = window.statusBar.bounds.width
        let frames = RetroStatusBar.fieldFrames(widths: window.statusBar.fields.map(\.width), totalWidth: bar, height: window.statusBar.bounds.height)
        #expect(frames.count == 2 && frames[1].width == 150)
        #expect(frames[0].maxX < frames[1].minX && frames[1].maxX <= bar - 12)
        #expect(frames[1].contains(window.progressBar.frame))
        #expect(window.progressBar.frame.width > 100)
    }
    check()
    var frame = window.window.frame
    frame.size.width += 240
    window.window.setFrame(frame, display: false)
    check()
}
