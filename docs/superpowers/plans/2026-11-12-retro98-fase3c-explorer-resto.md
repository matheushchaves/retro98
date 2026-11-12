# Retro98 Fase 3C — Explorer: o resto — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fechar o Retro98 Explorer:
- ícones pequenos, lista e detalhes, com colunas ordenáveis;
- procurar e filtrar por nome, e o "Localizar…" do menu Iniciar;
- ejetar discos, "Abrir com…" e Propriedades;
- mostrar ou esconder arquivos ocultos;
- a opção, desligada por padrão, de o Explorer atender o "Mostrar no Finder" dos outros apps.

**Architecture:**
- **`Retro98FilesCore`** ganha a parte sem AppKit:
  - ordenação e nomes de tipo, preferências da janela (modo, ordem, ocultos);
  - a busca em segundo plano, o filtro e o cálculo de Propriedades (tamanho de pastas incluído);
  - a lista de apps do "Abrir com", o plano de "revelar" e o pedido `retro98-explorer://search`.
- **`Retro98UI`:** a grade passa a ter quatro modos sobre a mesma interação (seleção, arrastar, renomear, menu de contexto). Ganha também um cabeçalho de colunas, uma caixa de seleção e marcas (✓ e •) nos menus.
- **`Retro98Explorer`** liga tudo:
  - os menus Exibir e Arquivo, a barra de procurar e as janelas de Propriedades;
  - ejetar e "Abrir com" via `ExplorerServices` (NSWorkspace, injetável nos testes);
  - o evento de "revelar" do sistema.
- **`Retro98Settings`:** ganha o ajuste reversível `explorerFileViewer` (a preferência global `NSFileViewer`), que o instalador oferece desligado.
- **`Retro98ShellCore`:** o menu Iniciar ganha "Localizar…".

**Tech Stack:** Swift 6, AppKit, UniformTypeIdentifiers, NSAppleEventManager, NSWorkspace (ejetar, apps por tipo), Swift Testing, bash.

**Spec:** `docs/superpowers/specs/2026-11-10-retro-desktop-design.md`, seção "Fase 3" (3C, "Janela", "Operações obrigatórias", "Explorer como padrão"). As Fases 3A e 3B estão no `main`.

## Global Constraints

- **Herança:** tudo das Fases 1 a 3B continua valendo:
  - pixel 1x, Tahoma 13 e negrito 12, paleta, só material original;
  - pt-BR e en, só APIs públicas;
  - o Finder fica intacto e os testes ficam isolados.
- **Testes isolados, mais estes cuidados:**
  - As preferências do Explorer em teste ficam em memória (`ExplorerPreferences.memory`), nunca em `UserDefaults` de verdade.
  - Nenhum teste muda o `NSFileViewer` real, ejeta disco ou abre app: ejetar e listar apps passam por `ExplorerServices`.
  - Os scripts usam o `retro98-settings` falso, como nas fases anteriores.
- **Modos de exibição [minha escolha]:**

  | Modo | Geometria |
  |---|---|
  | Ícones grandes | Como na 3A. |
  | Ícones pequenos | Células de 150×20 preenchidas por linha, margem de 8. Ícone 16 em (x+2, y+2) e rótulo de uma linha em x+22, cortado com "…". |
  | Lista | A mesma aparência dos ícones pequenos, em células de 180×18 preenchidas por coluna (de cima para baixo, colunas da esquerda para a direita). Rola na horizontal e a altura é a da área visível. |
  | Detalhes | Linhas de 18, sem margem no topo, e cabeçalho fixo de 20 acima da área que rola. Colunas: Nome (o que sobrar, no mínimo 160), Tamanho 80 (alinhado à direita), Tipo 150 e Modificado 130. Na busca com subpastas, "Em pasta" (180) entra logo depois de Nome. |

  - **Seleção:** como no 98, o fundo azul-marinho fica só no rótulo. Em Detalhes, só no ícone e no nome.
  - **Cabeçalho:** botões elevados; clicar ordena, clicar de novo inverte, e um triângulo de 7×4 marca a coluna ativa.
- **Ordenação:**
  - Critérios: nome (padrão), tipo, tamanho ou data.
  - Pastas sempre primeiro. Na Área de Trabalho, Meu Computador, Meus Documentos e Lixeira ficam sempre no topo, nessa ordem.
  - Nomes e desempates usam `localizedStandardCompare`.
- **Preferências [minha escolha]:**
  - Modo, ordem e ocultos valem para todas as janelas e são lembrados entre aberturas (`UserDefaults` do próprio app).
  - Mudar numa janela muda nas outras abertas.
  - A seleção continua ao trocar de modo.
- **Ocultos:**
  - Exibir › "Mostrar arquivos ocultos" (⇧⌘.).
  - Itens ocultos aparecem com o ícone esmaecido, como no 98 (o mesmo xadrez dos recortados).
  - A árvore continua sem ocultos.
- **Procurar [minha escolha]:**
  - **Abrir e fechar:** ⌘F abre a barra "Procurar" logo abaixo do endereço (27 pt): campo, caixa "Incluir subpastas" e botão "Parar". Esc ou navegar para outro lugar fecha a barra e volta à listagem.
  - **Sem subpastas:** filtra a pasta na hora, enquanto se digita.
  - **Com subpastas:** busca em segundo plano 300 ms depois que se para de digitar. Os resultados chegam aos poucos, até 5.000.
  - **Como compara:** parte do nome, sem diferenciar maiúsculas e acentos.
  - **O que fica de fora:** não entra em pacotes nem segue links; pastas sem permissão são puladas; ocultos só com "Mostrar ocultos".
  - **Onde procura:**
    - na pasta mostrada;
    - na Área de Trabalho, em `~/Desktop`;
    - em Meu Computador, na pasta pessoal;
    - na Lixeira fica desligado.
- **"Localizar…" no Iniciar:**
  - Fica entre Configurações e Ajuda, com o ícone `FileIcons.explorerApp`.
  - Abre `retro98-explorer://search`: uma janela na pasta pessoal com a busca aberta e "Incluir subpastas" marcado.
  - Some se o Explorer não estiver instalado.
- **Ejetar:**
  - ⌘E, menu Arquivo e menu de contexto, para volumes ejetáveis (removíveis e de rede) selecionados em Meu Computador.
  - Roda fora da thread principal; uma falha mostra um erro com o motivo.
