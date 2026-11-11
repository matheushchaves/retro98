# Retro98 Fase 3A — Explorer: navegar — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O app **Retro98 Explorer**, uma janela no estilo 98 que abre em "Área de Trabalho" e navega pelo Mac:
- Meu Computador, discos, pastas, Meus Documentos e Lixeira;
- Voltar, Avançar, Acima, barra de endereço, árvore e ícones grandes;
- abrir arquivos e apps, espiar com a barra de espaço, barra de status.

A barra de tarefas ganha o "Início rápido" com o atalho para a Área de Trabalho.

**Architecture:**
- **`Retro98UI`:** ganha as peças de app de verdade: janela redimensionável com minimizar, maximizar e fechar; barra de menus na janela; barra de ferramentas; barras de rolagem clássicas; árvore; grade de ícones; barra de status. A `PixelView` passa a desenhar só a área visível.
- **`Retro98FilesCore`** (nova biblioteca testável): locais, listagem de pastas, discos, histórico de navegação, interpretação do endereço, textos de status e o esquema de URL `retro98-explorer://`.
- **`Retro98Explorer`** (novo app comum, que aparece no ⌘Tab e na barra) liga tudo. A instalação reaproveita o empacotamento e o certificado das fases anteriores.

**Tech Stack:** Swift 6, AppKit (NSWindow sem borda, NSScrollView/NSScroller), Quartz (QLPreviewPanel), UniformTypeIdentifiers, DispatchSource, Swift Testing, bash, `iconutil`, `lsregister`.

**Spec:** `docs/superpowers/specs/2026-11-10-retro-desktop-design.md`, seção 6 › "Fase 3" (decisões de 2026-11-11), mais o esboço aprovado (`scratchpad/explorer-mockup/explorer.png`).

## Global Constraints

- Tudo das "Global Constraints" das Fases 1, 2A e 2B continua valendo: pixel 1x sem suavização, Tahoma 13 e negrito 12, paleta, só material original, pt-BR e en, só APIs públicas.
- **App:** `io.github.matheushchaves.retro98.explorer`, "Retro98 Explorer.app" em `~/Applications/Retro98/`, assinado com o mesmo certificado local (`sign_app`).
  - App comum (sem `LSUIElement`).
  - Esquema de URL `retro98-explorer`.
  - Ícone `.icns` gerado da pixel art original.
- **URLs:** `retro98-explorer://desktop`, `retro98-explorer://my-computer`, `retro98-explorer://trash` e `retro98-explorer://folder?path=<caminho com percent-encoding>`. Abrir uma URL abre uma janela nova no local.
- **Janela:**
  - Moldura de 4 pt (relevo `.window` de 2 pt mais 2 pt de face) e título de 18 pt com ícone de 16.
  - Botões minimizar, maximizar/restaurar e fechar, de 16×14, com 2 pt entre maximizar e fechar.
  - Tamanho mínimo 320×240; tamanho inicial 680×480, centralizado.
  - Maximizar ocupa a área visível da tela menos 28 pt embaixo quando o Retro98 Shell está rodando.
  - Duplo clique no título maximiza ou restaura.
- **Conteúdo da janela, de cima para baixo:**
  - barra de menus (22 pt) e linha entalhada;
  - barra de ferramentas (42 pt) e linha entalhada;
  - endereço (27 pt);
  - painéis, com árvore de 210 pt à esquerda, divisor de 4 pt e grade de ícones à direita;
  - barra de status (24 pt) com alça de redimensionar.
- **Grade de ícones grandes:**
  - Células de 88×76: ícone de 32 centralizado no topo (y + 4) e rótulo de até 2 linhas abaixo (y + 40), largura máxima 84, a segunda linha com "…".
  - Selecionado: fundo `#000080` e texto branco. Com foco: retângulo pontilhado.
- **Árvore:**
  - Linhas de 18 pt e recuo de 18 pt por nível; caixas +/− de 9×9 e linhas pontilhadas; ícone 16 e título.
  - Selecionado: fundo `#000080`.
- **Barras de rolagem:** clássicas, de 16 pt: setas em botões elevados, trilho em xadrez branco e face de 1 px, cursor com relevo `.window`.
- **Ícones:** retrô por tipo (pasta, documento, imagem, áudio, vídeo, compactado, texto, disco interno, removível, rede, Meu Computador, Meus Documentos, Lixeira vazia e cheia, Área de Trabalho). Apps usam o próprio ícone pixelado.
- **Ferramentas na 3A:** Voltar, Avançar e Acima funcionam. Recortar, Copiar, Colar, Desfazer, Excluir, Propriedades e Modos aparecem **desabilitados** (chegam na 3B e na 3C).
- **Lixeira:** sem permissão para ler `~/.Trash`, a área mostra a mensagem e um botão "Abrir no Finder". A Lixeira não é modificada na 3A.
- **Explorer padrão:** nada de `NSFileViewer` nesta fase; o Finder continua sendo o padrão.

## Review Focus

