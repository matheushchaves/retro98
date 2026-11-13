import AppKit
import Retro98UI

/// One Notepad window and its document: the retro menu bar, then the text in a sunken frame with retro scroll
/// bars. Saving writes the file the way it was found (line endings, byte-order mark); closing with changes asks first.
@MainActor
final class NotepadWindowController: NSObject, NSWindowDelegate, NSTextViewDelegate {
    static let shellBundleID = "io.github.matheushchaves.retro98.shell"
    static let menuHeight: CGFloat = 22
    static let contentSize = CGSize(width: 660, height: 444)
    static let textTop = menuHeight + 2
    /// Wider than any line: without word wrap the text never breaks.
    private static let unlimited = CGFloat.greatestFiniteMagnitude

    let window: RetroAppWindow
    let textView: NotepadTextView
    let scrollView: NSScrollView
    let menuBar = RetroMenuBar(menus: [])
    private(set) var fileURL: URL?
    /// The open file's line ending and byte-order mark (its text lives in the view).
    private(set) var file = TextFile.empty
    private(set) var isModified = false
    var onClose: (() -> Void)?
    var wordWrap: Bool {
        didSet { applyWordWrap() }
    }

    private let languages: [String]
    private let dialogs: NotepadDialogs
    private let prompter: NotepadPrompter
    private let startFolder: () -> URL
    private let folderUsed: (URL) -> Void
    private let textUndoManager = UndoManager()
    private var isClosed = false

    /// `startFolder` is where the dialogs open while the document has no file; `folderUsed` hears of every folder
    /// a file was opened from or saved to.
    init(languages: [String], preferences: NotepadPreferences, dialogs: NotepadDialogs, prompter: NotepadPrompter,
         startFolder: @escaping () -> URL, folderUsed: @escaping (URL) -> Void) {
        self.languages = languages
        self.dialogs = dialogs
        self.prompter = prompter
        self.startFolder = startFolder
        self.folderUsed = folderUsed
        wordWrap = preferences.wordWrap
        window = RetroAppWindow(title: NotepadText.windowTitle(fileName: nil, languages), icon: FileIcons.notepadAppSmall,
                                contentSize: Self.contentSize)
        textView = NotepadTextView(frame: CGRect(origin: .zero, size: Self.contentSize))
        scrollView = RetroScroller.makeScrollView(document: textView)
        super.init()
        window.delegate = self
        window.tabbingMode = .disallowed
        // Maximizing leaves the Retro98 taskbar visible while it runs, as in the Explorer.
        window.taskbarHeight = {
            NSRunningApplication.runningApplications(withBundleIdentifier: Self.shellBundleID).isEmpty ? 0 : 28
        }
        build()
    }

    private func build() {
        let content = window.contentContainer
        let width = content.bounds.width, height = content.bounds.height
        menuBar.frame = CGRect(x: 0, y: 0, width: width, height: Self.menuHeight)
        menuBar.autoresizingMask = [.width]
        let line = EtchedLine(frame: CGRect(x: 0, y: Self.menuHeight, width: width, height: 2))
        line.autoresizingMask = [.width]
        scrollView.frame = CGRect(x: 0, y: Self.textTop, width: width, height: height - Self.textTop)
        let frame = FieldFrame(wrapping: scrollView)
        frame.autoresizingMask = [.width, .height]
        for view in [menuBar, line, frame] { content.addSubview(view) }

        textView.delegate = self
        textView.minSize = CGSize(width: 0, height: scrollView.contentSize.height)
        textView.maxSize = CGSize(width: Self.unlimited, height: Self.unlimited)
        textView.isVerticallyResizable = true
        applyWordWrap()
        window.initialFirstResponder = textView
    }