- **Abrir com:**
  - **Menu de contexto:** submenu em arquivos e apps. Primeiro o app padrão com "(padrão)", depois os outros em ordem alfabética, sem repetidos, cada um com o próprio ícone 16. Por último um separador e "Outro…", um `NSOpenPanel` em `/Applications` que aceita só apps.
  - **Menu Arquivo:** "Abrir com…" mostra o mesmo menu na posição do ponteiro.
  - **Vários itens:** os apps vêm do primeiro, e todos abrem no escolhido.
- **Propriedades:**
  - **Atalhos:** ⌘I ou ⌥↩︎, menu Arquivo, botão da barra e menu de contexto.
  - **Janela:** não modal, com título "Propriedades de <nome>" e várias abertas ao mesmo tempo.
    - Ícone 32 e nome.
    - Tipo, Local e Tamanho ("1,2 MB (1.234.567 bytes)").
    - Contém (só pastas), Criado, Modificado e Acessado.
    - Botão OK.
  - **Pastas:** o tamanho é calculado em segundo plano. Mostra "Calculando..." e se atualiza; pastas sem permissão viram uma nota. Fechar a janela para o cálculo.
  - **Vários itens:** "<n> itens", tamanho total, Contém, e Local quando todos estão na mesma pasta.
  - **Volumes:** Tipo, Espaço usado, Espaço livre e Capacidade, com uma barra de uso (`RetroProgressBar`).
  - **Itens fixos:** Meus Documentos mostra a pasta Documentos e a Lixeira mostra `~/.Trash` (se legível). Meu Computador fica desabilitado.
- **Explorer como padrão:**
  - **O ajuste:** `explorerFileViewer`, grupo `fileViewer`, grava `NSFileViewer` global = `io.github.matheushchaves.retro98.explorer`.
  - **Instalador:** pergunta, com padrão Não e só quando a barra é escolhida. A resposta entra na lista de peças como `fileviewer`.
  - **Desfazer:** desmarcar a barra, desmarcar o ajuste ou desinstalar devolve o valor de antes, **sempre antes de remover o Explorer**.
  - **O que o Explorer faz:** atende o evento de "revelar" (`misc`/`mvis`) e também pedidos para abrir arquivos e pastas: abre uma janela na pasta de cada item e seleciona os itens.
- **Atalhos novos:** ⌘1 ⌘2 ⌘3 ⌘4 (modos) · ⇧⌘. (ocultos) · ⌘F (procurar) · ⌘I ou ⌥↩︎ (Propriedades) · ⌘E (ejetar) · Esc (fecha a busca).
- **Textos** (pt-BR | en):

  | Onde | pt-BR | en |
  |---|---|---|
  | Exibir | Ícones grandes · Ícones pequenos · Lista · Detalhes · Organizar por nome · Organizar por tipo · Organizar por tamanho · Organizar por data · Mostrar arquivos ocultos | Large Icons · Small Icons · List · Details · Arrange by Name · Arrange by Type · Arrange by Size · Arrange by Date · Show Hidden Files |
  | Colunas | Nome · Em pasta · Tamanho · Tipo · Modificado | Name · In Folder · Size · Type · Modified |
  | Tipos | Pasta de arquivos · Aplicativo · `Arquivo <EXT>` · Arquivo (sem extensão) · Disco local · Disco removível · Unidade de rede · Pasta do sistema | File Folder · Application · `<EXT> File` · File · Local Disk · Removable Disk · Network Drive · System Folder |
  | Outros tipos | `UTType.localizedDescription` quando existe | idem |
  | Procurar | Procurar… (menu) · Procurar: · Incluir subpastas · Parar · Procurando... · `<n> objeto(s) encontrado(s)` · `Mais de 5.000 resultados; refine a busca.` | Search… · Search for: · Include subfolders · Stop · Searching... · `<n> object(s) found` · `More than 5,000 results; refine your search.` |
  | Iniciar | Localizar… | Find… |
  | Propriedades | `Propriedades de <nome>` · Tipo · Local · Tamanho · Contém · Criado · Modificado · Acessado · Calculando... · `1 arquivo`/`<n> arquivos`, `1 pasta`/`<n> pastas` · `<n> itens` · `Algumas pastas não puderam ser lidas.` · Espaço usado · Espaço livre · Capacidade · OK | `<name> Properties` · Type · Location · Size · Contains · Created · Modified · Accessed · Calculating... · `1 file`/`<n> files`, `1 folder`/`<n> folders` · `<n> items` · `Some folders couldn't be read.` · Used space · Free space · Capacity · OK |
  | Abrir com | Abrir com · (padrão) · Outro… | Open With · (default) · Other… |
  | Ejetar | Ejetar · título Erro ao ejetar · `Não foi possível ejetar '<nome>': <motivo>` | Eject · Error Ejecting · `Couldn't eject '<name>': <reason>` |
  | Instalador | `Usar o Retro98 Explorer no lugar do Finder quando outros apps pedem "Mostrar no Finder"? (opcional)` [s/N] | `Use Retro98 Explorer instead of Finder when other apps ask to "Show in Finder"? (optional)` [y/N] |
  | Ajuste | Explorer no lugar do Finder em "Mostrar no Finder" | Explorer instead of Finder for "Show in Finder" |

  Datas em `DateFormatter` curto (data e hora); tamanhos com `StatusText.bytes`.
- **Versão:** os bundles passam a 0.6.0 (build 6).

## Review Focus

1. **Pastas enormes nos modos novos** (Downloads ou `node_modules`, com 10 mil itens): ordenar por tipo, desenhar só o visível e rolar a Lista na horizontal sem travar. Os nomes de tipo saem de um cache por extensão. → Task 1, `sortingTenThousandByTypeIsQuick`; Task 4, `visibleIndicesStayBoundedInEveryStyle`.
2. **Busca em árvore grande ou estranha:** links em laço, pastas sem permissão, pacotes, muitos resultados. A busca não trava, não entra em laço, para com Parar, ao fechar a barra ou ao navegar, e respeita o limite. → Task 2, `searchDoesNotFollowLinkLoops`, `searchSkipsPackagesHiddenAndUnreadable`, `searchStopsWhenCancelled`, `searchStopsAtTheLimit`; Task 6, `navigatingAwayEndsTheSearch`.
3. **As interações da 3B nos modos novos:** renomear com o campo sobre o rótulo certo, seleção por retângulo, arrastar, menu de contexto, e a seleção preservada ao trocar de modo. → Task 4, `editorSitsOnTheLabelInEveryStyle`, `styleChangeKeepsSelection`, `rubberBandSelectsInEveryStyle`.
4. **"Mostrar no Finder" depois de desligar ou desinstalar:** o `NSFileViewer` volta ao valor de antes antes de o Explorer sair do disco. Sem isso, o "Mostrar no Finder" dos outros apps para de funcionar. → Task 8, `uninstall-restores-file-viewer-before-removing-explorer` e `install-without-shell-restores-file-viewer-first`.
5. **Ejetar um disco em uso, ou com uma janela aberta nele:** aparece uma mensagem com o motivo, nada trava, e a janela aberta volta a Meu Computador quando o disco sai. → Task 7, `ejectFailureIsReported`; a recuperação da 3A cobre o resto.

