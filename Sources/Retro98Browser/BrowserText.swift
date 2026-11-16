import Foundation
import Retro98Settings

/// The Browser's words in Brazilian Portuguese or English, following the system language.
enum BrowserText {
    private static func text(_ l: [String], _ ptBR: String, _ en: String) -> String {
        LocalizedText(en: en, ptBR: ptBR).resolve(for: l)
    }

    static let appName = "Retro98 Browser"

    /// One line of at most `limit` characters: text from a page never brings line breaks or runs on forever.
    static func oneLine(_ text: String, limit: Int = 300) -> String {
        let line = String(text.prefix(limit).map { $0.isNewline || $0 == "\t" ? " " : $0 })
        return line.trimmingCharacters(in: .whitespaces)
    }

    /// The name in window titles and message boxes.
    static func name(_ l: [String]) -> String { text(l, "Navegador", "Browser") }

    /// "Exemplo - Navegador", or just "Navegador" for a page without a title.
    static func windowTitle(_ pageTitle: String, _ l: [String]) -> String {
        let title = oneLine(pageTitle)
        return title.isEmpty ? name(l) : "\(title) - \(name(l))"
    }

    /// A tab's title: the page's; without one, the server (or the file's name); without an address, "Nova guia".
    static func tabTitle(pageTitle: String, url: URL?, _ l: [String]) -> String {
        let title = oneLine(pageTitle)
        if !title.isEmpty { return title }
        guard let url else { return newTabTitle(l) }
        if AddressInput.isHome(url) { return homeTitle(l) }
        if url.isFileURL { return url.lastPathComponent }
        return url.host() ?? newTabTitle(l)
    }

    static func newTabTitle(_ l: [String]) -> String { text(l, "Nova guia", "New Tab") }
    static func homeTitle(_ l: [String]) -> String { text(l, "Página inicial", "Home") }

    // MARK: Window

    static func address(_ l: [String]) -> String { text(l, "Endereço", "Address") }
    static func go(_ l: [String]) -> String { text(l, "Ir", "Go") }
    static func opening(_ l: [String]) -> String { text(l, "Abrindo página…", "Opening page…") }
    static func done(_ l: [String]) -> String { text(l, "Concluído", "Done") }

    static func back(_ l: [String]) -> String { text(l, "Voltar", "Back") }
    static func forward(_ l: [String]) -> String { text(l, "Avançar", "Forward") }
    static func stop(_ l: [String]) -> String { text(l, "Parar", "Stop") }
    static func refresh(_ l: [String]) -> String { text(l, "Atualizar", "Refresh") }
    static func home(_ l: [String]) -> String { text(l, "Página inicial", "Home") }
    static func favorites(_ l: [String]) -> String { text(l, "Favoritos", "Favorites") }
    static func history(_ l: [String]) -> String { text(l, "Histórico", "History") }

    // MARK: Pages

    static func search(_ l: [String]) -> String { text(l, "Pesquisar", "Search") }
    static func searchTheWeb(_ l: [String]) -> String { text(l, "Pesquisar na web", "Search the web") }
    static func noFavorites(_ l: [String]) -> String {
        text(l, "Você ainda não tem favoritos. Use Favoritos › Adicionar a Favoritos numa página.",
             "You have no favorites yet. Use Favorites › Add to Favorites on a page.")
    }
    static func errorTitle(_ l: [String]) -> String { text(l, "Não foi possível abrir a página", "Can't open the page") }
    static func errorHint(_ l: [String]) -> String {
        text(l, "Confira o endereço e a conexão, e use Atualizar para tentar de novo.",
             "Check the address and the connection, then use Refresh to try again.")
    }
    static func pageNotFound(_ l: [String]) -> String { text(l, "Esta página interna não existe.", "This built-in page doesn't exist.") }
    static func pageStopped(_ l: [String]) -> String {
        text(l, "A página parou de funcionar.", "The page stopped working.")
    }

    // MARK: Questions

    static func yes(_ l: [String]) -> String { text(l, "Sim", "Yes") }
    static func no(_ l: [String]) -> String { text(l, "Não", "No") }

    static func otherAppQuestion(scheme: String, _ l: [String]) -> String {
        let scheme = oneLine(scheme, limit: 40)
        return text(l, "Este link abre outro app (\(scheme)). Abrir?", "This link opens another app (\(scheme)). Open it?")
    }

    /// What a page's alert or confirm shows: who is talking, then the page's words, cut short.
    static func pageSays(host: String?, message: String, _ l: [String]) -> String {
        let who = oneLine(host ?? "", limit: 80)
        let intro = who.isEmpty ? text(l, "A página diz:", "The page says:") : text(l, "A página em \(who) diz:", "The page at \(who) says:")
        return intro + "\n\n" + String(message.prefix(1000))
    }

    static func htmlFiles(_ l: [String]) -> String { text(l, "Páginas da web (*.html; *.htm)", "Web pages (*.html; *.htm)") }
    static func allFiles(_ l: [String]) -> String { text(l, "Todos os arquivos (*.*)", "All files (*.*)") }
}