    /// With word wrap the text is as wide as the window and has no sideways scroll bar; without it, lines run on.
    private func applyWordWrap() {
        guard let container = textView.textContainer else { return }
        scrollView.hasHorizontalScroller = !wordWrap
        let visibleWidth = scrollView.contentSize.width
        if wordWrap {
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            textView.setFrameSize(CGSize(width: visibleWidth, height: textView.frame.height))
            container.size = CGSize(width: visibleWidth, height: Self.unlimited)
            container.widthTracksTextView = true
        } else {
            container.widthTracksTextView = false
            container.size = CGSize(width: Self.unlimited, height: Self.unlimited)
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = []
        }
        textView.sizeToFit()
        textView.needsDisplay = true
    }

    // MARK: Document

    /// No file, no change, nothing typed: Open may reuse this window.
    var isUntouched: Bool { fileURL == nil && !isModified && textView.string.isEmpty }

    /// Shows the file's text; false (with a message, the window as it was) when it can't be read as UTF-8 text.
    @discardableResult
    func load(_ url: URL) -> Bool {
        let loaded: TextFile
        do {
            loaded = try TextFile.read(from: url)
        } catch {
            prompter.tell(NotepadText.openError(error, fileName: url.lastPathComponent, languages), icon: .error, languages: languages)
            return false
        }
        textView.string = loaded.text
        file = TextFile(text: "", lineEnding: loaded.lineEnding, hasBOM: loaded.hasBOM)
        textUndoManager.removeAllActions()
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        textView.scrollToBeginningOfDocument(nil)
        didStore(at: url)
        return true
    }

    /// Saves to the document's file, or asks where when it has none. False when cancelled or when writing failed.
    @discardableResult
    func save() -> Bool {
        guard let fileURL else { return saveAs() }
        return write(to: fileURL)
    }

    @discardableResult
    func saveAs() -> Bool {
        let folder = fileURL?.deletingLastPathComponent() ?? startFolder()
        let name = fileURL?.lastPathComponent ?? NotepadText.untitledFileName(languages)
        guard let url = dialogs.chooseSaveLocation(in: folder, name: name, languages: languages) else { return false }
        return write(to: url)
    }

    private func write(to url: URL) -> Bool {
        do {
            try TextFile(text: textView.string, lineEnding: file.lineEnding, hasBOM: file.hasBOM).write(to: url)
        } catch {
            prompter.tell(NotepadText.saveError(fileName: url.lastPathComponent, languages), icon: .error, languages: languages)
            return false
        }
        didStore(at: url)
        return true
    }

    /// The view and `url` now hold the same text.
    private func didStore(at url: URL) {
        fileURL = url
        isModified = false
        window.setTitle(NotepadText.windowTitle(fileName: url.lastPathComponent, languages), icon: FileIcons.notepadAppSmall)
        folderUsed(url.deletingLastPathComponent())
    }

    /// Asks when modified; true when the window may close (saved or discarded).
    func confirmDiscardingChanges() -> Bool {
        guard isModified else { return true }
        let message = NotepadText.askToSave(fileName: fileURL?.lastPathComponent, languages)
        switch prompter.askToSave(message, languages: languages) {
        case .save: return save()
        case .discard: return true
        case .cancel: return false
        }
    }

    /// Edit › Time/Date: replaces the selection, as typing would (so it can be undone).
    func insertTimeDate(_ date: Date) {
        textView.insertText(NotepadText.timeDate(date, locale: .current, timeZone: .current), replacementRange: textView.selectedRange())
    }

    // MARK: Menu commands (sent up the responder chain; the window's delegate is in it)

    @objc func saveDocument(_ sender: Any?) { save() }
    @objc func saveDocumentAs(_ sender: Any?) { saveAs() }
    @objc func insertTimeDate(_ sender: Any?) { insertTimeDate(Date()) }

    // MARK: Delegates

    func textDidChange(_ notification: Notification) {
        isModified = true
    }

    func undoManager(for view: NSTextView) -> UndoManager? { textUndoManager }
    func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager? { textUndoManager }

    func windowShouldClose(_ sender: NSWindow) -> Bool { confirmDiscardingChanges() }

    func windowWillClose(_ notification: Notification) {
        guard !isClosed else { return }
        isClosed = true
        onClose?()
    }
}
