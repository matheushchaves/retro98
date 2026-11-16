import Foundation

/// The HTML of the Browser's own pages: home and error. Everything that comes from outside (favorite titles,
/// addresses, error messages) is escaped, and the pages load nothing from the network.
enum BrowserPages {
    /// Favorites with these schemes become links on the home page; any other is shown as text.
    static let linkSchemes: Set<String> = ["http", "https", "file"]

    static func escape(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        for character in text {
            switch character {
            case "&": result += "&amp;"
            case "<": result += "&lt;"
            case ">": result += "&gt;"
            case "\"": result += "&quot;"
            case "'": result += "&#39;"
            default: result.append(character)
            }
        }
        return result
    }

    static func home(favorites: [Favorite], languages l: [String]) -> String {
        var list = "<p>\(escape(BrowserText.noFavorites(l)))</p>"
        if !favorites.isEmpty {
            let items = favorites.map { favorite -> String in
                let title = escape(BrowserText.oneLine(favorite.title))
                guard let scheme = favorite.url.scheme?.lowercased(), linkSchemes.contains(scheme) else { return "<li>\(title)</li>" }
                return "<li><a href=\"\(escape(favorite.url.absoluteString))\">\(title)</a></li>"
            }
            list = "<ul>\(items.joined())</ul>"
        }
        let body = """
        <h1>Retro98 — \(escape(BrowserText.name(l)))</h1>
        <div class="box">
        <h2>\(escape(BrowserText.searchTheWeb(l)))</h2>
        <form action="https://duckduckgo.com/" method="get">
        <input type="text" name="q" size="40" autofocus> <button type="submit">\(escape(BrowserText.search(l)))</button>
        </form>
        </div>
        <div class="box">
        <h2>\(escape(BrowserText.favorites(l)))</h2>
        \(list)
        </div>
        """
        return page(title: BrowserText.homeTitle(l), body: body, formAction: "https://duckduckgo.com", languages: l)
    }

    static func error(message: String, url: URL?, languages l: [String]) -> String {
        let address = url.map { "<p class=\"address\">\(escape(BrowserText.oneLine($0.absoluteString, limit: 500)))</p>" } ?? ""
        let body = """
        <h1>\(escape(BrowserText.errorTitle(l)))</h1>
        <div class="box">
        \(address)
        <p>\(escape(String(message.prefix(1000))))</p>
        <p>\(escape(BrowserText.errorHint(l)))</p>
        </div>
        """
        return page(title: BrowserText.errorTitle(l), body: body, formAction: "'none'", languages: l)
    }

    /// The shared frame: classic gray, navy title bar, Tahoma. The policy forbids scripts and anything remote.
    private static func page(title: String, body: String, formAction: String, languages l: [String]) -> String {
        let language = l.first?.hasPrefix("pt") == true ? "pt-BR" : "en"
        return """
        <!DOCTYPE html>
        <html lang="\(language)">
        <head>
        <meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy" content="default-src 'none'; style-src 'unsafe-inline'; form-action \(formAction)">
        <title>\(escape(title))</title>
        <style>
        body { background: #C0C0C0; color: #000000; font: 13px Tahoma, sans-serif; margin: 24px; }
        h1 { background: #000080; color: #FFFFFF; font-size: 14px; margin: 0 0 16px 0; padding: 4px 8px; }
        h2 { font-size: 13px; margin: 0 0 8px 0; }
        .box { border: 2px solid; border-color: #FFFFFF #808080 #808080 #FFFFFF; margin: 0 0 16px 0; padding: 12px; max-width: 560px; }
        input, button { font: 13px Tahoma, sans-serif; }
        ul { margin: 0; padding-left: 20px; }
        li { margin: 2px 0; }
        a { color: #000080; }
        .address { font-weight: bold; word-break: break-all; }
        </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
}
