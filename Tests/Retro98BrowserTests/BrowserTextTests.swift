import Foundation
import Testing
@testable import Retro98Browser

private let pt = ["pt-BR"], en = ["en"]

@Test func windowTitles() {
    #expect(BrowserText.windowTitle("Exemplo", pt) == "Exemplo - Navegador")
    #expect(BrowserText.windowTitle("", en) == "Browser")
    #expect(BrowserText.windowTitle("a\nb", pt) == "a b - Navegador")
}

@Test func otherAppQuestionNamesTheScheme() {
    #expect(BrowserText.otherAppQuestion(scheme: "mailto", pt).contains("mailto"))
    #expect(BrowserText.otherAppQuestion(scheme: "mailto", en).contains("another app"))
}

@Test func tabTitles() {
    #expect(BrowserText.tabTitle(pageTitle: "Exemplo", url: web("https://example.com/a"), pt) == "Exemplo")
    #expect(BrowserText.tabTitle(pageTitle: "", url: web("https://example.com/a"), pt) == "example.com")
    #expect(BrowserText.tabTitle(pageTitle: "  ", url: nil, pt) == "Nova guia")
    #expect(BrowserText.tabTitle(pageTitle: "", url: nil, en) == "New Tab")
    #expect(BrowserText.tabTitle(pageTitle: "", url: AddressInput.homeURL, pt) == "Página inicial")
    #expect(BrowserText.tabTitle(pageTitle: "", url: URL(filePath: "/tmp/a.html"), pt) == "a.html")
    #expect(BrowserText.tabTitle(pageTitle: "<b>a</b>\nb", url: nil, pt) == "<b>a</b> b")
}
