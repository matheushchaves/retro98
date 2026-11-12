import AppKit
import Retro98FilesCore
import Retro98UI

/// File commands of an Explorer window. Both menu bars send them up the responder chain, where the
/// window's delegate (this controller) receives them; the toolbar, keys and context menu call them directly.
/// While text is being edited (the address or a name), they all stay off: ⌘⌫, ⌘C and ⌘V belong to the text.
extension ExplorerWindowController: NSMenuItemValidation {
    var isEditingText: Bool { window.firstResponder is NSText }

    /// Where pasting and new folders go: the folder shown (the Desktop folder for the Desktop); nil elsewhere.
    var destinationFolder: URL? {
        guard case .folder(let url)? = DropRules.target(entry: nil, at: model.history.current, home: environment.home,
                                                         trash: environment.trash) else { return nil }
        return url
    }

    private var isInTrash: Bool { model.history.current == .trash }

    private var visibleTrashCount: Int {
        ((try? FileManager.default.contentsOfDirectory(atPath: environment.trash.path)) ?? []).filter { !$0.hasPrefix(".") }.count
    }

    func isEnabled(_ action: Selector?) -> Bool {
        if let action, Self.viewActions.contains(action) { return true }
        guard !isEditingText, let action else { return false }
        let selected = selectedEntries
        let files = !selected.isEmpty && selected.allSatisfy(\.isFileItem)
        switch action {
        case #selector(openSelection(_:)): return !selected.isEmpty
        case #selector(copy(_:)), #selector(cut(_:)), #selector(moveToTrash(_:)), #selector(deletePermanently(_:)): return files
        case #selector(renameSelection(_:)): return files && selected.count == 1
        case #selector(paste(_:)), #selector(moveItemHere(_:)): return operations.canPaste && destinationFolder != nil
        case #selector(newFolder(_:)): return destinationFolder != nil
        case #selector(restoreFromTrash(_:)): return isInTrash && files && selected.allSatisfy { operations.canRestore($0.url) }
        case #selector(emptyTrash(_:)): return TrashState.isFull(trash: environment.trash) == true
        case #selector(openTrashInFinder(_:)): return isInTrash
        default: return true
        }
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        menuItem.state = isChecked(menuItem.action) ? .on : .off
        return isEnabled(menuItem.action)
    }

    func spawn(_ work: @escaping @MainActor () async -> Void) {
        lastTask = Task { await work() }
    }

    /// After an operation: list the folder again and select what landed in it.
    func showResults(_ urls: [URL]) {
        model.reload()
        let paths = Set(urls.map(\.standardizedFileURL.path))
        grid.setSelection(IndexSet(model.entries.indices.filter { paths.contains(model.entries[$0].url.standardizedFileURL.path) }))
    }

    // MARK: Actions