---

## Estrutura de arquivos

```
Sources/Retro98FilesCore/
  ViewOptions.swift         (novo) ViewMode, SortKey, SortOrder, FileSorting, FileTypeName, ExplorerPreferences
  FileSearch.swift          (novo) SearchQuery, SearchEnd, FileSearch (filtro e busca)
  Properties.swift          (novo) ItemProperties, FolderTally, PropertiesReader, PropertiesText, OpenWithList, RevealPlan
  Location.swift            FileEntry.isHidden
  FolderListing.swift       marca ocultos (.isHiddenKey)
  ExplorerModel.swift       ExplorerEnvironment.preferences; ordem, ocultos e estado de busca no modelo
  Navigation.swift          ExplorerRequest e ExplorerURL.searchURL/request
  ExplorerText.swift, Prompts.swift   textos novos
Sources/Retro98UI/
  IconGridGeometry.swift    (novo) IconGridStyle, IconGridGeometry, GridColumn
  RetroColumnHeader.swift   (novo)
  RetroCheckBox.swift       (novo)
  RetroIconGrid*.swift      estilos, ícone pequeno, colunas, teclado e edição por estilo
  RetroMenu.swift           RetroMenuItem.mark (✓ e •)
Sources/Retro98ShellCore/StartMenuItems.swift, StartMenuModel.swift   "Localizar…"
Sources/Retro98Shell/StartMenuController.swift                         ícone e URL do Localizar
Sources/Retro98Settings/Tweaks/Tweak.swift, TweakCatalog.swift          explorerFileViewer (grupo fileViewer)
Sources/Retro98Explorer/
  ExplorerServices.swift    (novo) ejetar e apps por tipo (NSWorkspace), injetável
  ExplorerViewCommands.swift (novo) Exibir, modos, ordem, ocultos, cabeçalho
  ExplorerSearch.swift      (novo) barra de procurar e busca em segundo plano
  ExplorerProperties.swift  (novo) janela de Propriedades
  ExplorerOpenWith.swift    (novo) Abrir com e Ejetar
  ExplorerMenus.swift, ExplorerCommands.swift, ExplorerWindowController.swift, AppDelegate.swift
install.sh, uninstall.sh, Tests/scripts/test_install.sh, Tests/scripts/test_uninstall.sh, scripts/build-app.sh, README*.md
```

Trabalhar num branch `fase3c-explorer-resto` a partir do `main`.

---

### Task 1: Ordenação, tipos, ocultos e preferências

**Files:** Create `Sources/Retro98FilesCore/ViewOptions.swift`; Modify `Location.swift`, `FolderListing.swift`, `ExplorerModel.swift`, `ExplorerText.swift`. Test `Tests/Retro98FilesCoreTests/ViewOptionsTests.swift`.

**Interfaces:**
```swift
public enum ViewMode: String, CaseIterable, Sendable { case largeIcons, smallIcons, list, details }
public enum SortKey: String, CaseIterable, Sendable { case name, type, size, modified }
public struct SortOrder: Equatable, Sendable { public var key: SortKey; public var ascending: Bool; public static let byName: SortOrder }
public enum FileTypeName { public static func name(for entry: FileEntry, languages: [String]) -> String }   // cache por extensão
public enum FileSorting {
    /// Itens que não são isFileItem primeiro, na ordem em que vieram; depois pastas; depois o resto pela chave.
    public static func sorted(_ entries: [FileEntry], by order: SortOrder, languages: [String]) -> [FileEntry]
}
public final class ExplorerPreferences: @unchecked Sendable {     // trava interna
    public static func memory(showHidden: Bool = false) -> ExplorerPreferences
    public init(defaults: UserDefaults)                           // chaves "ViewMode", "SortKey", "SortAscending", "ShowHidden"
    public var viewMode: ViewMode { get set }; public var sort: SortOrder { get set }; public var showHidden: Bool { get set }
}
// FileEntry ganha `public let isHidden: Bool` (init com padrão false)
// ExplorerEnvironment ganha `public let preferences: ExplorerPreferences` (padrão .memory(showHidden: showHidden); .live usa UserDefaults.standard)
// ExplorerModel:
public private(set) var sort: SortOrder; public private(set) var showHidden: Bool    // lidos das preferências no init
public func setSort(_ order: SortOrder)        // reordena sem ler o disco e grava nas preferências
public func setShowHidden(_ show: Bool)        // relista e grava nas preferências
public func applyPreferences()                 // outra janela mudou: relê sort e showHidden das preferências e recarrega
```
- [ ] **Step 1: Testes que falham**
  - `sortsFoldersFirstThenByKey`, com a pasta Z, o.txt de 30 bytes (data d1), a.md de 10 bytes (d3) e b.txt de 20 bytes (d2):
    - Por nome: Z, a.md, b.txt, o.txt.
    - Por tamanho crescente: Z, a.md, b.txt, o.txt; decrescente: Z, o.txt, b.txt, a.md.
    - Por data crescente: Z, o.txt, b.txt, a.md.
    - Por tipo: os .md antes dos .txt (pelo nome de tipo) e, dentro do mesmo tipo, por nome.
  - `desktopPlacesStayFirst`: na Área de Trabalho, os 3 fixos continuam no topo em qualquer ordem e direção.
  - `typeNames`:
    - Pasta dá "Pasta de arquivos"; app, "Aplicativo"; volume removível, "Disco removível"; Meu Computador, "Pasta do sistema".
    - "x.zzq" dá "Arquivo ZZQ"; "LEIAME" (sem extensão) dá "Arquivo"; "a.txt" dá um texto não vazio.
    - Em en: "File Folder" e "ZZQ File".
  - `hiddenFilesAreFlagged`: com `showHidden: true`, ".oculto" e um arquivo com `isHidden` ligado via `setResourceValues` vêm com `isHidden == true`; "normal.txt" vem com false.
  - `preferencesRemember`: `.memory()` começa em largeIcons, byName e false e guarda o que for setado. Dois acessos à mesma instância veem o mesmo valor.
  - `modelSortsAndTogglesHidden`:
    - `setSort` reordena `entries` e grava em `environment.preferences.sort`.
    - `setShowHidden(true)` faz ".oculto" aparecer.
    - Um modelo novo com as mesmas preferências já nasce com a ordem e os ocultos gravados.
  - `sortingTenThousandByTypeIsQuick`: 10.000 entradas com 20 extensões, ordenadas por tipo em menos de 1 s.
