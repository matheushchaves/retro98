import AppKit
import Quartz
import Retro98FilesCore
import Retro98UI

/// One Explorer window: menu bar, toolbar, address, tree + large icons, status bar.
@MainActor
final class ExplorerWindowController: NSObject, NSWindowDelegate, RetroIconGridDataSource {
    static let shellBundleID = "io.github.matheushchaves.retro98.shell"
    static let menuHeight: CGFloat = 22, toolbarHeight: CGFloat = 42, addressHeight: CGFloat = 27, statusHeight: CGFloat = 24
    static let treeWidth: CGFloat = 210

    let model: ExplorerModel
    let window: RetroAppWindow
    var onClose: (() -> Void)?
    private let languages: [String]
    private let environment: ExplorerEnvironment
    private let toolbar = RetroToolbar()
    private let statusBar = RetroStatusBar()
    private let grid = RetroIconGrid()
    private let tree = RetroTreeView()
    private let treeSource: ExplorerTree
    private let address: AddressBar
    private let messageView = MessageView()
    private var watcher: DirectoryWatcher?
    private var iconCache: [URL: PixelIcon] = [:]
    private var observers: [NSObjectProtocol] = []
    private var reloadPending = false

    init(start: Location, languages: [String]) {
        self.languages = languages
        environment = .live(languages: languages)
        model = ExplorerModel(start: start, environment: environment)
        window = RetroAppWindow(title: model.title, icon: FileIcons.icon(.desktop, size: 16), contentSize: CGSize(width: 680, height: 480))
        treeSource = ExplorerTree(environment: environment, languages: languages)
        address = AddressBar(label: ExplorerText.address(languages))
        super.init()
        window.delegate = self
        window.taskbarHeight = {
            NSRunningApplication.runningApplications(withBundleIdentifier: Self.shellBundleID).isEmpty ? 0 : 28
        }
        build()
        model.onChange = { [weak self] in self?.refresh() }
        refresh()
        observeVolumes()
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        window.makeFirstResponder(grid)
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

        let split = RetroSplitView(frame: CGRect(x: 0, y: y, width: width, height: height - y - Self.statusHeight))
        split.autoresizingMask = [.width, .height]
        tree.dataSource = treeSource
        tree.onSelect = { [weak self] id in self?.treeSelected(id) }
        let treeScroll = RetroScroller.makeScrollView(document: tree)
        treeScroll.frame = CGRect(x: 0, y: 0, width: Self.treeWidth, height: split.bounds.height)
        let gridScroll = RetroScroller.makeScrollView(document: grid, as: QuickLookScrollView.self)
        gridScroll.controller = self
        gridScroll.hasHorizontalScroller = false
        gridScroll.frame = CGRect(x: Self.treeWidth + 4, y: 0, width: width - Self.treeWidth - 4, height: split.bounds.height)
        split.addSubview(FieldFrame(wrapping: treeScroll))
        split.addSubview(FieldFrame(wrapping: gridScroll))
        content.addSubview(split)
        tree.roots = [ExplorerTree.desktopID]
        tree.expand(ExplorerTree.desktopID)

        grid.dataSource = self
        grid.onOpen = { [weak self] index in self?.openEntry(at: index) }
        grid.onSelectionChange = { [weak self] _ in self?.updateStatus() }
        grid.onKey = { [weak self] event in self?.handleKey(event) ?? false }
        messageView.onOpenFinder = { NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser.appending(path: ".Trash")) }
        messageView.autoresizingMask = [.width, .height]

