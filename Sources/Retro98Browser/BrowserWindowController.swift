import AppKit
import Retro98UI

/// One tab: its page and the link the pointer is over in it.
@MainActor
final class BrowserTab {
    let page: BrowserPage
    var hoverText: String?

    init(page: BrowserPage) {
        self.page = page
    }
}

/// One Browser window: menu bar, toolbar, address, tabs, the selected tab's page and the status bar.
@MainActor
final class BrowserWindowController: NSObject, NSWindowDelegate {
    static let shellBundleID = "io.github.matheushchaves.retro98.shell"
    static let contentSize = CGSize(width: 900, height: 620)
    static let menuHeight: CGFloat = 22, toolbarHeight: CGFloat = 42, statusHeight: CGFloat = 24
    static let statusProgressWidth: CGFloat = 150
    /// The status bar's left edge (2), the gaps after each field (4 + 4) and the resize grip (12).
    static let statusReserve: CGFloat = 22
    static let zoomStep = 1.1, zoomRange = 0.5...3.0
    static let menuTitleLimit = 60

    let window: RetroAppWindow
    let menuBar = RetroMenuBar(menus: [])
    let toolbar = RetroToolbar()
    let addressBar: AddressBar
    let tabStrip = RetroTabStrip(frame: .zero)
    let statusBar = RetroStatusBar()
    let progressBar = RetroProgressBar()
    private(set) var tabs: [BrowserTab] = []
    private(set) var selectedIndex = 0
    var onClose: (() -> Void)?
    var onBecomeKey: (() -> Void)?
    /// A line shown in the status bar until the next hover or load (downloads use it).
    var notice: String? { didSet { refresh() } }

    let services: BrowserServices
    let languages: [String]
    private let pageContainer = NSView()
    private var favoritesMenu: RetroMenu?
    private var wasLoading = false
    private var isClosed = false

    /// Opens with one tab on `first`, or on the home page setting.
    init(services: BrowserServices, languages: [String], first target: AddressTarget? = nil) {
        self.services = services
        self.languages = languages
        addressBar = AddressBar(label: BrowserText.address(languages), goTitle: BrowserText.go(languages))
        window = RetroAppWindow(title: BrowserText.name(languages), icon: BrowserIcons.appSmall, contentSize: Self.contentSize)
        super.init()
        window.delegate = self
        window.tabbingMode = .disallowed
        // Maximizing leaves the Retro98 taskbar visible while it runs, as in the Explorer.
        window.taskbarHeight = {
            NSRunningApplication.runningApplications(withBundleIdentifier: Self.shellBundleID).isEmpty ? 0 : 28
        }
        build()
        openTab(target ?? homeTarget, focusingAddress: false)
    }

    var selectedTab: BrowserTab { tabs[selectedIndex] }

    /// What Home and new tabs open.
    var homeTarget: AddressTarget {
        AddressInput.resolve(services.preferences.homePage, home: services.home) ?? .home
    }

    private func build() {
        let content = window.contentContainer
        let width = content.bounds.width, height = content.bounds.height
        var y: CGFloat = 0
        func place(_ view: NSView, height viewHeight: CGFloat) {
            view.frame = CGRect(x: 0, y: y, width: width, height: viewHeight)
            view.autoresizingMask = [.width]
            content.addSubview(view)
            y += viewHeight
        }
        place(menuBar, height: Self.menuHeight)
        place(EtchedLine(), height: 2)
        place(toolbar, height: Self.toolbarHeight)
        place(EtchedLine(), height: 2)
        place(addressBar, height: AddressBar.height)
        place(tabStrip, height: RetroTabStrip.height)
        pageContainer.frame = CGRect(x: 0, y: y, width: width, height: height - y - Self.statusHeight)
        pageContainer.autoresizingMask = [.width, .height]
        content.addSubview(pageContainer)
        statusBar.frame = CGRect(x: 0, y: height - Self.statusHeight, width: width, height: Self.statusHeight)
        statusBar.autoresizingMask = [.width, .minYMargin]
        content.addSubview(statusBar)
        progressBar.isHidden = true
        statusBar.addSubview(progressBar)

        menuBar.menus = BrowserMenus.retroMenus(languages: languages) { [weak self] in self?.favoritesMenuItems() ?? [] }
        addressBar.onSubmit = { [weak self] in self?.go($0) }
        addressBar.onCancel = { [weak self] in
            guard let self else { return }
            refresh()
            window.makeFirstResponder(selectedTab.page.view)
        }
        tabStrip.onSelect = { [weak self] in self?.selectTab(at: $0) }
        tabStrip.onClose = { [weak self] in self?.closeTab(at: $0) }
        tabStrip.onNew = { [weak self] in self?.openTab() }
    }

    // MARK: Tabs

