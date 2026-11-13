import AppKit
import Retro98FilesCore
import Retro98UI

/// A 98-style open or save dialog: "Look in" with the places, an up button, the folder's files as a list,
/// the file name and the file type. `RetroFileDialog.run` shows it modally; tests drive it directly.
@MainActor
public final class FileDialogController: RetroIconGridDataSource {
    public static let contentSize = CGSize(width: 430, height: 266)
    static let margin: CGFloat = 8
    static let fieldX: CGFloat = 100
    static let fieldWidth: CGFloat = 230
    static let buttonWidth: CGFloat = 75

    public let window: RetroWindow
    public let title: String
    public private(set) var folder: URL
    public private(set) var entries: [FileEntry] = []
    public private(set) var filterIndex = 0
    /// The chosen file once the dialog finished with Open/Save; nil after Cancel.
    public private(set) var result: URL?
    public var onFinish: (() -> Void)?

    let nameField = RetroTextField(frame: CGRect(x: fieldX, y: 198, width: fieldWidth, height: RetroTextField.height))
    let grid = RetroIconGrid()
    let lookIn = RetroDropDown(items: { [] })
    let typeBox = RetroDropDown(items: { [] })
    let upButton: RetroButton
    let okButton: RetroButton
    private let mode: FileDialogMode
    private let filters: [FileTypeFilter]
    private let languages: [String]
    private let home: URL
    private let volumes: () -> [VolumeInfo]
    private let prompter: FileDialogPrompter
    private let actions = Actions()

    /// Lets the buttons, created before `self` is complete, call back into the controller.
    private final class Actions {
        var up: () -> Void = {}
        var confirm: () -> Void = {}
        var cancel: () -> Void = {}
    }

    /// Shows `folder`, or silently `home` when `folder` can't be listed.
    public init(mode: FileDialogMode, folder: URL, fileName: String, filters: [FileTypeFilter], languages: [String],
                home: URL = FileManager.default.homeDirectoryForCurrentUser,
                volumes: @escaping () -> [VolumeInfo] = { Volumes.mounted() },
                prompter: FileDialogPrompter = RetroFileDialogPrompter()) {
        self.mode = mode
        self.filters = filters
        self.languages = languages
        self.home = home.standardizedFileURL
        self.volumes = volumes
        self.prompter = prompter
        self.folder = home.standardizedFileURL
        title = FileDialogText.title(mode, languages)
        window = RetroWindow(title: title, contentSize: Self.contentSize)
        let actions = actions
        upButton = RetroButton(title: "", icon: FileIcons.up) { actions.up() }
        okButton = RetroButton(title: FileDialogText.confirm(mode, languages), isDefault: true) { actions.confirm() }
        actions.up = { [weak self] in self?.goUp() }
        actions.confirm = { [weak self] in self?.submit() }
        actions.cancel = { [weak self] in self?.cancel() }
        build()
        nameField.text = fileName
        if !list(folder) { _ = list(self.home) }
        refresh()
    }

    // MARK: Building

    private func build() {
        let content = window.contentContainer
        let width = Self.contentSize.width, margin = Self.margin
        let buttonX = width - margin - Self.buttonWidth

        content.addSubview(label(FileDialogText.lookIn(mode, languages), y: 11))
        lookIn.frame = CGRect(x: 72, y: 8, width: 260, height: RetroDropDown.height)
        lookIn.items = { [weak self] in self?.placeItems() ?? [] }
        content.addSubview(lookIn)
        upButton.frame = CGRect(x: 338, y: 8, width: 24, height: 22)
        content.addSubview(upButton)

        grid.dataSource = self
        grid.style = .list
        grid.onOpen = { [weak self] index in self?.activate(itemAt: index) }
        grid.onRename = { [weak self] index in self?.activate(itemAt: index) }
        grid.onSelectionChange = { [weak self] selection in self?.selectionChanged(selection) }
        let scroll = RetroScroller.makeScrollView(document: grid)
        scroll.frame = CGRect(x: margin, y: 38, width: width - margin * 2, height: 150)
        content.addSubview(FieldFrame(wrapping: scroll))

        content.addSubview(label(FileDialogText.fileName(languages), y: 201))
        nameField.onSubmit = { [weak self] in self?.submit() }
        content.addSubview(nameField)
        okButton.frame = CGRect(x: buttonX, y: 198, width: Self.buttonWidth, height: RetroButton.height)
        content.addSubview(okButton)

        content.addSubview(label(FileDialogText.filesOfType(mode, languages), y: 231))
        typeBox.frame = CGRect(x: Self.fieldX, y: 228, width: Self.fieldWidth, height: RetroDropDown.height)
        typeBox.items = { [weak self] in self?.filterItems() ?? [] }
        typeBox.set(text: filters[filterIndex].title, icon: nil)
        content.addSubview(typeBox)
        let actions = actions
        let cancelButton = RetroButton(title: FileDialogText.cancel(languages)) { actions.cancel() }
        cancelButton.frame = CGRect(x: buttonX, y: 227, width: Self.buttonWidth, height: RetroButton.height)
        content.addSubview(cancelButton)

        window.defaultButton = okButton
        window.onCancel = { [weak self] in self?.cancel() }
    }