    @objc func openSelection(_ sender: Any?) {
        guard isEnabled(#selector(openSelection(_:))) else { return }
        let indexes = grid.selection.sorted()
        if indexes.count == 1 {
            openEntry(at: indexes[0])
        } else {
            indexes.map { model.entries[$0] }.filter { $0.location == nil }.forEach { NSWorkspace.shared.open($0.url) }
        }
    }

    @objc func newFolder(_ sender: Any?) {
        guard isEnabled(#selector(newFolder(_:))), let folder = destinationFolder else { return }
        spawn { [weak self] in
            guard let self, let url = await self.operations.newFolder(in: folder) else { return }
            self.showResults([url])
            if let index = self.model.entries.firstIndex(where: { $0.url.standardizedFileURL.path == url.standardizedFileURL.path }) {
                self.beginRename(at: index)
            }
        }
    }

    @objc func renameSelection(_ sender: Any?) {
        guard isEnabled(#selector(renameSelection(_:))), let index = grid.selection.first else { return }
        beginRename(at: index)
    }

    @objc func moveToTrash(_ sender: Any?) {
        guard isEnabled(#selector(moveToTrash(_:))) else { return }
        let urls = selectedEntries.map(\.url), permanently = isInTrash
        spawn { [weak self] in
            if permanently { await self?.operations.deletePermanently(urls) } else { await self?.operations.trash(urls) }
            self?.model.reload()
        }
    }

    @objc func deletePermanently(_ sender: Any?) {
        guard isEnabled(#selector(deletePermanently(_:))) else { return }
        let urls = selectedEntries.map(\.url)
        spawn { [weak self] in
            await self?.operations.deletePermanently(urls)
            self?.model.reload()
        }
    }

    @objc func restoreFromTrash(_ sender: Any?) {
        guard isEnabled(#selector(restoreFromTrash(_:))) else { return }
        let urls = selectedEntries.map(\.url)
        spawn { [weak self] in
            _ = await self?.operations.restore(urls)
            self?.model.reload()
        }
    }

    @objc func emptyTrash(_ sender: Any?) {
        guard isEnabled(#selector(emptyTrash(_:))) else { return }
        let count = visibleTrashCount
        spawn { [weak self] in
            await self?.operations.emptyTrash(count: count)
            self?.model.reload()
        }
    }

    @objc func openTrashInFinder(_ sender: Any?) { NSWorkspace.shared.open(environment.trash) }

    @objc func cut(_ sender: Any?) {
        guard isEnabled(#selector(cut(_:))) else { return }
        operations.cut(selectedEntries.map(\.url))
    }

    @objc func copy(_ sender: Any?) {
        guard isEnabled(#selector(copy(_:))) else { return }
        operations.copy(selectedEntries.map(\.url))
    }

    @objc func paste(_ sender: Any?) {
        guard isEnabled(#selector(paste(_:))), let folder = destinationFolder else { return }
        paste(into: folder, forceMove: false)
    }

    @objc func moveItemHere(_ sender: Any?) {
        guard isEnabled(#selector(moveItemHere(_:))), let folder = destinationFolder else { return }
        paste(into: folder, forceMove: true)
    }

    private func paste(into folder: URL, forceMove: Bool) {
        let showsResults = folder.standardizedFileURL.path == destinationFolder?.standardizedFileURL.path
        spawn { [weak self] in
            guard let self else { return }
            let results = await self.operations.paste(into: folder, forceMove: forceMove)
            if showsResults { self.showResults(results) } else { self.model.reload() }
        }
    }

    // MARK: Rename in place

    /// The name without its extension is selected (Finder); folders and apps select the whole name.
    func beginRename(at index: Int) {
        guard !isEditingText || grid.editingIndex != nil, model.entries.indices.contains(index) else { return }
        let entry = model.entries[index]
        guard entry.isFileItem else { return }
        let isApp = entry.kind == .application
        let text = isApp ? (entry.url.lastPathComponent as NSString).deletingPathExtension : entry.url.lastPathComponent
        let selected = entry.kind == .folder || isApp ? text : (text as NSString).deletingPathExtension
        renamingURL = entry.url
        grid.beginEditing(at: index, text: text, selecting: NSRange(location: 0, length: (selected as NSString).length))
    }

    func endRename(_ text: String?) {
        let url = renamingURL
        renamingURL = nil
        guard let text, let url, let entry = model.entries.first(where: { $0.url == url }) else { return }
        spawn { [weak self] in
            guard let self, let renamed = await self.operations.rename(entry, to: text) else { return }
            self.showResults([renamed])
        }
    }

    // MARK: Context menu

    func showContextMenu(at index: Int?) {
        let menu = RetroMenu(items: contextMenuItems(at: index), style: .standard)
        contextMenu = menu
        menu.show(at: NSEvent.mouseLocation, opensUpward: false) {}
    }

    func contextMenuItems(at index: Int?) -> [RetroMenuItem] {
        let l = languages
        func command(_ title: String, _ action: Selector) -> RetroMenuItem {
            RetroMenuItem(title: title, kind: .action({ [weak self] in _ = self?.perform(action, with: nil) }), isEnabled: isEnabled(action))
        }
        let refresh = RetroMenuItem(title: ExplorerText.refresh(l), kind: .action({ [weak self] in self?.model.reload() }))
        guard let index, model.entries.indices.contains(index) else {
            if isInTrash {
                return [command(ExplorerText.emptyTrash(l), #selector(emptyTrash(_:))),
                        command(ExplorerText.openInFinder(l), #selector(openTrashInFinder(_:))), .separator, refresh]
            }
            return [command(ExplorerText.paste(l), #selector(paste(_:))), command(ExplorerText.moveItemHere(l), #selector(moveItemHere(_:))),
                    .separator, command(ExplorerText.newFolder(l), #selector(newFolder(_:))), .separator, refresh]
        }
        let entry = model.entries[index]
        let open = command(ExplorerText.open(l), #selector(openSelection(_:)))
        guard entry.isFileItem else {
            guard case .recycleBin = entry.kind else { return [open] }
            return [open, .separator, command(ExplorerText.emptyTrash(l), #selector(emptyTrash(_:)))]
        }
        var items = [open]
        if isInTrash { items.append(command(ExplorerText.restore(l), #selector(restoreFromTrash(_:)))) }
        items += [.separator, command(ExplorerText.cut(l), #selector(cut(_:))), command(ExplorerText.copy(l), #selector(copy(_:)))]
        if entry.kind == .folder {
            let folder = entry.url
            items.append(RetroMenuItem(title: ExplorerText.paste(l), kind: .action({ [weak self] in self?.paste(into: folder, forceMove: false) }),
                                       isEnabled: !isEditingText && operations.canPaste))
        }
        items += [.separator, command(ExplorerText.delete(l), #selector(moveToTrash(_:))),
                  command(ExplorerText.rename(l), #selector(renameSelection(_:))), .separator,
                  RetroMenuItem(title: ExplorerText.properties(l), kind: .action({}), isEnabled: false)]
        return items
    }
}