    /// A new tab at the end: on `target`, or on the home page with the keyboard in the address bar.
    @discardableResult
    func openTab(_ target: AddressTarget? = nil, inBackground: Bool = false) -> BrowserTab {
        openTab(target ?? homeTarget, inBackground: inBackground, focusingAddress: target == nil && !inBackground)
    }

    @discardableResult
    private func openTab(_ target: AddressTarget, inBackground: Bool = false, focusingAddress: Bool) -> BrowserTab {
        let tab = insert(services.makePage(), at: tabs.count, inBackground: inBackground)
        tab.page.load(target)
        if focusingAddress { addressBar.focus(in: window) }
        return tab
    }

    @discardableResult
    private func insert(_ page: BrowserPage, at index: Int, inBackground: Bool) -> BrowserTab {
        let tab = BrowserTab(page: page)
        tabs.insert(tab, at: index)
        wire(tab)
        if inBackground, tabs.count > 1 {
            if index <= selectedIndex { selectedIndex += 1 }
            refresh()
        } else {
            select(index)
        }
        return tab
    }

    private func wire(_ tab: BrowserTab) {
        let page = tab.page
        page.onChange = { [weak self, weak tab] in
            guard let self, let tab else { return }
            if let url = tab.page.url, !tab.page.title.isEmpty { services.history.setTitle(BrowserText.oneLine(tab.page.title), for: url) }
            refresh()
        }
        page.onVisit = { [weak self] url, title in
            guard let self else { return }
            services.history.record(url: url, title: BrowserText.oneLine(title), at: services.now())
        }
        page.onHover = { [weak self, weak tab] text in
            guard let self, let tab else { return }
            // Whatever a page reports is shown as one short line of text, nothing more.
            let line = text.map { BrowserText.oneLine($0) } ?? ""
            tab.hoverText = line.isEmpty ? nil : line
            guard tab === selectedTab else { return }
            if tab.hoverText != nil { notice = nil } else { refresh() }
        }
        page.onNotice = { [weak self, weak tab] text in
            guard let self, let tab, tab === selectedTab else { return }
            notice = text
        }
        page.onNewPage = { [weak self, weak tab] newPage, inBackground in
            guard let self, let tab, let index = tabs.firstIndex(where: { $0 === tab }) else {
                newPage.close()
                return
            }
            insert(newPage, at: index + 1, inBackground: inBackground)
        }
        page.onClose = { [weak self, weak tab] in
            guard let self, let tab, let index = tabs.firstIndex(where: { $0 === tab }) else { return }
            closeTab(at: index)
        }
    }

    /// Closing the selected tab selects the one to its right, else the one to its left; the last tab takes the window with it.
    func closeTab(at index: Int) {
        guard tabs.indices.contains(index) else { return }
        guard tabs.count > 1 else {
            window.close()
            return
        }
        let tab = tabs.remove(at: index)
        tab.page.view.removeFromSuperview()
        tab.page.close()
        if index < selectedIndex {
            selectedIndex -= 1
            refresh()
        } else if index == selectedIndex {
            select(min(index, tabs.count - 1))
        } else {
            refresh()
        }
    }

    func selectTab(at index: Int) {
        guard tabs.indices.contains(index), index != selectedIndex else { return }
        select(index)
    }

    /// ⌘1…⌘8 pick a tab by position; ⌘9 is always the last one.
    func selectTab(number: Int) {
        if number == 9 { selectTab(at: tabs.count - 1) } else { selectTab(at: number - 1) }
    }

    private func select(_ index: Int) {
        selectedIndex = index
        let view = tabs[index].page.view
        for other in pageContainer.subviews where other !== view { other.removeFromSuperview() }
        if view.superview !== pageContainer {
            view.frame = pageContainer.bounds
            view.autoresizingMask = [.width, .height]
            pageContainer.addSubview(view)
        }
        addressBar.endEditing()
        wasLoading = false
        refresh()
        window.makeFirstResponder(view)
    }

    // MARK: Address

    /// Opens what was typed in the address bar: an address, a local file or a search.
    func go(_ text: String) {
        guard let target = AddressInput.resolve(text, home: services.home) else {
            refresh()
            return
        }
        addressBar.endEditing()
        selectedTab.page.load(target)
        window.makeFirstResponder(selectedTab.page.view)
    }

    // MARK: State → views

    var statusText: String {
        let page = selectedTab.page
        if let hover = selectedTab.hoverText { return hover }
        if let notice { return BrowserText.oneLine(notice) }
        return page.isLoading ? BrowserText.opening(languages) : BrowserText.done(languages)
    }

