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