1. **Pastas enormes** (10 mil arquivos ou mais, como Downloads ou `node_modules`): listar sem travar e rolar desenhando só o visível. → Task 5, `visibleIndicesOnlyCoverTheRect`; Task 7, `listsTenThousandFilesQuickly`.
2. **Pastas sem permissão** (Mesa, Documentos e Downloads sob proteção do macOS, ou pastas do sistema): a janela mostra a mensagem e o resto continua funcionando. → Task 7, `unreadableFolderReportsPermission`; Task 8, mensagem na grade.
3. **Discos que somem** (pen drive ejetado com a janela aberta nele): Meu Computador se atualiza e a janela sobe para a pasta existente mais próxima, ou para Meu Computador. → Task 7, `recoverWalksUpToAnExistingPlace`.
4. **Nomes difíceis e pacotes:** emoji, acentos, nomes muito longos, sem extensão; `.app`, `.photoslibrary` e `.bundle` são itens, não pastas. → Task 7, `packagesAreNotFolders`; Task 5, `labelWrapsToTwoLinesWithEllipsis`.
5. **Endereço digitado:** `~`, `~/Downloads/`, `/Volumes/X`, "área de trabalho" e "meu computador" sem diferenciar maiúsculas; caminho inexistente mostra erro sem sair do lugar. → Task 7, testes de `AddressParser`.

---

## Estrutura de arquivos

```
Package.swift                         + Retro98FilesCore (lib), Retro98FilesCoreTests, Retro98Explorer (app), retro98-tools (exe)
Sources/Retro98UI/
  PixelCanvas.swift                   render por região; PixelView desenha só o retângulo sujo
  RetroScroller.swift                 barras de rolagem clássicas + fábrica de NSScrollView
  RetroAppWindow.swift, WindowGeometry.swift
  RetroMenuBar.swift, RetroToolbar.swift, RetroStatusBar.swift, RetroSplitView.swift
  RetroIconGrid.swift, IconGridLayout.swift, RetroTreeView.swift, TreeRows.swift
  RetroText.swift                     + label(_:maxWidth:maxLines:)
  Icons.swift, FileIcons.swift        ícones por tipo e da barra de ferramentas
Sources/Retro98FilesCore/
  Location.swift, FileEntry.swift, FileKindClassifier.swift, FolderListing.swift, Volumes.swift,
  DesktopLocation.swift, NavigationHistory.swift, AddressParser.swift, StatusText.swift,
  ExplorerURL.swift, DirectoryWatcher.swift, ExplorerText.swift
Sources/Retro98Explorer/              main.swift, AppDelegate.swift, ExplorerWindowController.swift,
                                      ExplorerMenus.swift, ExplorerTree.swift, ExplorerGrid.swift, QuickLook.swift
Sources/retro98-tools/main.swift      `iconset <nome> <pasta.iconset>`
Sources/Retro98Shell/QuickLaunchView.swift, TaskbarPanel.swift
scripts/build-app.sh (genérico), scripts/build-shell-app.sh (passa a chamar build-app.sh)
install.sh, uninstall.sh, README*.md, Tests/...
```

---

### Task 1: PixelView desenha só o que é visível

**Files:** Modify `Sources/Retro98UI/PixelCanvas.swift`. Test `Tests/Retro98UITests/PixelCanvasRegionTests.swift`.

**Interfaces:**
```swift
extension PixelCanvas {
    /// Render 1x de `region` (coordenadas da view, y para baixo): o desenho usa as coordenadas da view;
    /// o pixel (0,0) da imagem é region.origin; o clip do contexto é a própria região.
    public static func render(region: CGRect, _ draw: (CGContext) -> Void) -> PixelImage
}
// PixelView.draw(_ dirtyRect:) passa a usar render(region: dirtyRect.integral ∩ bounds) e desenha a imagem nesse retângulo.
// Views grandes podem pular itens fora de context.boundingBoxOfClipPath.
```
- [ ] **Step 1: Testes que falham**
  - `regionRenderUsesViewCoordinates`: com região `(10, 20, 5, 5)`, preencher `(12, 22, 1, 1)` de preto deixa o pixel (2, 2) preto e o (0, 0) intocado.
  - `regionRenderClipsToTheRegion`: `context.boundingBoxOfClipPath == region`.
  - `fullRenderStillWorks`: `render(width:height:)` não muda.
- [ ] **Step 2: Rodar `swift test --filter PixelCanvasRegionTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test`.** Esperado: tudo PASS.
- [ ] **Step 5: Commit** `feat: PixelView renders only the dirty region`

---

### Task 2: Barras de rolagem clássicas

**Files:** Create `Sources/Retro98UI/RetroScroller.swift`. Test `Tests/Retro98UITests/ScrollerTests.swift`.

