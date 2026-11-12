import AppKit
import Retro98FilesCore
import Retro98UI

/// The "Search for" bar under the address: a field, "Include subfolders" and Stop. Typing searches as
/// you go; Esc closes the bar.
@MainActor
final class SearchBar: PixelView, NSTextFieldDelegate {
    static let height: CGFloat = 27

    let field = NSTextField()
    let includeSubfolders: RetroCheckBox
    private(set) lazy var stopButton = RetroButton(title: ExplorerText.stop(languages)) { [weak self] in self?.onStop?() }
    var onChange: ((String, Bool) -> Void)?
    var onStop: (() -> Void)?
    var onClose: (() -> Void)?
    private let languages: [String]
    private let label: String

    init(languages: [String]) {
        self.languages = languages
        label = ExplorerText.searchFor(languages)
        var changed: ((Bool) -> Void)?
        includeSubfolders = RetroCheckBox(title: ExplorerText.includeSubfolders(languages), isOn: false) { changed?($0) }
        super.init(frame: .zero)
        changed = { [weak self] _ in self?.reportChange() }
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = true
        field.backgroundColor = .white
        field.focusRingType = .none
        field.font = NSFont(name: "Tahoma", size: PixelFont.regular.size)
        field.delegate = self
        addSubview(field)
        addSubview(includeSubfolders)
        addSubview(stopButton)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var labelWidth: CGFloat { CGFloat(PixelText.width(of: label, font: .regular)) + 16 }

    private var fieldFrame: CGRect {
        let right = bounds.width - stopButton.frame.width - includeSubfolders.frame.width - 24
        return CGRect(x: labelWidth, y: 2, width: max(right - labelWidth, 60), height: bounds.height - 4)
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        let frame = fieldFrame
        field.frame = frame.insetBy(dx: 3, dy: 3)
        includeSubfolders.setFrameOrigin(CGPoint(x: frame.maxX + 8, y: ((newSize.height - includeSubfolders.frame.height) / 2).rounded(.down)))
        stopButton.frame.size.height = newSize.height - 4
        stopButton.setFrameOrigin(CGPoint(x: newSize.width - stopButton.frame.width - 4, y: 2))
    }

    func reportChange() { onChange?(field.stringValue, includeSubfolders.isOn) }

    func controlTextDidChange(_ notification: Notification) { reportChange() }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
        switch commandSelector {
        case #selector(NSResponder.cancelOperation(_:)):
            onClose?()
            return true
        case #selector(NSResponder.insertNewline(_:)):
            reportChange()
            return true
        default:
            return false
        }
    }

    override func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        PixelText.draw(label, font: .regular, color: .black,
                       at: CGPoint(x: 8, y: ((size.height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down)), context: context)
        Bevel.draw(.field, in: fieldFrame, context: context)
    }
}

/// Searching from an Explorer window: without subfolders it filters the folder as you type; with them
/// it walks the folder in the background (300 ms after typing stops) and the matches arrive in batches.
extension ExplorerWindowController {
    static let searchDelay: Duration = .milliseconds(300)
    static let escapeKey: UInt16 = 53

    /// The folder shown (the Desktop folder for the Desktop), the home folder for My Computer; none in the Recycle Bin.
    var searchRoot: URL? {
        destinationFolder ?? (model.history.current == .myComputer ? environment.home : nil)
    }

    @objc func showSearch(_ sender: Any?) {
        guard isEnabled(#selector(showSearch(_:))) else { return }
        openSearchBar(includeSubfolders: searchBar.includeSubfolders.isOn)
    }

    func openSearchBar(includeSubfolders: Bool) {
        searchBar.includeSubfolders.isOn = includeSubfolders
        layoutSearchBar(visible: true)
        window.makeFirstResponder(searchBar.field)
    }

    func search(text: String, includeSubfolders: Bool) {
        guard let root = searchRoot else { return }
        cancelSearchWork()
        searchGeneration += 1
        let generation = searchGeneration
        // Nothing typed: show the folder rather than everything below it.
        let query = SearchQuery(text: text, root: root, includeSubfolders: includeSubfolders && !text.isEmpty, showHidden: model.showHidden)
        model.beginSearch(query)
        guard query.includeSubfolders else { return }
        let control = OperationControl()
        searchControl = control
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: Self.searchDelay)
            guard !Task.isCancelled else { return }
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    let end = FileSearch.run(query, control: control) { [weak self] batch in
                        DispatchQueue.main.async { [weak self] in
                            MainActor.assumeIsolated { self?.addSearchResults(batch, generation: generation) }
                        }
                    }
                    // Queued after the last batch, so the end comes after every match.
                    DispatchQueue.main.async { [weak self] in
                        MainActor.assumeIsolated { self?.finishSearch(end, generation: generation) }
                        continuation.resume()
                    }
                }
            }
        }
    }

    func stopSearch() {
        guard model.search != nil, model.searchEnd == nil else { return }
        cancelSearchWork()
        model.finishSearch(.cancelled)
    }

    /// Esc, the close of the window, or going somewhere else.
    func closeSearch() {
        cancelSearchWork()
        layoutSearchBar(visible: false)
        if model.search != nil { model.endSearch() }
        window.makeFirstResponder(grid)
    }

    func cancelSearchWork() {
        searchControl?.cancel()
        searchControl = nil
        searchTask?.cancel()
        searchGeneration += 1
    }

    var isSearchBarVisible: Bool { !searchBar.isHidden }

    func layoutSearchBar(visible: Bool) {
        searchBar.isHidden = !visible
        let width = window.contentContainer.bounds.width, height = window.contentContainer.bounds.height
        let top = Self.panesTop + (visible ? SearchBar.height : 0)
        searchBar.frame = CGRect(x: 0, y: Self.panesTop, width: width, height: SearchBar.height)
        splitView.frame = CGRect(x: 0, y: top, width: width, height: max(height - top - Self.statusHeight, 0))
    }

    func wireSearchBar() {
        searchBar.isHidden = true
        searchBar.autoresizingMask = [.width]
        searchBar.onChange = { [weak self] text, subfolders in self?.search(text: text, includeSubfolders: subfolders) }
        searchBar.onStop = { [weak self] in self?.stopSearch() }
        searchBar.onClose = { [weak self] in self?.closeSearch() }
    }

    private func addSearchResults(_ batch: [FileEntry], generation: Int) {
        guard generation == searchGeneration else { return }
        model.addResults(batch)
    }

    private func finishSearch(_ end: SearchEnd, generation: Int) {
        guard generation == searchGeneration else { return }
        model.finishSearch(end)
    }

    /// "Procurando..." while it runs, then the count (or the limit warning).
    var searchStatus: String? {
        guard model.search != nil else { return nil }
        switch model.searchEnd {
        case nil: return ExplorerText.searching(languages)
        case .limitReached: return ExplorerText.tooManyResults(languages)
        case .finished, .cancelled: return ExplorerText.found(model.entries.count, languages)
        }
    }
}
