import AppKit
import Retro98FilesCore

/// Opens one window per `retro98-explorer://` URL, or a Desktop window when launched or reopened plainly.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controllers: [ExplorerWindowController] = []
    let languages = Locale.preferredLanguages
    /// One clipboard, undo history and set of running operations for every window.
    private lazy var operations = injectedOperations ?? ExplorerOperations(environment: injectedEnvironment ?? .live(languages: languages))
    private let injectedEnvironment: ExplorerEnvironment?
    private let injectedOperations: ExplorerOperations?
    /// Tests open windows without putting them on screen.
    var presentsWindows = true

    var windowControllers: [ExplorerWindowController] { controllers }

    init(environment: ExplorerEnvironment? = nil, operations: ExplorerOperations? = nil) {
        injectedEnvironment = environment
        injectedOperations = operations
        super.init()
    }

    /// Other apps' "Show in Finder" arrives as the reveal event when the Explorer is the file viewer.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSAppleEventManager.shared().setEventHandler(self, andSelector: #selector(handleReveal(_:withReply:)),
                                                     forEventClass: Self.miscStandards, andEventID: Self.makeObjectsVisible)
    }

    var active: ExplorerWindowController? {
        controllers.first { $0.window.isKeyWindow } ?? controllers.first { $0.window.isMainWindow } ?? controllers.last
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // URLs that launched the app arrive right after this; only open the Desktop if none did.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.controllers.isEmpty else { return }
            self.openWindow(at: .desktop)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        let files = urls.filter(\.isFileURL)
        if !files.isEmpty { reveal(files) }
        for request in urls.compactMap(ExplorerURL.request(from:)) {
            switch request {
            case .open(let location): openWindow(at: location)
            case .search(let location): openWindow(at: location ?? .folder(FileManager.default.homeDirectoryForCurrentUser), searching: true)
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openWindow(at: .desktop) }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// Quitting (or logging out) during a copy cancels it and waits for its cleanup, so no
    /// half-written file is left behind under its full name.
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard operations.runningOperations > 0 else { return .terminateNow }
        operations.cancelRunning()
        Task { [operations] in
            await operations.waitForOperations()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    @discardableResult
    func openWindow(at location: Location, searching: Bool = false) -> ExplorerWindowController {
        let controller = ExplorerWindowController(start: location, languages: languages, operations: operations, searching: searching)
        controller.onClose = { [weak self, weak controller] in
            self?.controllers.removeAll { $0 === controller }
        }
        controllers.append(controller)
        if presentsWindows { controller.show() }
        return controller
    }

    // MARK: Reveal ("Show in Finder")

    static let miscStandards: AEEventClass = 0x6D69_7363      // 'misc'
    static let makeObjectsVisible: AEEventID = 0x6D76_6973    // 'mvis'
    static let directObject: AEKeyword = 0x2D2D_2D2D          // '----'
    static let fileURLType: DescType = 0x6675_726C            // 'furl'

    /// One window per folder (reusing one already showing it), with the items selected.
    func reveal(_ urls: [URL]) {
        for plan in RevealPlan.windows(for: urls) {
            let path = plan.folder.standardizedFileURL.path
            let existing = controllers.first { controller in
                if case .folder(let url) = controller.model.history.current { return url.standardizedFileURL.path == path }
                return false
            }
            let controller = existing ?? openWindow(at: .folder(plan.folder))
            if existing != nil, presentsWindows { controller.show() }
            controller.select(plan.select)
        }
    }

    @objc func handleReveal(_ event: NSAppleEventDescriptor, withReply reply: NSAppleEventDescriptor) {
        guard let items = event.paramDescriptor(forKeyword: Self.directObject) else { return }
        let descriptors = items.numberOfItems > 0 ? (1...items.numberOfItems).compactMap { items.atIndex($0) } : [items]
        reveal(descriptors.compactMap { $0.coerce(toDescriptorType: Self.fileURLType)?.fileURLValue })
    }

    // MARK: Menu actions (both menu bars send these up the responder chain)

    @objc func newWindow(_ sender: Any?) { openWindow(at: active?.model.history.current ?? .desktop) }
    @objc func closeWindow(_ sender: Any?) { active?.window.performClose(nil) }
    @objc func goBack(_ sender: Any?) { active?.model.back() }
    @objc func goForward(_ sender: Any?) { active?.model.forward() }
    @objc func goUp(_ sender: Any?) { active?.model.up() }
    @objc func refresh(_ sender: Any?) { active?.model.reload() }
    @objc func goDesktop(_ sender: Any?) { active?.model.go(to: .desktop) }
    @objc func goMyComputer(_ sender: Any?) { active?.model.go(to: .myComputer) }
    @objc func goDocuments(_ sender: Any?) { active?.go(toHomeFolder: "Documents") }
    @objc func goDownloads(_ sender: Any?) { active?.go(toHomeFolder: "Downloads") }
    @objc func goApplications(_ sender: Any?) { active?.model.go(to: .folder(URL(filePath: "/Applications"))) }
    @objc func openHelp(_ sender: Any?) { NSWorkspace.shared.open(ExplorerMenus.helpURL) }
}