        statusBar.frame = CGRect(x: 0, y: height - Self.statusHeight, width: width, height: Self.statusHeight)
        statusBar.autoresizingMask = [.width, .minYMargin]
        content.addSubview(statusBar)
    }

    // MARK: State → views

    private func refresh() {
        let location = model.history.current
        window.setTitle(model.title, icon: smallIcon(for: location))
        address.set(text: AddressParser.text(for: location, languages: languages), icon: smallIcon(for: location))
        toolbar.items = toolbarItems()
        grid.setSelection([])
        grid.reloadData()
        grid.scroll(.zero)
        showMessage(model.error)
        tree.reveal(path: treeSource.path(to: location))
        watch(location)
        updateStatus()
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
            item(ExplorerText.cut(l), FileIcons.cut, false) {}, item(ExplorerText.copy(l), FileIcons.copy, false) {},
            item(ExplorerText.paste(l), FileIcons.paste, false) {},
            nil,
            item(ExplorerText.undo(l), FileIcons.undo, false) {}, item(ExplorerText.delete(l), FileIcons.delete, false) {},
            item(ExplorerText.properties(l), FileIcons.properties, false) {},
            nil,
            item(ExplorerText.views(l), FileIcons.views, false) {},
        ]
    }

    private func updateStatus() {
        let selected = grid.selection.map { model.entries[$0] }
        let size = selected.compactMap(\.size).reduce(0, +)
        let freeSpace = currentVolume()?.freeBytes
        statusBar.fields = [
            (StatusText.objects(count: model.entries.count, selected: selected.count, languages: languages), 300),
            (size > 0 ? StatusText.bytes(size, locale: .current) : "", 140),
            (freeSpace.map { StatusText.free($0, locale: .current, languages: languages) } ?? "", nil),
        ]
    }

    private func currentVolume() -> VolumeInfo? {
        let path: String
        switch model.history.current {
        case .folder(let url): path = url.path
        default: path = environment.home.path
        }
        return environment.volumes().filter { path == $0.url.path || path.hasPrefix($0.url.path == "/" ? "/" : $0.url.path + "/") }
            .max { $0.url.path.count < $1.url.path.count }
    }

    // MARK: Actions

    private func openEntry(at index: Int) {
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
        NavigationHistory.ancestors(of: model.history.current, volumes: environment.volumes().map(\.url)).map { location in
            RetroMenuItem(title: ExplorerText.locationTitle(location, languages), icon: smallIcon(for: location),
                          kind: .action({ [weak self] in self?.model.go(to: location) }))
        }
    }

    private func treeSelected(_ id: String) {
        guard let location = treeSource.location(for: id), location != model.history.current else { return }
        model.go(to: location)
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard event.charactersIgnoringModifiers == " " else { return false }
        if let panel = QLPreviewPanel.shared(), panel.isVisible {
            panel.orderOut(nil)
        } else {
            QLPreviewPanel.shared()?.makeKeyAndOrderFront(nil)
        }
        return true
    }

    fileprivate var previewURLs: [URL] {
        grid.selection.map { model.entries[$0] }.filter { $0.location == nil || $0.kind == .folder }.map(\.url)
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
        watcher?.stop()
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        onClose?()
    }

    // MARK: Grid data

    func numberOfItems(in grid: RetroIconGrid) -> Int { model.entries.count }
    func grid(_ grid: RetroIconGrid, titleAt index: Int) -> String { model.entries[index].name }
    func grid(_ grid: RetroIconGrid, iconAt index: Int) -> PixelIcon { largeIcon(for: model.entries[index]) }

    private func largeIcon(for entry: FileEntry) -> PixelIcon {
        if entry.kind == .application {
            if let cached = iconCache[entry.url] { return cached }
            let image = PixelIcon.appIcon(for: entry.url, size: 32)
            let icon = PixelIcon(width: 32, height: 32) { PixelIcon.drawUpright(image, in: CGRect(x: 0, y: 0, width: 32, height: 32), context: $0) }
            iconCache[entry.url] = icon
            return icon
        }
        return FileIcons.icon(ExplorerIcons.kind(for: entry.kind), size: 32)
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

enum ExplorerIcons {
    static func kind(for kind: FileKind) -> FileIconKind {
        switch kind {
        case .folder, .application: .folder
        case .image: .image
        case .audio: .audio
        case .video: .video
        case .archive: .archive
        case .text: .text
        case .document: .document
        case .volume(.internal): .hardDisk
        case .volume(.removable): .removableDisk
        case .volume(.network): .networkDisk
        case .myComputer: .myComputer
        case .myDocuments: .myDocuments
        case .recycleBin(let isFull): isFull == true ? .recycleBinFull : .recycleBinEmpty
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
        MainActor.assumeIsolated { controller?.previewURLs[index] as NSURL? }
    }
}
