import AppKit
import WebKit

/// What every real page shares: the WebKit configuration (site data, built-in pages, the hover script) and
/// the services pages need from the app.
@MainActor
final class WebKitEnvironment {
    static let scheme = "retro98"
    static let hoverHandler = "retro98Hover"
    /// Sites treat the web view as the Safari it is underneath.
    static let userAgentName = "Version/18.0 Safari/605.1.15"
    /// Reports the link under the pointer (or "" when it leaves one), only when it changes.
    static let hoverScript = """
    (function () {
        var last = "";
        function send(value) {
            if (value === last) { return; }
            last = value;
            try { window.webkit.messageHandlers.\(hoverHandler).postMessage(value); } catch (error) {}
        }
        document.addEventListener("mouseover", function (event) {
            var link = event.target && event.target.closest ? event.target.closest("a[href]") : null;
            send(link ? String(link.href) : "");
        }, true);
        document.addEventListener("mouseout", function (event) {
            if (!event.relatedTarget) { send(""); }
        }, true);
    })();
    """

    let configuration: WKWebViewConfiguration
    let prompter: BrowserPrompter
    let dialogs: BrowserDialogs
    let opener: (URL) -> Void
    let home: URL
    let languages: [String]
    /// A navigation became a download.
    var onDownload: ((WKDownload) -> Void)?
    private let pages = NSHashTable<WebKitPage>.weakObjects()

    init(favorites: FavoritesStore, prompter: BrowserPrompter, dialogs: BrowserDialogs, opener: @escaping (URL) -> Void,
         home: URL = FileManager.default.homeDirectoryForCurrentUser, languages: [String]) {
        self.prompter = prompter
        self.dialogs = dialogs
        self.opener = opener
        self.home = home
        self.languages = languages
        configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.applicationNameForUserAgent = Self.userAgentName
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.preferences.isElementFullscreenEnabled = true
        configuration.setURLSchemeHandler(BuiltInPages(favorites: favorites, languages: languages), forURLScheme: Self.scheme)
        // The script and its handler live in a world of their own: the page's scripts can't reach either.
        let controller = configuration.userContentController
        controller.addUserScript(WKUserScript(source: Self.hoverScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false,
                                              in: .defaultClient))
        controller.add(HoverRelay { [weak self] webView, text in self?.page(for: webView)?.onHover?(text) },
                       contentWorld: .defaultClient, name: Self.hoverHandler)
    }

    func makePage() -> BrowserPage { makeWebKitPage() }

    func makeWebKitPage() -> WebKitPage { WebKitPage(environment: self, configuration: configuration) }

    func register(_ page: WebKitPage) { pages.add(page) }
    func forget(_ page: WebKitPage) { pages.remove(page) }

    private func page(for webView: WKWebView?) -> WebKitPage? {
        pages.allObjects.first { $0.webView === webView }
    }

    /// Cookies, caches and everything else sites keep.
    func clearWebsiteData(completion: @escaping @MainActor @Sendable () -> Void) {
        WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast) {
            MainActor.assumeIsolated { completion() }
        }
    }
}

/// Serves the Browser's own pages: retro98://home/ is the home page, built when asked for.
@MainActor
final class BuiltInPages: NSObject, WKURLSchemeHandler {
    private let favorites: FavoritesStore
    private let languages: [String]

    init(favorites: FavoritesStore, languages: [String]) {
        self.favorites = favorites
        self.languages = languages
    }

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        let url = task.request.url ?? AddressInput.homeURL
        let isHome = AddressInput.isHome(url)
        let html = isHome ? BrowserPages.home(favorites: favorites.items, languages: languages)
            : BrowserPages.error(message: BrowserText.pageNotFound(languages), url: nil, languages: languages)
        let headers = ["Content-Type": "text/html; charset=utf-8", "Cache-Control": "no-store"]
        guard let response = HTTPURLResponse(url: url, statusCode: isHome ? 200 : 404, httpVersion: "HTTP/1.1", headerFields: headers) else {
            task.didFailWithError(URLError(.badServerResponse))
            return
        }
        task.didReceive(response)
        task.didReceive(Data(html.utf8))
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}

/// Receives the hover script's messages and hands the text on. Whatever arrives is treated as text only.
@MainActor
final class HoverRelay: NSObject, WKScriptMessageHandler {
    private let onHover: (WKWebView?, String?) -> Void

    init(onHover: @escaping (WKWebView?, String?) -> Void) {
        self.onHover = onHover
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        onHover(message.webView, NavigationPolicy.hoverText(message.body))
    }
}