- [ ] **Step 2: Rodar `swift test --filter ViewOptionsTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.** Os textos novos vão para `ExplorerText`: tipos, colunas e o menu Exibir da tabela.
- [ ] **Step 4: Rodar `swift test`.** Esperado: tudo PASS, inclusive 3A e 3B.
- [ ] **Step 5: Commit** `feat: sorting, type names, hidden files and view preferences`

---

### Task 2: Busca e filtro, e o pedido de busca por URL

**Files:** Create `Sources/Retro98FilesCore/FileSearch.swift`; Modify `Navigation.swift`, `ExplorerModel.swift`. Test `Tests/Retro98FilesCoreTests/FileSearchTests.swift`.

**Interfaces:**
```swift
public struct SearchQuery: Equatable, Sendable { public let text: String; public let root: URL; public let includeSubfolders: Bool; public let showHidden: Bool }
public enum SearchEnd: Equatable, Sendable { case finished, limitReached, cancelled }
public enum FileSearch {
    public static let resultLimit = 5_000
    public static let batchSize = 200
    public static func matches(_ name: String, _ text: String) -> Bool          // contém, sem caixa e acentos; texto vazio casa tudo
    public static func filter(_ entries: [FileEntry], text: String) -> [FileEntry]
    /// Percorre `root` (sem entrar em pacotes, sem seguir links, pulando pastas ilegíveis e ocultos se !showHidden).
    public static func run(_ query: SearchQuery, limit: Int = resultLimit, control: OperationControl,
                           onBatch: @Sendable ([FileEntry]) -> Void) -> SearchEnd
}
public enum ExplorerRequest: Equatable, Sendable { case open(Location), search(Location?) }   // search(nil) = pasta pessoal
// ExplorerURL:
public static func searchURL(in location: Location?) -> URL     // retro98-explorer://search[?path=...]
public static func request(from url: URL) -> ExplorerRequest?   // location(from:) continua para os pedidos de abrir
// ExplorerModel:
public private(set) var search: SearchQuery?                    // nil = listagem normal
public private(set) var searchEnd: SearchEnd?                   // nil enquanto a busca com subpastas roda
public func beginSearch(_ query: SearchQuery)                    // sem subpastas: filtra a listagem na hora (searchEnd = .finished)
public func addResults(_ entries: [FileEntry])                   // ordena conforme `sort`
public func finishSearch(_ end: SearchEnd)
public func endSearch()                                          // volta à listagem; go/back/forward/up também encerram
```
- [ ] **Step 1: Testes que falham**
  - `matchesIgnoringCaseAndAccents`: "relatorio" casa "Relatório Final.pdf"; "FINAL" também; "x" não; "" casa tudo.
  - `filterKeepsOrder`.
  - `searchFindsInSubfolders`: A/rel1.txt, A/B/C/rel2.txt e A/outro.txt dão rel1 e rel2 com as URLs certas, e o fim é `.finished`.
  - `searchSkipsPackagesHiddenAndUnreadable`:
    - Calc.app/Contents/rel.txt não aparece; .escondido/rel.txt também não (com `showHidden` falso).
    - Trancada/rel.txt com chmod 000 não aparece e não dá erro.
    - Com `showHidden` verdadeiro, .escondido/rel.txt aparece.
  - `searchDoesNotFollowLinkLoops`: o link A/volta → A termina e não repete resultados.
  - `searchStopsWhenCancelled`: com 300 arquivos e cancelamento no 1º lote, dá `.cancelled` e no máximo 200 resultados.
  - `searchStopsAtTheLimit`: com `limit: 10` e 30 arquivos que casam, dá `.limitReached` e exatamente 10 resultados.
  - `searchURLsRoundTrip`: `searchURL(in: nil)` volta como `.search(nil)` e `searchURL(in: .folder(x))` como `.search(.folder(x))`; `retro98-explorer://desktop` volta como `.open(.desktop)`.
  - `modelSearchState`:
    - `beginSearch` sem subpastas filtra na hora.
    - `addResults` acumula e ordena.
    - `endSearch` volta à listagem.
    - `go(to:)` durante a busca encerra a busca.
