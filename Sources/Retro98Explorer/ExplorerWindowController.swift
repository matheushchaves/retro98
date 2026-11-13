import AppKit
import Quartz
import Retro98Dialogs
import Retro98FilesCore
import Retro98UI

/// One Explorer window: menu bar, toolbar, address, tree + large icons, status bar.
@MainActor
final class ExplorerWindowController: NSObject, NSWindowDelegate, RetroIconGridDataSource {
    static let shellBundleID = "io.github.matheushchaves.retro98.shell"
    static let menuHeight: CGFloat = 22, toolbarHeight: CGFloat = 42, addressHeight: CGFloat = 27, statusHeight: CGFloat = 24
    static let treeWidth: CGFloat = 210
    /// Where the panes start, under the menu bar, toolbar and address (the search bar goes here when open).
    static let panesTop: CGFloat = menuHeight + 2 + toolbarHeight + 2 + addressHeight
    static let spaceKey: UInt16 = 49, backspaceKey: UInt16 = 51, downArrowKey: UInt16 = 125, forwardDeleteKey: UInt16 = 117
    static let returnKey: UInt16 = 36

    let model: ExplorerModel
    let window: RetroAppWindow
    let operations: ExplorerOperations
    var onClose: (() -> Void)?
    let languages: [String]
    let environment: ExplorerEnvironment
    private let toolbar = RetroToolbar()
    let statusBar = RetroStatusBar()
    let splitView = RetroSplitView(frame: .zero)
    private(set) lazy var searchBar = SearchBar(languages: languages)
    var searchTask: Task<Void, Never>?
    var searchControl: OperationControl?
    var searchGeneration = 0
    let grid: RetroIconGrid
    /// The Details header above the scrolling grid.
    let gridPane: GridPane
    private let tree = RetroTreeView()
    private let treeSource: ExplorerTree
    let address: AddressBar
    private let messageView = MessageView()
    private var watcher: DirectoryWatcher?
    private var iconCache: [URL: PixelIcon] = [:]
    private var smallIconCache: [URL: PixelIcon] = [:]
    var viewObserver: NSObjectProtocol?
    private var observers: [NSObjectProtocol] = []
    private var reloadPending = false
    /// What the grid shows right now; a reload with the same place keeps selection and scroll.
    private var shownLocation: Location?
    private var shownURLs: [URL] = []
    private var operationsObserver: NSObjectProtocol?
    /// The item being renamed in place (its index changes when the folder reloads).
    var renamingURL: URL?
    var contextMenu: RetroMenu?
    /// The last file operation this window started (tests wait for it).
    var lastTask: Task<Void, Never>?
    /// Properties windows opened from here (each leaves the list when closed).
    var propertiesWindows: [PropertiesWindow] = []
    /// The app's file undo history, as seen from this window (off while it edits text).
    private lazy var windowUndoManager = operations.makeUndoManager { [weak self] in self?.isEditingText ?? false }

