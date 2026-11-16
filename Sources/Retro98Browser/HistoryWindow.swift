import AppKit
import Retro98UI

/// "History": a filter field, the visited pages (title, address, when) newest first, and Open, Delete, Close.
/// It takes the store's `onChange`, so the list follows every visit.
@MainActor
final class HistoryWindow: RetroIconGridDataSource {
    static let contentSize = CGSize(width: 560, height: 340)
    static let margin: CGFloat = 8

    let window: RetroWindow
    let grid: RetroIconGrid
    let filter: RetroTextField
    /// The entries listed now: all of them, or the ones the filter leaves.
    private(set) var shown: [HistoryEntry] = []
    /// Open, double-click or Enter on an entry.
    var onOpen: ((URL) -> Void)?
    private let history: HistoryStore
    private let languages: [String]
    private let dates = DateFormatter(), times = DateFormatter()

    init(history: HistoryStore, languages l: [String], locale: Locale = .current, timeZone: TimeZone = .current) {
        self.history = history
        languages = l
        for (formatter, isDate) in [(dates, true), (times, false)] {
            formatter.locale = locale
            formatter.timeZone = timeZone
            formatter.dateStyle = isDate ? .short : .none
            formatter.timeStyle = isDate ? .none : .short
        }
        window = RetroWindow(title: BrowserText.history(l), contentSize: Self.contentSize)
        window.level = .normal
        let margin = Self.margin, width = Self.contentSize.width, height = Self.contentSize.height
        let content = window.contentContainer
        let labelText = BrowserText.filterLabel(l)
        let labelWidth = CGFloat(PixelText.width(of: labelText, font: .regular))
        let label = RetroLabel(lines: [labelText])
        label.frame = CGRect(x: margin, y: margin + 4, width: labelWidth, height: CGFloat(PixelText.lineHeight))
        filter = RetroTextField(frame: CGRect(x: margin + labelWidth + 8, y: margin, width: width - margin * 2 - labelWidth - 8,
                                              height: RetroTextField.height))
        let listTop = margin + RetroTextField.height + 6
        let listHeight = height - listTop - margin - RetroButton.height - 8
        let pane = BrowserListPane(frame: CGRect(x: margin, y: listTop, width: width - margin * 2, height: listHeight),
                                   columns: [GridColumn(title: BrowserText.titleColumn(l), width: 0),
                                             GridColumn(title: BrowserText.address(l), width: 200),
                                             GridColumn(title: BrowserText.visitedColumn(l), width: 120)])
        grid = pane.grid
        for view in [label, filter, pane] as [NSView] { content.addSubview(view) }

        let actions: [(String, () -> Void)] = [
            (BrowserText.open(l), { [weak self] in self?.open() }),
            (BrowserText.delete(l), { [weak self] in self?.remove() }),
            (BrowserText.close(l), { [weak self] in self?.window.orderOut(nil) }),
        ]
        var x = width - margin
        for action in actions.reversed() {
            let button = RetroButton(title: action.0, action: action.1)
            x -= button.frame.width
            button.frame.origin = CGPoint(x: x, y: height - margin - RetroButton.height)
            x -= 6
            content.addSubview(button)
        }
        window.onCancel = { [weak self] in self?.window.orderOut(nil) }

        grid.dataSource = self
        grid.onOpen = { [weak self] index in self?.open(at: index) }
        grid.onKey = { [weak self] event in
            guard FavoritesWindow.deleteKeys.contains(event.keyCode) else { return false }
            self?.remove()
            return true
        }
        filter.onChange = { [weak self] in self?.reload() }
        history.onChange = { [weak self] in self?.reload() }
        reload()
    }

    func show() {
        if !window.isVisible { window.showCentered() }
        window.makeKeyAndOrderFront(nil)
        filter.focus(in: window)
    }

    private func reload() {
        shown = history.search(filter.text)
        grid.reloadData()
        grid.setSelection(grid.selection.filteredIndexSet { $0 < shown.count })
    }

    private var selected: Int? {
        guard let index = grid.selection.first, shown.indices.contains(index) else { return nil }
        return index
    }

    func open() {
        if let selected { open(at: selected) }
    }

    private func open(at index: Int) {
        guard shown.indices.contains(index) else { return }
        onOpen?(shown[index].url)
    }

    func remove() {
        guard let selected else { return }
        history.remove(shown[selected].url)
        grid.setSelection(shown.isEmpty ? [] : [min(selected, shown.count - 1)])
    }

    // MARK: Rows

    func numberOfItems(in grid: RetroIconGrid) -> Int { shown.count }

    func grid(_ grid: RetroIconGrid, titleAt index: Int) -> String {
        BrowserText.tabTitle(pageTitle: shown[index].title, url: shown[index].url, languages)
    }

    func grid(_ grid: RetroIconGrid, iconAt index: Int) -> PixelIcon { BrowserIcons.page }
    func grid(_ grid: RetroIconGrid, smallIconAt index: Int) -> PixelIcon { BrowserIcons.page }

    func grid(_ grid: RetroIconGrid, detailsAt index: Int) -> [String] {
        let entry = shown[index]
        return [BrowserText.oneLine(entry.url.absoluteString), "\(dates.string(from: entry.lastVisited)) \(times.string(from: entry.lastVisited))"]
    }
}