- [ ] **Step 2: Rodar `swift test --filter FileSearchTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.** Use `FileManager.enumerator(at:includingPropertiesForKeys:options: [.skipsPackageDescendants] + ocultos, errorHandler: { _, _ in true })`; o enumerador não segue links. As entradas vêm de `FolderListing.entry(for:in:)`.
- [ ] **Step 4: Rodar `swift test --filter FileSearchTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: file search, name filter and search requests`

---

### Task 3: Propriedades, "Abrir com" e o plano de revelar

**Files:** Create `Sources/Retro98FilesCore/Properties.swift`; Modify `ExplorerText.swift`, `Prompts.swift`. Test `Tests/Retro98FilesCoreTests/PropertiesTests.swift`.

**Interfaces:**
```swift
public struct FolderTally: Equatable, Sendable { public var bytes: Int64; public var files: Int; public var folders: Int; public var skippedUnreadable: Bool }
public struct ItemProperties: Equatable, Sendable {
    public let title: String          // "Propriedades de <nome>" / "<n> itens"
    public let name: String; public let typeName: String; public let location: String?
    public var tally: FolderTally     // arquivos já somados; pastas somam ao medir
    public let needsMeasuring: [URL]  // pastas a medir em segundo plano
    public let created: Date?; public let modified: Date?; public let accessed: Date?   // nil para vários itens
}
public enum PropertiesReader {
    public static func summary(of entries: [FileEntry], languages: [String]) -> ItemProperties
    /// Soma tudo dentro de `folder` (links não seguidos, ilegíveis marcados); `onProgress` a cada 500 itens.
    public static func measure(_ folder: URL, control: OperationControl, onProgress: @Sendable (FolderTally) -> Void) -> FolderTally
}
public enum PropertiesText {
    public static func size(_ bytes: Int64, locale: Locale, languages: [String]) -> String   // "1,2 MB (1.234.567 bytes)"; < 1000: "5 bytes"
    public static func contains(files: Int, folders: Int, languages: [String]) -> String    // "1 arquivo, 3 pastas"
    public static func volume(_ info: VolumeInfo, locale: Locale, languages: [String]) -> (used: String, free: String, capacity: String, fraction: Double)
}
public struct OpenWithChoice: Equatable, Sendable { public let app: URL; public let name: String; public let isDefault: Bool }
public enum OpenWithList { public static func choices(defaultApp: URL?, apps: [URL]) -> [OpenWithChoice] }   // padrão primeiro, resto por nome, sem repetir
public enum RevealPlan {
    /// Agrupa por pasta-mãe, na ordem em que apareceram. Uma pasta pedida sozinha vira uma janela nela mesma.
    public static func windows(for urls: [URL]) -> [(folder: URL, select: [URL])]
}
// Prompts.ejectFailed(name: String, reason: String, languages:) -> Prompt   (título "Erro ao ejetar")
```
- [ ] **Step 1: Testes que falham**
  - `folderTallyCountsEverything`: A com 3 arquivos (10, 20, 30 bytes) e 2 subpastas, uma delas com 1 arquivo de 40, dá 100 bytes, 4 arquivos e 2 pastas.
  - `measureSkipsUnreadableAndSaysSo`: uma subpasta com chmod 000 dá `skippedUnreadable == true` e soma o resto.
  - `measureStopsWhenCancelled`.
  - `sizeAndContainsTexts`:
    - `size(1_234_567, pt_BR)` == "1,2 MB (1.234.567 bytes)" e `size(5)` == "5 bytes".
    - `contains(1, 1)` == "1 arquivo, 1 pasta"; `contains(2, 3)` == "2 arquivos, 3 pastas"; en "2 files, 3 folders".
  - `summaryOfOneFileAndOfSeveral`:
    - Um arquivo: título "Propriedades de a.txt", tipo, local = a pasta, tally com o tamanho e `needsMeasuring` vazio.
    - Dois arquivos e uma pasta na mesma pasta: título "3 itens", local presente, `needsMeasuring == [pasta]` e datas nil.
    - Itens de pastas diferentes: local nil.
  - `volumeTexts`: total 1000, livre 250 dá a fração 0.75 e o texto de usado com "750 bytes".
  - `openWithPutsTheDefaultFirst`: com o padrão B.app e os apps [C, B, A, A], dá B (padrão), A, C.
  - `revealGroupsByFolder`: [X/a, Y/b, X/c] dá [(X, [a, c]), (Y, [b])]; [Pasta] (uma pasta só) dá [(Pasta, [])].
- [ ] **Step 2: Rodar `swift test --filter PropertiesTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar**, com os textos da tabela.
- [ ] **Step 4: Rodar `swift test --filter PropertiesTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: properties, open-with list and reveal plan`

---

### Task 4: Grade em quatro modos, cabeçalho de colunas, caixa de seleção e marcas de menu

**Files:** Create `Sources/Retro98UI/IconGridGeometry.swift`, `RetroColumnHeader.swift`, `RetroCheckBox.swift`; Modify `RetroIconGrid.swift`, `RetroIconGrid+Editing.swift`, `RetroIconGrid+DragDrop.swift`, `RetroMenu.swift`. Test `Tests/Retro98UITests/GridStylesTests.swift`.

**Interfaces:**
```swift
public enum IconGridStyle: Equatable, Sendable { case largeIcons, smallIcons, list, details }
public enum MoveDirection: Sendable { case left, right, up, down }
public struct GridColumn: Equatable, Sendable {
    public let title: String; public let width: CGFloat; public let alignsRight: Bool
    /// A 1ª coluna (Nome) fica com o que sobrar, no mínimo 160.
    public static func widths(_ columns: [GridColumn], totalWidth: CGFloat) -> [CGFloat]
}
public struct IconGridGeometry: Equatable, Sendable {
    public static let smallCell = CGSize(width: 150, height: 20), listCell = CGSize(width: 180, height: 18), rowHeight: CGFloat = 18
    public init(style: IconGridStyle, visibleSize: CGSize, count: Int)
    public var contentSize: CGSize { get }
    public func frame(of index: Int) -> CGRect            // célula (linha inteira em Detalhes)
    public func index(at point: CGPoint) -> Int?
    public func indices(in rect: CGRect) -> [Int]
    public func move(from index: Int?, _ direction: MoveDirection) -> Int?
}
// RetroIconGrid:
public var style: IconGridStyle            // ao mudar: relayout, mantém a seleção, reposiciona o campo de renomear
public var columns: [GridColumn]           // Detalhes: Nome + as demais; o app define
// data source (padrões em extensão):
func grid(_ grid: RetroIconGrid, smallIconAt index: Int) -> PixelIcon         // padrão: o ícone grande reduzido
func grid(_ grid: RetroIconGrid, detailsAt index: Int) -> [String]            // textos das colunas depois de Nome; padrão []
public final class RetroColumnHeader: PixelView {
    public var columns: [GridColumn]; public var sortedColumn: Int?; public var ascending: Bool
    public var onClick: ((Int) -> Void)?
}
public final class RetroCheckBox: PixelView {          // quadrado afundado branco 13×13 com ✓ e rótulo; espaço e clique alternam
    public init(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void); public var isOn: Bool
}
// RetroMenuItem ganha `public let mark: Mark` (enum Mark { case none, check, bullet }; init com padrão .none),
// desenhada no lugar do ícone quando não há ícone
```
- [ ] **Step 1: Testes que falham**
  - **Geometria:**
    - `smallIconsFlowInRows`: com largura 470, há 3 colunas; o índice 4 fica em (8+150, 8+20).
    - `listFlowsInColumnsAndScrollsSideways`: com altura visível 100 cabem 5 por coluna; o índice 7 fica na coluna 1, linha 2; com 12 itens, `contentSize.width` = 8×2 + 3×180 e a altura é 100.
    - `detailsRowsStack`: o índice 3 vai de y 54 a 72, na largura toda.
    - `indexAtPointPerStyle`: o ponto no meio de uma célula dá o índice certo nos 4 modos; fora dá nil.
    - `arrowsPerStyle`: na Lista, baixo = +1 e direita = +linhas; em Detalhes, cima e baixo = ±1 e esquerda/direita = nil; em ícones pequenos, baixo = +colunas.
    - `visibleIndicesStayBoundedInEveryStyle`: com 10.000 itens, `indices(in:)` de uma janela de 450×300 devolve no máximo ~100 índices em cada modo.
  - **Colunas:** `columnWidthsGiveTheRestToName`: com 520 de largura e as demais 80, 150 e 130, Nome fica com 160; com 1000, fica com 640.
  - **Grade:**
    - `editorSitsOnTheLabelInEveryStyle`: o campo de `beginEditing` começa no x do rótulo em cada modo (x+22 nos pequenos e na Lista, a coluna Nome + 22 em Detalhes).
    - `styleChangeKeepsSelection`.
    - `rubberBandSelectsInEveryStyle`: os índices sob um retângulo vêm de `indices(in:)` mais o teste de interseção.
  - **Componentes:**
    - `headerClickReportsTheColumn`: um clique sintético na 3ª coluna chama `onClick(2)`.
    - `checkBoxToggles`.
    - `menuMarksDraw`: um item com `.check` tem pixels pretos no lugar do ícone; com `.none`, não.