    init(start: Location, languages: [String], environment: ExplorerEnvironment? = nil, operations: ExplorerOperations? = nil,
         searching: Bool = false) {
        self.languages = languages
        let environment = environment ?? operations?.environment ?? .live(languages: languages)
        self.environment = environment
        self.operations = operations ?? ExplorerOperations(environment: environment)
        model = ExplorerModel(start: start, environment: environment)
        window = RetroAppWindow(title: model.title, icon: FileIcons.icon(.desktop, size: 16), contentSize: CGSize(width: 680, height: 480))
        treeSource = ExplorerTree(environment: self.environment, languages: languages)
        address = AddressBar(label: ExplorerText.address(languages))
        let grid = RetroIconGrid()
        self.grid = grid
        gridPane = GridPane(scroll: RetroScroller.makeScrollView(document: grid, as: QuickLookScrollView.self), frame: .zero)
        super.init()
        window.delegate = self
        window.taskbarHeight = {
            NSRunningApplication.runningApplications(withBundleIdentifier: Self.shellBundleID).isEmpty ? 0 : 28
        }
        build()
        model.onChange = { [weak self] in self?.refresh() }
        refresh()
        observeVolumes()
        observeViewChanges()
        applyViewMode(environment.preferences.viewMode)
        operationsObserver = NotificationCenter.default.addObserver(forName: ExplorerOperations.didChange, object: self.operations,
                                                                    queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.operationsChanged() }
        }
        if searching { openSearchBar(includeSubfolders: true) }
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        focusInitialResponder()
    }

    /// The search field when the window opened to search (Start › Find…), the icons otherwise.
    func focusInitialResponder() {
        window.makeFirstResponder(isSearchBarVisible ? searchBar.field : grid)
    }

    func go(toHomeFolder name: String) {
        model.go(to: .folder(environment.home.appending(path: name, directoryHint: .notDirectory)))
    }

    // MARK: Layout

    private func build() {
        let content = window.contentContainer
        let width = content.bounds.width, height = content.bounds.height
        let menuBar = RetroMenuBar(menus: ExplorerMenus.retroMenus(languages: languages))
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
        place(address, height: Self.addressHeight)
        address.onSubmit = { [weak self] text in self?.submitAddress(text) }
        address.dropDownItems = { [weak self] in self?.ancestorItems() ?? [] }

        content.addSubview(searchBar)
        wireSearchBar()
        let split = splitView
        split.frame = CGRect(x: 0, y: y, width: width, height: height - y - Self.statusHeight)
        split.autoresizingMask = [.width, .height]
        tree.dataSource = treeSource
        tree.onSelect = { [weak self] id in self?.treeSelected(id) }
        let treeScroll = RetroScroller.makeScrollView(document: tree)
        treeScroll.frame = CGRect(x: 0, y: 0, width: Self.treeWidth, height: split.bounds.height)
        (gridPane.scroll as? QuickLookScrollView)?.controller = self
        gridPane.scroll.hasHorizontalScroller = false
        gridPane.frame = CGRect(x: Self.treeWidth + 4, y: 0, width: width - Self.treeWidth - 4, height: split.bounds.height)
        gridPane.header.onClick = { [weak self] column in self?.sortByColumn(column) }
        split.addSubview(FieldFrame(wrapping: treeScroll))
        split.addSubview(FieldFrame(wrapping: gridPane))
        content.addSubview(split)
        tree.roots = [ExplorerTree.desktopID]
        tree.expand(ExplorerTree.desktopID)

        grid.dataSource = self
        grid.dropDelegate = self
        grid.onOpen = { [weak self] index in self?.openEntry(at: index) }
        grid.onSelectionChange = { [weak self] _ in
            self?.updateStatus()
            self?.updateCommands()
            self?.reloadPreviewPanel()
        }
        grid.onKey = { [weak self] event in self?.handleKey(event) ?? false }
        grid.onRename = { [weak self] index in self?.beginRename(at: index) }
        grid.onEndEditing = { [weak self] _, text in self?.endRename(text) }
        grid.onContextMenu = { [weak self] index, _ in self?.showContextMenu(at: index) }
        messageView.onOpenFinder = { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appending(path: ".Trash")) }
        messageView.autoresizingMask = [.width, .height]

        statusBar.frame = CGRect(x: 0, y: height - Self.statusHeight, width: width, height: Self.statusHeight)
        statusBar.autoresizingMask = [.width, .minYMargin]
        content.addSubview(statusBar)
    }

    // MARK: State → views

    /// Navigating resets the view; a reload of the same place (files changed, a disk mounted)
    /// keeps the selection by file, the scroll position and any address being typed.
    private func refresh() {
        let location = model.history.current
        let navigated = location != shownLocation
        let kept = navigated ? [] : Set(grid.selection.compactMap { shownURLs.indices.contains($0) ? shownURLs[$0] : nil })
        shownLocation = location
        shownURLs = model.entries.map(\.url)
        address.set(text: AddressParser.text(for: location, languages: languages), icon: smallIcon(for: location), keepsEdits: !navigated)
        treeSource.refreshTrash()
        tree.needsDisplay = true
        grid.reloadData()
        grid.setSelection(IndexSet(model.entries.indices.filter { kept.contains(model.entries[$0].url) }))
        if grid.editingIndex != nil {
            grid.moveEditing(to: navigated ? nil : renamingURL.flatMap { url in model.entries.firstIndex { $0.url == url } })
        }
        showMessage(model.error)
        updateColumns()
        updateCommands()
        if navigated, isSearchBarVisible, model.search == nil {
            cancelSearchWork()
            layoutSearchBar(visible: false)
        }
        if navigated {
            window.setTitle(model.title, icon: smallIcon(for: location))
            grid.scroll(.zero)
            tree.reveal(path: treeSource.path(to: location))
            watch(location)
        }
        reloadPreviewPanel()
    }

    private func showMessage(_ message: String?) {
        guard let gridScroll = grid.enclosingScrollView else { return }
        if let message {
            messageView.message = message
            messageView.showsFinderButton = model.history.current == .trash
            messageView.frame = gridScroll.bounds
            gridScroll.addSubview(messageView)
        } else {
            messageView.removeFromSuperview()
        }
    }

    /// Toolbar and cut ghosts follow the selection, the clipboard and the undo history.
    func updateCommands() {
        toolbar.items = toolbarItems()
        grid.needsDisplay = true
    }

    private func operationsChanged() {
        updateCommands()
    }

    private func toolbarItems() -> [ToolbarItem?] {
        let l = languages
        let item = { (title: String, icon: PixelIcon, enabled: Bool, action: @escaping @Sendable @MainActor () -> Void) in
            ToolbarItem(title: title, icon: icon, isEnabled: enabled, action: action)
        }
        return [
            item(ExplorerText.back(l), FileIcons.back, model.history.canGoBack) { [weak self] in self?.model.back() },
            item(ExplorerText.forward(l), FileIcons.forward, model.history.canGoForward) { [weak self] in self?.model.forward() },
            item(ExplorerText.up(l), FileIcons.up, model.history.current != .desktop) { [weak self] in self?.model.up() },
            nil,
            item(ExplorerText.cut(l), FileIcons.cut, isEnabled(#selector(cut(_:)))) { [weak self] in self?.cut(nil) },
            item(ExplorerText.copy(l), FileIcons.copy, isEnabled(#selector(copy(_:)))) { [weak self] in self?.copy(nil) },
            item(ExplorerText.paste(l), FileIcons.paste, isEnabled(#selector(paste(_:)))) { [weak self] in self?.paste(nil) },
            nil,
            item(ExplorerText.undo(l), FileIcons.undo, !isEditingText && operations.undoStack.canUndo) { [weak self] in
                self?.spawn { await self?.operations.undo() }
            },
            item(ExplorerText.delete(l), FileIcons.delete, isEnabled(#selector(moveToTrash(_:)))) { [weak self] in self?.moveToTrash(nil) },
            item(ExplorerText.properties(l), FileIcons.properties, isEnabled(#selector(showProperties(_:)))) { [weak self] in
                self?.showProperties(nil)
            },
            nil,
            item(ExplorerText.views(l), FileIcons.views, true) { [weak self] in self?.showViewsMenu() },
        ]
    }

    var selectedEntries: [FileEntry] {
        grid.selection.filter { model.entries.indices.contains($0) }.map { model.entries[$0] }
    }

    private func updateStatus() {
        let selected = selectedEntries
        let size = selected.compactMap(\.size).reduce(0, +)
        let freeSpace = model.freeSpace
        statusBar.fields = [
            (searchStatus ?? StatusText.objects(count: model.entries.count, selected: selected.count, languages: languages), 300),
            (size > 0 ? StatusText.bytes(size, locale: .current) : "", 140),
            (freeSpace.map { StatusText.free($0, locale: .current, languages: languages) } ?? "", nil),
        ]
    }

    // MARK: Actions

    func openEntry(at index: Int) {
        guard model.entries.indices.contains(index), let url = model.open(model.entries[index]) else { return }
        NSWorkspace.shared.open(url)
    }

    private func submitAddress(_ text: String) {
        let location = AddressParser.location(for: text, home: environment.home, languages: languages) { path in
            var isDirectory: ObjCBool = false
            return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory) && isDirectory.boolValue
        }
        guard let location else {
            _ = RetroMessageBox.run(title: "Retro98 Explorer", message: ExplorerText.notFound(text, languages), icon: .error, buttons: ["OK"])
            return
        }
        model.go(to: location)
        window.makeFirstResponder(grid)
    }

    private func ancestorItems() -> [RetroMenuItem] {
        NavigationHistory.ancestors(of: model.history.current, volumes: model.volumes.map(\.url)).map { location in
            RetroMenuItem(title: ExplorerText.locationTitle(location, languages), icon: smallIcon(for: location),
                          kind: .action({ [weak self] in self?.model.go(to: location) }))
        }
    }

    private func treeSelected(_ id: String) {
        guard let location = treeSource.location(for: id), location != model.history.current else { return }
        model.go(to: location)
    }

    /// Space: Quick Look. Backspace: up one level (98). ⌘↓: open the selection (Finder).
    /// Del: to the Recycle Bin; ⇧Del: delete permanently.
    private func handleKey(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).subtracting([.numericPad, .function])
        switch (event.keyCode, modifiers) {
        case (Self.spaceKey, []):
            if let panel = QLPreviewPanel.shared(), panel.isVisible {
                panel.orderOut(nil)
            } else {
                QLPreviewPanel.shared()?.makeKeyAndOrderFront(nil)
            }
        case (Self.backspaceKey, []):
            model.up()
        case (Self.downArrowKey, [.command]):
            guard let index = grid.selection.first else { return true }
            openEntry(at: index)
        case (Self.returnKey, [.option]):
            showProperties(nil)
        case (Self.escapeKey, []):
            guard isSearchBarVisible else { return false }
            closeSearch()
        case (Self.forwardDeleteKey, []):
            moveToTrash(nil)
        case (Self.forwardDeleteKey, [.shift]):
            deletePermanently(nil)
        default:
            return false
        }
        return true
    }

    fileprivate var previewURLs: [URL] {
        selectedEntries.filter { $0.location == nil || $0.kind == .folder }.map(\.url)
    }

    /// The panel caches the item count; it must follow every selection or contents change.
    private func reloadPreviewPanel() {
        guard QLPreviewPanel.sharedPreviewPanelExists(), let panel = QLPreviewPanel.shared(), panel.isVisible,
              (panel.dataSource as AnyObject?) === grid.enclosingScrollView else { return }
        panel.reloadData()
    }

    // MARK: Watching

    private func watch(_ location: Location) {
        watcher?.stop()
        let folder: URL?
        switch location {
        case .desktop: folder = environment.home.appending(path: "Desktop")
        case .trash: folder = environment.trash
        case .folder(let url): folder = url
        case .myComputer: folder = nil
        }
        watcher = folder.flatMap { url in
            DirectoryWatcher(url: url) { [weak self] in
                Task { @MainActor in self?.scheduleReload() }
            }
        }
    }

    /// A copy of many files sends many events; reload once per burst.
    private func scheduleReload() {
        guard !reloadPending else { return }
        reloadPending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            MainActor.assumeIsolated {
                self?.reloadPending = false
                self?.model.reload()
            }
        }
    }

    private func observeVolumes() {
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didMountNotification, NSWorkspace.didUnmountNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated {
                    self?.treeSource.reset()
                    self?.tree.reloadData()
                    self?.model.reload()
                }
            })
        }
    }

    func windowWillClose(_ notification: Notification) {
        cancelSearchWork()
        watcher?.stop()
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        operationsObserver.map(NotificationCenter.default.removeObserver)
        viewObserver.map(NotificationCenter.default.removeObserver)
        onClose?()
    }

    /// One undo history for the whole app: Edit › Undo, ⌘Z and its title come from the operations,
    /// except while typing in the address or a name, where ⌘Z belongs to the text.
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? { windowUndoManager }

    func windowDidBecomeKey(_ notification: Notification) { updateCommands() }

    // MARK: Grid data

    func numberOfItems(in grid: RetroIconGrid) -> Int { model.entries.count }
    func grid(_ grid: RetroIconGrid, titleAt index: Int) -> String { model.entries[index].name }
    func grid(_ grid: RetroIconGrid, iconAt index: Int) -> PixelIcon { largeIcon(for: model.entries[index]) }
    func grid(_ grid: RetroIconGrid, isDimmedAt index: Int) -> Bool {
        model.entries[index].isHidden || operations.isCut(model.entries[index].url)
    }
    func grid(_ grid: RetroIconGrid, smallIconAt index: Int) -> PixelIcon { smallIcon(for: model.entries[index]) }

    private func smallIcon(for entry: FileEntry) -> PixelIcon {
        guard entry.kind == .application else { return FileIcons.icon(entry.kind.iconKind, size: 16) }
        if let cached = smallIconCache[entry.url] { return cached }
        let image = PixelIcon.appIcon(for: entry.url, size: 16)
        let icon = PixelIcon(width: 16, height: 16) { PixelIcon.drawUpright(image, in: CGRect(x: 0, y: 0, width: 16, height: 16), context: $0) }
        smallIconCache[entry.url] = icon
        return icon
    }

    private func largeIcon(for entry: FileEntry) -> PixelIcon {
        if entry.kind == .application {
            if let cached = iconCache[entry.url] { return cached }
            let image = PixelIcon.appIcon(for: entry.url, size: 32)
            let icon = PixelIcon(width: 32, height: 32) { PixelIcon.drawUpright(image, in: CGRect(x: 0, y: 0, width: 32, height: 32), context: $0) }
            iconCache[entry.url] = icon
            return icon
        }
        return FileIcons.icon(entry.kind.iconKind, size: 32)
    }

    private func smallIcon(for location: Location) -> PixelIcon {
        switch location {
        case .desktop: FileIcons.icon(.desktop, size: 16)
        case .myComputer: FileIcons.icon(.myComputer, size: 16)
        case .trash: FileIcons.icon(.recycleBinEmpty, size: 16)
        case .folder: FileIcons.icon(.folder, size: 16)
        }
    }
}

/// Grid scroll view that also drives the Quick Look panel (it sits in the responder chain).
final class QuickLookScrollView: NSScrollView, QLPreviewPanelDataSource {
    weak var controller: ExplorerWindowController?

    override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool { true }
    override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) { MainActor.assumeIsolated { panel.dataSource = self } }
    override func endPreviewPanelControl(_ panel: QLPreviewPanel!) { MainActor.assumeIsolated { panel.dataSource = nil } }

    nonisolated func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
        MainActor.assumeIsolated { controller?.previewURLs.count ?? 0 }
    }

    nonisolated func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        let url: NSURL? = MainActor.assumeIsolated {
            let urls = controller?.previewURLs ?? []
            return urls.indices.contains(index) ? urls[index] as NSURL : nil
        }
        return url
    }
}
