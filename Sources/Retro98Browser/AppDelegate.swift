import AppKit
import Retro98Settings
import Retro98UI

/// The Browser app: its windows, the favorites and history shared by all of them, downloads, and the commands
/// that belong to no single window. Addresses and files from outside open in a new tab of the active window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, BrowserAppCommands {
    /// New windows open this far right of and below the active one.
    static let cascadeOffset: CGFloat = 22
    /// What comes from outside is opened only when it is a page or a file.
    static let openedSchemes: Set<String> = ["http", "https", "file"]
    static let fixedFavoriteItems = 3

    let languages: [String]
    /// Tests open windows without putting them on screen.
    var presentsWindows = true
    let downloads: DownloadCenter
    private let services: BrowserServices
    private let clearWebsiteData: (@escaping @MainActor @Sendable () -> Void) -> Void
    private let openFolder: (URL) -> Void
    private var controllers: [BrowserWindowController] = []
    /// The window used last: the small windows take the keyboard without changing which window they act on.
    private weak var lastActive: BrowserWindowController?

    private(set) lazy var historyWindow: HistoryWindow = {
        let window = HistoryWindow(history: services.history, languages: languages)
        window.onOpen = { [weak self] in self?.open($0) }
        return window
    }()

    private(set) lazy var favoritesWindow: FavoritesWindow = {
        let window = FavoritesWindow(favorites: services.favorites, languages: languages)
        window.onOpen = { [weak self] in self?.openInActiveTab($0) }
        return window
    }()

    private(set) lazy var findDialog = FindInPageDialog(languages: languages, prompter: services.prompter) { [weak self] in
        self?.active?.selectedTab.page
    }

    var windowControllers: [BrowserWindowController] { controllers }

    init(services: BrowserServices, downloads: DownloadCenter,
         clearWebsiteData: @escaping (@escaping @MainActor @Sendable () -> Void) -> Void,
         openFolder: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }, languages: [String] = Locale.preferredLanguages) {
        self.services = services
        self.downloads = downloads
        self.clearWebsiteData = clearWebsiteData
        self.openFolder = openFolder
        self.languages = languages
        super.init()
        downloads.onFinish = { [weak self] name in
            guard let self else { return }
            for controller in controllers { controller.notice = BrowserText.downloadDone(name: name, languages) }
        }
    }

    /// The real app: favorites and history in Retro98's support folder, WebKit pages, the Downloads folder.
    static func live(languages: [String] = Locale.preferredLanguages) -> AppDelegate {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let data = Retro98Paths.standard(home: home, environment: ProcessInfo.processInfo.environment).supportDirectory
            .appending(path: "Browser")
        let favorites = FavoritesStore(file: data.appending(path: "favorites.json"))
        let prompter = RetroBrowserPrompter(), dialogs = RetroBrowserDialogs()
        let environment = WebKitEnvironment(favorites: favorites, prompter: prompter, dialogs: dialogs,
                                            opener: { NSWorkspace.shared.open($0) }, home: home, languages: languages)
        let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first ?? home.appending(path: "Downloads")
        let center = DownloadCenter(folder: folder, prompter: prompter, languages: languages)
        let webKitDownloads = WebKitDownloads(center: center)
        environment.onDownload = { webKitDownloads.adopt($0) }
        let services = BrowserServices(
            makePage: { environment.makePage() }, favorites: favorites,
            history: HistoryStore(file: data.appending(path: "history.json")),
            preferences: BrowserPreferences(defaults: .standard), prompter: prompter, dialogs: dialogs, home: home, now: { Date() }
        )
        return AppDelegate(services: services, downloads: center, clearWebsiteData: { environment.clearWebsiteData(completion: $0) },
                           languages: languages)
    }

    var active: BrowserWindowController? {
        controllers.first { $0.window.isKeyWindow } ?? controllers.first { $0.window.isMainWindow } ?? lastActive ?? controllers.last
    }

    // MARK: Application

    /// The Browser has its own tabs; macOS's window tabs stay out of the way.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    /// An address that launched the app may arrive before or after this; either way it gets the first window.
    func applicationDidFinishLaunching(_ notification: Notification) {
        if controllers.isEmpty { openWindow() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { open(url) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openWindow() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Quitting stops the downloads in progress, so it asks first.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard downloads.activeCount > 0 else { return .terminateNow }
        guard services.prompter.ask(BrowserText.quitWithDownloads(languages), languages: languages) else { return .terminateCancel }
        downloads.cancelAll()
        return .terminateNow
    }

    // MARK: Windows

    @discardableResult
    func openWindow(_ target: AddressTarget? = nil) -> BrowserWindowController {
        let controller = BrowserWindowController(services: services, languages: languages, first: target)
        controller.onClose = { [weak self, weak controller] in
            self?.controllers.removeAll { $0 === controller }
        }
        controller.onBecomeKey = { [weak self, weak controller] in self?.lastActive = controller }
        if let previous = active?.window.frame {
            controller.window.setFrameTopLeftPoint(CGPoint(x: previous.minX + Self.cascadeOffset, y: previous.maxY - Self.cascadeOffset))
        }
        controllers.append(controller)
        present(controller)
        return controller
    }

    /// A web address or file opens in a new tab of the active window (a new window when there is none).
    /// Anything else (other apps' links, scripts, the Browser's own pages) is ignored.
    func open(_ url: URL) {
        guard let scheme = url.scheme?.lowercased(), Self.openedSchemes.contains(scheme) else { return }
        guard let active else {
            openWindow(.url(url))
            return
        }
        active.openTab(.url(url))
        present(active)
    }

    private func openInActiveTab(_ url: URL) {
        guard let active else {
            openWindow(.url(url))
            return
        }
        active.load(url)
        present(active)
    }

    private func present(_ controller: BrowserWindowController) {
        lastActive = controller
        guard presentsWindows else { return }
        controller.window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    // MARK: Menu actions (both menu bars send these up the responder chain)

    @objc func newWindow(_ sender: Any?) { openWindow() }
    @objc func closeWindow(_ sender: Any?) { active?.window.performClose(nil) }

    @objc func showHistory(_ sender: Any?) { historyWindow.show() }
    @objc func organizeFavorites(_ sender: Any?) { favoritesWindow.show() }

    /// A favorite picked in the macOS menu bar: the item carries its address.
    @objc func openFavorite(_ sender: Any?) {
        if let url = (sender as? NSMenuItem)?.representedObject as? URL { openInActiveTab(url) }
    }

    @objc func clearBrowsingData(_ sender: Any?) {
        guard services.prompter.ask(BrowserText.clearDataQuestion(languages), languages: languages) else { return }
        services.history.clear()
        clearWebsiteData { [weak self] in
            guard let self else { return }
            for controller in controllers { controller.notice = BrowserText.dataCleared(languages) }
        }
    }

    @objc func showFind(_ sender: Any?) { findDialog.show() }

    /// Without a text to look for yet, Find Next asks for one.
    @objc func findNext(_ sender: Any?) {
        if findDialog.needle.isEmpty { findDialog.show() } else { findDialog.findNext() }
    }

    @objc func openDownloadsFolder(_ sender: Any?) { openFolder(downloads.folder) }

    @objc func showAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: BrowserText.appName,
            .credits: NSAttributedString(string: BrowserText.aboutCredits(languages)),
        ])
        NSApp.activate()
    }

    @objc func openHelp(_ sender: Any?) { NSWorkspace.shared.open(BrowserMenus.helpURL) }

    // MARK: The Favorites menu in the macOS menu bar

    /// Rebuilds the list under the two commands and the separator each time the menu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        while menu.items.count > Self.fixedFavoriteItems { menu.removeItem(at: menu.items.count - 1) }
        let favorites = services.favorites.items
        if favorites.isEmpty {
            let empty = menu.addItem(withTitle: BrowserText.emptyList(languages), action: nil, keyEquivalent: "")
            empty.isEnabled = false
        }
        for favorite in favorites {
            let title = BrowserText.oneLine(favorite.title, limit: BrowserWindowController.menuTitleLimit)
            let item = menu.addItem(withTitle: title, action: #selector(openFavorite(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = favorite.url
        }
    }
}