- [ ] **Step 2: Rodar `swift test --filter GridStylesTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
  - A geometria dos ícones grandes delega a `IconGridLayout`.
  - O desenho por modo segue as Global Constraints. Em Detalhes, Tamanho alinha à direita e o texto é cortado com `RetroText.fit`.
  - Arrastar, soltar, menu de contexto e esmaecidos valem em todos os modos.
- [ ] **Step 4: Rodar `swift test`.** Esperado: PASS, inclusive os testes da grade da 3A e da 3B.
- [ ] **Step 5: Commit** `feat: small icons, list and details grid styles with column header`

---

### Task 5: Modos, ordenação e ocultos na janela

**Files:** Create `Sources/Retro98Explorer/ExplorerViewCommands.swift`; Modify `ExplorerWindowController.swift`, `ExplorerMenus.swift`, `AppDelegate.swift`. Test `Tests/Retro98ExplorerTests/ExplorerViewTests.swift`.

**Interfaces:**
```swift
// ExplorerWindowController (ações @objc + validação; o estado vem de environment.preferences e do modelo):
showLargeIcons(_:) showSmallIcons(_:) showList(_:) showDetails(_:)     // ⌘1…⌘4
arrangeByName(_:) arrangeByType(_:) arrangeBySize(_:) arrangeByDate(_:)
toggleHiddenFiles(_:)                                                  // ⇧⌘.
static let viewDidChange = Notification.Name("Retro98ExplorerViewDidChange")   // as outras janelas chamam applyPreferences() e reaplicam o modo
func showViewsMenu()                                                   // botão Modos: RetroMenu com os 4 modos (• no atual)
// ExplorerMenus.validated passa a devolver também o estado: (title, isEnabled, mark) — NSMenuItem.state .on vira .check ou .bullet
```
**Na janela:**
- O botão Modos da barra fica habilitado.
- Em Detalhes, um `RetroColumnHeader` de 20 pt fica no topo do painel direito, dentro do `FieldFrame`, acima da área que rola. Clicar chama `model.setSort`.
- A Lista liga a rolagem horizontal; os outros modos a desligam.
- Os dados da grade:
  - `smallIconAt`: ícones de 16, com o ícone próprio para apps, em cache por tamanho;
  - `detailsAt`: tamanho (vazio para pastas), tipo (`FileTypeName`) e modificado;
  - `isDimmedAt`: recortado ou oculto.
- **Exibir, nesta ordem:**
  - os 4 modos com •;
  - os 4 "Organizar por…" com •;
  - "Mostrar arquivos ocultos" com ✓;
  - Atualizar.

- [ ] **Step 1: Testes que falham** (`ExplorerPreferences.memory()` compartilhada pelo ambiente de teste)
  - `viewCommandsSwitchModesAndRemember`: `showDetails(nil)` deixa `grid.style == .details`, `preferences.viewMode == .details` e o cabeçalho visível. Uma janela nova com o mesmo ambiente já abre em Detalhes. `showList(nil)` liga `hasHorizontalScroller`.
  - `headerSortsAndReverses`:
    - Um clique em Tamanho dá `model.sort == SortOrder(key: .size, ascending: true)`.
    - Outro clique inverte, e as entradas seguem a ordem.
    - O triângulo do cabeçalho fica na coluna 1.
  - `hiddenFilesToggleAndLookGhosted`: `toggleHiddenFiles(nil)` faz ".oculto" aparecer com `grid(_:isDimmedAt:)` verdadeiro; ⇧⌘. no menu principal tem esse seletor.
  - `otherWindowsFollow`: duas janelas com as mesmas preferências; ligar ocultos numa faz a outra listar ".oculto" depois da notificação.
  - `viewMenuShowsMarks`: `validated` do modo atual dá `.bullet`, e o de "Mostrar arquivos ocultos" ligado dá `.check`.
  - `menusHaveTheViewShortcuts`: ⌘1…⌘4 e ⇧⌘. com os seletores certos.
- [ ] **Step 2: Rodar `swift test --filter ExplorerViewTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.** O `AppDelegate` passa a usar o ambiente com `ExplorerPreferences(defaults: .standard)` (via `.live`).
- [ ] **Step 4: Rodar `swift test`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: view modes, sorting and hidden files in Explorer windows`

---

### Task 6: Procurar na janela e "Localizar…" no Iniciar

**Files:** Create `Sources/Retro98Explorer/ExplorerSearch.swift`; Modify `ExplorerWindowController.swift`, `ExplorerMenus.swift`, `AppDelegate.swift`, `Sources/Retro98ShellCore/StartMenuItems.swift`, `StartMenuModel.swift`, `Sources/Retro98Shell/StartMenuController.swift`. Test `Tests/Retro98ExplorerTests/ExplorerSearchTests.swift`, `Tests/Retro98ShellCoreTests/StartMenuItemsTests.swift`.

**Interfaces:**
```swift
// ExplorerWindowController:
init(start: Location, languages:, environment:, operations:, searching: Bool = false)   // searching: abre com a barra e subpastas ligadas
@objc func showSearch(_ sender: Any?)                  // ⌘F (menu Arquivo "Procurar…")
func search(text: String, includeSubfolders: Bool)     // o que a barra chama (debounce de 300 ms para subpastas)
func closeSearch()                                     // Esc, navegar ou fechar a janela
var searchTask: Task<Void, Never>? { get }             // testes aguardam
// ShellCore:
StartMenuEntry ganha .find (depois de .settings); StartMenuSymbol ganha .find
StartMenuItems.build(programs:documents:languages:findURL: URL?)   // nil omite "Localizar…"
```
**Comportamento:**
- **A barra:** a `SearchBar` (nesta task) tem rótulo, `NSTextField` Tahoma 13, `RetroCheckBox` "Incluir subpastas" e `RetroButton` "Parar". Fica abaixo do endereço e empurra os painéis para baixo.
- **Buscar:**
  - Com subpastas, a busca roda em fila global, com `OperationControl` e lotes repassados à principal (`model.addResults`).
  - Uma busca nova cancela a anterior.
  - Em Detalhes, a coluna "Em pasta" mostra o caminho da pasta-mãe com `~`.
- **Status:** "Procurando..." enquanto roda, depois "<n> objeto(s) encontrado(s)", ou o aviso do limite.
- **AppDelegate:** `.search(nil)` abre uma janela com `searching: true` na pasta pessoal, e `.search(local)` no local pedido.
- **Shell:** passa `findURL: ExplorerURL.searchURL(in: nil)` quando `QuickLaunch.isAvailable`, e o ícone de `.find` é `FileIcons.explorerApp`.

- [ ] **Step 1: Testes que falham**
  - `searchBarFiltersTheFolderAsYouType`: em A com rel.txt, outro.txt e Sub/rel2.txt, `search(text: "rel", includeSubfolders: false)` deixa só rel.txt.
  - `searchInSubfoldersFindsNestedFiles`: `search(text: "rel", includeSubfolders: true)` e a espera de `searchTask` dão rel.txt e Sub/rel2.txt, com o status "2 objeto(s) encontrado(s)" e a coluna "Em pasta" nas colunas da grade.
  - `navigatingAwayEndsTheSearch`: durante a busca, `model.go(to:)` deixa `model.search == nil`, a barra fechada e a tarefa cancelada.
  - `escapeClosesTheSearch`.
  - `searchRequestOpensSearching`: `ExplorerWindowController(start:…, searching: true)` abre com a barra visível e a caixa de subpastas marcada.
  - `findEntryAppearsOnlyWithTheExplorer` (ShellCore): com `findURL` presente, "Localizar…" aparece entre Configurações e Ajuda e abre a URL; com nil, não aparece.
  - `menusHaveTheSearchShortcut`: ⌘F com `showSearch:`.
- [ ] **Step 2: Rodar `swift test --filter "ExplorerSearchTests|StartMenuItemsTests"`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test`** e o build release do Shell e do Explorer sem warnings. Esperado: PASS.
- [ ] **Step 5: Commit** `feat: search in Explorer windows and Find in the Start menu`

