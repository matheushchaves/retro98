# Retro98 Fase 8 — Navegador retrô (WebKit) — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o Retro98 Browser (Navegador):
- uma janela 98 com menus, barra de ferramentas (Voltar, Avançar, Parar, Atualizar, Página inicial, Favoritos, Histórico), barra de endereço e barra de status com o progresso do carregamento;
- abas no estilo 98;
- downloads para `~/Downloads` com diálogo de progresso;
- favoritos e histórico;
- as páginas são desenhadas pelo WebKit do macOS (`WKWebView`), como elas são hoje: só a moldura é retrô.

**Architecture:**
- **`Retro98UI`** ganha `RetroTabStrip` (as abas, que a spec lista entre os componentes da base e ainda não existem) e os ícones do navegador.
- **`Retro98Browser`** (app novo) tem três camadas:
  - **Regras sem tela:** o que foi digitado no endereço, favoritos, histórico, nomes e arquivos de download, decisões de navegação, páginas internas (início e erro).
  - **A página atrás de um protocolo (`BrowserPage`):** a janela, as abas e os testes falam com o protocolo. `WebKitPage` é a única parte que conhece o `WKWebView`.
  - **Janela e app:** abas, barra de ferramentas, endereço, status, menus, janelas de favoritos e histórico, downloads.
- **Scripts:** a peça `browser` no instalador, a remoção no desinstalador (os favoritos e o histórico da pessoa ficam) e dois argumentos novos no `build-app.sh`.

**Tech Stack:** Swift 6, AppKit, WebKit (`WKWebView`, `WKDownload`, `WKURLSchemeHandler`), Swift Testing, bash.

**Spec:** `docs/superpowers/specs/2026-11-10-retro-desktop-design.md`, seção "Fase 8 — Navegador retrô (motor WebKit)", mais as seções 3 a 5. As Fases 1 a 7 estão no `main` (0.10.0).

## Global Constraints

- **Herança:** tudo das fases anteriores continua valendo:
  - pixel 1x, Tahoma 13 e negrito 12 na interface, paleta clássica, só material original;
  - pt-BR e en, só APIs públicas;
  - Safari, Chrome e o navegador padrão do macOS ficam intactos.
- **Nomes [minha escolha]:**
  - App `Retro98 Browser`, produto `Retro98Browser`, id `io.github.matheushchaves.retro98.browser`, em `~/Applications/Retro98/Retro98 Browser.app`.
  - Na janela: "Navegador" / "Browser". Título: `<título da página> - Navegador`; sem título de página, só `Navegador`.
  - Nunca "Internet Explorer", nem o "e" azul. O ícone é um globo original em pixel art.
- **Navegador secundário [spec]:**
  - Não se registra para `http`/`https`: nunca aparece como opção de navegador padrão do macOS.
  - Aparece em "Abrir com" para arquivos HTML (`public.html`, `LSHandlerRank Alternate`, papel `Viewer`).
  - Sem extensões, sem logins do Chrome ou do Safari, sem gerenciador de senhas, sem chaves de acesso (passkeys), sem câmera, microfone ou localização.
- **Testes isolados, mais estes cuidados:**
  - Nenhum teste usa a rede nem cria `WKWebView`: as janelas recebem páginas falsas (`FakePage`).
  - Nenhum teste toca a pasta real de suporte, a pasta `~/Downloads` real, as preferências reais (`BrowserPreferences.memory`) ou abre outro app (o `opener` é um roteiro).
  - Nenhum teste abre diálogo ou caixa de mensagem na tela.
  - Os scripts continuam com o `retro98-settings` falso, assinatura ad-hoc, `RETRO98_TCCUTIL`/`RETRO98_DEFAULTS`/`RETRO98_FONTS_DIR`/`RETRO98_SUBLIME_PACKAGES` e pastas temporárias.
- **Endereço digitado [minha escolha]** (`AddressInput.resolve`), nesta ordem, depois de tirar espaços das pontas:
  1. Vazio → nada.
  2. `about:home` → a página inicial interna. `about:blank` → ela mesma.
  3. Começa com `http://`, `https://` ou `file://` → esse endereço.
  4. Começa com `/` ou `~` → arquivo local (com `~` expandido para a pasta pessoal).
  5. Sem espaços e com cara de endereço → ganha `https://` na frente. Tem cara de endereço o que tem um ponto no nome do servidor, ou é `localhost`, ou termina em `:<porta>`. `localhost`, endereços IPv4 e nomes `.local` ganham `http://`.
  6. Todo o resto é busca: `https://duckduckgo.com/?q=<texto codificado>`.
- **Página inicial [minha escolha]:**
  - Padrão `about:home`: uma página interna original (cinza `#C0C0C0`, título azul-marinho), com um campo de busca do DuckDuckGo e a lista de favoritos. Sem JavaScript e sem nada baixado da rede.
  - "Ir › Usar a página atual como inicial" troca por um endereço; "Ir › Voltar à página inicial padrão" desfaz.
  - Por dentro a página interna é `retro98://home/`, servida por um `WKURLSchemeHandler`; a barra de endereço mostra `about:home`.
- **Página de erro [minha escolha]:**
  - Uma falha ao abrir mostra uma página interna com o motivo (o texto do erro do macOS) e o endereço, via `loadSimulatedRequest`. O endereço que falhou fica na barra, e Atualizar tenta de novo.
  - Não geram página de erro: navegação cancelada (`NSURLErrorCancelled`) e carregamento que virou download (`WebKitErrorDomain` 102).
  - Erro de certificado é erro: não há botão para ignorar.
  - Se o processo da página cair, aparece a página de erro com "A página parou de funcionar"; não recarrega sozinho.
- **WebKit [minha escolha]:**
  - Dados de sites no armazenamento padrão do app (`WKWebsiteDataStore.default()`): os logins ficam entre uma abertura e outra.
  - `applicationNameForUserAgent = "Version/18.0 Safari/605.1.15"`, para os sites tratarem o navegador como um Safari.
  - `javaScriptCanOpenWindowsAutomatically = false` (janelas que a página abre sem clique são bloqueadas) e `isElementFullscreenEnabled = true`.
  - O `Info.plist` ganha `NSAllowsArbitraryLoadsInWebContent`, para páginas `http://` abrirem.
  - Link com `target="_blank"` ou `window.open` a partir de um clique abre em nova aba, logo à direita. ⌘-clique num link abre em nova aba em segundo plano.
  - `alert` e `confirm` usam `RetroMessageBox`. "Escolher arquivo" numa página usa o diálogo retrô de abrir (um arquivo por vez). `prompt()` e a senha de autenticação HTTP não têm diálogo nesta fase: seguem o comportamento padrão (sem resposta).
  - O menu de contexto da página é o do WebKit.
- **Links para outros apps [minha escolha]** (`mailto:`, `tel:`, `zoommtg:` e qualquer esquema fora de `http`, `https`, `file`, `about`, `data`, `blob`, `retro98`):
  - No quadro principal, o navegador pergunta "Este link abre outro app (`<esquema>`). Abrir?" com Sim e Não. Sim entrega o endereço ao macOS.
  - Depois de um Não, novos pedidos da mesma página são recusados sem perguntar, até a pessoa navegar.
  - Em quadros internos, são recusados sem perguntar.
- **Abas [minha escolha]:**
  - Faixa de 24 pt entre a barra de endereço e a página. Cada aba tem título e um "×"; no fim da fila, um botão "+" de 22 pt.
  - Largura: `min(160, max(60, (largura − 26) / n))`, arredondada para baixo. Se nem com 60 pt couberem, a faixa rola o necessário para a aba selecionada aparecer inteira.
  - Aba nova pelo "+" ou ⌘T vai para o fim, abre a página inicial e deixa o foco no endereço. Aba aberta por uma página fica logo à direita dela.
  - Fechar a aba selecionada seleciona a da direita; se não houver, a da esquerda. Fechar a última aba fecha a janela. Clique do meio numa aba fecha a aba.
  - Título da aba: o da página; sem título, o servidor; sem endereço, "Nova guia"/"New Tab". Sempre uma linha só, cortada com reticências.
  - Sem arrastar para reordenar e sem restaurar as abas na próxima abertura.
- **Janela [minha escolha]:**
  - Conteúdo 900×620. De cima para baixo: menu 22, linha 2, barra de ferramentas 42, linha 2, endereço 27, abas 24, página, status 24.
  - Barra de endereço: rótulo "Endereço"/"Address", campo e botão "Ir"/"Go". Enter ou "Ir" navega; Esc devolve o endereço da página.
  - Barra de status: à esquerda, o texto (endereço do link sob o ponteiro, "Abrindo página…"/"Opening page…" ou "Concluído"/"Done"); à direita, 150 pt com a barra de progresso em blocos enquanto carrega.
  - O endereço do link sob o ponteiro chega por um script pequeno injetado nas páginas. Ele é só texto: uma linha, cortado para caber.