    var toolbarItems: [ToolbarItem?] {
        let l = languages, page = selectedTab.page
        func item(_ title: String, _ icon: PixelIcon, _ isEnabled: Bool = true, _ action: @escaping @MainActor (BrowserWindowController) -> Void) -> ToolbarItem {
            ToolbarItem(title: title, icon: icon, isEnabled: isEnabled) { [weak self] in
                if let self { action(self) }
            }
        }
        return [
            item(BrowserText.back(l), FileIcons.back, page.canGoBack) { $0.pageBack(nil) },
            item(BrowserText.forward(l), FileIcons.forward, page.canGoForward) { $0.pageForward(nil) },
            item(BrowserText.stop(l), BrowserIcons.stop, page.isLoading) { $0.stopPage(nil) },
            item(BrowserText.refresh(l), BrowserIcons.refresh) { $0.reloadPage(nil) },
            item(BrowserText.home(l), BrowserIcons.home) { $0.goHome(nil) },
            nil,
            item(BrowserText.favorites(l), BrowserIcons.favorites) { $0.showFavoritesMenu() },
            item(BrowserText.history(l), BrowserIcons.history) { _ in
                NSApplication.shared.sendAction(#selector(BrowserAppCommands.showHistory(_:)), to: nil, from: nil)
            },
        ]
    }

    /// Brings toolbar, address, tabs, title and status in line with the selected tab.
    func refresh() {
        guard !isClosed, tabs.indices.contains(selectedIndex) else { return }
        let page = selectedTab.page
        // A load that starts takes a notice off the status bar.
        if page.isLoading, !wasLoading, notice != nil {
            wasLoading = true
            notice = nil
            return
        }
        wasLoading = page.isLoading
        toolbar.items = toolbarItems
        if !addressBar.isEditing { addressBar.text = AddressInput.display(page.url) }
        tabStrip.titles = tabs.map { BrowserText.tabTitle(pageTitle: $0.page.title, url: $0.page.url, languages) }
        tabStrip.selected = selectedIndex
        let title = BrowserText.windowTitle(page.title, languages)
        if window.title != title { window.setTitle(title, icon: BrowserIcons.appSmall) }
        // The text field takes what the progress field, the gaps and the resize grip leave.
        let widths: [CGFloat?] = [max(statusBar.bounds.width - Self.statusProgressWidth - Self.statusReserve, 0), Self.statusProgressWidth]
        statusBar.fields = [(statusText, widths[0]), ("", widths[1])]
        let frames = RetroStatusBar.fieldFrames(widths: widths, totalWidth: statusBar.bounds.width, height: statusBar.bounds.height)
        progressBar.frame = frames[1].insetBy(dx: 2, dy: 2)
        progressBar.isHidden = !page.isLoading
        progressBar.fraction = page.progress
    }

    // MARK: Favorites

    /// The Favorites menu's items: Add, Organize…, then the list (a favorite opens in the selected tab).
    func favoritesMenuItems() -> [RetroMenuItem] {
        let l = languages
        var items = [
            RetroMenuItem(title: BrowserText.addFavorite(l), kind: .action { [weak self] in self?.addFavorite(nil) }),
            RetroMenuItem(title: BrowserText.organizeFavorites(l), kind: .action {
                NSApplication.shared.sendAction(#selector(BrowserAppCommands.organizeFavorites(_:)), to: nil, from: nil)
            }),
            RetroMenuItem.separator,
        ]
        let favorites = services.favorites.items
        if favorites.isEmpty {
            items.append(RetroMenuItem(title: BrowserText.emptyList(l), kind: .action {}, isEnabled: false))
        }
        for favorite in favorites {
            let url = favorite.url
            items.append(RetroMenuItem(title: BrowserText.oneLine(favorite.title, limit: Self.menuTitleLimit), icon: BrowserIcons.page,
                                       kind: .action { [weak self] in self?.load(url) }))
        }
        return items
    }

    func load(_ url: URL) {
        addressBar.endEditing()
        selectedTab.page.load(AddressInput.isHome(url) ? .home : .url(url))
    }

    /// The toolbar's Favorites button drops the menu under itself.
    private func showFavoritesMenu() {
        if let favoritesMenu, favoritesMenu.isOpen {
            favoritesMenu.close()
            return
        }
        let frames = RetroToolbar.frames(items: toolbarItems, height: toolbar.bounds.height)
        guard let index = toolbarItems.firstIndex(where: { $0?.title == BrowserText.favorites(languages) }) else { return }
        let corner = toolbar.convert(CGPoint(x: frames[index].minX, y: frames[index].maxY), to: nil)
        let menu = RetroMenu(items: favoritesMenuItems(), style: .standard)
        favoritesMenu = menu
        menu.show(at: window.convertPoint(toScreen: corner), opensUpward: false) { [weak self] in self?.favoritesMenu = nil }
    }

    // MARK: Window

    func windowDidBecomeKey(_ notification: Notification) { onBecomeKey?() }

    /// The status fields are laid out on the bar's width.
    func windowDidResize(_ notification: Notification) { refresh() }

    func windowWillClose(_ notification: Notification) {
        guard !isClosed else { return }
        isClosed = true
        favoritesMenu?.close()
        for tab in tabs {
            tab.page.view.removeFromSuperview()
            tab.page.close()
        }
        onClose?()
    }
}