    private func label(_ text: String, y: CGFloat) -> RetroLabel {
        let label = RetroLabel(lines: [text])
        label.frame = CGRect(x: Self.margin, y: y, width: CGFloat(PixelText.width(of: text, font: .regular)),
                             height: CGFloat(PixelText.lineHeight))
        return label
    }

    // MARK: Moving around

    /// Lists `folder`; false (with a message, staying where it was) when macOS refuses it or it's gone.
    @discardableResult
    public func show(_ folder: URL) -> Bool {
        guard list(folder) else {
            prompter.tell(FileDialogText.cannotOpenFolder(FileManager.default.displayName(atPath: folder.path), languages),
                          title: title, icon: .warning, languages: languages)
            return false
        }
        refresh()
        return true
    }

    private func list(_ folder: URL) -> Bool {
        let target = folder.standardizedFileURL
        guard let listed = try? FileDialogLogic.entries(of: target, filter: filters[filterIndex]) else { return false }
        self.folder = target
        entries = listed
        return true
    }

    private func refresh() {
        grid.reloadData()
        grid.setSelection([])
        grid.scroll(.zero)
        let place = places().first { $0.url.standardizedFileURL.path == folder.path }
        lookIn.set(text: place?.name ?? FileManager.default.displayName(atPath: folder.path), icon: icon(for: place?.kind ?? .folder))
        upButton.isEnabled = folder.path != "/"
    }

    public func goUp() {
        guard folder.path != "/" else { return }
        show(folder.deletingLastPathComponent())
    }

    public func chooseFilter(at index: Int) {
        guard filters.indices.contains(index) else { return }
        filterIndex = index
        typeBox.set(text: filters[index].title, icon: nil)
        show(folder)
    }

    /// Double-click or Enter on an item: a folder opens (what was typed stays), a file is chosen.
    public func activate(itemAt index: Int) {
        guard entries.indices.contains(index) else { return }
        let entry = entries[index]
        if entry.kind == .folder {
            show(entry.url)
        } else {
            nameField.text = entry.url.lastPathComponent
            submit()
        }
    }

    // MARK: Finishing

    /// The Open/Save button, and Enter in the name field.
    public func submit() {
        let outcome = FileDialogLogic.resolve(nameField.text, in: folder, mode: mode, filter: filters[filterIndex], home: home)
        switch outcome {
        case .nothing:
            break
        case .navigate(let url):
            if show(url) { nameField.text = "" }
        case .choose(let url):
            finish(url)
        case .confirmReplace(let url):
            if prompter.confirmReplace(FileDialogText.replace(url.lastPathComponent, languages), title: title, languages: languages) {
                finish(url)
            }
        case .notFound(let name):
            warn(FileDialogText.notFound(name, languages))
        case .invalidName(let name):
            warn(FileDialogText.invalidName(name, languages))
        case .folderNotFound(let path):
            warn(FileDialogText.folderNotFound(path, languages))
        }
    }

    public func cancel() {
        result = nil
        onFinish?()
    }

    private func finish(_ url: URL) {
        result = url
        onFinish?()
    }

    private func warn(_ message: String) {
        prompter.tell(message, title: title, icon: .warning, languages: languages)
    }

    /// One click on a file puts its name in the field; folders and empty selections leave it alone.
    func selectionChanged(_ selection: IndexSet) {
        guard selection.count == 1, let index = selection.first, entries.indices.contains(index),
              entries[index].kind != .folder else { return }
        nameField.text = entries[index].url.lastPathComponent
    }

    // MARK: Drop-downs

    private func places() -> [FileDialogPlace] {
        FileDialogLogic.places(current: folder, home: home, volumes: volumes(), languages: languages)
    }

    func placeItems() -> [RetroMenuItem] {
        places().map { place in
            RetroMenuItem(title: String(repeating: "  ", count: place.depth) + place.name, icon: icon(for: place.kind),
                          kind: .action({ [weak self] in _ = self?.show(place.url) }))
        }
    }

    private func filterItems() -> [RetroMenuItem] {
        filters.enumerated().map { index, filter in
            RetroMenuItem(title: filter.title, kind: .action({ [weak self] in self?.chooseFilter(at: index) }),
                          mark: index == filterIndex ? .bullet : .none)
        }
    }

    private func icon(for kind: FileDialogPlace.Kind) -> PixelIcon {
        switch kind {
        case .desktop: FileIcons.icon(.desktop, size: 16)
        case .documents: FileIcons.icon(.myDocuments, size: 16)
        case .volume(let volume): FileIcons.icon(FileKind.volume(volume).iconKind, size: 16)
        case .folder: FileIcons.icon(.folder, size: 16)
        }
    }

    // MARK: Grid

    public func numberOfItems(in grid: RetroIconGrid) -> Int { entries.count }
    public func grid(_ grid: RetroIconGrid, titleAt index: Int) -> String { entries[index].name }
    public func grid(_ grid: RetroIconGrid, iconAt index: Int) -> PixelIcon { FileIcons.icon(entries[index].kind.iconKind, size: 32) }
    public func grid(_ grid: RetroIconGrid, smallIconAt index: Int) -> PixelIcon {
        FileIcons.icon(entries[index].kind.iconKind, size: 16)
    }
}
