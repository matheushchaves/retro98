import AppKit
import Retro98FilesCore
import Retro98UI

/// The Properties window: icon and name, type, location, size and contents (folders measured in the
/// background), and dates; disks show used and free space with a bar. Several can be open at once.
@MainActor
final class PropertiesWindow {
    enum Row: Equatable {
        case row(label: String, value: String)
        case separator
        case note(String)
    }

    static let width: CGFloat = 320
    static let rowHeight: CGFloat = 18
    static let separatorHeight: CGFloat = 10
    static let margin: CGFloat = 12
    static let valueX: CGFloat = 100
    static let headerHeight: CGFloat = 44
    static let barHeight: CGFloat = 26

    let window: RetroWindow
    let title: String
    /// Used share of a disk, shown as a bar.
    let usage: Double?
    private(set) var measuring: Task<Void, Never>?
    var onClose: (() -> Void)?
    private(set) var rows: [Row]
    private var properties: ItemProperties
    private let control = OperationControl()
    private let view: PropertiesView
    private let languages: [String]
    private let locale: Locale
    /// Open windows keep themselves alive until closed: the Explorer window that opened one may close first.
    private var keepAlive: PropertiesWindow?

    init(entries: [FileEntry], icon: PixelIcon, volume: VolumeInfo?, languages: [String], locale: Locale) {
        self.languages = languages
        self.locale = locale
        properties = PropertiesReader.summary(of: entries, languages: languages)
        title = properties.title
        var usage: Double?
        if let volume {
            let space = PropertiesText.volume(volume, locale: locale, languages: languages)
            usage = space.fraction
            rows = [.row(label: ExplorerText.labelType(languages), value: properties.typeName), .separator,
                    .row(label: ExplorerText.labelUsedSpace(languages), value: space.used),
                    .row(label: ExplorerText.labelFreeSpace(languages), value: space.free),
                    .row(label: ExplorerText.labelCapacity(languages), value: space.capacity)]
        } else {
            rows = Self.itemRows(properties, measured: properties.needsMeasuring.isEmpty && properties.packages.isEmpty, languages: languages,
                                 locale: locale)
        }
        self.usage = usage
        view = PropertiesView(icon: icon, name: properties.name)
        window = RetroWindow(title: properties.title, contentSize: Self.contentSize(rows: rows, hasBar: usage != nil))
        window.level = .normal
        layout()
        window.onCancel = { [weak self] in self?.close() }
        keepAlive = self
        measureFolders()
    }

    deinit { control.cancel() }

    /// The value next to `label` ("Tamanho:"), or nil when there is no such row.
    func text(of label: String) -> String? {
        for case .row(let rowLabel, let value) in rows where rowLabel == label { return value }
        return nil
    }

    /// Centered in front; the person asked for it, so it takes the keyboard.
    func show() {
        if let screen = NSScreen.main {
            let visible = screen.visibleFrame
            window.setFrameOrigin(CGPoint(x: (visible.midX - window.frame.width / 2).rounded(),
                                          y: (visible.midY - window.frame.height / 2).rounded()))
        }
        window.makeKeyAndOrderFront(nil)
    }

    /// Closing stops the measuring.
    func close() {
        control.cancel()
        measuring?.cancel()
        window.orderOut(nil)
        onClose?()
        onClose = nil
        keepAlive = nil
    }

    // MARK: Rows

    private static func itemRows(_ properties: ItemProperties, measured: Bool, languages l: [String], locale: Locale) -> [Row] {
        let calculating = ExplorerText.calculating(l)
        var rows: [Row] = [.row(label: ExplorerText.labelType(l), value: properties.typeName)]
        if let location = properties.location { rows.append(.row(label: ExplorerText.labelLocation(l), value: location)) }
        rows.append(.row(label: ExplorerText.labelSize(l),
                         value: measured ? PropertiesText.size(properties.tally.bytes, locale: locale, languages: l) : calculating))
        let isPackageAlone = properties.needsMeasuring.isEmpty && properties.packages.count == 1 && properties.tally.files == 1
        if !isPackageAlone, !properties.needsMeasuring.isEmpty || properties.title != ExplorerText.propertiesTitle(properties.name, l) {
            rows.append(.row(label: ExplorerText.labelContains(l),
                             value: measured ? PropertiesText.contains(files: properties.tally.files, folders: properties.tally.folders,
                                                                      languages: l) : calculating))
        }
        let dates = [(ExplorerText.labelCreated(l), properties.created), (ExplorerText.labelModified(l), properties.modified),
                     (ExplorerText.labelAccessed(l), properties.accessed)].compactMap { label, date in
            date.map { Row.row(label: label, value: ExplorerWindowController.modifiedFormatter.string(from: $0)) }
        }
        if !dates.isEmpty { rows += [.separator] + dates }
        if measured && properties.tally.skippedUnreadable { rows.append(.note(ExplorerText.someFoldersUnreadable(l))) }
        return rows
    }