---

### Task 7: Propriedades, "Abrir com" e Ejetar

**Files:** Create `Sources/Retro98Explorer/ExplorerServices.swift`, `ExplorerProperties.swift`, `ExplorerOpenWith.swift`; Modify `ExplorerOperations.swift` (guarda os serviços), `ExplorerCommands.swift`, `ExplorerMenus.swift`, `ExplorerWindowController.swift`. Test `Tests/Retro98ExplorerTests/ExplorerPropertiesTests.swift`.

**Interfaces:**
```swift
struct ExplorerServices: Sendable {
    let eject: @Sendable (URL) throws -> Void                         // live: NSWorkspace.unmountAndEjectDevice(at:)
    let applications: @Sendable (URL) -> (default: URL?, all: [URL])  // live: urlForApplication(toOpen:) e urlsForApplications(toOpen:)
    let open: @Sendable ([URL], URL) -> Void                          // live: NSWorkspace.open(_:withApplicationAt:configuration:)
    static let live: ExplorerServices
}
// ExplorerOperations.init ganha `services: ExplorerServices = .live`
@MainActor final class PropertiesWindow {                            // RetroWindow com nível .normal
    init(entries: [FileEntry], volume: VolumeInfo?, languages: [String], locale: Locale)
    let window: RetroWindow
    var measuring: Task<Void, Never>? { get }                         // testes aguardam
    func show(); func close()                                         // fechar cancela a medição
    func text(of row: String) -> String?                              // testes: valor da linha com o rótulo dado
}
// ExplorerWindowController:
@objc func showProperties(_:)   // ⌘I (e ⌥↩︎ na grade)
@objc func ejectSelection(_:)   // ⌘E
@objc func openWith(_:)         // Arquivo › "Abrir com…": o menu de apps na posição do ponteiro
func openWithItems(for urls: [URL]) -> [RetroMenuItem]   // o submenu do menu de contexto
private(set) var propertiesWindows: [PropertiesWindow]  // abertas; sai da lista ao fechar
```
- [ ] **Step 1: Testes que falham** (serviços falsos)
  - `propertiesShowFolderTotals`:
    - Selecionar a Pasta (3 arquivos, 1 subpasta) e chamar `showProperties(nil)`.
    - Esperar `measuring`.
    - Contém = "3 arquivos, 1 pasta"; Tamanho com "bytes"; Local = a pasta-mãe; título "Propriedades de Pasta".
  - `propertiesForSeveralItems`: o título é "<n> itens" e não há linhas de data.
  - `propertiesOfAVolumeShowSpace`: em Meu Computador, com o volume falso (1000/250), aparecem Espaço usado, Espaço livre e Capacidade, e a barra fica em 0.75.
  - `closingPropertiesStopsMeasuring`.
  - `openWithListsTheDefaultFirst`:
    - Com `applications` devolvendo (B, [C, B, A]), os títulos do submenu são "B (padrão)", "A", "C", —, "Outro…".
    - Escolher "A" chama `open([a.txt], A)`.
  - `ejectRunsOnlyForEjectableVolumes`: `ejectSelection` fica habilitado só com um volume ejetável selecionado, e chama `eject` com a URL dele.
  - `ejectFailureIsReported`: um `eject` que lança erro mostra `Prompts.ejectFailed(name:reason:)`.
  - `menusHaveThePropertiesAndEjectShortcuts`: ⌘I, ⌘E e "Abrir com…" no Arquivo; o botão Propriedades da barra fica habilitado com seleção.
