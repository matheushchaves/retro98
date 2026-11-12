import AppKit
import Retro98FilesCore
import Retro98UI

/// View menu of an Explorer window: the four view modes, the sort order and hidden files. They are
/// shared by every window (and remembered), so a change here is posted to the others.
extension ExplorerWindowController {
    static let viewDidChange = Notification.Name("Retro98ExplorerViewDidChange")
    static let modifiedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static let viewActions: Set<Selector> = [
        #selector(showLargeIcons(_:)), #selector(showSmallIcons(_:)), #selector(showList(_:)), #selector(showDetails(_:)),
        #selector(arrangeByName(_:)), #selector(arrangeByType(_:)), #selector(arrangeBySize(_:)), #selector(arrangeByDate(_:)),
        #selector(toggleHiddenFiles(_:)),
    ]

    private var preferences: ExplorerPreferences { environment.preferences }

    @objc func showLargeIcons(_ sender: Any?) { setViewMode(.largeIcons) }
    @objc func showSmallIcons(_ sender: Any?) { setViewMode(.smallIcons) }
    @objc func showList(_ sender: Any?) { setViewMode(.list) }
    @objc func showDetails(_ sender: Any?) { setViewMode(.details) }
    @objc func arrangeByName(_ sender: Any?) { arrange(by: .name) }
    @objc func arrangeByType(_ sender: Any?) { arrange(by: .type) }
    @objc func arrangeBySize(_ sender: Any?) { arrange(by: .size) }
    @objc func arrangeByDate(_ sender: Any?) { arrange(by: .modified) }

    @objc func toggleHiddenFiles(_ sender: Any?) {
        model.setShowHidden(!model.showHidden)
        postViewChange()
    }

    /// The toolbar's Views button: the four modes, a bullet on the current one.
    func showViewsMenu() {
        let items = ViewMode.allCases.map { mode in
            RetroMenuItem(title: ExplorerText.viewMode(mode, languages), kind: .action({ [weak self] in self?.setViewMode(mode) }),
                          mark: preferences.viewMode == mode ? .bullet : .none)
        }
        let menu = RetroMenu(items: items, style: .standard)
        contextMenu = menu
        menu.show(at: NSEvent.mouseLocation, opensUpward: false) {}
    }

    func isChecked(_ action: Selector?) -> Bool {
        switch action {
        case #selector(showLargeIcons(_:)): preferences.viewMode == .largeIcons
        case #selector(showSmallIcons(_:)): preferences.viewMode == .smallIcons
        case #selector(showList(_:)): preferences.viewMode == .list
        case #selector(showDetails(_:)): preferences.viewMode == .details
        case #selector(arrangeByName(_:)): model.sort.key == .name
        case #selector(arrangeByType(_:)): model.sort.key == .type
        case #selector(arrangeBySize(_:)): model.sort.key == .size
        case #selector(arrangeByDate(_:)): model.sort.key == .modified
        case #selector(toggleHiddenFiles(_:)): model.showHidden
        default: false
        }
    }

    private func setViewMode(_ mode: ViewMode) {
        preferences.viewMode = mode
        applyViewMode(mode)
        postViewChange()
    }

    /// Menu "Arrange by": that key, ascending.
    private func arrange(by key: SortKey) {
        model.setSort(SortOrder(key: key, ascending: true))
        postViewChange()
    }

    /// A header click sorts by that column; the same column again reverses.
    func sortByColumn(_ column: Int) {
        let keys = detailColumns.map(\.key)
        guard keys.indices.contains(column), let key = keys[column] else { return }
        model.setSort(SortOrder(key: key, ascending: model.sort.key == key ? !model.sort.ascending : true))
        postViewChange()
    }

    func applyViewMode(_ mode: ViewMode) {
        grid.style = switch mode {
        case .largeIcons: .largeIcons
        case .smallIcons: .smallIcons
        case .list: .list
        case .details: .details
        }
        gridPane.showsHeader = mode == .details
        gridPane.scroll.hasHorizontalScroller = mode == .list
        if mode != .list { gridPane.scroll.contentView.scroll(to: CGPoint(x: 0, y: gridPane.scroll.contentView.bounds.minY)) }
        updateColumns()
    }

    /// Name, (In Folder while searching subfolders), Size, Type, Modified — with the key each one sorts by.
    var detailColumns: [(column: GridColumn, key: SortKey?)] {
        let l = languages
        var columns: [(GridColumn, SortKey?)] = [(GridColumn(title: ExplorerText.columnName(l), width: 0), .name)]
        if model.search?.includeSubfolders == true { columns.append((GridColumn(title: ExplorerText.columnInFolder(l), width: 180), nil)) }
        columns += [(GridColumn(title: ExplorerText.columnSize(l), width: 80, alignsRight: true), .size),
                    (GridColumn(title: ExplorerText.columnType(l), width: 150), .type),
                    (GridColumn(title: ExplorerText.columnModified(l), width: 130), .modified)]
        return columns.map { (column: $0.0, key: $0.1) }
    }

    func updateColumns() {
        let columns = detailColumns
        grid.columns = columns.map(\.column)
        gridPane.header.columns = columns.map(\.column)
        gridPane.header.sortedColumn = columns.firstIndex { $0.key == model.sort.key }
        gridPane.header.ascending = model.sort.ascending
    }

    func grid(_ grid: RetroIconGrid, detailsAt index: Int) -> [String] {
        let entry = model.entries[index]
        var texts: [String] = []
        if model.search?.includeSubfolders == true {
            texts.append((entry.url.deletingLastPathComponent().path as NSString).abbreviatingWithTildeInPath)
        }
        let showsSize = entry.kind != .folder && entry.kind != .myComputer && entry.kind != .myDocuments && entry.kind != .recycleBin(isFull: nil)
        let size = showsSize ? entry.size.map { StatusText.bytes($0, locale: .current) } ?? "" : ""
        texts += [size, FileTypeName.name(for: entry, languages: languages),
                  entry.modified.map(Self.modifiedFormatter.string(from:)) ?? ""]
        return texts
    }

    // MARK: Other windows

    private func postViewChange() {
        NotificationCenter.default.post(name: Self.viewDidChange, object: preferences, userInfo: ["sender": ObjectIdentifier(self)])
    }

    func observeViewChanges() {
        viewObserver = NotificationCenter.default.addObserver(forName: Self.viewDidChange, object: preferences, queue: nil) { [weak self] note in
            let sender = note.userInfo?["sender"] as? ObjectIdentifier
            MainActor.assumeIsolated {
                guard let self, sender != ObjectIdentifier(self) else { return }
                self.model.applyPreferences()
                self.applyViewMode(self.preferences.viewMode)
            }
        }
    }
}