**Interfaces:**
```swift
public final class RetroScroller: NSScroller {   // largura 16; nunca sobreposta; desenha via PixelCanvas
    public enum Arrow: Sendable { case up, down, left, right }
    nonisolated public static func drawArrowButton(_ arrow: Arrow, pressed: Bool, in rect: CGRect, context: CGContext)
    nonisolated public static func drawTrack(in rect: CGRect, context: CGContext)    // xadrez: (x+y) par = branco, ímpar = face
    nonisolated public static func drawKnob(in rect: CGRect, context: CGContext)     // face + relevo .window
    @MainActor public static func makeScrollView(document: NSView) -> NSScrollView  // .legacy, sem auto-ocultar, as duas barras retrô
}
```
- [ ] **Step 1: Testes que falham** (render 16×16 e 16×40)
  - `arrowButtonIsRaisedWithBlackTriangle`: (0, 0) é luz e o pixel central é preto.
  - `pressedArrowIsSunken`: (0, 0) é sombra escura.
  - `trackIsCheckered`: (0, 0) branco, (1, 0) face, (1, 1) branco.
  - `knobUsesWindowBevel`: (0, 0) face, (1, 1) luz.
  - `scrollViewUsesRetroScrollers`: as duas barras são `RetroScroller` e `scrollerStyle == .legacy`.
- [ ] **Step 2: Rodar `swift test --filter ScrollerTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test --filter ScrollerTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: classic scroll bars`

---

### Task 3: Janela de app redimensionável

**Files:** Create `Sources/Retro98UI/WindowGeometry.swift`, `RetroAppWindow.swift`. Test `Tests/Retro98UITests/AppWindowTests.swift`.

**Interfaces:**
```swift
public struct ResizeEdge: OptionSet, Sendable { public let rawValue: Int; left, right, top, bottom }
public enum WindowGeometry {
    public static let border: CGFloat = 4, titleHeight: CGFloat = 18, cornerGrip: CGFloat = 12
    public static let minimumSize = CGSize(width: 320, height: 240)
    /// Área de maximizar (coordenadas do AppKit, y para cima): visibleFrame menos `taskbarHeight` embaixo.
    public static func maximizedFrame(visibleFrame: CGRect, taskbarHeight: CGFloat) -> CGRect
    /// Borda sob o ponto (coordenadas viradas da janela); cantos de 12 pt combinam duas bordas; nil fora da moldura.
    public static func edge(at point: CGPoint, windowSize: CGSize) -> ResizeEdge?
    /// Novo frame (AppKit) ao arrastar a borda por `delta` (AppKit, y para cima), respeitando o tamanho mínimo.
    public static func resized(_ frame: CGRect, edge: ResizeEdge, delta: CGVector, minimumSize: CGSize) -> CGRect
}
@MainActor public final class RetroAppWindow: NSWindow {
    public init(title: String, icon: PixelIcon, contentSize: CGSize)
    public func setTitle(_ title: String, icon: PixelIcon)
    public let contentContainer: NSView                 // virada, abaixo do título
    public private(set) var isMaximized: Bool
    public var taskbarHeight: () -> CGFloat              // o app informa (0 ou 28)
    public func toggleMaximize()                         // guarda o frame para restaurar
    // botões: minimizar → miniaturize; maximizar → toggleMaximize; fechar → performClose
}
```
- A janela usa `styleMask [.borderless, .miniaturizable, .resizable]` e `canBecomeKey/Main = true`.
- **Arrastar:** pelo título move; pelas bordas e cantos redimensiona, com cursores de redimensionar.

- [ ] **Step 1: Testes que falham**
  - `maximizedFrameLeavesTheTaskbar`: visible `(0, 0, 1470, 922)` com barra de 28 → `(0, 28, 1470, 894)`.
  - `edgesAndCorners`: em 680×480, o ponto (1, 200) é `.left`; (678, 478) é `[.right, .bottom]`; (300, 10) é nil (título, dentro da moldura); (2, 8) é `[.left, .top]` (borda esquerda, a menos de 12 pt do canto).
  - `resizeFromLeftMovesOriginAndKeepsMinimum`: frame `(100, 100, 400, 300)`, `.left`, delta `+200` → `(180, 100, 320, 300)`.
  - `resizeFromTopGrowsUp`: `.top`, delta `+50` (AppKit) → altura 350, origem y igual.
  - `maximizeAndRestoreRoundTrip`: `toggleMaximize` duas vezes volta ao frame original.
- [ ] **Step 2: Rodar `swift test --filter AppWindowTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test --filter AppWindowTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: resizable retro app window`

---

### Task 4: Barra de menus, barra de ferramentas, barra de status e divisor

**Files:** Create `Sources/Retro98UI/RetroMenuBar.swift`, `RetroToolbar.swift`, `RetroStatusBar.swift`, `RetroSplitView.swift`. Test `Tests/Retro98UITests/ChromeTests.swift`.

