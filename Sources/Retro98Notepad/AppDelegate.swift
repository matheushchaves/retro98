import AppKit
import Retro98Settings
import Retro98UI

/// One window per document. Opens an empty one at launch, on ⌘N and when reopened with none; files from the
/// Open dialog, "Open With" or a drop on the icon reuse an untouched window or get their own. Quitting asks
/// about each window with unsaved changes.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    /// New windows open this far right of and below the active one.
    static let cascadeOffset: CGFloat = 22

    let languages: [String]
    /// Tests open windows without putting them on screen.
    var presentsWindows = true
    /// Makes the VGA font available; runs once, before the first window is built.
    var registerFont: () -> Void = {
        if let font = VGAFont.bundledURL { VGAFont.register(at: font) }
    }
    private var isFontRegistered = false
    /// Where the dialogs start when the document has no folder: the last folder used, first ~/Documents.
    private(set) var lastFolder: URL
    private var controllers: [NotepadWindowController] = []
    /// The Notepad window used last: the Find window takes the keyboard without changing which text it searches.
    private weak var lastActive: NotepadWindowController?
    private let preferences: NotepadPreferences
    private let dialogs: NotepadDialogs
    private let prompter: NotepadPrompter
    private(set) lazy var findDialog = FindDialog(languages: languages, prompter: prompter) { [weak self] in self?.active?.textView }

    var windowControllers: [NotepadWindowController] { controllers }

    init(preferences: NotepadPreferences = NotepadPreferences(defaults: .standard),
         dialogs: NotepadDialogs = RetroNotepadDialogs(), prompter: NotepadPrompter = RetroNotepadPrompter(),
         home: URL = FileManager.default.homeDirectoryForCurrentUser, languages: [String] = Locale.preferredLanguages) {
        self.preferences = preferences
        self.dialogs = dialogs
        self.prompter = prompter
        self.languages = languages
        lastFolder = home.appending(path: "Documents")
        super.init()
    }

    var active: NotepadWindowController? {
        controllers.first { $0.window.isKeyWindow } ?? controllers.first { $0.window.isMainWindow } ?? lastActive ?? controllers.last
    }

    // MARK: Application

    /// One window per document, never tabs.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    /// Files that launched the app may arrive before or after this; either way the first one takes the empty window.
    func applicationDidFinishLaunching(_ notification: Notification) {
        if controllers.isEmpty { openWindow() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.isFileURL { open(url) }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openWindow() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for controller in controllers where controller.isModified {
            if presentsWindows { controller.window.makeKeyAndOrderFront(nil) }
            if !controller.confirmDiscardingChanges() { return .terminateCancel }
        }
        return .terminateNow
    }

    // MARK: Windows

    @discardableResult
    func openWindow() -> NotepadWindowController {
        let controller = makeController()
        add(controller)
        return controller
    }

    /// An open file comes to the front; an untouched active window takes it; otherwise it gets a new window.
    /// False when it can't be read (a message says why, and no window is left behind).
    @discardableResult
    func open(_ url: URL) -> Bool {
        let wanted = Self.identity(of: url)
        if let existing = controllers.first(where: { $0.fileURL.map(Self.identity(of:)) == wanted }) {
            present(existing)
            return true
        }
        if let active, active.isUntouched {
            guard active.load(url) else { return false }
            present(active)
            return true
        }
        let controller = makeController()
        guard controller.load(url) else { return false }
        add(controller)
        return true
    }

    /// The same file reached through a link or a different spelling of its path is still the same document.
    private static func identity(of url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
    }

    private func makeController() -> NotepadWindowController {
        // Here and not at launch: a file that started the app ("Open With") gets its window before launch finishes.
        if !isFontRegistered {
            registerFont()
            isFontRegistered = true
        }
        let controller = NotepadWindowController(
            languages: languages, preferences: preferences, dialogs: dialogs, prompter: prompter,
            startFolder: { [weak self] in self?.lastFolder ?? FileManager.default.homeDirectoryForCurrentUser },
            folderUsed: { [weak self] in self?.lastFolder = $0 }
        )
        controller.onClose = { [weak self, weak controller] in
            self?.controllers.removeAll { $0 === controller }
        }
        controller.onBecomeKey = { [weak self, weak controller] in self?.lastActive = controller }
        return controller
    }

    private func add(_ controller: NotepadWindowController) {
        if let previous = active?.window.frame {
            controller.window.setFrameTopLeftPoint(CGPoint(x: previous.minX + Self.cascadeOffset, y: previous.maxY - Self.cascadeOffset))
        }
        controllers.append(controller)
        lastActive = controller
        present(controller)
    }

    private func present(_ controller: NotepadWindowController) {
        lastActive = controller
        guard presentsWindows else { return }
        controller.window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    // MARK: Menu actions (both menu bars send these up the responder chain)

    @objc func newDocument(_ sender: Any?) { openWindow() }

    @objc func openDocument(_ sender: Any?) {
        let folder = active?.fileURL?.deletingLastPathComponent() ?? lastFolder
        guard let url = dialogs.chooseFileToOpen(in: folder, languages: languages) else { return }
        open(url)
    }

    @objc func closeWindow(_ sender: Any?) { active?.window.performClose(nil) }

    /// Format › Word Wrap: one switch for every window, remembered between launches.
    @objc func toggleWordWrap(_ sender: Any?) {
        let wrap = !preferences.wordWrap
        preferences.wordWrap = wrap
        controllers.forEach { $0.wordWrap = wrap }
    }

    @objc func showFind(_ sender: Any?) { findDialog.show() }

    /// Without a text to look for yet, Find Next asks for one.
    @objc func findNext(_ sender: Any?) {
        if findDialog.needle.isEmpty { findDialog.show() } else { findDialog.findNext() }
    }

    @objc func showAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: NotepadText.appName,
            .credits: NSAttributedString(string: NotepadText.aboutCredits(languages)),
        ])
        NSApp.activate()
    }

    @objc func openHelp(_ sender: Any?) { NSWorkspace.shared.open(NotepadMenus.helpURL) }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleWordWrap(_:)) { menuItem.state = preferences.wordWrap ? .on : .off }
        return true
    }
}
