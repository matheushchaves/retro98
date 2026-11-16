import AppKit
import Testing
import WebKit
import Retro98UI
@testable import Retro98Browser

/// The Browser on its own home page, drawn by the real WebKit (the page is built in: nothing comes from the network).
@MainActor @Test(.enabled(if: screenshotFolder != nil), arguments: ["en", "pt-BR"])
func screenshotBrowser(language: String) async throws {
    let folder = try temporaryFolder()
    defer { try? FileManager.default.removeItem(at: folder) }
    let favorites = FavoritesStore(file: folder.appending(path: "favorites.json"))
    favorites.add(title: "Example Domain", url: web("https://example.com/"))
    favorites.add(title: "Retro98", url: web("https://github.com/matheushchaves/retro98"))
    favorites.add(title: "DuckDuckGo", url: web("https://duckduckgo.com/"))
    let prompter = ScriptedBrowserPrompter(), dialogs = ScriptedBrowserDialogs()
    let environment = WebKitEnvironment(favorites: favorites, prompter: prompter, dialogs: dialogs, opener: { _ in }, home: folder,
                                        languages: [language], dataStore: .nonPersistent())
    let services = BrowserServices(makePage: { environment.makePage() }, favorites: favorites,
                                   history: HistoryStore(file: folder.appending(path: "history.json")),
                                   preferences: .memory(), prompter: prompter, dialogs: dialogs, home: folder, now: { Date() })
    let controller = BrowserWindowController(services: services, languages: [language])
    controller.openTab(.home, inBackground: true)
    let page = try #require(controller.selectedTab.page as? WebKitPage)
    for _ in 0..<200 where page.isLoading || page.title.isEmpty { try await Task.sleep(nanoseconds: 50_000_000) }
    for tab in controller.tabs {
        for _ in 0..<200 where tab.page.isLoading || tab.page.title.isEmpty { try await Task.sleep(nanoseconds: 50_000_000) }
    }
    let snapshot = try await page.webView.takeSnapshot(configuration: nil)
    let frame = try #require(controller.window.contentView)
    let pageRect = page.webView.convert(page.webView.bounds, to: frame)
    try saveScreenshot(of: controller.window, as: "browser", language: language, overlays: [(snapshot, pageRect)])
    controller.window.close()
}
