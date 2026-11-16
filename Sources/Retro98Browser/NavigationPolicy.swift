import Foundation

/// What to do with a navigation a page asks for.
enum NavigationDecision: Equatable, Sendable {
    case allow, download, newTab, askOtherApp, cancel
}

/// The Browser's navigation rules, apart from WebKit so they can be tested.
enum NavigationPolicy {
    /// Addresses the web view opens itself. Anything else belongs to another app.
    static let webSchemes: Set<String> = ["http", "https", "file", "about", "data", "blob", "retro98"]
    static let hoverLimit = 300

    /// Download links download; ⌘-click opens a tab; other apps' links ask first, in the main frame only and
    /// not again after a "no" from this page.
    static func decide(scheme: String?, isMainFrame: Bool, isCommandClick: Bool, wantsDownload: Bool,
                       otherAppsRefused: Bool) -> NavigationDecision {
        guard let scheme = scheme?.lowercased(), !scheme.isEmpty else { return .cancel }
        guard webSchemes.contains(scheme) else { return isMainFrame && !otherAppsRefused ? .askOtherApp : .cancel }
        if wantsDownload { return .download }
        return isCommandClick ? .newTab : .allow
    }

    /// Whether a "no" to opening another app still holds after a navigation. It ends when the person follows a
    /// link or sends a form to a web address in the main frame; a script moving the page doesn't end it, so a
    /// page can't earn itself a new question.
    static func refusedAfter(refused: Bool, scheme: String?, isMainFrame: Bool, isPersonAction: Bool) -> Bool {
        guard refused else { return false }
        guard isMainFrame, isPersonAction, let scheme = scheme?.lowercased(), webSchemes.contains(scheme) else { return true }
        return false
    }

    /// What WebKit can't show, and what the server sends as an attachment, is downloaded.
    static func decideResponse(canShow: Bool, isAttachment: Bool) -> NavigationDecision {
        canShow && !isAttachment ? .allow : .download
    }

    static func isAttachment(contentDisposition: String?) -> Bool {
        contentDisposition?.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("attachment") ?? false
    }

    /// Cancelled loads and loads that became downloads show no error page.
    static func isSilent(_ error: Error) -> Bool {
        let error = error as NSError
        return (error.domain == NSURLErrorDomain && error.code == NSURLErrorCancelled)
            || (error.domain == "WebKitErrorDomain" && error.code == 102)
    }

    /// The link under the pointer as a page's script reports it: text only, one short line; nil for none.
    static func hoverText(_ body: Any) -> String? {
        guard let text = body as? String else { return nil }
        let line = BrowserText.oneLine(text, limit: hoverLimit)
        return line.isEmpty ? nil : line
    }
}

/// Keeps a page from holding the app with one alert after another: after two message boxes, the next one
/// first asks whether to keep showing them, and a "no" silences the page until the person navigates.
struct PageDialogs: Equatable {
    static let freeDialogs = 2

    enum Step: Equatable {
        /// Show the page's message.
        case show
        /// Ask first whether this page may keep showing messages.
        case askFirst
        /// Show nothing: the person said no.
        case silent
    }

    private var shown = 0
    private var isSilenced = false

    mutating func next() -> Step {
        if isSilenced { return .silent }
        guard shown < Self.freeDialogs else { return .askFirst }
        shown += 1
        return .show
    }

    /// The answer to `askFirst`: a yes shows the pending message and starts counting again.
    mutating func answer(keepShowing: Bool) {
        if keepShowing { shown = 1 } else { isSilenced = true }
    }

    mutating func reset() { self = PageDialogs() }
}