**Interfaces:**
```swift
public struct RetroMenuBarMenu: Sendable { public let title: String; public let items: @Sendable @MainActor () -> [RetroMenuItem] }
@MainActor public final class RetroMenuBar: PixelView {   // títulos com 7 pt de folga dos dois lados; aberto = relevo afundado de 1 px
    public init(menus: [RetroMenuBarMenu])
    nonisolated public static func titleFrames(titles: [String], height: CGFloat) -> [CGRect]   // começa em x = 2
}
public struct ToolbarItem: Sendable { public let title: String; public let icon: PixelIcon; public let isEnabled: Bool
    public let action: @Sendable @MainActor () -> Void }
@MainActor public final class RetroToolbar: PixelView {   // botões planos: hover elevado de 1 px, pressionado afundado, desabilitado em relevo cinza
    public var items: [ToolbarItem?]                      // nil = separador
    nonisolated public static func frames(items: [ToolbarItem?], height: CGFloat) -> [CGRect]
    // largura = max(texto + 10, 48); separador = 8; folga inicial 4
}
@MainActor public final class RetroStatusBar: PixelView {
    public var fields: [(text: String, width: CGFloat?)]  // nil = ocupa o resto; 4 pt entre campos; alça de 12 pt à direita
    nonisolated public static func fieldFrames(widths: [CGFloat?], totalWidth: CGFloat, height: CGFloat) -> [CGRect]
}
@MainActor public final class RetroSplitView: NSSplitView {}   // divisor de 4 pt na cor face, vertical
```
- [ ] **Step 1: Testes que falham**
  - `menuTitlesAreSpacedFromTheLeft`: para "Arquivo" e "Editar", o primeiro frame começa em x = 2 com largura = texto + 14, e o segundo começa no fim do primeiro.
  - `toolbarFramesIncludeSeparators`: `[a, nil, b]` dá a, depois 8 de separador, depois b; a largura mínima é 48.
  - `disabledToolbarItemIsEmbossed`: o render de um item desabilitado contém pixels de luz e de sombra e nenhum preto.
  - `statusFieldsFillTheRest`: larguras `[300, 140, nil]` em 680 → o terceiro vai até `680 - 4 - 12`.
