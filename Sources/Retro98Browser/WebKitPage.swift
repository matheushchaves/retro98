import AppKit
import WebKit

/// A real page: a `WKWebView` and the rules around it (new tabs, downloads, other apps' links, error pages).
@MainActor
final class WebKitPage: NSObject, BrowserPage, WKNavigationDelegate, WKUIDelegate {
    let webView: WKWebView
    var onChange: (() -> Void)?
    var onVisit: ((URL, String) -> Void)?
    var onHover: ((String?) -> Void)?
    var onNewPage: ((BrowserPage, Bool) -> Void)?
    var onClose: (() -> Void)?

    private let environment: WebKitEnvironment
    private var observations: [NSKeyValueObservation] = []
    /// The address the main frame is trying to open, kept for the error page.
    private var pendingURL: URL?
    /// The address that failed while its error page shows: Refresh tries it again.
    private var failedURL: URL?
    private var errorNavigation: WKNavigation?
    /// A "no" to opening another app holds until the person navigates.
    private var otherAppsRefused = false
    private var isClosed = false

    init(environment: WebKitEnvironment, configuration: WKWebViewConfiguration) {
        self.environment = environment
        webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 800, height: 600), configuration: configuration)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsMagnification = true
        environment.register(self)
        observe(\.title)
        observe(\.url)
        observe(\.isLoading)
        observe(\.estimatedProgress)
        observe(\.canGoBack)
        observe(\.canGoForward)
    }

    private func observe<Value>(_ keyPath: KeyPath<WKWebView, Value>) {
        observations.append(webView.observe(keyPath) { [weak self] _, _ in
            MainActor.assumeIsolated { self?.onChange?() }
        })
    }

    // MARK: BrowserPage

    var view: NSView { webView }
    var url: URL? { failedURL ?? webView.url }
    var title: String { webView.title ?? "" }
    var isLoading: Bool { webView.isLoading }
    var progress: Double { webView.estimatedProgress }
    var canGoBack: Bool { webView.canGoBack }
    var canGoForward: Bool { webView.canGoForward }

    var zoom: Double {
        get { webView.pageZoom }
        set { webView.pageZoom = newValue }
    }

    func load(_ target: AddressTarget) {
        personNavigated()
        switch target {
        case .home:
            webView.load(URLRequest(url: AddressInput.homeURL))
        case .url(let url) where url.isFileURL:
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        case .url(let url):
            webView.load(URLRequest(url: url))
        }
    }

    func goBack() {
        personNavigated()
        webView.goBack()
    }

    func goForward() {
        personNavigated()
        webView.goForward()
    }

    /// On an error page, tries the address that failed.
    func reload() {
        if let failedURL {
            load(.url(failedURL))
        } else {
            personNavigated()
            webView.reload()
        }
    }

    func stop() { webView.stopLoading() }

    func find(_ text: String, backwards: Bool, completion: @escaping @MainActor @Sendable (Bool) -> Void) {
        let configuration = WKFindConfiguration()
        configuration.backwards = backwards
        configuration.wraps = true
        configuration.caseSensitive = false
        webView.find(text, configuration: configuration) { result in
            let found = result.matchFound
            MainActor.assumeIsolated { completion(found) }
        }
    }

    func close() {
        guard !isClosed else { return }
        isClosed = true
        observations.forEach { $0.invalidate() }
        observations = []
        webView.stopLoading()
        webView.pauseAllMediaPlayback()
        webView.loadHTMLString("", baseURL: nil)
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        webView.removeFromSuperview()
        environment.forget(self)
        onChange = nil
        onVisit = nil
        onHover = nil
        onNewPage = nil
        onClose = nil
    }

    private func personNavigated() {
        otherAppsRefused = false
        failedURL = nil
    }

    // MARK: Navigation

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
        let url = navigationAction.request.url
        // No target frame means a new window, which opens as a tab.
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true
        let isCommandClick = navigationAction.navigationType == .linkActivated && navigationAction.modifierFlags.contains(.command)
        let decision = NavigationPolicy.decide(scheme: url?.scheme, isMainFrame: isMainFrame, isCommandClick: isCommandClick,
                                               wantsDownload: navigationAction.shouldPerformDownload, otherAppsRefused: otherAppsRefused)
        switch decision {
        case .allow:
            if isMainFrame { pendingURL = url }
            return .allow
        case .download:
            return .download
        case .newTab:
            if let url, onNewPage != nil {
                let page = environment.makeWebKitPage()
                page.load(.url(url))
                onNewPage?(page, true)
            }
            return .cancel
        case .askOtherApp:
            if let url, let scheme = url.scheme {
                if environment.prompter.ask(BrowserText.otherAppQuestion(scheme: scheme, environment.languages), languages: environment.languages) {
                    environment.opener(url)
                } else {
                    otherAppsRefused = true
                }
            }
            return .cancel
        case .cancel:
            return .cancel
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse) async -> WKNavigationResponsePolicy {
        let disposition = (navigationResponse.response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Disposition")
        let decision = NavigationPolicy.decideResponse(canShow: navigationResponse.canShowMIMEType,
                                                       isAttachment: NavigationPolicy.isAttachment(contentDisposition: disposition))
        return decision == .download ? .download : .allow
    }

    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        environment.onDownload?(download)
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        environment.onDownload?(download)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if navigation !== errorNavigation, failedURL != nil {
            failedURL = nil
            onChange?()
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard navigation !== errorNavigation, failedURL == nil, let url = webView.url else { return }
        onVisit?(url, title)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: any Error) {
        showError(error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
        showError(error)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        showErrorPage(message: BrowserText.pageStopped(environment.languages), url: webView.url ?? pendingURL)
    }

    private func showError(_ error: any Error) {
        guard !NavigationPolicy.isSilent(error) else { return }
        let failing = (error as NSError).userInfo[NSURLErrorFailingURLErrorKey] as? URL
        showErrorPage(message: error.localizedDescription, url: failing ?? pendingURL ?? webView.url)
    }

    /// The error page stands in for the address that failed, which stays in the address bar.
    private func showErrorPage(message: String, url: URL?) {
        guard !isClosed else { return }
        let html = BrowserPages.error(message: message, url: url, languages: environment.languages)
        guard let url, !AddressInput.isHome(url) else {
            errorNavigation = webView.loadHTMLString(html, baseURL: nil)
            return
        }
        failedURL = url
        errorNavigation = webView.loadSimulatedRequest(URLRequest(url: url), responseHTML: html)
        onChange?()
    }

    // MARK: What pages ask for

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let onNewPage else { return nil }
        let page = WebKitPage(environment: environment, configuration: configuration)
        onNewPage(page, false)
        return page.webView
    }

    func webViewDidClose(_ webView: WKWebView) { onClose?() }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async {
        let l = environment.languages
        environment.prompter.tell(BrowserText.pageSays(host: frame.securityOrigin.host, message: message, l), icon: .warning, languages: l)
    }

    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo) async -> Bool {
        let l = environment.languages
        return environment.prompter.ask(BrowserText.pageSays(host: frame.securityOrigin.host, message: message, l), languages: l)
    }

    func webView(_ webView: WKWebView, runOpenPanelWith parameters: WKOpenPanelParameters, initiatedByFrame frame: WKFrameInfo) async -> [URL]? {
        environment.dialogs.chooseFileToOpen(in: environment.home, languages: environment.languages).map { [$0] }
    }
}