    /// Folders add their contents; apps and other packages add only their size (they stay one item).
    private func measureFolders() {
        guard usage == nil, !properties.needsMeasuring.isEmpty || !properties.packages.isEmpty else { return }
        let folders = properties.needsMeasuring, packages = properties.packages, control = control, base = properties.tally
        measuring = Task { [weak self] in
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                    var total = base
                    for folder in folders where !control.isCancelled {
                        let before = total
                        total.add(PropertiesReader.measure(folder, control: control) { [weak self] partial in
                            var shown = before
                            shown.add(partial)
                            DispatchQueue.main.async { [weak self] in MainActor.assumeIsolated { self?.update(shown, finished: false) } }
                        })
                    }
                    for package in packages where !control.isCancelled {
                        let inside = PropertiesReader.measure(package, control: control, onProgress: { _ in })
                        total.bytes += inside.bytes
                        total.skippedUnreadable = total.skippedUnreadable || inside.skippedUnreadable
                    }
                    let final = total
                    DispatchQueue.main.async { [weak self] in
                        MainActor.assumeIsolated { self?.update(final, finished: true) }
                        continuation.resume()
                    }
                }
            }
        }
    }

    private func update(_ tally: FolderTally, finished: Bool) {
        guard !control.isCancelled else { return }
        properties.tally = tally
        rows = Self.itemRows(properties, measured: true, languages: languages, locale: locale)
        if !finished, let index = rows.firstIndex(where: { if case .note = $0 { true } else { false } }) { rows.remove(at: index) }
        layout()
    }

    // MARK: Layout

    static func contentSize(rows: [Row], hasBar: Bool) -> CGSize {
        let separators = CGFloat(rows.filter { $0 == .separator }.count), lines = CGFloat(rows.count) - separators
        let height = margin + headerHeight + lines * rowHeight + separators * separatorHeight + (hasBar ? barHeight : 0)
            + margin + RetroButton.height + margin
        return CGSize(width: width, height: height)
    }

    private func layout() {
        let size = Self.contentSize(rows: rows, hasBar: usage != nil), height = size.height
        if size != window.contentContainer.bounds.size { window.resizeContent(to: size) }
        let content = window.contentContainer
        content.subviews.forEach { $0.removeFromSuperview() }
        view.rows = rows
        view.usage = usage
        view.frame = CGRect(x: 0, y: 0, width: Self.width, height: height - Self.margin - RetroButton.height - Self.margin)
        content.addSubview(view)
        let ok = RetroButton(title: ExplorerText.ok(languages), isDefault: true) { [weak self] in self?.close() }
        ok.frame.origin = CGPoint(x: Self.width - Self.margin - ok.frame.width, y: height - Self.margin - RetroButton.height)
        content.addSubview(ok)
        window.defaultButton = ok
    }
}

extension RetroWindow {
    /// Resizes the content area, keeping the window's top edge where it is.
    func resizeContent(to size: CGSize) {
        let extra = CGSize(width: frame.width - contentContainer.frame.width, height: frame.height - contentContainer.frame.height)
        let newFrame = CGRect(x: frame.minX, y: frame.maxY - size.height - extra.height,
                              width: size.width + extra.width, height: size.height + extra.height)
        setFrame(newFrame, display: true)
        contentContainer.setFrameSize(size)
    }
}

/// Draws the header (icon and name), the rows and, for disks, the used-space bar.
@MainActor
private final class PropertiesView: PixelView {
    let icon: PixelIcon
    let name: String
    var rows: [PropertiesWindow.Row] = [] { didSet { needsDisplay = true } }
    var usage: Double?