- **Atalhos [minha escolha]:**

  | Comando | Atalho |
  |---|---|
  | Nova janela, nova guia | ⌘N, ⌘T |
  | Abrir endereço (foco na barra), abrir arquivo | ⌘L, ⌘O |
  | Fechar guia, fechar janela | ⌘W, ⌘⇧W |
  | Voltar, avançar, página inicial | ⌘[, ⌘], ⌘⇧H |
  | Parar, atualizar | ⌘., ⌘R |
  | Próxima guia, guia anterior | ⌃⇥, ⌃⇧⇥ (e ⌘⇧], ⌘⇧[) |
  | Guia 1 a 9 | ⌘1 a ⌘9 |
  | Aumentar, diminuir, tamanho normal | ⌘+, ⌘−, ⌘0 |
  | Localizar nesta página, localizar próxima | ⌘F, ⌘G |
  | Adicionar a Favoritos, Histórico | ⌘D, ⌘Y |
  | Abrir a pasta Downloads | ⌥⌘L |

- **Menus [minha escolha]:** Arquivo, Editar, Exibir, Ir, Favoritos e Ajuda na janela; a barra do macOS tem os mesmos, mais o menu do app e Janela.
  - **Arquivo:** Nova janela, Nova guia, Abrir endereço…, Abrir arquivo…, —, Abrir a pasta Downloads, —, Fechar guia, Fechar janela.
  - **Editar:** Desfazer, Refazer, —, Recortar, Copiar, Colar, Selecionar tudo, —, Localizar nesta página…, Localizar próxima.
  - **Exibir:** Parar, Atualizar, —, Aumentar, Diminuir, Tamanho normal.
  - **Ir:** Voltar, Avançar, Página inicial, —, Próxima guia, Guia anterior, —, Histórico…, Limpar dados de navegação…, —, Usar a página atual como inicial, Voltar à página inicial padrão.
  - **Favoritos:** Adicionar a Favoritos, Organizar Favoritos…, —, a lista.
  - **Ajuda:** Leia-me, —, Sobre.
- **Favoritos e histórico [minha escolha]:**
  - Arquivos JSON em `<pasta de suporte>/Browser/`: `favorites.json` e `history.json`, gravados de forma atômica a cada mudança.
  - **Favoritos:** lista simples e ordenada de título e endereço, sem pastas. Adicionar um endereço que já está na lista não duplica.
  - **Histórico:** uma entrada por endereço (título e última visita), a mais recente primeiro, no máximo 2.000. Só entram `http`, `https` e `file`, e só depois de a página abrir sem erro.
  - **Arquivo danificado:** um arquivo que não pode ser lido como JSON é guardado como `favorites-damaged.json` (ou `history-damaged.json`) antes da primeira gravação, e a lista começa vazia.
  - **Limpar dados de navegação…:** pergunta antes; apaga o histórico e os dados de sites (cookies, cache, logins). Os favoritos ficam.
- **Downloads [minha escolha]:**
  - Vira download: resposta que o WebKit não sabe mostrar, resposta com `Content-Disposition: attachment` e link com o atributo `download`.
  - **Nome:** o sugerido, limpo: só o último componente, `:` vira `-`, pontos iniciais saem, e vazio vira `download`.
  - **Durante:** o arquivo é gravado como `<nome>.download` em `~/Downloads`. Ao terminar, é movido para `<nome>`; se já existir, para `nome (2).ext`, `nome (3).ext`… Nunca substitui nada.
  - **Cancelar ou falhar:** o `.download` é apagado. Falha mostra uma caixa de erro.
  - **Diálogo:** um `RetroProgressDialog` por download, não modal: "Salvando: `<nome>` de `<servidor>`", "`<recebido>` de `<total>`" (só o recebido quando o total é desconhecido) e Cancelar.
  - **Ao terminar:** o diálogo fecha e a barra de status das janelas mostra "Download concluído: `<nome>`".
  - **Sair com downloads em andamento:** pergunta "Há downloads em andamento. Sair cancela esses downloads. Sair mesmo assim?" com Sim e Não.
- **Peça e versão:** `browser` / `nobrowser`; pergunta "Instalar o Navegador (motor WebKit)?"; padrão `base shell prompt notepad themes browser`; versão `0.11.0`, build `12`.
- **Desinstalar [minha escolha]:** remove o app. A pasta `Browser` (favoritos e histórico da pessoa) fica, e o desinstalador diz onde ela está. Recusar a peça depois de instalada faz o mesmo.

## Review Focus

1. **Download com nome repetido, cancelado, com falha, ou com o app encerrando no meio:** nada é substituído, e nenhum arquivo pela metade fica com o nome final. Testes da Task 1 e da Task 5.
2. **Arquivo de favoritos ou histórico danificado, ou pasta sem escrita:** os favoritos nunca somem em silêncio; a cópia danificada fica guardada e o app continua abrindo. Testes da Task 1.
3. **Texto hostil vindo da página** (título com HTML, com quebras de linha ou com 10.000 letras; endereço de link falso no script do ponteiro; endereço com `<script>` na página de erro): abas, status e páginas internas tratam tudo como texto. Testes das Tasks 2, 3 e 4.
4. **Links para outros apps e janelas abertas pela página:** nunca abre outro app sem perguntar; depois de um Não, a página não consegue repetir a pergunta em laço; janelas sem clique são bloqueadas. Testes das Tasks 3 e 4.
5. **Fechar:** a última aba, uma aba ainda carregando, uma aba que abriu outra, a janela com várias abas. Toda página fechada é encerrada (`close()`), para o som parar. Testes da Task 4.

## Estrutura de arquivos

| Arquivo | Responsabilidade |
|---|---|
| `Package.swift` | Alvos `Retro98Browser` e `Retro98BrowserTests` |
| `Sources/Retro98UI/RetroTabStrip.swift` | As abas: layout e desenho |
| `Sources/Retro98UI/BrowserIcons.swift`, `Sources/retro98-tools/main.swift` | Ícones do navegador e o `iconset browser` |
| `Sources/Retro98Browser/AddressInput.swift` | Texto digitado → destino |
| `Sources/Retro98Browser/BrowserStorage.swift` | Ler e gravar um arquivo JSON, guardando o danificado |
| `Sources/Retro98Browser/Favorites.swift`, `History.swift` | As duas listas |
| `Sources/Retro98Browser/DownloadFiles.swift` | Nome limpo, nome livre, arquivo `.download` |
| `Sources/Retro98Browser/BrowserPreferences.swift` | Página inicial lembrada |
| `Sources/Retro98Browser/BrowserText.swift` | Textos pt-BR/en |
| `Sources/Retro98Browser/BrowserPages.swift` | HTML das páginas internas (início e erro) |
| `Sources/Retro98Browser/NavigationPolicy.swift` | Decisões de navegação e de download, erros silenciosos |
| `Sources/Retro98Browser/BrowserPage.swift` | O protocolo da página |
| `Sources/Retro98Browser/WebKitPage.swift`, `WebKitSupport.swift` | A página real: `WKWebView`, delegados, página interna, script do ponteiro |
| `Sources/Retro98Browser/BrowserServices.swift` | Perguntas, diálogos e o que a janela recebe de fora |
| `Sources/Retro98Browser/BrowserWindowController.swift`, `BrowserWindowController+Commands.swift`, `AddressBar.swift` | A janela, as abas e os comandos |
| `Sources/Retro98Browser/Downloads.swift`, `WebKitDownloads.swift` | Downloads em andamento e a ligação com o `WKDownload` |
| `Sources/Retro98Browser/FavoritesWindow.swift`, `HistoryWindow.swift`, `FindInPageDialog.swift` | As três janelas pequenas |
| `Sources/Retro98Browser/BrowserMenus.swift`, `AppDelegate.swift`, `main.swift` | Menus, várias janelas, abrir de fora, encerrar |
| `scripts/build-app.sh`, `scripts/common.sh`, `install.sh`, `uninstall.sh` | Peça `browser`, papel do documento, conteúdo web, versão |
| `README.md`, `README.pt-BR.md` | Seção do Navegador, situação |
| `Tests/Retro98BrowserTests/…`, `Tests/Retro98UITests/RetroTabStripTests.swift`, `Tests/scripts/…` | Testes de cada parte |

---

### Task 1: Regras sem tela (endereço, favoritos, histórico, arquivos de download)

