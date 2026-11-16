import Foundation
import Testing
@testable import Retro98Browser

private let pt = ["pt-BR"], en = ["en"]

@Test func escapeCoversTheFiveCharacters() {
    #expect(BrowserPages.escape("<a href=\"x\">'&'</a>") == "&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;")
}

@Test func homeListsFavoritesEscaped() {
    let hostile = Favorite(title: "<script>alert(1)</script>", url: web("https://example.com/?a=%22b%22"))
    let html = BrowserPages.home(favorites: [hostile], languages: pt)
    #expect(!html.lowercased().contains("<script"))
    #expect(html.contains("&lt;script&gt;alert(1)&lt;/script&gt;"))
    #expect(html.contains("href=\"https://example.com/?a=%22b%22\""))
}

@Test func favoriteAddressCannotLeaveItsAttribute() {
    // A URL type never holds a raw quote, but the page escapes the address anyway.
    let html = BrowserPages.home(favorites: [Favorite(title: "x", url: web("https://example.com/?a=1&b='2'"))], languages: pt)
    #expect(html.contains("href=\"https://example.com/?a=1&amp;b=&#39;2&#39;\""))
}

@Test func onlyWebAndFileFavoritesAreLinks() {
    let html = BrowserPages.home(favorites: [Favorite(title: "ruim", url: web("javascript:alert(1)"))], languages: pt)
    #expect(!html.contains("href=\"javascript:"))
    #expect(html.contains("ruim"))
}

@Test func homeHasTheSearchForm() {
    let html = BrowserPages.home(favorites: [], languages: pt)
    #expect(html.contains("action=\"https://duckduckgo.com/\""))
    #expect(html.contains("name=\"q\""))
}

@Test func homeWithoutFavoritesSaysSo() {
    #expect(BrowserPages.home(favorites: [], languages: pt).contains("Você ainda não tem favoritos"))
    #expect(BrowserPages.home(favorites: [], languages: en).contains("You have no favorites yet"))
}

@Test func pagesNeedNothingFromTheNetwork() {
    let pages = [BrowserPages.home(favorites: [Favorite(title: "A", url: web("https://a.example/"))], languages: pt),
                 BrowserPages.error(message: "x", url: web("https://a.example/"), languages: pt)]
    for html in pages {
        for forbidden in ["src=", "<link", "@import", "url(", "<script"] { #expect(!html.contains(forbidden), "\(forbidden)") }
    }
}

@Test func errorPageEscapesTheAddressAndTheMessage() {
    let html = BrowserPages.error(message: "a<b", url: URL(string: "https://example.com/%3Cscript%3E?q=<script>"), languages: pt)
    #expect(!html.lowercased().contains("<script"))
    #expect(html.contains("a&lt;b"))
    #expect(html.contains("example.com"))
    #expect(BrowserPages.error(message: "<img onerror=x>", url: nil, languages: pt).contains("&lt;img onerror=x&gt;"))
}

@Test func pagesAreInBothLanguages() {
    #expect(BrowserPages.home(favorites: [], languages: pt).contains("Página inicial"))
    #expect(BrowserPages.home(favorites: [], languages: en).contains("Home"))
    #expect(BrowserPages.error(message: "x", url: nil, languages: pt).contains("Não foi possível abrir a página"))
    #expect(BrowserPages.error(message: "x", url: nil, languages: en).contains("Can&#39;t open the page"))
}
