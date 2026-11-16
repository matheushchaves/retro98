import Foundation
import Testing
@testable import Retro98Browser

private func decide(_ scheme: String?, mainFrame: Bool = true, command: Bool = false, download: Bool = false,
                    refused: Bool = false) -> NavigationDecision {
    NavigationPolicy.decide(scheme: scheme, isMainFrame: mainFrame, isCommandClick: command, wantsDownload: download,
                            otherAppsRefused: refused)
}

@Test(arguments: ["http", "https", "file", "about", "data", "blob", "retro98", "HTTPS", "File"])
func webSchemesLoad(scheme: String) {
    #expect(decide(scheme) == .allow)
    #expect(decide(scheme, mainFrame: false) == .allow)
}

@Test func commandClickOpensATab() {
    #expect(decide("https", command: true) == .newTab)
    #expect(decide("https", mainFrame: false, command: true) == .newTab)
}

@Test func downloadLinksDownload() {
    #expect(decide("https", download: true) == .download)
    #expect(decide("https", command: true, download: true) == .download)
}

@Test(arguments: ["mailto", "tel", "zoommtg", "itms-apps"])
func otherSchemesAsk(scheme: String) {
    #expect(decide(scheme) == .askOtherApp)
    #expect(decide(scheme, command: true) == .askOtherApp)
}

@Test func otherSchemesInFramesAreCancelled() {
    #expect(decide("mailto", mainFrame: false) == .cancel)
}

@Test func afterARefusalOtherSchemesAreCancelled() {
    #expect(decide("mailto", refused: true) == .cancel)
    #expect(decide("https", refused: true) == .allow)
}

@Test func missingSchemeIsCancelled() {
    #expect(decide(nil) == .cancel)
    #expect(decide("") == .cancel)
}

@Test func responses() {
    #expect(NavigationPolicy.decideResponse(canShow: true, isAttachment: false) == .allow)
    #expect(NavigationPolicy.decideResponse(canShow: true, isAttachment: true) == .download)
    #expect(NavigationPolicy.decideResponse(canShow: false, isAttachment: false) == .download)
}

@Test func attachmentHeader() {
    #expect(NavigationPolicy.isAttachment(contentDisposition: "attachment; filename=\"a.zip\""))
    #expect(NavigationPolicy.isAttachment(contentDisposition: " ATTACHMENT"))
    #expect(!NavigationPolicy.isAttachment(contentDisposition: "inline; filename=attachment.pdf"))
    #expect(!NavigationPolicy.isAttachment(contentDisposition: nil))
}

@Test func silentErrors() {
    #expect(NavigationPolicy.isSilent(NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled)))
    #expect(NavigationPolicy.isSilent(NSError(domain: "WebKitErrorDomain", code: 102)))
    #expect(!NavigationPolicy.isSilent(NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)))
    #expect(!NavigationPolicy.isSilent(NSError(domain: "WebKitErrorDomain", code: 101)))
}

@Test func hoverTextIsOneShortLine() {
    #expect(NavigationPolicy.hoverText("https://example.com/a") == "https://example.com/a")
    #expect(NavigationPolicy.hoverText("") == nil)
    #expect(NavigationPolicy.hoverText("  \n ") == nil)
    #expect(NavigationPolicy.hoverText(42) == nil)
    #expect(NavigationPolicy.hoverText(["https://example.com"]) == nil)
    #expect(NavigationPolicy.hoverText("a\nb\r\nc") == "a b c")
    #expect(NavigationPolicy.hoverText(String(repeating: "x", count: 10_000))?.count == 300)
}
