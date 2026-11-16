import AppKit
import Retro98UI

/// "Organize Favorites": the list (name and address) and the buttons that open, rename, delete and reorder.
/// It takes the store's `onChange`, so the list follows every change.
@MainActor
final class FavoritesWindow: RetroIconGridDataSource {
    static let contentSize = CGSize(width: 480, height: 320)
    static let margin: CGFloat = 8, buttonWidth: CGFloat = 96
    static let deleteKeys: Set<UInt16> = [51, 117]

    let window: RetroWindow
    let grid: RetroIconGrid
    /// Open, double-click or Enter on a favorite.
    var onOpen: ((URL) -> Void)?
    private let favorites: FavoritesStore
    private let languages: [String]

    init(favorites: FavoritesStore, languages l: [String]) {
        self.favorites = favorites
        languages = l
        window = RetroWindow(title: BrowserText.organizeTitle(l), contentSize: Self.contentSize)
        window.level = .normal
        let margin = Self.margin
        let listWidth = Self.contentSize.width - margin * 3 - Self.buttonWidth
        let pane = BrowserListPane(frame: CGRect(x: margin, y: margin, width: listWidth, height: Self.contentSize.height - margin * 2),
                                   columns: [GridColumn(title: BrowserText.nameColumn(l), width: 0),
                                             GridColumn(title: BrowserText.address(l), width: 170)])
        grid = pane.grid
        window.contentContainer.addSubview(pane)

        let actions: [(String, () -> Void)] = [
            (BrowserText.open(l), { [weak self] in self?.open() }),
            (BrowserText.rename(l), { [weak self] in self?.beginRename() }),
            (BrowserText.delete(l), { [weak self] in self?.remove() }),
            (BrowserText.moveUp(l), { [weak self] in self?.moveUp() }),
            (BrowserText.moveDown(l), { [weak self] in self?.moveDown() }),
            (BrowserText.close(l), { [weak self] in self?.window.orderOut(nil) }),
        ]
        for (index, action) in actions.enumerated() {
            let button = RetroButton(title: action.0, action: action.1)
            button.frame = CGRect(x: Self.contentSize.width - margin - Self.buttonWidth, y: margin + CGFloat(index) * (RetroButton.height + 6),
                                  width: Self.buttonWidth, height: RetroButton.height)
            window.contentContainer.addSubview(button)
        }
        window.onCancel = { [weak self] in self?.window.orderOut(nil) }

        grid.dataSource = self
        grid.onOpen = { [weak self] index in self?.open(at: index) }
        grid.onRename = { [weak self] _ in self?.beginRename() }
        grid.onEndEditing = { [weak self] index, text in
            if let text { self?.favorites.rename(at: index, to: text) }
        }
        grid.onKey = { [weak self] event in
            guard Self.deleteKeys.contains(event.keyCode) else { return false }
            self?.remove()
            return true
        }
        favorites.onChange = { [weak self] in self?.grid.reloadData() }
        grid.reloadData()
    }

    func show() {
        if !window.isVisible { window.showCentered() }
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(grid)
    }

    private var selected: Int? {
        guard let index = grid.selection.first, favorites.items.indices.contains(index) else { return nil }
        return index
    }

    // MARK: Commands (on the selected favorite)

    func open() {
        if let selected { open(at: selected) }
    }

    private func open(at index: Int) {
        guard favorites.items.indices.contains(index) else { return }
        onOpen?(favorites.items[index].url)
    }

    func beginRename() {
        guard let selected else { return }
        let title = favorites.items[selected].title
        grid.beginEditing(at: selected, text: title, selecting: NSRange(location: 0, length: (title as NSString).length))
    }

    /// The row that takes the deleted one's place stays selected, so Delete can be pressed again.
    func remove() {
        guard let selected else { return }
        favorites.remove(at: selected)
        let count = favorites.items.count
        grid.setSelection(count == 0 ? [] : [min(selected, count - 1)])
    }

    func moveUp() { move(by: -1) }
    func moveDown() { move(by: 1) }

    private func move(by offset: Int) {
        guard let selected, favorites.items.indices.contains(selected + offset) else { return }
        favorites.move(from: selected, to: selected + offset)
        grid.setSelection([selected + offset])
    }

    // MARK: Rows

    func numberOfItems(in grid: RetroIconGrid) -> Int { favorites.items.count }
    func grid(_ grid: RetroIconGrid, titleAt index: Int) -> String { BrowserText.oneLine(favorites.items[index].title) }
    func grid(_ grid: RetroIconGrid, iconAt index: Int) -> PixelIcon { BrowserIcons.page }
    func grid(_ grid: RetroIconGrid, smallIconAt index: Int) -> PixelIcon { BrowserIcons.page }
    func grid(_ grid: RetroIconGrid, detailsAt index: Int) -> [String] { [BrowserText.oneLine(favorites.items[index].url.absoluteString)] }
}
