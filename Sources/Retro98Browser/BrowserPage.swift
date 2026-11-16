import AppKit
import Retro98UI

/// One web page as the window sees it. `WebKitPage` is the real one; tests use a fake.
@MainActor
protocol BrowserPage: AnyObject {
    var view: NSView { get }
    var url: URL? { get }
    var title: String { get }
    var isLoading: Bool { get }
    /// 0...1 while loading.
    var progress: Double { get }
    var canGoBack: Bool { get }
    var canGoForward: Bool { get }
    /// Any of the properties above changed.
    var onChange: (() -> Void)? { get set }
    /// A page finished opening without error (for the history).
    var onVisit: ((URL, String) -> Void)? { get set }
    /// The link under the pointer, or nil when it left.
    var onHover: ((String?) -> Void)? { get set }
    /// The page opened another page (a new tab): the new page, and whether it stays in the background.
    var onNewPage: ((BrowserPage, Bool) -> Void)? { get set }
    /// Something the person should know, for the status bar (a link the page wasn't allowed to open, say).
    var onNotice: ((String) -> Void)? { get set }
    /// The page asked to be closed.
    var onClose: (() -> Void)? { get set }
    func load(_ target: AddressTarget)
    func goBack()
    func goForward()
    func reload()
    func stop()
    func find(_ text: String, backwards: Bool, completion: @escaping @MainActor @Sendable (Bool) -> Void)
    /// 1 is the normal size.
    var zoom: Double { get set }
    /// Stops loading and media; the page is not used again.
    func close()
}

/// The Browser's yes/no questions and warnings (tests answer from a script).
@MainActor
protocol BrowserPrompter: AnyObject {
    func ask(_ message: String, languages: [String]) -> Bool
    func tell(_ message: String, icon: MessageBoxIcon, languages: [String])
}

/// Where to open a file from (tests hand out files instead of showing the dialog).
@MainActor
protocol BrowserDialogs: AnyObject {
    func chooseFileToOpen(in folder: URL, languages: [String]) -> URL?
}