**Files:**
- Modify `Package.swift`: product and target `Retro98Browser` (dependencies `Retro98UI`, `Retro98FilesCore`, `Retro98Settings`, `Retro98Dialogs`) and test target `Retro98BrowserTests` (dependencies `Retro98Browser`, `Retro98UI`).
- Create `Sources/Retro98Browser/AddressInput.swift`, `BrowserStorage.swift`, `Favorites.swift`, `History.swift`, `DownloadFiles.swift`, `BrowserPreferences.swift`, and a placeholder `main.swift` (replaced in Task 7).
- Test `Tests/Retro98BrowserTests/TestSupport.swift` (`temporaryFolder()`, as in the Notepad's), `AddressInputTests.swift`, `StoresTests.swift`, `DownloadFilesTests.swift`.

**Interfaces (Produces):**
```swift
enum AddressTarget: Equatable, Sendable { case home, url(URL) }

enum AddressInput {
    static let searchPrefix = "https://duckduckgo.com/?q="
    static let homeText = "about:home"
    static let homeURL = URL(string: "retro98://home/")!
    static func resolve(_ text: String, home: URL) -> AddressTarget?
    /// What the address bar shows for a page: "about:home" for the built-in home, the URL's text otherwise, "" for none.
    static func display(_ url: URL?) -> String
}

/// One JSON file. Reading a damaged file moves it aside as "<name>-damaged.json" and returns nil.
struct BrowserStorage<Value: Codable> {
    let file: URL
    func load() -> Value?
    func save(_ value: Value) throws          // creates the folder; atomic
}

struct Favorite: Codable, Equatable, Sendable { var title: String; var url: URL }

@MainActor final class FavoritesStore {
    private(set) var items: [Favorite]
    var onChange: (() -> Void)?
    /// False when the last change could not be written (the list in memory still has it).
    private(set) var isSaved: Bool
    init(file: URL)
    @discardableResult func add(title: String, url: URL) -> Bool   // false when the URL is already there
    func remove(at index: Int)
    func move(from index: Int, to destination: Int)
    func rename(at index: Int, to title: String)                   // blank titles are ignored
}

struct HistoryEntry: Codable, Equatable, Sendable { var url: URL; var title: String; var lastVisited: Date }

@MainActor final class HistoryStore {
    static let limit = 2000
    private(set) var entries: [HistoryEntry]                       // newest first
    var onChange: (() -> Void)?
    init(file: URL)
    func record(url: URL, title: String, at date: Date)
    func setTitle(_ title: String, for url: URL)
    func search(_ text: String) -> [HistoryEntry]                  // title or address, ignoring case and accents; "" is all
    func remove(_ url: URL)
    func clear()
}

enum DownloadNames {
    static func clean(_ suggested: String) -> String
    /// `name` if nothing in `folder` has it (as a file or as "<name>.download"), else "stem (2).ext", "stem (3).ext"…
    static func free(_ name: String, in folder: URL, fileManager: FileManager = .default) -> String
}

/// One download's file: written as "<name>.download", moved to a free final name when done.
struct DownloadFile: Equatable {
    let folder: URL
    let name: String
    var partURL: URL { get }
    init(suggestedName: String, folder: URL, fileManager: FileManager = .default)
    func finish(fileManager: FileManager = .default) throws -> URL
    func discard(fileManager: FileManager = .default)
}

final class BrowserPreferences: @unchecked Sendable {              // like NotepadPreferences
    init(defaults: UserDefaults)
    static func memory(homePage: String = AddressInput.homeText) -> BrowserPreferences
    var homePage: String { get set }                               // default "about:home"
}
```

- [ ] **Step 1: Write the failing tests.**
  - **`AddressInputTests`** (home is `/Users/ana`):
    - `emptyIsNothing`: `""` and `"   "` → `nil`.
    - `homeAndBlank`: `"about:home"` → `.home`; `"about:blank"` → `.url(about:blank)`.
    - `fullAddressesStay`: `"https://example.com/a?b=1"`, `"http://example.com"`, `"file:///tmp/a.html"` → the same URL.
    - `localPaths`: `"/tmp/a.html"` → `file:///tmp/a.html`; `"~/site/index.html"` → `file:///Users/ana/site/index.html`.
    - `hostsGetHTTPS`: `"example.com"` → `https://example.com`; `"example.com/a b"` has a space → search; `"sub.example.com:8443/x"` → `https://sub.example.com:8443/x`.
    - `localHostsGetHTTP`: `"localhost"` → `http://localhost`; `"localhost:3000/app"` → `http://localhost:3000/app`; `"192.168.0.10"` → `http://192.168.0.10`; `"impressora.local"` → `http://impressora.local`; `"servidor:8080"` → `https://servidor:8080`.
    - `everythingElseSearches`: `"pão de queijo"` → `https://duckduckgo.com/?q=p%C3%A3o%20de%20queijo`; `"swift"` → `…?q=swift`; `"a&b=c"` → `…?q=a%26b%3Dc`; `"what is node.js"` → search.
    - `displayShowsHomeAsAbout`: `display(homeURL) == "about:home"`, `display(nil) == ""`, `display(https://example.com/) == "https://example.com/"`.
  - **`StoresTests`** (temp folder):
    - `favoritesRoundTrip`: add two, new store on the same file has both in order.
    - `addingTheSameAddressTwiceKeepsOne`: second `add` returns `false`, `items.count == 1`.
    - `moveRenameRemove`: `move(from: 0, to: 1)` swaps; `rename(at:to: "  ")` keeps the old title; out-of-range indexes change nothing.
    - `damagedFavoritesAreKeptAside`: file with `"{not json"` → `items.isEmpty`, `favorites-damaged.json` holds the same bytes, and after `add` the new `favorites.json` is valid.
    - `unwritableFolderKeepsTheListInMemory`: folder with mode `0o500` → `add` returns `true`, `items.count == 1`, `isSaved == false`.
    - `historyNewestFirstOnePerAddress`: record A, B, A → `entries.map(\.url) == [A, B]` with A's date the later one.
    - `historyIgnoresOtherSchemes`: `about:blank`, `retro98://home/`, `data:` → nothing recorded.
    - `historyKeepsTheLimit`: 2,005 records → 2,000 entries, the 5 oldest gone.
    - `historySearchIgnoresCaseAndAccents`: title "Pão de Queijo" matches `"pao"`; address `example.com/Receita` matches `"receita"`.
    - `historyRemoveAndClear` and `damagedHistoryIsKeptAside`.
  - **`DownloadFilesTests`** (temp folder):
    - `cleanNames`: `"a/b/c.zip"` → `"c.zip"`; `"..\u{0}evil"` → `"evil"`; `"a:b.txt"` → `"a-b.txt"`; `""` and `"..."` → `"download"`.
    - `freeNames`: empty folder → `"a.txt"`; with `a.txt` → `"a (2).txt"`; with `a.txt` and `a (2).txt` → `"a (3).txt"`; with only `a.txt.download` → `"a (2).txt"`; `"arquivo"` (no extension) with `arquivo` → `"arquivo (2)"`.
    - `finishMovesToTheFinalName`: write the part file, `finish()` → the returned URL has the content and the part is gone.
    - `finishNeverReplaces`: `a.txt` appears between `init` and `finish()` → result is `a (2).txt` and the old `a.txt` keeps its content.
    - `discardRemovesThePart`; `discardWithoutAPartIsQuiet`.
    - `twoDownloadsOfTheSameNameGetDifferentParts`.
  - **Preferences:** `homePageDefaultsToAboutHome`, `homePageIsRemembered` (memory).
- [ ] **Step 2: Run** `swift test --filter Retro98BrowserTests`. Expected: FAIL to compile (types missing).
- [ ] **Step 3: Implement.** Stores write on every change and set `isSaved`; they never throw to the caller. `HistoryStore.record` ignores schemes other than `http`, `https` and `file`.
- [ ] **Step 4: Run** `swift test --filter Retro98BrowserTests`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: browser rules for addresses, favorites, history and download files`.

### Task 2: Peças da base (abas e ícones)

**Files:**
- Create `Sources/Retro98UI/RetroTabStrip.swift`, `Sources/Retro98UI/BrowserIcons.swift`.
- Modify `Sources/retro98-tools/main.swift` (`iconset browser`, usage text).
- Test `Tests/Retro98UITests/RetroTabStripTests.swift`, `Tests/Retro98UITests/BrowserIconsTests.swift`.

**Interfaces (Produces):**
```swift
public struct TabStripLayout: Equatable, Sendable {
    public let tabs: [CGRect]          // in the strip's coordinates, already scrolled
    public let closeBoxes: [CGRect]
    public let newButton: CGRect
}

@MainActor public final class RetroTabStrip: PixelView {
    nonisolated public static let height: CGFloat = 24
    nonisolated public static let maxTabWidth: CGFloat = 160, minTabWidth: CGFloat = 60, newButtonWidth: CGFloat = 22
    public var titles: [String] { didSet }
    public var selected: Int { didSet }
    public var onSelect: ((Int) -> Void)?
    public var onClose: ((Int) -> Void)?
    public var onNew: (() -> Void)?
    nonisolated public static func layout(count: Int, selected: Int, width: CGFloat) -> TabStripLayout
    /// One line that fits the tab: line breaks become spaces, long titles end in "…".
    nonisolated public static func label(_ title: String, tabWidth: CGFloat) -> String
}

public enum BrowserIcons {
    public static let app: PixelIcon, appSmall: PixelIcon             // 32 and 16: an original globe
    public static let stop, refresh, home, favorites, history, page: PixelIcon   // 16×16
}
```

- [ ] **Step 1: Write the failing tests.**
  - `tabsShareTheWidth`: `layout(count: 3, selected: 0, width: 800)` → three tabs 160 wide starting at x 2, side by side; `newButton.minX == tabs[2].maxX + 2`.
  - `tabsShrinkToFit`: `count: 10, width: 800` → each `floor((800 − 26) / 10) = 77` wide.
  - `tabsNeverGoBelowTheMinimum`: `count: 30, width: 800` → every tab 60 wide.
  - `selectedTabIsAlwaysVisible`: `count: 30, selected: 29, width: 800` → `tabs[29].minX >= 0` and `tabs[29].maxX <= 800 − 26`; with `selected: 0` → `tabs[0].minX == 2`.
  - `closeBoxSitsInsideItsTab`: every close box is 14×14 and inside its tab.
  - `noTabsStillHasTheNewButton`: `count: 0` → `tabs.isEmpty`, `newButton.minX == 2`.
  - `labelIsOneLine`: `label("a\nb\tc", tabWidth: 160) == "a b c"`; a 10,000-letter title returns a string whose `PixelText.width` fits `tabWidth − 30` and ends in "…"; `label("", …) == ""`.
  - `clicksReachTheRightCallback` (view 800×24 with 3 titles): mouse down in tab 1's body → `onSelect(1)`; in tab 1's close box → `onClose(1)` and no `onSelect`; in the new button → `onNew`; other-mouse (middle) down on tab 2 → `onClose(2)`.
  - `iconsHaveTheRightSizes`: `app` 32×32, `appSmall` 16×16, the six toolbar icons 16×16, and no two of them draw the same pixels.
- [ ] **Step 2: Run** `swift test --filter "RetroTabStripTests|BrowserIconsTests"`. Expected: FAIL to compile.
- [ ] **Step 3: Implement.**
  - **Look:** raised tabs with the classic bevel on the top and sides; the selected one is 2 px taller, has no bottom line and its label is not bold; the others sit on a `#C0C0C0` strip with a white line under them. The "×" and "+" are drawn in pixels, sunken while pressed.
  - **Icons:** drawn with `Sketch`, as in `ControlPanelIcons`. Stop: a red "×" on a page. Refresh: two curved arrows. Home: a small house. Favorites: a folder with a star. History: a clock. Page: a sheet with a folded corner.
  - `retro98-tools iconset browser` uses `BrowserIcons.app`/`appSmall`.
- [ ] **Step 4: Run** `swift test --filter Retro98UITests`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: retro tab strip and browser icons`.

### Task 3: A página (protocolo, páginas internas, decisões e WebKit)

**Files:**
- Create `Sources/Retro98Browser/BrowserText.swift`, `BrowserPages.swift`, `NavigationPolicy.swift`, `BrowserPage.swift`, `WebKitPage.swift`, `WebKitSupport.swift`.
- Test `Tests/Retro98BrowserTests/BrowserPagesTests.swift`, `NavigationPolicyTests.swift`, `BrowserTextTests.swift`.

**Interfaces (Produces):**
```swift
enum BrowserPages {
    static func escape(_ text: String) -> String                       // & < > " '
    static func home(favorites: [Favorite], languages: [String]) -> String
    static func error(message: String, url: URL?, languages: [String]) -> String
}

enum NavigationDecision: Equatable, Sendable { case allow, download, newTab, askOtherApp, cancel }

enum NavigationPolicy {
    static let webSchemes: Set<String>     // http, https, file, about, data, blob, retro98
    static func decide(scheme: String?, isMainFrame: Bool, isCommandClick: Bool, wantsDownload: Bool,
                       otherAppsRefused: Bool) -> NavigationDecision
    static func decideResponse(canShow: Bool, isAttachment: Bool) -> NavigationDecision   // .allow or .download
    /// Cancelled loads and loads that became downloads show no error page.
    static func isSilent(_ error: Error) -> Bool
}

/// One web page as the window sees it. `WebKitPage` is the real one; tests use a fake.
@MainActor protocol BrowserPage: AnyObject {
    var view: NSView { get }
    var url: URL? { get }
    var title: String { get }
    var isLoading: Bool { get }
    var progress: Double { get }                    // 0...1
    var canGoBack: Bool { get }
    var canGoForward: Bool { get }
    /// Any of the properties above changed.
    var onChange: (() -> Void)? { get set }
    /// A page finished opening without error (for the history).
    var onVisit: ((URL, String) -> Void)? { get set }
    /// The link under the pointer, or nil when it left.
    var onHover: ((String?) -> Void)? { get set }
    /// The page opened another page (a new tab): the new page, and whether it stays in the background.
    var onNewPage: ((BrowserPage, Bool) -> Void)? { get set }
    var onClose: (() -> Void)? { get set }          // window.close() from the page
    func load(_ target: AddressTarget)
    func goBack(); func goForward(); func reload(); func stop()
    func find(_ text: String, backwards: Bool, completion: @escaping (Bool) -> Void)
    var zoom: Double { get set }                    // 1 is normal
    func close()                                    // stops loading and media; the page is not used again
}

/// What every real page shares (the window's services and the download hook).
@MainActor final class WebKitEnvironment {
    init(favorites: FavoritesStore, prompter: BrowserPrompter, dialogs: BrowserDialogs, opener: @escaping (URL) -> Void,
         languages: [String])
    var onDownload: ((WKDownload) -> Void)?
    func makePage() -> BrowserPage
    func clearWebsiteData(completion: @escaping () -> Void)
}
```
`BrowserPrompter` and `BrowserDialogs` are declared here in `BrowserPage.swift` so `WebKitPage` compiles; Task 4 adds their live versions:
```swift
@MainActor protocol BrowserPrompter: AnyObject {
    func ask(_ message: String, languages: [String]) -> Bool           // Sim / Não
    func tell(_ message: String, icon: MessageBoxIcon, languages: [String])
}
@MainActor protocol BrowserDialogs: AnyObject {
    func chooseFileToOpen(in folder: URL, languages: [String]) -> URL?
}
```

- [ ] **Step 1: Write the failing tests.**
  - **`BrowserPagesTests`:**
    - `escapeCoversTheFiveCharacters`: `escape("<a href=\"x\">'&'</a>") == "&lt;a href=&quot;x&quot;&gt;&#39;&amp;&#39;&lt;/a&gt;"`.
    - `homeListsFavoritesEscaped`: a favorite titled `<script>alert(1)</script>` with URL `https://example.com/?a="b"` → the HTML has no `<script>` tag at all, contains `&lt;script&gt;`, and the link's `href` is `https://example.com/?a=%22b%22` inside double quotes.
    - `homeHasTheSearchForm`: contains `action="https://duckduckgo.com/"` and `name="q"`.
    - `homeWithoutFavoritesSaysSo`: contains the "no favorites yet" text in pt and en.
    - `homeNeedsNothingFromTheNetwork`: no `src=`, no `<link`, no `@import`, no `url(`.
    - `errorPageEscapesTheAddress`: URL `https://example.com/<script>` and message `a<b` → no `<script>`, has `a&lt;b`.
    - `pagesAreInBothLanguages`: `["pt-BR"]` has "Página inicial"; `["en"]` has "Home".
  - **`NavigationPolicyTests`:**
    - `webSchemesLoad`: `http`, `https`, `file`, `about`, `data`, `blob`, `retro98`, any letter case → `.allow`.
    - `commandClickOpensATab`: `https`, main frame, command click → `.newTab`.
    - `downloadLinksDownload`: `wantsDownload: true` → `.download`, even with command click.
    - `otherSchemesAsk`: `mailto`, `tel`, `zoommtg` in the main frame → `.askOtherApp`.
    - `otherSchemesInFramesAreCancelled`: `isMainFrame: false` → `.cancel`.
    - `afterARefusalOtherSchemesAreCancelled`: `otherAppsRefused: true` → `.cancel`.
    - `missingSchemeIsCancelled`: `nil` → `.cancel`.
    - `responses`: `(canShow: true, isAttachment: false)` → `.allow`; `(true, true)` → `.download`; `(false, false)` → `.download`.
    - `silentErrors`: `NSError(NSURLErrorDomain, NSURLErrorCancelled)` and `NSError("WebKitErrorDomain", 102)` → `true`; `NSURLErrorNotConnectedToInternet` → `false`.
  - **`BrowserTextTests`:** `windowTitle("Exemplo", ["pt-BR"]) == "Exemplo - Navegador"`; `windowTitle("", ["en"]) == "Browser"`; `otherAppQuestion(scheme: "mailto", ["pt-BR"])` contains `mailto`; `tabTitle(pageTitle: "", url: https://example.com/a, l) == "example.com"`; `tabTitle(pageTitle: "", url: nil, ["pt-BR"]) == "Nova guia"`; `tabTitle(pageTitle: "", url: AddressInput.homeURL, ["pt-BR"]) == "Página inicial"`.
- [ ] **Step 2: Run** `swift test --filter Retro98BrowserTests`. Expected: FAIL to compile.
- [ ] **Step 3: Implement the rules and texts**, then `WebKitPage` and `WebKitSupport` (not unit-tested: they are the `WKWebView` wiring, checked by hand after the merge).
  - **Configuration** (one per environment, shared by its pages): the values in Global Constraints; `setURLSchemeHandler` for `retro98` (answers `retro98://home/` with `BrowserPages.home` built at that moment, anything else with a 404); a user script at document end, in all frames, that posts the `href` of the link under the pointer (or `""`) to the message handler `retro98Hover`.
  - **Message handler:** takes only a `String` body, at most 2,000 characters, replaces line breaks by spaces; `""` → `onHover(nil)`.
  - **Loading:** `.home` loads `retro98://home/`; a `file:` URL uses `loadFileURL(_:allowingReadAccessTo:)` with the file's folder; the rest uses `load(URLRequest)`.
  - **`url`:** the web view's URL, except while an error page shows, when it is the address that failed.
  - **Observation:** KVO on `title`, `url`, `isLoading`, `estimatedProgress`, `canGoBack`, `canGoForward` calls `onChange`.
  - **`WKNavigationDelegate`:**
    - `decidePolicyFor navigationAction` maps to `NavigationPolicy.decide` (`wantsDownload` is `navigationAction.shouldPerformDownload`; command click is `.linkActivated` with `.command`). `.newTab` cancels and calls `onNewPage` with a fresh page loading that URL, in the background. `.askOtherApp` cancels, asks the prompter and calls `opener` on yes; a no sets `otherAppsRefused` until the next navigation the person starts (`load`, `goBack`, `goForward`, `reload`).
    - `decidePolicyFor navigationResponse` maps to `decideResponse` (`isAttachment` from the `Content-Disposition` header).
    - `navigationAction/navigationResponse didBecome download` hand the `WKDownload` to `environment.onDownload`.
    - `didFinish` calls `onVisit` (not for error pages).
    - `didFail` and `didFailProvisionalNavigation`: unless `isSilent`, `loadSimulatedRequest` with `BrowserPages.error`.
    - `webViewWebContentProcessDidTerminate`: the error page with the "stopped working" text.
  - **`WKUIDelegate`:**
    - `createWebViewWith`: a new `WebKitPage` built with the configuration WebKit hands over; `onNewPage(page, false)`; returns its web view.
    - `webViewDidClose` → `onClose`.
    - `runJavaScriptAlertPanel` → `prompter.tell(.warning)`; `runJavaScriptConfirmPanel` → `prompter.ask`. Messages are cut to 1,000 characters.
    - `runOpenPanelWith` → `dialogs.chooseFileToOpen` in the home folder.
  - **`find`:** `WKWebView.find(_:configuration:)` with `wraps = true`. **`zoom`:** `pageZoom`. **`close()`:** `stopLoading()`, `loadHTMLString("", baseURL: nil)`, remove the view from its superview and drop the delegates.
  - **`clearWebsiteData`:** `WKWebsiteDataStore.default().removeData(ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(), modifiedSince: .distantPast)`.
- [ ] **Step 4: Run** `swift test --filter Retro98BrowserTests`. Expected: PASS. Then `swift build -c release --product Retro98Browser 2>&1 | grep -c "warning:"`. Expected: `0`.
- [ ] **Step 5: Commit** `feat: browser page protocol, built-in pages and the WebKit page`.

### Task 4: A janela (abas, barra de ferramentas, endereço e status)

**Files:**
- Create `Sources/Retro98Browser/BrowserServices.swift`, `BrowserWindowController.swift`, `BrowserWindowController+Commands.swift`, `AddressBar.swift`.
- Test `Tests/Retro98BrowserTests/FakePage.swift`, `BrowserWindowTests.swift`.

**Interfaces:**
- Consumes: Tasks 1 to 3.
- Produces:
```swift
/// What a window gets from the app (tests build it from fakes and memory stores).
@MainActor struct BrowserServices {
    var makePage: () -> BrowserPage
    var favorites: FavoritesStore
    var history: HistoryStore
    var preferences: BrowserPreferences
    var prompter: BrowserPrompter
    var dialogs: BrowserDialogs
    var home: URL
    var now: () -> Date
}

@MainActor final class RetroBrowserPrompter: BrowserPrompter      // RetroMessageBox, titled "Navegador"
@MainActor final class RetroBrowserDialogs: BrowserDialogs        // RetroFileDialog .open; filters: HTML (html, htm), All files

@MainActor final class BrowserTab {
    let page: BrowserPage
    var hoverText: String?
}

@MainActor final class BrowserWindowController: NSObject, NSWindowDelegate {
    static let contentSize = CGSize(width: 900, height: 620)
    static let statusProgressWidth: CGFloat = 150
    let window: RetroAppWindow
    let tabStrip: RetroTabStrip
    let addressBar: AddressBar
    let statusBar: RetroStatusBar
    let progressBar: RetroProgressBar
    private(set) var tabs: [BrowserTab]
    private(set) var selectedIndex: Int
    var selectedTab: BrowserTab { get }
    var onClose: (() -> Void)?
    var onBecomeKey: (() -> Void)?
    /// A line shown in the status bar until the next hover or load (downloads use it).
    var notice: String?
    init(services: BrowserServices, languages: [String], first target: AddressTarget? = nil)   // nil is the home page setting
    @discardableResult func newTab(_ target: AddressTarget? = nil, inBackground: Bool = false) -> BrowserTab
    func closeTab(at index: Int)
    func selectTab(at index: Int)
    func go(_ text: String)                                   // what the address bar submits
    var toolbarItems: [ToolbarItem?] { get }
    var statusText: String { get }
    // Commands, sent up the responder chain:
    @objc func newTab(_ sender: Any?); @objc func closeTab(_ sender: Any?)
    @objc func goBack(_ sender: Any?); @objc func goForward(_ sender: Any?); @objc func goHome(_ sender: Any?)
    @objc func stopLoading(_ sender: Any?); @objc func reloadPage(_ sender: Any?)
    @objc func focusAddress(_ sender: Any?); @objc func openFile(_ sender: Any?)
    @objc func selectNextTab(_ sender: Any?); @objc func selectPreviousTab(_ sender: Any?)
    @objc func selectTabByNumber(_ sender: Any?)              // the menu item's tag, 1...9 (9 is the last tab)
    @objc func zoomIn(_ sender: Any?); @objc func zoomOut(_ sender: Any?); @objc func zoomReset(_ sender: Any?)
    @objc func addFavorite(_ sender: Any?)
    @objc func useCurrentPageAsHome(_ sender: Any?); @objc func useDefaultHome(_ sender: Any?)
}

@MainActor final class AddressBar: PixelView {
    static let height: CGFloat = 27
    var text: String
    var onSubmit: ((String) -> Void)?
    var onCancel: (() -> Void)?
    var isEditing: Bool { get }
    func focus(in window: NSWindow)                           // selects all
}
```
`FakePage` (tests): settable `url`, `title`, `isLoading`, `progress`, `canGoBack`, `canGoForward` that call `onChange`; records `loads`, `backs`, `forwards`, `reloads`, `stops`, `closes`; `view` is a plain `NSView`.

- [ ] **Step 1: Write the failing tests** in `BrowserWindowTests.swift` (services from fakes; the window is never shown).
  - **Opening:**
    - `opensOneTabOnTheHomePage`: 1 tab, its page's `loads == [.home]`.
    - `homePageSettingIsUsed`: preferences `homePage = "https://example.com"` → `loads == [.url(https://example.com)]`.
    - `newTabGoesToTheEndAndIsSelected`: 3 tabs after two `newTab()`, `selectedIndex == 2`, and the tab strip has 3 titles.
    - `backgroundTabKeepsTheSelection`.
    - `pageOpenedByAPageSitsRightAfterIt`: tabs A, B; A's page calls `onNewPage(C, false)` → order A, C, B and C selected; with `true`, A stays selected.
  - **Closing (Review Focus 5):**
    - `closingTheSelectedTabSelectsTheRightNeighbor`; `closingTheLastPositionSelectsTheLeft`.
    - `closingATabClosesItsPage`: `closes == 1`, and its view has no superview.
    - `closingTheOnlyTabClosesTheWindow`: `onClose` called once and the page closed.
    - `closingTheWindowClosesEveryPage`: 3 tabs, `window.close()` → each `closes == 1`.
    - `pageAskingToCloseClosesItsTab`: a background page calls `onClose` → that tab goes, the selection stays on the same page.
    - `closingATabThatIsStillLoadingIsFine`.
  - **Address:**
    - `goLoadsWhatWasTyped`: `go("example.com")` → `.url(https://example.com)`; `go("pão")` → the search URL; `go("  ")` → nothing loaded.
    - `addressFollowsThePage`: the page's `url` changes → `addressBar.text` is its `display`; while `addressBar.isEditing`, it does not change.
    - `switchingTabsShowsThatTabsAddress`.
  - **Toolbar and status:**
    - `toolbarHasTheSevenButtons`: titles `["Voltar", "Avançar", "Parar", "Atualizar", "Página inicial", "Favoritos", "Histórico"]` (with one separator after "Página inicial").
    - `buttonsFollowThePage`: Voltar enabled only with `canGoBack`, Avançar only with `canGoForward`, Parar only while loading.
    - `buttonsDriveThePage`: each action reaches `backs`, `forwards`, `stops`, `reloads`; Página inicial loads the home setting.
    - `statusShowsLoadingThenDone`: loading → "Abrindo página…" and `progressBar.isHidden == false` with `fraction == progress`; done → "Concluído" and the bar hidden.
    - `statusShowsTheHoveredLink`: `onHover("https://example.com/x")` → that text; `onHover(nil)` → back to "Concluído".
    - `hoverFromABackgroundTabIsIgnored`.
    - `hostileHoverTextIsOneShortLine` (Review Focus 3): `onHover` with 10,000 letters and line breaks → `statusText` has no line break and at most 300 characters.
    - `noticeShowsUntilTheNextLoad`.
  - **Titles (Review Focus 3):**
    - `windowAndTabFollowTheTitle`: title "Exemplo" → window title "Exemplo - Navegador", tab title "Exemplo".
    - `titleWithMarkupAndBreaksIsPlainText`: title `"<b>a</b>\nb"` → tab title `"<b>a</b> b"`.
  - **History and favorites:**
    - `visitsAreRecorded`: `onVisit(https://example.com, "Exemplo")` → history has it with `now()`.
    - `addFavoriteUsesThePage`: page at `https://example.com` titled "Exemplo" → `favorites.items == [Favorite("Exemplo", …)]`; on the home page nothing is added.
    - `currentPageBecomesTheHomePage`: `useCurrentPageAsHome` → `preferences.homePage == "https://example.com/"`; `useDefaultHome` → `"about:home"`.
  - **Tabs by keyboard:** `nextAndPreviousWrapAround`; `tabNumberNineIsTheLast`.
  - **Zoom:** `zoomStepsAndResets`: in ×1.1 each step, clamped to 0.5…3, reset to 1.
- [ ] **Step 2: Run** `swift test --filter BrowserWindowTests`. Expected: FAIL to compile.
- [ ] **Step 3: Implement.**
  - Layout as in Global Constraints, built like `NotepadWindowController.build()`; `taskbarHeight` and `tabbingMode = .disallowed` as there.
  - Only the selected tab's `page.view` is in the content area (autoresizing with it); switching swaps the view and makes it first responder unless the address is being edited.
  - One `refresh()` updates toolbar, address, status, progress, tab titles and window title from the selected tab; every page's `onChange` calls it.
  - The Favorites toolbar button opens a `RetroMenu` under itself (its frame from `RetroToolbar.frames`): Add, Organize…, separator, the list; picking one loads it in the selected tab. The History button and "Organize…" send `showHistory:` / `organizeFavorites:` up the responder chain (the app delegate answers in Tasks 6 and 7).
  - `openFile` asks `dialogs.chooseFileToOpen` and loads the file URL.
  - `windowWillClose` closes every page once and calls `onClose`.
- [ ] **Step 4: Run** `swift test --filter Retro98BrowserTests`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: browser window with tabs, toolbar, address and status bar`.

### Task 5: Downloads

**Files:**
- Create `Sources/Retro98Browser/Downloads.swift`, `Sources/Retro98Browser/WebKitDownloads.swift`.
- Modify `Sources/Retro98Browser/BrowserText.swift` (download texts).
- Test `Tests/Retro98BrowserTests/DownloadsTests.swift`.

**Interfaces:**
- Consumes: `DownloadFile`, `DownloadNames`, `BrowserPrompter`, `RetroProgressDialog`.
- Produces:
```swift
/// The transfer behind one download (a WKDownload when live).
@MainActor protocol DownloadTransfer: AnyObject {
    var received: Int64 { get }
    var total: Int64? { get }                       // nil when the server didn't say
    func cancel()
}

@MainActor final class DownloadCenter {
    /// Tests turn the progress dialogs off.
    var presentsDialogs = true
    var onFinish: ((String) -> Void)?               // the final file name
    var activeCount: Int { get }
    init(folder: URL, prompter: BrowserPrompter, languages: [String])
    /// Starts tracking and returns where the transfer must write.
    func begin(_ transfer: DownloadTransfer, suggestedName: String, host: String) -> URL
    func progressed(_ transfer: DownloadTransfer)
    func finished(_ transfer: DownloadTransfer)
    func failed(_ transfer: DownloadTransfer, message: String)
    func cancel(_ transfer: DownloadTransfer)       // the dialog's Cancel
    func cancelAll()                                // quitting
    /// The dialog lines for a transfer (tests read them).
    func lines(for transfer: DownloadTransfer) -> (item: String, detail: String, fraction: Double)?
}
```

- [ ] **Step 1: Write the failing tests** (temp folder as Downloads, fake transfers, `presentsDialogs = false`).
  - `beginReturnsAPartFileInTheFolder`: `begin(t, suggestedName: "a.zip", host: "example.com")` → `<folder>/a.zip.download`, `activeCount == 1`.
  - `hostileNamesStayInTheFolder`: suggested `"../../etc/passwd"` → `<folder>/passwd.download`.
  - `finishMovesTheFileAndTellsTheWindows`: write the part, `finished(t)` → `<folder>/a.zip` exists, `onFinish("a.zip")`, `activeCount == 0`.
  - `finishNeverReplacesAnExistingFile` (Review Focus 1): `a.zip` already there → the download ends as `a (2).zip` and the old file keeps its bytes.
  - `cancelRemovesThePartAndCancelsTheTransfer`: `cancel(t)` → the transfer's `cancel()` called once, no `.download` left, `activeCount == 0`, `onFinish` never called.
  - `failureRemovesThePartAndTells`: `failed(t, message: "sem conexão")` → no part file, the prompter was told a message containing `a.zip` and `sem conexão`.
  - `finishThatCannotMoveIsAFailure`: the part file is missing at `finished(t)` → told, `activeCount == 0`, no crash.
  - `cancelAllLeavesNoPartFiles`: two transfers → both cancelled, folder has no `.download`.
  - `linesShowReceivedAndTotal`: received 1,536, total 4,096 → detail has both sizes, fraction `0.375`; total `nil` → detail has only the received size, fraction `0`.
  - `eventsForAnUnknownTransferAreIgnored`.
- [ ] **Step 2: Run** `swift test --filter DownloadsTests`. Expected: FAIL to compile.
- [ ] **Step 3: Implement.**
  - `DownloadCenter`: sizes with `Properties.size(_:locale:languages:)` from `Retro98FilesCore` if it is public, else `ByteCountFormatter`; one `RetroProgressDialog` per transfer when `presentsDialogs` (style: the copy animation; `remaining` line: "Para: Downloads"/"To: Downloads"), `onCancel` → `cancel(transfer)`.
  - `WebKitDownloads` (`NSObject, WKDownloadDelegate`, not unit-tested): wraps each `WKDownload` in a `DownloadTransfer` (bytes from `download.progress`, observed with KVO on `fractionCompleted`, hopping to the main actor); `decideDestinationUsing` → `center.begin` with `response.url?.host`; `downloadDidFinish` → `finished`; `didFailWithError` → `failed` with the error's localized text unless it was our cancel.
  - `WebKitEnvironment.onDownload` is set to `WebKitDownloads.adopt(_:)` in Task 7.
- [ ] **Step 4: Run** `swift test --filter Retro98BrowserTests`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: browser downloads with progress dialog`.

### Task 6: Janelas de Favoritos, Histórico e Localizar

**Files:**
- Create `Sources/Retro98Browser/FavoritesWindow.swift`, `HistoryWindow.swift`, `FindInPageDialog.swift`.
- Modify `Sources/Retro98Browser/BrowserText.swift`.
- Test `Tests/Retro98BrowserTests/SmallWindowsTests.swift`.

**Interfaces (Produces):**
```swift
/// "Organizar Favoritos": the list in details mode (Nome, Endereço) and the buttons Abrir, Renomear, Excluir, Para cima, Para baixo, Fechar.
@MainActor final class FavoritesWindow {
    let window: RetroWindow
    let grid: RetroIconGrid
    var onOpen: ((URL) -> Void)?
    init(favorites: FavoritesStore, languages: [String])
    func open(); func beginRename(); func remove(); func moveUp(); func moveDown()   // on the selection
    func show()
}

/// "Histórico": a filter field, the list in details mode (Título, Endereço, Visitado) and the buttons Abrir, Excluir, Fechar.
@MainActor final class HistoryWindow {
    let window: RetroWindow
    let grid: RetroIconGrid
    let filter: RetroTextField
    private(set) var shown: [HistoryEntry]
    var onOpen: ((URL) -> Void)?
    init(history: HistoryStore, languages: [String], locale: Locale = .current)
    func open(); func remove()
    func show()
}

/// "Localizar": a field and the buttons Localizar próxima (default), Localizar anterior, Fechar.
@MainActor final class FindInPageDialog {
    let window: RetroWindow
    let field: RetroTextField
    private(set) var needle: String
    init(languages: [String], prompter: BrowserPrompter, page: @escaping () -> BrowserPage?)
    func show()
    func findNext(); func findPrevious()
}
```

- [ ] **Step 1: Write the failing tests** (windows never shown).
  - **Favorites window:**
    - `listsFavoritesWithNameAndAddress`: 2 favorites → 2 rows whose details are title and address.
    - `openSendsTheSelectedAddress`; `openWithNothingSelectedDoesNothing`.
    - `removeDeletesTheSelectionAndKeepsARowSelected`.
    - `moveUpAndDownFollowTheItem`: move the second up → order swapped and the same favorite still selected; moving the first up changes nothing.
    - `renameFromTheGridChangesTheTitle`: the grid's `onEndEditing(0, "Novo")` → `items[0].title == "Novo"`; `onEndEditing(0, nil)` keeps it.
    - `listFollowsTheStore`: adding to the store from outside reloads the rows.
  - **History window:**
    - `listsNewestFirst`; `filterNarrowsTheList`: typing "pao" leaves the "Pão de Queijo" entry only.
    - `openSendsTheAddress`; `removeForgetsTheEntry`.
    - `visitedColumnUsesTheLocale`: an entry dated 2026-11-16 14:05 with `pt_BR` shows "16/11/2026 14:05".
  - **Find:**
    - `findNextAsksThePage`: needle "abc" → the fake page got `("abc", backwards: false)`; `findPrevious` → `backwards: true`.
    - `notFoundTells`: the page answers `false` → the prompter was told a message with "abc".
    - `emptyNeedleDoesNothing`; `noPageDoesNothing`.
- [ ] **Step 2: Run** `swift test --filter SmallWindowsTests`. Expected: FAIL to compile.
- [ ] **Step 3: Implement**, following `Retro98Dialogs/FileDialogController.swift` for a `RetroIconGrid` in a `RetroWindow` with a sunken frame and `RetroScroller`, and the Notepad's `FindDialog` for the Find window. Sizes: Favorites and History content 480×320, Find 360×96. Double-click and Enter open; Delete removes; F2 renames (favorites). Rows use `BrowserIcons.page`. The windows are normal level and not modal.
- [ ] **Step 4: Run** `swift test --filter Retro98BrowserTests`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: favorites, history and find windows for the browser`.

### Task 7: O app (menus, várias janelas, abrir de fora, encerrar)

**Files:**
- Create `Sources/Retro98Browser/BrowserMenus.swift`, `Sources/Retro98Browser/AppDelegate.swift`.
- Modify `Sources/Retro98Browser/main.swift` (the real one, like the Notepad's) and `BrowserWindowController.swift` (`menuBar.menus = BrowserMenus.retroMenus(…)`).
- Test `Tests/Retro98BrowserTests/BrowserAppTests.swift`.

**Interfaces (Produces):**
```swift
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    static let cascadeOffset: CGFloat = 22
    let languages: [String]
    var presentsWindows: Bool                       // tests: false
    var windowControllers: [BrowserWindowController] { get }
    let downloads: DownloadCenter
    /// Live: stores in `<support>/Browser`, WebKit pages, ~/Downloads. Tests pass their own.
    init(services: BrowserServices, downloads: DownloadCenter, clearWebsiteData: @escaping (@escaping () -> Void) -> Void,
         languages: [String] = Locale.preferredLanguages)
    static func live(languages: [String] = Locale.preferredLanguages) -> AppDelegate
    @discardableResult func openWindow(_ target: AddressTarget? = nil) -> BrowserWindowController
    /// A web address or file from outside opens in a new tab of the active window (a new window when there is none).
    func open(_ url: URL)
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply
    @objc func newWindow(_ sender: Any?); @objc func closeWindow(_ sender: Any?)
    @objc func showHistory(_ sender: Any?); @objc func organizeFavorites(_ sender: Any?)
    @objc func openFavorite(_ sender: Any?)          // the menu item's representedObject is the URL
    @objc func clearBrowsingData(_ sender: Any?)
    @objc func showFind(_ sender: Any?); @objc func findNext(_ sender: Any?)
    @objc func openDownloadsFolder(_ sender: Any?)
    @objc func showAbout(_ sender: Any?); @objc func openHelp(_ sender: Any?)
}