- [ ] **Step 2: Rodar `swift test --filter ExplorerPropertiesTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
  - **Layout da janela:** conteúdo de 320 de largura, linhas de 18 com rótulo em x 12 e valor em x 100, separadores entalhados entre os grupos, OK alinhado à direita.
  - **Medição:** em fila global; um toque a cada 500 itens atualiza Tamanho e Contém.
- [ ] **Step 4: Rodar `swift test`** e `swift build -c release --product Retro98Explorer` sem warnings. Esperado: PASS.
- [ ] **Step 5: Commit** `feat: properties, open with and eject in Explorer`

---

### Task 8: Explorer como padrão do "Mostrar no Finder" (opcional)

**Files:** Modify `Sources/Retro98Settings/Tweaks/Tweak.swift`, `TweakCatalog.swift`, `Sources/retro98-settings/main.swift` (se preciso), `Sources/Retro98Explorer/AppDelegate.swift`, `install.sh`, `uninstall.sh`, `scripts/common.sh`, `Tests/scripts/test_install.sh`, `Tests/scripts/test_uninstall.sh`. Test `Tests/Retro98SettingsTests/FileViewerTweakTests.swift`, `Tests/Retro98ExplorerTests/ExplorerRevealTests.swift`.

**Interfaces:**
```swift
TweakID ganha .explorerFileViewer; TweakGroup ganha .fileViewer
TweakCatalog.fileViewer() -> [Tweak]   // change(.global, "NSFileViewer", .string("io.github.matheushchaves.retro98.explorer")); `all` inclui
// AppDelegate:
init(environment: ExplorerEnvironment? = nil, operations: ExplorerOperations? = nil)   // testes injetam; nil = .live
func reveal(_ urls: [URL])             // RevealPlan.windows → uma janela por pasta (reaproveita a que já mostra a pasta) e seleciona
// registra em applicationWillFinishLaunching: NSAppleEventManager handler para ('misc', 'mvis');
// application(_:open:) manda URLs file:// para reveal (pastas sozinhas abrem nelas mesmas)
```
**Instalador:**
- **Pergunta nova:** `ask_no`, com padrão Não, feita só se a barra foi escolhida, logo depois da pergunta da barra. "Sim" acrescenta `fileviewer` às peças.
- **Com `--yes`:** vale a lista de peças; na primeira vez continua "base shell".
- **Com `fileviewer` e `shell`:** `"$BIN" apply --only explorerFileViewer`.
- **Com `shell` sem `fileviewer`:** `"$BIN" restore --only explorerFileViewer`.
- **Barra desmarcada:** `restore --only explorerFileViewer` vem **antes** de `remove_explorer`.

**Desinstalador:** confirmar que `restore` (de tudo) roda antes de `remove_explorer`; senão, ajustar.

- [ ] **Step 1: Testes que falham**
  - `fileViewerTweakIsItsOwnGroup` (Settings): o catálogo traz `explorerFileViewer` no grupo `.fileViewer`, com a chave global `NSFileViewer` e o bundle id do Explorer. O conjunto que `apply` sem `--only` usa (o grupo `.base`) não o inclui.
  - `revealOpensOneWindowPerFolderAndSelects` (Explorer, num `AppDelegate` com ambiente e operações de teste injetáveis por `init(environment:operations:)`):
    - `reveal([A/a.txt, B/b.txt, A/c.txt])` abre 2 janelas, em A com a.txt e c.txt selecionados e em B com b.txt.
    - Um segundo `reveal([A/a.txt])` reaproveita a janela de A.
  - `test_install.sh`:
    - `fileviewer-off-by-default`: com `--yes` na primeira vez, não há `apply --only explorerFileViewer` no log do bin falso.
    - `fileviewer-applied-when-chosen`: com a lista de peças "base shell fileviewer", o apply aparece.
    - `install-without-shell-restores-file-viewer-first`: com "base", `restore --only explorerFileViewer` aparece no log antes da remoção do Explorer.
  - `test_uninstall.sh`, `uninstall-restores-file-viewer-before-removing-explorer`: o restore aparece no log antes de o app sumir. Use o mesmo truque de ordem dos casos existentes: o bin falso grava se o Explorer ainda existe no momento do restore.
- [ ] **Step 2: Rodar `swift test --filter "FileViewerTweakTests|ExplorerRevealTests"` e os dois scripts no bash do sistema.** Esperado: FAIL nos casos novos.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test` e os três scripts.** Esperado: tudo PASS e a lista de chaveiros inalterada.
- [ ] **Step 5: Commit** `feat: optional Explorer as the default file viewer`

---

### Task 9: Versão e README

**Files:** Modify `scripts/build-app.sh`, `README.md`, `README.pt-BR.md`.

- [ ] **Step 1: Versão 0.6.0, build 6.**
- [ ] **Step 2: README** (pt-BR e en):
  - Na tabela, 3C fica "✅ disponível".
  - A seção do Explorer ganha:
    - os modos de exibição e a ordenação pelas colunas;
    - mostrar ocultos;
    - procurar (⌘F) e "Localizar…" no Iniciar;
    - Propriedades (⌘I), "Abrir com" e ejetar (⌘E).
  - **Explorer no lugar do Finder:**
    - Como ligar: a pergunta do instalador.
    - Como desligar: rodar o instalador e responder Não, ou desinstalar.
    - Limites: apps já abertos podem precisar ser reabertos; abrir uma pasta com dois cliques em outros apps continua indo para o Finder.
  - Tabela de atalhos atualizada, em formato de tabela (pendência menor da 3B).
  - A linha "Na próxima entrega" sai.
- [ ] **Step 3: Rodar `swift test` e os três scripts.** Esperado: tudo PASS.
- [ ] **Step 4: Commit** `docs: Explorer views, search, properties and default viewer (Phase 3C)`

---

### Aceitação pelo autor (manual, no Mac dele, depois da Task 9)

O autor roda `./install.sh` (respondendo à pergunta nova) ou `./install.sh --yes` e confere:

- [ ] **Modos:**
  - ⌘1…⌘4 e o botão Modos trocam entre ícones grandes, pequenos, Lista e Detalhes.
  - A Lista rola para o lado.
  - Em Detalhes, clicar nas colunas ordena e um segundo clique inverte.
  - O modo escolhido continua na próxima janela.
- [ ] **Nos modos novos:** renomear (Enter), arrastar, selecionar com retângulo e o menu de contexto funcionam.
- [ ] **Ocultos:** ⇧⌘. mostra e esconde, e os ocultos aparecem esmaecidos.
- [ ] **Procurar:**
  - ⌘F filtra a pasta enquanto você digita.
  - Com "Incluir subpastas", acha arquivos em subpastas e mostra "Em pasta".
  - Parar e Esc funcionam.
  - "Localizar…" no Iniciar abre a busca na pasta pessoal.
- [ ] **Propriedades:** ⌘I numa pasta grande mostra "Calculando..." e depois tamanho e "Contém"; também funciona num pen drive e em vários itens.
- [ ] **Abrir com:** lista o app padrão primeiro, abre no app escolhido, e "Outro…" deixa escolher qualquer app.
- [ ] **Ejetar:** ⌘E num pen drive em Meu Computador ejeta. Com um arquivo dele aberto, aparece o erro com o motivo.
- [ ] **Explorer no lugar do Finder** (se escolhido):
  - "Mostrar no Finder" de outro app (por exemplo, em Downloads do Safari, depois de reabrir o Safari) abre o Explorer com o arquivo selecionado.
  - Rodar `./install.sh` e responder Não devolve o Finder.
- [ ] **Desinstalar:** `./uninstall.sh` devolve o Finder no "Mostrar no Finder" e remove tudo.
