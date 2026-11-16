import Foundation
import Testing
@testable import Retro98Browser

private let home = URL(filePath: "/Users/ana")

/// The address a typed text leads to, as text ("home" for the built-in page, nil for nothing).
private func resolved(_ text: String) -> String? {
    switch AddressInput.resolve(text, home: home) {
    case .home: "home"
    case .url(let url): url.absoluteString
    case nil: nil
    }
}

@Test func emptyIsNothing() {
    #expect(resolved("") == nil)
    #expect(resolved("   ") == nil)
}

@Test func homeAndBlank() {
    #expect(resolved("about:home") == "home")
    #expect(resolved("about:blank") == "about:blank")
}

@Test(arguments: ["https://example.com/a?b=1", "http://example.com", "file:///tmp/a.html"])
func fullAddressesStay(text: String) {
    #expect(resolved(text) == text)
    #expect(resolved("  \(text) ") == text)
}

@Test func localPaths() {
    #expect(resolved("/tmp/a.html") == "file:///tmp/a.html")
    #expect(resolved("~/site/index.html") == "file:///Users/ana/site/index.html")
}

@Test func hostsGetHTTPS() {
    #expect(resolved("example.com") == "https://example.com")
    #expect(resolved("sub.example.com:8443/x") == "https://sub.example.com:8443/x")
    #expect(resolved("example.com/a b")?.hasPrefix(AddressInput.searchPrefix) == true)
}

@Test func localHostsGetHTTP() {
    #expect(resolved("localhost") == "http://localhost")
    #expect(resolved("localhost:3000/app") == "http://localhost:3000/app")
    #expect(resolved("192.168.0.10") == "http://192.168.0.10")
    #expect(resolved("impressora.local") == "http://impressora.local")
    #expect(resolved("servidor:8080") == "https://servidor:8080")
}

@Test func everythingElseSearches() {
    #expect(resolved("pão de queijo") == "https://duckduckgo.com/?q=p%C3%A3o%20de%20queijo")
    #expect(resolved("swift") == "https://duckduckgo.com/?q=swift")
    #expect(resolved("a&b=c") == "https://duckduckgo.com/?q=a%26b%3Dc")
    #expect(resolved("what is node.js") == "https://duckduckgo.com/?q=what%20is%20node.js")
}

@Test func displayShowsHomeAsAbout() {
    #expect(AddressInput.display(AddressInput.homeURL) == "about:home")
    #expect(AddressInput.display(nil) == "")
    #expect(AddressInput.display(URL(string: "https://example.com/")) == "https://example.com/")
}