- [ ] **Step 2: Rodar `swift test --filter ChromeTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.** A barra de menus abre `RetroMenu` (estilo padrão) logo abaixo do título; com um menu aberto, passar sobre outro título troca o menu.
- [ ] **Step 4: Rodar `swift test --filter ChromeTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: menu bar, toolbar, status bar and split view`

---

### Task 5: Grade de ícones e árvore

**Files:** Create `Sources/Retro98UI/IconGridLayout.swift`, `RetroIconGrid.swift`, `TreeRows.swift`, `RetroTreeView.swift`; Modify `RetroText.swift`. Test `Tests/Retro98UITests/GridAndTreeTests.swift`.

**Interfaces:**
```swift
extension RetroText {
    /// Até `maxLines` linhas; a última termina em "…" se sobrar texto; uma palavra larga demais é cortada com "…".
    public static func label(_ text: String, maxWidth: Int, maxLines: Int) -> [String]
}
public enum IconGridLayout {
    public static let cell = CGSize(width: 88, height: 76), inset: CGFloat = 8
    public static func columns(forWidth width: CGFloat) -> Int                      // max(1, floor((width − 2·inset) / 88))
    public static func frame(of index: Int, columns: Int) -> CGRect
    public static func contentHeight(count: Int, columns: Int) -> CGFloat
    public static func indices(in rect: CGRect, columns: Int, count: Int) -> Range<Int>
    public static func index(at point: CGPoint, columns: Int, count: Int) -> Int?
}
@MainActor public protocol RetroIconGridDataSource: AnyObject {
    func numberOfItems(in grid: RetroIconGrid) -> Int
    func grid(_ grid: RetroIconGrid, titleAt index: Int) -> String
    func grid(_ grid: RetroIconGrid, iconAt index: Int) -> PixelIcon
}
@MainActor public final class RetroIconGrid: PixelView {   // documento de um RetroScroller scroll view; desenha só o visível
    public weak var dataSource: RetroIconGridDataSource?
    public private(set) var selection: IndexSet
    public var onOpen: ((Int) -> Void)?; public var onSelectionChange: ((IndexSet) -> Void)?
    public func reloadData()
    // clique, ⌘-clique, retângulo no fundo, duplo clique e Enter abrem; setas movem; ⌘A seleciona tudo
}
public struct TreeRow: Equatable, Sendable { public let id: String; public let depth: Int }
public enum TreeRows {
    public static func flatten(roots: [String], children: (String) -> [String], expanded: Set<String>) -> [TreeRow]
}
@MainActor public protocol RetroTreeDataSource: AnyObject {
    func tree(_ tree: RetroTreeView, childrenOf id: String) -> [String]   // carregado ao expandir
    func tree(_ tree: RetroTreeView, titleOf id: String) -> String
    func tree(_ tree: RetroTreeView, iconOf id: String) -> PixelIcon
    func tree(_ tree: RetroTreeView, isExpandable id: String) -> Bool
}
@MainActor public final class RetroTreeView: PixelView {
    public weak var dataSource: RetroTreeDataSource?
    public var roots: [String]; public private(set) var expanded: Set<String>; public private(set) var selected: String?
    public var onSelect: ((String) -> Void)?
    public func reveal(path ids: [String])        // expande os ancestrais e seleciona o último
    public func reloadData()
    // clique na caixa expande ou recolhe; clique no título seleciona; setas: ↑↓ andam, ← recolhe/sobe, → expande/desce
}
```
- [ ] **Step 1: Testes que falham**
  - `gridColumnsAndFrames`: largura 450 dá 4 colunas; o frame do índice 5 é `(8 + 88, 8 + 76, 88, 76)`.
  - `visibleIndicesOnlyCoverTheRect`: 10.000 itens com 4 colunas e retângulo `(0, 76·100, 450, 300)` dão as linhas 99 a 103, ou seja, os índices 396..<416.
  - `indexAtPoint`: centro da célula 5 → 5; abaixo do último item → nil.
  - `labelWrapsToTwoLinesWithEllipsis`: com 7 pt por caractere e largura 84 (12 caracteres), "Captura de Tela 2026-11-11.png" vira `["Captura de", "Tela 2026-1…"]`.
  - `flattenRespectsExpansion`: as raízes `[d]`, com d → `[c, m]` e c → `[hd]`, expandidas `{d, c}`, dão `[d:0, c:1, hd:2, m:1]`.
- [ ] **Step 2: Rodar `swift test --filter GridAndTreeTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test --filter GridAndTreeTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: icon grid and tree view`

---

### Task 6: Ícones por tipo, de locais e da barra de ferramentas

**Files:** Create `Sources/Retro98UI/FileIcons.swift`. Test `Tests/Retro98UITests/FileIconTests.swift`.

**Interfaces:**
```swift
public enum FileIconKind: CaseIterable, Sendable {
    case folder, document, image, audio, video, archive, text, hardDisk, removableDisk, networkDisk,
         myComputer, myDocuments, recycleBinEmpty, recycleBinFull, desktop
}
public enum FileIcons {
    public static func icon(_ kind: FileIconKind, size: Int) -> PixelIcon   // size 16 ou 32; originais, desenhados com Painter
    public static let back, forward, up, cut, copy, paste, undo, delete, properties, views: PixelIcon   // 16×16
    public static let explorerApp: PixelIcon   // 32×32: pasta amarela com lupa (ícone do app e do Início rápido)
}
```
- [ ] **Step 1: Testes que falham**
  - `everyKindHasBothSizes`: as 15 espécies em 16 e 32 têm o tamanho certo e mais de 1/8 de pixels opacos.
  - `kindsAreDistinct`: os renders de 32 são diferentes entre si.
  - `toolbarIconsAre16`.
- [ ] **Step 2: Rodar `swift test --filter FileIconTests`.** Esperado: FAIL.
- [ ] **Step 3: Desenhar** e conferir numa folha de contato no scratchpad.
- [ ] **Step 4: Rodar `swift test --filter FileIconTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: retro file, place and toolbar icons`

---

### Task 7: `Retro98FilesCore` — locais, listagem, discos, navegação, endereço, status e URLs

**Files:** Create `Sources/Retro98FilesCore/*` (veja a estrutura) e o alvo no `Package.swift` (depende de `Retro98Settings`). Test `Tests/Retro98FilesCoreTests/*`.

**Interfaces:**
```swift
public enum Location: Hashable, Sendable { case desktop, myComputer, trash, folder(URL) }
public enum FileKind: Equatable, Sendable {
    case folder, application, image, audio, video, archive, text, document
    case volume(VolumeKind), myComputer, myDocuments, recycleBin(isFull: Bool?)
}
public enum VolumeKind: Equatable, Sendable { case internal, removable, network }
public struct FileEntry: Equatable, Sendable {
    public let url: URL; public let name: String; public let kind: FileKind
    public let size: Int64?; public let modified: Date?; public let location: Location?   // para onde ir ao abrir; nil = abrir com o app
}
public enum FileKindClassifier { public static func kind(for url: URL, isDirectory: Bool, isPackage: Bool) -> FileKind }
public enum FolderListingError: Error, Equatable { case notFound, permissionDenied }
public enum FolderListing {
    /// Pastas primeiro, depois localizedStandardCompare; ocultos fora (a menos que showHidden); pacotes são itens.
    public static func entries(of folder: URL, showHidden: Bool, fileManager: FileManager = .default) throws(FolderListingError) -> [FileEntry]
}
public struct VolumeInfo: Equatable, Sendable { public let url: URL; public let name: String; public let kind: VolumeKind
    public let totalBytes: Int64?; public let freeBytes: Int64?; public let isEjectable: Bool }
public enum Volumes { public static func mounted(fileManager: FileManager = .default) -> [VolumeInfo] }   // .skipHiddenVolumes
public enum DesktopLocation {
    public static func entries(desktop: URL, documents: URL, trash: URL, languages: [String],
                               fileManager: FileManager = .default) -> [FileEntry]   // fixos + arquivos da Mesa (sem erro: Mesa ilegível → só fixos)
}
public struct NavigationHistory: Equatable, Sendable {
    public init(start: Location)
    public private(set) var current: Location
    public var canGoBack: Bool { get }; public var canGoForward: Bool { get }
    public mutating func go(to location: Location)       // limpa o futuro; ir ao mesmo local não empilha
    public mutating func back(); public mutating func forward()
    public static func parent(of location: Location, volumes: [URL]) -> Location?
    // pasta → pasta-mãe; raiz de volume → .myComputer; .myComputer, .trash → .desktop; .desktop → nil
    public static func recover(_ location: Location, exists: (URL) -> Bool, volumes: [URL]) -> Location
}
public enum AddressParser {
    public static func location(for text: String, home: URL, languages: [String], isDirectory: (String) -> Bool) -> Location?
    public static func text(for location: Location, languages: [String]) -> String   // pasta = caminho POSIX completo
}
public enum StatusText {
    public static func objects(count: Int, selected: Int, languages: [String]) -> String   // "7 objeto(s)" / "2 objeto(s) selecionado(s)"; en "7 object(s)" / "2 object(s) selected"
    public static func bytes(_ value: Int64, locale: Locale) -> String                      // ByteCountFormatter .file
    public static func free(_ value: Int64, locale: Locale, languages: [String]) -> String  // "Livre: 190 GB" / "Free: 190 GB"
}
public enum ExplorerURL {
    public static let scheme = "retro98-explorer"
    public static func url(for location: Location) -> URL
    public static func location(from url: URL) -> Location?
}
public final class DirectoryWatcher { public init?(url: URL, onChange: @escaping @Sendable () -> Void); public func stop() }
public enum ExplorerText {
    // títulos pt/en: "Área de Trabalho"/"Desktop", "Meu Computador"/"My Computer", "Meus Documentos"/"My Documents",
    // "Lixeira"/"Recycle Bin", "Downloads"/"Downloads"; menus "Arquivo","Editar","Exibir","Ir","Favoritos","Ajuda"
    // (en "File","Edit","View","Go","Favorites","Help"); ferramentas "Voltar","Avançar","Acima","Recortar","Copiar",
    // "Colar","Desfazer","Excluir","Propriedades","Modos" (en "Back","Forward","Up","Cut","Copy","Paste","Undo",
    // "Delete","Properties","Views"); "Endereço"/"Address"; erros: "Não foi possível encontrar '<x>'." / "Cannot find '<x>'.";
    // "Você não tem permissão para ver esta pasta." / "You don't have permission to view this folder.";
    // Lixeira sem acesso: "Para ver a Lixeira aqui, dê Acesso Total ao Disco ao Retro98 Explorer." +
    // botão "Abrir no Finder" / en equivalentes
}
```
- [ ] **Step 1: Testes que falham** (pastas temporárias; `TempTree` como na 2A)
  - `listsFoldersFirstThenNames`, `hiddenFilesStayHiddenUnlessAsked`, `packagesAreNotFolders` (`Foo.app` vira `.application`; `Lib.bundle` e `X.photoslibrary` são itens e não pastas).
  - `classifiesByType`: png → image, mp3 → audio, mov → video, zip → archive, txt e swift → text, pdf → document, sem extensão → document.
  - `listsTenThousandFilesQuickly`: 10.000 arquivos listados em menos de 1 s.
  - `unreadableFolderReportsPermission` (chmod 000) e `missingFolderReportsNotFound`.
  - `desktopShowsFixedItemsThenFiles`: os ids e a ordem como na 2C. Uma Mesa ilegível dá só os 3 fixos.
  - **Histórico:**
    - `historyBackForward`: ir de A para B e para C, voltar duas vezes (A), avançar (B), ir para D apaga o C do futuro.
    - `goingToTheSamePlaceDoesNotStack`.
    - `parents`: `/Users/t/Docs` → `/Users/t`; raiz de volume → `.myComputer`; `.myComputer` → `.desktop`; `.desktop` → nil.
    - `recoverWalksUpToAnExistingPlace`: com `/Volumes/PEN/a/b`, sem existir nada em `/Volumes/PEN`, dá `.myComputer`.
  - **Endereço:**
    - `addressAcceptsNamesAndPaths`: "área de trabalho" → `.desktop`; "MEU COMPUTADOR" → `.myComputer`; "~" → a home; "~/Downloads/" → `folder(home/Downloads)`; "/Volumes/X" (existente) → folder; "nada" → nil.
    - `addressTextRoundTrips`.
  - **Status:** `statusTexts` com pt_BR: `bytes(1_200_000)` contém "1,2" e "MB"; `objects(count: 7, selected: 0)` == "7 objeto(s)"; `objects(count: 7, selected: 2)` == "2 objeto(s) selecionado(s)".
  - **URLs:** `explorerURLsRoundTrip` para os 4 locais, incluindo um caminho com espaço e acento; uma URL de outro esquema dá nil.
  - **Vigia:** `watcherFiresOnChange` com espera por `confirmation` e limite de 1 s.
- [ ] **Step 2: Rodar `swift test --filter Retro98FilesCoreTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test`.** Esperado: tudo PASS.
- [ ] **Step 5: Commit** `feat: add Retro98FilesCore (places, listing, volumes, history, address, status, URLs)`

---

### Task 8: App Retro98 Explorer

**Files:** Create `Sources/Retro98Explorer/*` e o alvo executável no `Package.swift` (depende de UI, FilesCore e Settings). Test `Tests/Retro98FilesCoreTests/ExplorerControllerModelTests.swift` (modelo testável abaixo).

**Interfaces:**
```swift
// FilesCore: estado de uma janela, sem AppKit
@MainActor public final class ExplorerModel {
    public init(start: Location, environment: ExplorerEnvironment)
    public private(set) var history: NavigationHistory
    public private(set) var entries: [FileEntry]
    public private(set) var error: String?            // mensagem para mostrar no lugar da grade
    public var title: String { get }
    public func go(to location: Location); public func back(); public func forward(); public func up()
    public func open(_ entry: FileEntry) -> URL?        // local → navega e retorna nil; arquivo ou app → URL para o NSWorkspace
    public func reload()                                // usa recover() se o local sumiu
    public var onChange: (() -> Void)?
}
public struct ExplorerEnvironment: Sendable {          // injetável nos testes
    public let home: URL; public let languages: [String]; public let showHidden: Bool
    public let volumes: @Sendable () -> [VolumeInfo]; public let trash: URL
}
```
**App** (verificação manual):
- **`AppDelegate`:**
  - Trata `application(_:open urls:)` e as URLs `retro98-explorer://`. Sem URL ao abrir, ou ao reabrir sem janelas, abre uma janela nova na Área de Trabalho.
  - Política `.regular`; o menu principal do macOS vem de `ExplorerMenus`.
- **`ExplorerWindowController`** monta a janela na ordem de Global Constraints:
  - Árvore: Área de Trabalho › (Meu Computador › volumes › pastas), Meus Documentos, Downloads, Lixeira.
  - Grade com dados do modelo.
  - Barra de ferramentas: só Voltar, Avançar e Acima habilitados, conforme o histórico.
  - Endereço: `NSTextField` Tahoma 13 num relevo `.field`, com ícone e seta da lista de ancestrais. Enter leva ao local, ou mostra `RetroMessageBox` de erro.
  - Barra de status com objetos, tamanho da seleção e espaço livre do volume atual.
  - Título da janela igual ao do local.
  - `DirectoryWatcher` na pasta atual; `NSWorkspace.didMount` e `didUnmount` atualizam Meu Computador e a árvore.
- **`ExplorerMenus`:**
  - Na janela e no macOS: Arquivo (Nova janela ⌘N, Fechar ⌘W); Editar (Selecionar tudo ⌘A; os demais desabilitados); Exibir (Atualizar ⌘R).
  - Ir: Voltar ⌘[, Avançar ⌘], Acima ⌘↑, Área de Trabalho ⇧⌘D, Meu Computador ⇧⌘C, Meus Documentos ⇧⌘O, Downloads ⌥⌘L.
  - Favoritos: Área de Trabalho, Documentos, Downloads, Aplicativos.
  - Ajuda: abre o README.
  - No menu do app do macOS: Sobre e Encerrar ⌘Q.
- **`QuickLook`:** a barra de espaço alterna o `QLPreviewPanel` com os arquivos selecionados; a janela é a controladora do painel.
- **Lixeira sem acesso:** mostra `ExplorerText` mais o botão "Abrir no Finder" (`NSWorkspace.open(~/.Trash)`).
- **Maximizar:** usa `taskbarHeight = 28` se houver um app rodando com o bundle `io.github.matheushchaves.retro98.shell`, senão 0.

- [ ] **Step 1: Testes que falham** (`ExplorerModel` com ambiente falso e pastas temporárias)
  - `startsOnTheDesktop`: o título é "Área de Trabalho" e as entradas começam com os 3 fixos.
  - `openingAFolderNavigatesAndAFileReturnsItsURL`.
  - `upFromAFolderGoesToItsParent`, e `backAndForwardFollowHistory`.
  - `vanishedFolderRecovers`: apagar a pasta atual e chamar `reload()` sobe para a mãe.
  - `permissionErrorIsShownNotThrown`: pasta com chmod 000 dá `error == ExplorerText.permissionDenied` e `entries` vazio.
- [ ] **Step 2: Rodar `swift test --filter ExplorerControllerModelTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar o modelo e o app.**
- [ ] **Step 4: Rodar `swift test`** e `swift build -c release --product Retro98Explorer` sem warnings. Esperado: PASS.
- [ ] **Step 5: Teste rápido de fumaça:** rodar `.build/release/Retro98Explorer` sem argumentos. Ele abre a Área de Trabalho e deve continuar vivo depois de 4 s; depois encerrar.
- [ ] **Step 6: Commit** `feat: Retro98 Explorer app (browse)`

---

### Task 9: "Início rápido" na barra de tarefas

**Files:** Create `Sources/Retro98Shell/QuickLaunchView.swift`; Modify `TaskbarPanel.swift`, `Package.swift` (ShellCore passa a depender de FilesCore). Test `Tests/Retro98ShellCoreTests/QuickLaunchTests.swift`.

**Interfaces:**
- `QuickLaunch.desktopURL: URL` (ShellCore) = `ExplorerURL.url(for: .desktop)`.
- `QuickLaunch.isAvailable(canOpen: (URL) -> Bool) -> Bool`: o app usa `NSWorkspace.urlForApplication(toOpen:) != nil`.
- **`QuickLaunchView`:**
  - Botão plano de 22×22 com `FileIcons.explorerApp` reduzido a 16, depois do Iniciar e de um separador entalhado. Hover elevado, pressionado afundado.
  - Dica: "Mostrar a Área de Trabalho" / "Show Desktop".
  - Some se o Explorer não estiver instalado.
  - Os botões de janela começam depois dele.

- [ ] **Step 1: Teste que falha.** `quickLaunchOpensTheDesktop`: a URL é `retro98-explorer://desktop`, e `isAvailable` segue o `canOpen`.
- [ ] **Step 2: Rodar `swift test --filter QuickLaunchTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test`** e o build release do Shell. Esperado: PASS.
- [ ] **Step 5: Commit** `feat: quick launch on the taskbar`

---

### Task 10: Empacotamento, ícone do app, instalador e README

**Files:** Create `scripts/build-app.sh`, `Sources/retro98-tools/main.swift`; Modify `scripts/build-shell-app.sh` (vira wrapper), `install.sh`, `uninstall.sh`, `Tests/scripts/test_install.sh`, `Tests/scripts/test_uninstall.sh`, `README*.md`, `.github/workflows/ci.yml`.

**Interfaces:**
- **`retro98-tools iconset <explorer|shell> <saída.iconset>`:** grava os PNGs das tamanhos padrão (16 a 1024, @1x e @2x), ampliando a pixel art sem suavização. Para `shell`, usa o `Icons.startLogo`.
- **`build-app.sh <produto> <bundle id> <nome> <saída.app> <agent|regular> [esquema-url] [icone]`:**
  - Compila e monta o bundle; inclui `CFBundleURLTypes` quando há esquema, e o `.icns` via `iconutil` quando há ícone.
  - Assina com `sign_app`. Recusa saída que não termine em `.app`.
  - `build-shell-app.sh "$OUT"` chama `build-app.sh Retro98Shell <id do shell> "Retro98 Shell" "$OUT" agent "" shell`.
- **`install.sh`**, na peça shell (o Explorer acompanha a barra):
  - Monta `~/Applications/Retro98/Retro98 Explorer.app` (regular, esquema `retro98-explorer`, ícone `explorer`).
  - Registra no LaunchServices com `"${RETRO98_LSREGISTER:-/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister}" -f "$APP"`.
  - Mostra o aviso de Acesso Total ao Disco para o Explorer, só para ver a Lixeira. pt-BR: "Para o Explorer mostrar a Lixeira, dê Acesso Total ao Disco ao Retro98 Explorer em Ajustes do Sistema › Privacidade e Segurança › Acesso Total ao Disco." (en equivalente)
  - Abre o painel e roda `open -R` no app.
- **`uninstall.sh`:** remove o Explorer (`lsregister -u` antes) junto com o Shell, só depois de uma restauração bem-sucedida.
- **Testes:**
  - `test_install.sh`: `open` falso e `RETRO98_LSREGISTER` falso no PATH. Casos `explorer-built`, `explorer-is-regular-app` (sem LSUIElement), `explorer-url-scheme` (PlistBuddy lê o esquema), `explorer-has-icon` (`.icns` existe), `explorer-registered`, `explorer-fda-hint`.
  - `test_uninstall.sh`: caso `explorer-removed`.
- **CI:** monta também o Explorer com `RETRO98_SIGNING=adhoc`.

- [ ] **Step 1: Testes que falham** (os casos acima).
- [ ] **Step 2: Rodar os scripts.** Esperado: FAIL nos casos novos.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: README** (pt-BR e en):
  - Fase 3A disponível.
  - Seção "Explorer": o que faz, como abrir (Início rápido, menu Iniciar › Programas › Retro98, URL), atalhos e o que chega na 3B e na 3C.
  - Acesso Total ao Disco opcional, só para a Lixeira.
- [ ] **Step 5: Rodar `swift test` e os três scripts, no bash do sistema.** Esperado: tudo PASS e a lista de chaveiros inalterada.
- [ ] **Step 6: Commit** `feat: package and install Retro98 Explorer`

---

### Aceitação pelo autor (manual, no Mac dele, depois da Task 10)

O autor roda `./install.sh --yes` (ou autoriza explicitamente) e confere:
- [ ] O ícone do Início rápido abre o Explorer na Área de Trabalho, como no esboço: Meu Computador, Meus Documentos, Lixeira e os arquivos da Mesa.
- [ ] A janela move, redimensiona pelas bordas e pela alça, maximiza e restaura (botão e duplo clique no título), minimiza e fecha. Maximizada, não passa por baixo da barra.
- [ ] Clique duplo entra nas pastas; Voltar, Avançar e Acima funcionam (botões e ⌘[, ⌘], ⌘↑); digitar um caminho no endereço funciona e um caminho errado mostra erro.
- [ ] A árvore expande, recolhe e navega, e acompanha a pasta atual.
- [ ] Meu Computador mostra o disco interno e os pen drives; plugar e ejetar um pen drive atualiza a janela.
- [ ] Arquivos abrem no app certo, apps abrem, e a barra de espaço espia o arquivo.
- [ ] Downloads, ou outra pasta grande, rola liso. A barra de status mostra objetos, tamanho e espaço livre.
- [ ] Uma pasta sem permissão mostra a mensagem; a Lixeira mostra o conteúdo ou o botão "Abrir no Finder".
- [ ] O Explorer aparece no ⌘Tab e nos botões da barra, com o próprio ícone.
- [ ] `./uninstall.sh` remove o Explorer junto com o resto.