@MainActor enum BrowserMenus {
    static let helpURL: URL
    static func groups(_ l: [String]) -> [(title: String, commands: [Command?])]     // Arquivo, Editar, Exibir, Ir, Favoritos, Ajuda
    static func mainMenu(languages: [String]) -> NSMenu
    static func windowMenu(in main: NSMenu, languages: [String]) -> NSMenu?
    static func favoritesMenu(in main: NSMenu, languages: [String]) -> NSMenu?
    static func retroMenus(languages: [String], favorites: @escaping @MainActor () -> [Favorite]) -> [RetroMenuBarMenu]
}
```

- [ ] **Step 1: Write the failing tests** (`presentsWindows = false`, fake pages, memory stores, scripted prompter, temp folders).
  - **Windows:**
    - `launchOpensOneWindowOnTheHomePage`.
    - `newWindowCascades`: the second window's top-left is 22 pt right of and below the first.
    - `addressesFromOutsideOpenInANewTab`: one window, `open(https://example.com)` → still one window, 2 tabs, the new one selected and loading that URL.
    - `addressFromOutsideWithNoWindowOpensOne`: `open` before launch finishes → after `applicationDidFinishLaunching`, exactly 1 window with 1 tab on that URL.
    - `onlyWebAndFileAddressesAreOpened`: `application(_:open: [mailto:a@b.c])` opens nothing.
    - `reopenWithNoWindowsOpensOne`; `closingTheLastWindowKeepsTheAppRunning` (`applicationShouldTerminateAfterLastWindowClosed == false`).
  - **Quitting (Review Focus 1):**
    - `quittingWithNoDownloadsJustQuits`: `.terminateNow`, nothing asked.
    - `quittingWithDownloadsAsks`: one active transfer, prompter answers no → `.terminateCancel`, the transfer not cancelled; answers yes → `.terminateNow`, the transfer cancelled and no `.download` file left.
  - **Favorites and history:**
    - `favoritesMenuListsTheStore`: after `menuNeedsUpdate`, the Favoritos menu ends with one item per favorite (title cut to 60 characters, `representedObject` the URL); with none, a disabled "(vazio)"/"(empty)" item.
    - `openFavoriteLoadsInTheActiveTab`.
    - `historyWindowOpensInANewTab`: the history window's `onOpen(url)` → a new selected tab in the active window.
    - `clearBrowsingDataAsksFirst`: prompter no → history untouched, website data not cleared; yes → history empty, the clear closure called once, favorites untouched.
  - **Downloads:** `finishedDownloadShowsInEveryWindow`: `downloads.onFinish("a.zip")` → each window's `statusText` contains `a.zip`.
  - **Menus:**
    - `retroMenusMatchTheSpec`: titles `["Arquivo", "Editar", "Exibir", "Ir", "Favoritos", "Ajuda"]`.
    - `macMenuBarHasShortcuts`: top items are the app name, Arquivo, Editar, Exibir, Ir, Favoritos, Janela, Ajuda. "Nova guia" has `"t"`; "Fechar janela" has `"w"` with `[.command, .shift]`; "Atualizar" has `"r"`; "Parar" has `"."`; "Voltar" has `"["`; "Página inicial" has `"h"` with `[.command, .shift]`; "Histórico…" has `"y"`; "Adicionar a Favoritos" has `"d"`; "Abrir a pasta Downloads" has `"l"` with `[.command, .option]`; "Próxima guia" has a tab character with `[.control]`.
    - `tabNumberShortcutsExist`: nine hidden-from-the-retro-bar items with keys "1"…"9" and tags 1…9 in the macOS Window menu.
- [ ] **Step 2: Run** `swift test --filter BrowserAppTests`. Expected: FAIL to compile.
- [ ] **Step 3: Implement**, following the Notepad's `AppDelegate`, `NotepadMenus` and `main.swift`.
  - **`live`:** `Retro98Paths.standard(home:environment:)` gives the support folder; stores in `Browser/`; `WebKitEnvironment` makes the pages, with `opener = { NSWorkspace.shared.open($0) }`; `DownloadCenter` on the system's Downloads folder; `WebKitDownloads` adopted through `environment.onDownload`.
  - `applicationWillFinishLaunching` sets `NSWindow.allowsAutomaticWindowTabbing = false`.
  - `application(_:open:)` takes `http`, `https` and `file` URLs only.
  - Edit commands use the standard selectors (`undo:`, `redo:`, `cut:`, `copy:`, `paste:`, `selectAll:`), which `WKWebView` and the address field answer.
  - The About panel says the pages are drawn by the WebKit that comes with macOS.
  - `openDownloadsFolder` opens the folder with `NSWorkspace`.
- [ ] **Step 4: Run** `swift test`. Expected: PASS (whole suite). Also `swift build -c release --product Retro98Browser 2>&1 | grep -c "warning:"`. Expected: `0`.
- [ ] **Step 5: Commit** `feat: Retro98 Browser app with menus, multiple windows and downloads`.

### Task 8: Instalar, desinstalar, README e versão

**Files:**
- Modify `scripts/build-app.sh`, `scripts/common.sh`, `install.sh`, `uninstall.sh`, `README.md`, `README.pt-BR.md`.
- Test `Tests/scripts/test_install.sh` and `Tests/scripts/test_uninstall.sh`.

**Interfaces:**
- **`build-app.sh`:**
  - An 11th optional argument: the document role, `Editor` (default) or `Viewer`. `CFBundleTypeName` stays as it is.
  - A 12th optional argument: `web`. When given, `Info.plist` gets `NSAppTransportSecurity` with `NSAllowsArbitraryLoadsInWebContent` true.
  - `VERSION="0.11.0"`, `BUILD="12"`. Update the usage comment and line.
- **`common.sh`:** `BROWSER_ID="io.github.matheushchaves.retro98.browser"`, `BROWSER_APP="$APPS_DIR/Retro98 Browser.app"`, `BROWSER_DATA_DIR="$SUPPORT_DIR/Browser"`, `remove_browser()` like `remove_notepad`, and `"$BROWSER_ID|$BROWSER_APP"` in `forget_permissions`.
- **`install.sh`:**
  - The question after the themes one, the `nobrowser` migration line and the default pieces, as in Global Constraints.
  - Build: `build-app.sh Retro98Browser "$BROWSER_ID" "Retro98 Browser" "$BROWSER_APP" regular "" browser "" "" "public.html" Viewer web`, then `lsregister -f`; otherwise `remove_browser`.
  - The header comment lists the Browser.
- **`uninstall.sh`:** `remove_browser` next to `remove_notepad`. When `$BROWSER_DATA_DIR` exists, the closing lines add: "Seus favoritos e o histórico do Navegador ficaram em `<pasta>`. Apague a pasta se não quiser guardá-los." / "Your Browser favorites and history were kept in `<folder>`. Delete the folder if you don't want them."

- [ ] **Step 1: Write the failing script tests.**
  - **`test_install.sh`:**
    - Every expected pieces string gains `browser` at the end (for example `pieces-recorded` expects `"base shell prompt notepad themes browser"`); the fixtures that write a pieces file to keep other apps out add `nobrowser`.
    - New checks: `browser-built` (`codesign --verify`), `browser-is-regular-app`, `browser-has-icon`, `browser-registered`.
    - `browser-opens-html-without-being-default`: `LSItemContentTypes:0 == public.html`, `LSHandlerRank == Alternate`, `CFBundleTypeRole == Viewer`.
    - `browser-is-never-a-default-browser`: `Print :CFBundleURLTypes` fails.
    - `browser-loads-plain-http-pages`: `Print :NSAppTransportSecurity:NSAllowsArbitraryLoadsInWebContent` is `true`.
    - `notepad-is-still-an-editor`: the Notepad's `CFBundleTypeRole == Editor` and it has no `NSAppTransportSecurity`.
    - `old-pieces-get-browser`: pieces `"base shell prompt notepad themes"` → the app exists and the pieces end in `browser`.
    - `declined-browser-stays-off`: pieces with `nobrowser` → no app, `lsregister -u` logged.
    - `declined-browser-keeps-the-persons-favorites`: with `support/Browser/favorites.json` present and pieces `nobrowser` → the file is still there with the same content.
  - **`test_uninstall.sh`:**
    - The installed-apps fixture gains `Retro98 Browser.app`; the shell case also expects `tccutil reset All io.github.matheushchaves.retro98.browser`, `lsregister -u <apps>/Retro98 Browser.app` and the app gone.
    - `uninstall-keeps-browser-favorites`: with `support/Browser/favorites.json` → the file survives with the same content and the output names the folder.
    - `uninstall-without-browser-data-says-nothing-about-it`: no `Browser` folder → the output has no "favoritos"/"favorites" line and the support folder is gone.
- [ ] **Step 2: Run** `bash Tests/scripts/test_uninstall.sh` and, in the background (about 10 minutes), `bash Tests/scripts/test_install.sh`. Expected: the new checks FAIL.
- [ ] **Step 3: Implement** the script changes.
  - **READMEs (both languages, same content):**
    - **"Situação":** phase 8 "✅ disponível" / "✅ available".
    - **New section "Navegador (Fase 8)" / "Browser (Phase 8)" after the themes'.** It covers:
      - what it is: a retro frame around the WebKit that comes with macOS, so pages look as they do today;
      - **that it is a secondary browser:** no Chrome extensions, no logins shared with Chrome or Safari, no password manager or passkeys, no camera, microphone or location, never offered as the default browser;
      - tabs, the address bar rules (address, local file, or DuckDuckGo search) and the shortcuts table;
      - downloads (to Downloads, never replacing a file) and the "another app" question for links such as `mailto:`;
      - favorites and history: where they are kept, "Limpar dados de navegação…", and that uninstalling keeps the favorites folder;
      - limits: no `prompt()` dialog, no HTTP password dialog, tabs are not restored, certificate errors can't be bypassed;
      - "Instalar o Navegador (motor WebKit)?" in the installer.
    - **Install and uninstall sections:** mention the Browser piece.
- [ ] **Step 4: Run** `bash Tests/scripts/test_uninstall.sh && bash Tests/scripts/test_signing.sh`, and `bash Tests/scripts/test_install.sh` in the background. Expected: every line PASS, and `security list-keychains -d user` unchanged before and after. Then run `swift test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: install Retro98 Browser as its own piece (0.11.0)`.

---

## Checagem manual (depois do merge, no Mac do autor)

Os testes não abrem páginas de verdade. Tudo o que depende do WebKit é conferido aqui.

1. `./install.sh --yes` → "Retro98 Browser" aparece em Iniciar › Programas › Retro98 e abre na página inicial cinza, com busca e favoritos.
2. Digitar `example.com` + Enter → a página abre, o título vai para a janela e para a aba, a barra de status mostra o progresso e depois "Concluído".
3. Digitar `pão de queijo` → abre a busca do DuckDuckGo. Passar o ponteiro num link mostra o endereço na barra de status.
4. ⌘T abre aba nova; ⌘-clique num link abre em segundo plano; um link que abre janela nova vira aba; ⌘W fecha; ⌃⇥ troca.
5. Voltar, Avançar, Parar, Atualizar e Página inicial funcionam pela barra e pelos atalhos. Voltar até a página inicial mostra a página, não uma tela em branco.
6. Entrar num site com login, sair do navegador (⌘Q) e abrir de novo → continua logado.
7. Baixar um arquivo (por exemplo um `.zip` de um repositório público) → diálogo de progresso; o arquivo aparece em `~/Downloads`; baixar de novo cria `nome (2).zip`; Cancelar não deixa `.download`.
8. ⌘D adiciona aos Favoritos; o item aparece no menu, no botão Favoritos e na página inicial; "Organizar Favoritos…" renomeia, move e exclui.
9. ⌘Y mostra o Histórico com filtro; "Limpar dados de navegação…" esvazia o histórico e desloga dos sites.
10. Um endereço que não existe (`https://nao-existe.invalid`) mostra a página de erro, com o endereço mantido na barra.
11. Um link `mailto:` pergunta antes de abrir o Mail. Um vídeo toca e a tela cheia do vídeo funciona. Fechar a aba para o som.
12. ⌘F localiza na página; ⌘+ e ⌘− mudam o tamanho; no Explorer, clique direito num `.html` › Abrir com › Retro98 Browser abre o arquivo.
13. Em Ajustes do Sistema › Mesa e Dock › Navegador padrão, o Retro98 Browser **não** aparece.