    init(icon: PixelIcon, name: String) {
        self.icon = icon
        self.name = name
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func drawPixels(in context: CGContext, size: CGSize) {
        let margin = PropertiesWindow.margin, valueX = PropertiesWindow.valueX
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        icon.draw(at: CGPoint(x: margin, y: margin), context: context)
        PixelText.draw(RetroText.fit(name, maxWidth: Int(size.width - valueX - margin)), font: .regular, color: .black,
                       at: CGPoint(x: valueX, y: margin + 10), context: context)
        var y = margin + PropertiesWindow.headerHeight
        drawSeparator(at: y - PropertiesWindow.separatorHeight / 2, width: size.width, context: context)
        for row in rows {
            switch row {
            case .separator:
                drawSeparator(at: y + PropertiesWindow.separatorHeight / 2, width: size.width, context: context)
                y += PropertiesWindow.separatorHeight
            case .row(let label, let value):
                PixelText.draw(label, font: .regular, color: .black, at: CGPoint(x: margin, y: y + 2), context: context)
                PixelText.draw(RetroText.fit(value, maxWidth: Int(size.width - valueX - margin)), font: .regular, color: .black,
                               at: CGPoint(x: valueX, y: y + 2), context: context)
                y += PropertiesWindow.rowHeight
            case .note(let text):
                PixelText.draw(RetroText.fit(text, maxWidth: Int(size.width - margin * 2)), font: .regular, color: Palette.shadow,
                               at: CGPoint(x: margin, y: y + 2), context: context)
                y += PropertiesWindow.rowHeight
            }
        }
        if let usage {
            let bar = CGRect(x: margin, y: y + 6, width: size.width - margin * 2, height: 16)
            Bevel.fill(bar, color: .white, context: context)
            Bevel.draw(.statusField, in: bar, context: context)
            Bevel.fill(CGRect(x: bar.minX + 2, y: bar.minY + 2, width: ((bar.width - 4) * usage).rounded(.down), height: bar.height - 4),
                       color: Palette.selection, context: context)
        }
    }

    private func drawSeparator(at y: CGFloat, width: CGFloat, context: CGContext) {
        let margin = PropertiesWindow.margin
        Bevel.fill(CGRect(x: margin, y: y.rounded(.down), width: width - margin * 2, height: 1), color: Palette.shadow, context: context)
        Bevel.fill(CGRect(x: margin, y: y.rounded(.down) + 1, width: width - margin * 2, height: 1), color: Palette.light, context: context)
    }
}

extension ExplorerWindowController {
    /// Properties of the selection: My Documents and the Recycle Bin are their folders; a disk shows its space.
    @objc func showProperties(_ sender: Any?) {
        guard isEnabled(#selector(showProperties(_:))) else { return }
        let selected = selectedEntries
        let volume = selected.count == 1 ? selected.first.flatMap(volumeInfo(for:)) : nil
        let entries = selected.map { entry -> FileEntry in
            switch entry.kind {
            case .myDocuments: FileEntry(url: entry.url, name: entry.name, kind: .folder, size: nil, modified: nil, location: entry.location)
            case .recycleBin: FileEntry(url: environment.trash, name: entry.name, kind: .folder, size: nil, modified: nil, location: .trash)
            default: entry
            }
        }
        guard let first = selected.first else { return }
        let properties = PropertiesWindow(entries: entries, icon: grid(grid, iconAt: model.entries.firstIndex(of: first) ?? 0),
                                          volume: volume, languages: languages, locale: .current)
        properties.onClose = { [weak self, weak properties] in self?.propertiesWindows.removeAll { $0 === properties } }
        propertiesWindows.append(properties)
        properties.show()
    }

    /// Removable disks, and network shares (which macOS doesn't flag as ejectable but unmounts all the same).
    func canEject(_ entry: FileEntry) -> Bool {
        guard let volume = volumeInfo(for: entry) else { return false }
        return volume.isEjectable || volume.kind == .network
    }

    func volumeInfo(for entry: FileEntry) -> VolumeInfo? {
        guard case .volume = entry.kind else { return nil }
        return model.volumes.first { $0.url.standardizedFileURL.path == entry.url.standardizedFileURL.path }
    }
}
