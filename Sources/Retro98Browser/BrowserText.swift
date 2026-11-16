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

    // MARK: Favorites

    static func addFavorite(_ l: [String]) -> String { text(l, "Adicionar a Favoritos", "Add to Favorites") }
    static func organizeFavorites(_ l: [String]) -> String { text(l, "Organizar Favoritos…", "Organize Favorites…") }
    static func emptyList(_ l: [String]) -> String { text(l, "(vazio)", "(empty)") }
    static func favoriteAdded(_ l: [String]) -> String { text(l, "Página adicionada aos Favoritos.", "Page added to Favorites.") }
    static func favoriteAlreadyThere(_ l: [String]) -> String {
        text(l, "Esta página já está nos Favoritos.", "This page is already in Favorites.")
    }
    static func homePageChanged(_ l: [String]) -> String { text(l, "Página inicial alterada.", "Home page changed.") }

    // MARK: Menus

    static func menuFile(_ l: [String]) -> String { text(l, "Arquivo", "File") }
    static func menuEdit(_ l: [String]) -> String { text(l, "Editar", "Edit") }
    static func menuView(_ l: [String]) -> String { text(l, "Exibir", "View") }
    static func menuGo(_ l: [String]) -> String { text(l, "Ir", "Go") }
    static func menuWindow(_ l: [String]) -> String { text(l, "Janela", "Window") }
    static func menuHelp(_ l: [String]) -> String { text(l, "Ajuda", "Help") }

    static func newWindow(_ l: [String]) -> String { text(l, "Nova janela", "New Window") }
    static func newTab(_ l: [String]) -> String { text(l, "Nova guia", "New Tab") }
    static func openAddress(_ l: [String]) -> String { text(l, "Abrir endereço…", "Open Address…") }
    static func openFile(_ l: [String]) -> String { text(l, "Abrir arquivo…", "Open File…") }
    static func openDownloads(_ l: [String]) -> String { text(l, "Abrir a pasta Downloads", "Open the Downloads Folder") }
    static func closeTab(_ l: [String]) -> String { text(l, "Fechar guia", "Close Tab") }
    static func closeWindow(_ l: [String]) -> String { text(l, "Fechar janela", "Close Window") }

    static func undo(_ l: [String]) -> String { text(l, "Desfazer", "Undo") }
    static func redo(_ l: [String]) -> String { text(l, "Refazer", "Redo") }
    static func cut(_ l: [String]) -> String { text(l, "Recortar", "Cut") }
    static func copy(_ l: [String]) -> String { text(l, "Copiar", "Copy") }
    static func paste(_ l: [String]) -> String { text(l, "Colar", "Paste") }
    static func selectAll(_ l: [String]) -> String { text(l, "Selecionar tudo", "Select All") }
    static func findInPage(_ l: [String]) -> String { text(l, "Localizar nesta página…", "Find on This Page…") }

    static func zoomIn(_ l: [String]) -> String { text(l, "Aumentar", "Zoom In") }
    static func zoomOut(_ l: [String]) -> String { text(l, "Diminuir", "Zoom Out") }
    static func zoomReset(_ l: [String]) -> String { text(l, "Tamanho normal", "Actual Size") }

    static func nextTab(_ l: [String]) -> String { text(l, "Próxima guia", "Next Tab") }
    static func previousTab(_ l: [String]) -> String { text(l, "Guia anterior", "Previous Tab") }
    static func tabNumber(_ number: Int, _ l: [String]) -> String { text(l, "Guia \(number)", "Tab \(number)") }
    static func historyItem(_ l: [String]) -> String { text(l, "Histórico…", "History…") }
    static func clearData(_ l: [String]) -> String { text(l, "Limpar dados de navegação…", "Clear Browsing Data…") }
    static func useCurrentAsHome(_ l: [String]) -> String { text(l, "Usar a página atual como inicial", "Use the Current Page as Home") }
    static func useDefaultHome(_ l: [String]) -> String { text(l, "Voltar à página inicial padrão", "Go Back to the Default Home Page") }

    static func readme(_ l: [String]) -> String { text(l, "Leia-me", "Readme") }
    static func about(_ l: [String]) -> String { text(l, "Sobre o Retro98 Browser", "About Retro98 Browser") }
    static func hide(_ l: [String]) -> String { text(l, "Ocultar Retro98 Browser", "Hide Retro98 Browser") }
    static func hideOthers(_ l: [String]) -> String { text(l, "Ocultar outros", "Hide Others") }
    static func showAll(_ l: [String]) -> String { text(l, "Mostrar tudo", "Show All") }
    static func quit(_ l: [String]) -> String { text(l, "Encerrar Retro98 Browser", "Quit Retro98 Browser") }
    static func minimize(_ l: [String]) -> String { text(l, "Minimizar", "Minimize") }
    static func zoomWindow(_ l: [String]) -> String { text(l, "Zoom", "Zoom") }
    static func bringAllToFront(_ l: [String]) -> String { text(l, "Trazer todas para a frente", "Bring All to Front") }

    static func aboutCredits(_ l: [String]) -> String {
        text(l, "Um navegador secundário com moldura retrô. As páginas são desenhadas pelo WebKit que vem com o macOS.",
             "A secondary browser in a retro frame. Pages are drawn by the WebKit that comes with macOS.")
    }

    static func clearDataQuestion(_ l: [String]) -> String {
        text(l, "Isto apaga o histórico e os dados de sites (cookies, cache e logins). Os favoritos ficam.\n\nApagar?",
             "This clears the history and the site data (cookies, cache and logins). Favorites stay.\n\nClear?")
    }
    static func dataCleared(_ l: [String]) -> String { text(l, "Dados de navegação apagados.", "Browsing data cleared.") }

    // MARK: Small windows

    static func organizeTitle(_ l: [String]) -> String { text(l, "Organizar Favoritos", "Organize Favorites") }
    static func nameColumn(_ l: [String]) -> String { text(l, "Nome", "Name") }
    static func titleColumn(_ l: [String]) -> String { text(l, "Título", "Title") }
    static func visitedColumn(_ l: [String]) -> String { text(l, "Visitado", "Visited") }
    static func filterLabel(_ l: [String]) -> String { text(l, "Filtrar:", "Filter:") }
    static func open(_ l: [String]) -> String { text(l, "Abrir", "Open") }
    static func rename(_ l: [String]) -> String { text(l, "Renomear", "Rename") }
    static func delete(_ l: [String]) -> String { text(l, "Excluir", "Delete") }
    static func moveUp(_ l: [String]) -> String { text(l, "Para cima", "Move Up") }
    static func moveDown(_ l: [String]) -> String { text(l, "Para baixo", "Move Down") }
    static func close(_ l: [String]) -> String { text(l, "Fechar", "Close") }
    static func findTitle(_ l: [String]) -> String { text(l, "Localizar", "Find") }
    static func findWhat(_ l: [String]) -> String { text(l, "Localizar:", "Find what:") }
    static func findNext(_ l: [String]) -> String { text(l, "Localizar próxima", "Find Next") }
    static func findPrevious(_ l: [String]) -> String { text(l, "Localizar anterior", "Find Previous") }
    static func notFound(_ needle: String, _ l: [String]) -> String {
        let needle = oneLine(needle, limit: 100)
        return text(l, "Não foi possível encontrar \"\(needle)\" nesta página.", "Can't find \"\(needle)\" on this page.")
    }

    // MARK: Downloads

    static func downloadTitle(_ l: [String]) -> String { text(l, "Download de arquivo", "File Download") }
    static func cancel(_ l: [String]) -> String { text(l, "Cancelar", "Cancel") }
    static func toDownloads(_ l: [String]) -> String { text(l, "Para: Downloads", "To: Downloads") }

    /// "Salvando: a.zip de example.com"; without a server, just the name.
    static func saving(name: String, host: String, _ l: [String]) -> String {
        host.isEmpty ? text(l, "Salvando: \(name)", "Saving: \(name)") : text(l, "Salvando: \(name) de \(host)", "Saving: \(name) from \(host)")
    }

    static func receivedOfTotal(_ received: String, _ total: String, _ l: [String]) -> String {
        text(l, "\(received) de \(total)", "\(received) of \(total)")
    }

    static func downloadDone(name: String, _ l: [String]) -> String {
        text(l, "Download concluído: \(name)", "Download complete: \(name)")
    }

    static func downloadFailed(name: String, message: String, _ l: [String]) -> String {
        text(l, "Não foi possível baixar \(name).\n\n\(message)", "Couldn't download \(name).\n\n\(message)")
    }

    static func downloadKeptAsPart(name: String, part: String, _ l: [String]) -> String {
        text(l, "O download de \(name) terminou, mas o arquivo não pôde receber o nome final.\n\nEle ficou na pasta Downloads como \(part).",
             "The download of \(name) finished, but the file couldn't get its final name.\n\nIt was left in the Downloads folder as \(part).")
    }

    static func quitWithDownloads(_ l: [String]) -> String {
        text(l, "Há downloads em andamento. Sair cancela esses downloads.\n\nSair mesmo assim?",
             "There are downloads in progress. Quitting cancels them.\n\nQuit anyway?")
    }

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

    static func otherAppRefused(scheme: String, _ l: [String]) -> String {
        let scheme = oneLine(scheme, limit: 40)
        return text(l, "Link para outro app (\(scheme)) não aberto: você respondeu Não nesta página.",
                    "Link to another app (\(scheme)) not opened: you answered No on this page.")
    }

    static func keepShowingMessages(_ l: [String]) -> String {
        text(l, "Esta página já mostrou várias mensagens.\n\nContinuar mostrando as mensagens dela?",
             "This page has shown several messages.\n\nKeep showing its messages?")
    }
    static func messagesSilenced(_ l: [String]) -> String {
        text(l, "As mensagens desta página foram silenciadas.", "This page's messages were silenced.")
    }

    static func favoritesNotSaved(_ l: [String]) -> String {
        text(l, "Não foi possível gravar os Favoritos. A mudança vale até você sair do Navegador, mas pode se perder depois.",
             "Couldn't save the Favorites. The change holds until you quit the Browser, but may be lost after that.")
    }

    static func damagedFile(copy: URL, _ l: [String]) -> String {
        text(l, "Um arquivo do Navegador não pôde ser lido e a lista começou vazia. O arquivo antigo foi guardado como:\n\n\(copy.path)",
             "A Browser file couldn't be read and the list started empty. The old file was kept as:\n\n\(copy.path)")
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
