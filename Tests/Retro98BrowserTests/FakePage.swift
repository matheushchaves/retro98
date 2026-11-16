import AppKit
import Retro98UI
@testable import Retro98Browser

/// A page that loads nothing: tests set what it shows and read what it was asked to do.
@MainActor final class FakePage: BrowserPage {
    let view: NSView = NSView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
    var url: URL? { didSet { onChange?() } }
    var title = "" { didSet { onChange?() } }
    var isLoading = false { didSet { onChange?() } }
    var progress = 0.0 { didSet { onChange?() } }
    var canGoBack = false { didSet { onChange?() } }
    var canGoForward = false { didSet { onChange?() } }
    var onChange: (() -> Void)?
    var onVisit: ((URL, String) -> Void)?
    var onHover: ((String?) -> Void)?
    var onNewPage: ((BrowserPage, Bool) -> Void)?
    var onNotice: ((String) -> Void)?
    var onClose: (() -> Void)?
    var zoom = 1.0

    private(set) var loads: [AddressTarget] = []
    private(set) var backs = 0, forwards = 0, reloads = 0, stops = 0, closes = 0
    private(set) var finds: [(text: String, backwards: Bool)] = []
    /// What `find` answers.
    var findsText = true

    /// Like a real page, the address is the one asked for as soon as loading starts.
    func load(_ target: AddressTarget) {
        loads.append(target)
        switch target {
        case .home: url = AddressInput.homeURL
        case .url(let url): self.url = url
        }
    }

    func goBack() { backs += 1 }
    func goForward() { forwards += 1 }
    func reload() { reloads += 1 }
    func stop() { stops += 1 }
    func close() { closes += 1 }

    func find(_ text: String, backwards: Bool, completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        finds.append((text, backwards))
        completion(findsText)
    }
}

/// Answers yes/no from a queue (no when it runs out) and records every message.
@MainActor final class ScriptedBrowserPrompter: BrowserPrompter {
    var answers: [Bool] = []
    var asked: [String] = []
    var told: [String] = []

    func ask(_ message: String, languages: [String]) -> Bool {
        asked.append(message)
        return answers.isEmpty ? false : answers.removeFirst()
    }

    func tell(_ message: String, icon: MessageBoxIcon, languages: [String]) { told.append(message) }
}

/// Hands out queued files instead of showing the dialog (nil, a cancel, when the queue is empty).
@MainActor final class ScriptedBrowserDialogs: BrowserDialogs {
    var opens: [URL?] = []

    func chooseFileToOpen(in folder: URL, languages: [String]) -> URL? {
        opens.isEmpty ? nil : opens.removeFirst()
    }
}

/// Everything a window needs, from fakes: pages are recorded in the order they were made.
@MainActor final class TestBrowser {
    let folder: URL
    let favorites: FavoritesStore
    let history: HistoryStore
    let preferences = BrowserPreferences.memory()
    let prompter = ScriptedBrowserPrompter()
    let dialogs = ScriptedBrowserDialogs()
    var pages: [FakePage] = []
    var now = Date(timeIntervalSince1970: 1_800_000_000)

    init() throws {
        folder = try temporaryFolder()
        favorites = FavoritesStore(file: folder.appending(path: "Browser/favorites.json"))
        history = HistoryStore(file: folder.appending(path: "Browser/history.json"))
    }

    var services: BrowserServices {
        BrowserServices(
            makePage: { [unowned self] in
                let page = FakePage()
                pages.append(page)
                return page
            },
            favorites: favorites, history: history, preferences: preferences, prompter: prompter, dialogs: dialogs,
            home: folder, now: { [unowned self] in now }
        )
    }

    func window() -> BrowserWindowController { BrowserWindowController(services: services, languages: ["pt-BR"]) }

    func cleanUp() { try? FileManager.default.removeItem(at: folder) }
}
