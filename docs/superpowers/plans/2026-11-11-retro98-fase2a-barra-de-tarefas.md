# Retro98 Fase 2A — Base visual, barra de tarefas e menu Iniciar: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Um app `Retro98 Shell` que mostra uma barra de tarefas estilo 98 na base da tela principal: botão Iniciar com menu, relógio, bateria e volume. Ele roda como LaunchAgent, se recupera de quedas e é instalado e desinstalado pelos scripts existentes.

**Architecture:** A biblioteca nova `Retro98UI` desenha tudo pixel a pixel: cada view renderiza numa bitmap 1x sem suavização e amplia sem interpolação para a tela Retina. A biblioteca `Retro98ShellCore` concentra a lógica testável: modelo do menu Iniciar, interpretação do Executar, ações de energia, bandeja e contador de quedas. O executável `Retro98Shell` liga UI e lógica. O Dock passa a ser um ajuste reversível do motor da Fase 1 (`dockUnderTaskbar`).

**Tech Stack:** Swift 6, AppKit, CoreText, Carbon (`RegisterEventHotKey`), IOKit (bateria), CoreAudio (volume), launchd, Swift Testing, bash.

**Spec:** `docs/superpowers/specs/2026-11-10-retro-desktop-design.md` (seções 4, 5, 6 "Fase 2", 7). Divisão da Fase 2 **[minha escolha]**: 2A = base visual + barra de tarefas + Iniciar + recuperação; 2B = botões de janela (Acessibilidade + certificado local) + área de trabalho.

## Global Constraints

- Tudo da seção "Global Constraints" do plano da Fase 1 continua valendo (macOS 14+, sem dependências de terceiros, prefixo `io.github.matheushchaves.retro98`, backup antes de qualquer mudança, pt-BR/en pelo primeiro idioma, nada da Microsoft).
- **Paleta exata** (spec §5): face `#C0C0C0`, sombra `#808080`, luz `#FFFFFF`, sombra escura `#000000`, título ativo `#000080`→`#1084D0`, título inativo `#808080`→`#C0C0C0`, seleção `#000080` com texto branco, tooltip `#FFFFE1` com borda preta.
- **1 pt = 1 pixel retrô.** Cada view desenha numa bitmap de 1x (tamanho em pontos) com anti-aliasing e suavização de fonte desligados, e essa bitmap é desenhada na view com `interpolationQuality = .none`. Exceção permitida: o texto **editável** do campo do Executar usa `NSTextField` comum com Tahoma 11.
- **Fonte:** Tahoma 11 pt (`/System/Library/Fonts/Supplemental/Tahoma.ttf`), regular e negrito. Validada em spike: sem suavização fica nítida. Não é redistribuída.
- **Ícones:** pixel art original, definida no código como mapas ASCII com a paleta de 16 cores VGA abaixo. Ícones de apps do Mac são o ícone real desenhado em 16×16 ou 32×32 a 1x e ampliado sem suavização.
- Paleta ASCII dos ícones: `.` transparente, `K` `#000000`, `W` `#FFFFFF`, `G` `#C0C0C0`, `D` `#808080`, `N` `#000080`, `B` `#0000FF`, `T` `#008080`, `C` `#00FFFF`, `E` `#008000`, `L` `#00FF00`, `O` `#808000`, `Y` `#FFFF00`, `M` `#800000`, `R` `#FF0000`, `P` `#800080`.
- Bundle do Shell: `io.github.matheushchaves.retro98.shell`, nome `Retro98 Shell.app`, instalado em `~/Applications/Retro98/`. LaunchAgent: `~/Library/LaunchAgents/io.github.matheushchaves.retro98.shell.plist`, label igual ao bundle id. O app é agente (`LSUIElement = true`), sem ícone no Dock.
- Barra de tarefas: só na tela principal, largura total, altura = **max(28 pt, altura que o Dock reserva na tela principal)**, nível de janela = nível do Dock + 1, visível em todos os Spaces, oculta em apps de tela cheia, nunca rouba o foco do app ativo.
- Sem permissões novas nesta fase, exceto o aviso de Automação do macOS na primeira vez que "Desligar…" for usado. Assinatura ad-hoc nesta fase; o certificado local fica para a 2B.
- Itens fora da 2A, com motivo: "Localizar" (precisa da lista do Explorer, entra na Fase 3); botão "Procurar…" do Executar (precisa do diálogo de abrir próprio, Fase 3); "Painel de Controle" em Configurações (Fase 5); sons (Fase 5); botões de janela e área de trabalho (2B).

## Review Focus

1. **Listas grandes de apps**: centenas de apps, pastas aninhadas, nomes repetidos em pastas diferentes, pasta ilegível. O menu Programas não trava, ordena pastas primeiro e depois por nome (sem diferenciar maiúsculas), ignora o que não consegue ler e quebra em colunas quando passa da altura da tela. → Task 8, `buildsTreeFromNestedFolders`, `skipsUnreadableFolders`; Task 7, `wrapsIntoColumnsWhenTallerThanScreen`.
2. **Mudanças de tela**: ligar ou desligar monitor, mudar resolução ou tamanho do Dock. A barra recalcula posição e altura e continua só na tela principal. → Task 11, `taskbarFrameCoversDockReservedArea`, `taskbarFrameUsesMinimumHeight`.
3. **Shell caindo em loop ou morto**: o launchd relança. Com 3 quedas em 60 s, o Shell desiste, devolve o Dock, avisa e se desliga. → Task 12, `givesUpAfterThreeLaunchesWithinSixtySeconds`, `cleanExitClearsHistory`.
4. **Automação negada no "Desligar…"**: aparece caixa de mensagem explicando, nunca falha em silêncio. → Task 9, `powerActionReportsFailureWhenOsascriptFails`.
5. **Entradas do Executar**: vazio, só espaços, `~/Downloads`, caminho inexistente, `safari` (minúsculas), `Safari.app`, `https://…`, `www.exemplo.com`, nome com acento, app com o mesmo nome em duas pastas. → Task 9, testes `RunTarget`.

---

## Estrutura de arquivos

```
Package.swift                                   + alvos Retro98UI, Retro98ShellCore, Retro98Shell e testes
Sources/Retro98Settings/Tweaks/Tweak.swift      + TweakGroup, case dockUnderTaskbar, RefreshEffect.restartDock
Sources/Retro98Settings/Tweaks/TweakCatalog.swift  + shell(), all(...)
Sources/Retro98Settings/System/MacSystemRefresher.swift  + restartDock
Sources/retro98-settings/{main,Messages}.swift  correções da Fase 1, apply padrão = grupo base
Sources/Retro98UI/
  Palette.swift            cores
  PixelCanvas.swift        render 1x + leitura de pixels (testes) + PixelView (base NSView)
  Bevel.swift              estilos de relevo
  PixelText.swift          Tahoma 11 sem suavização: desenhar e medir
  PixelIcon.swift          mapa ASCII → CGImage; ícone de app pixelado
  Icons.swift              conjunto de ícones originais da 2A
  RetroButton.swift        botão (normal, pressionado, padrão, foco)
  RetroRadioButton.swift
  RetroWindow.swift        janela de diálogo com barra de título e ×
  RetroMessageBox.swift
  RetroMenu.swift          menu em cascata (modelo de item + painel)
  RetroTooltip.swift
Sources/Retro98ShellCore/
  StartMenuModel.swift     árvore de itens do Iniciar
  ProgramsTreeBuilder.swift
  RecentDocuments.swift
  RunTarget.swift
  PowerAction.swift
  TrayModels.swift         relógio, bateria, volume (formatação e estados)
  TaskbarGeometry.swift
  LaunchHistory.swift      contador de quedas
Sources/Retro98Shell/
  main.swift, AppDelegate.swift, TaskbarPanel.swift, StartMenuController.swift,
  RunDialog.swift, ShutdownDialog.swift, TrayView.swift, HotKey.swift, SystemReaders.swift, Recovery.swift
scripts/build-shell-app.sh                       monta o .app e assina ad-hoc
install.sh, uninstall.sh, scripts/common.sh      peças, LaunchAgent, app
Tests/Retro98UITests/, Tests/Retro98ShellCoreTests/, Tests/scripts/test_uninstall.sh
README.md, README.pt-BR.md
```

---

### Task 1: Correções da Fase 1 vistas no teste real

**Files:**
- Modify: `Sources/retro98-settings/main.swift`, `Sources/retro98-settings/Messages.swift`, `uninstall.sh`
- Test: `Tests/scripts/test_uninstall.sh`

- [ ] **Step 1: Teste que falha.** Em `test_uninstall.sh`, adicionar o caso `dsstore`: a pasta de suporte tem `.DS_Store` além do `backup.plist`, o stub sai 0, e a pasta deve sumir.
- [ ] **Step 2: Rodar `bash Tests/scripts/test_uninstall.sh`.** Esperado: `FAIL dsstore`.
- [ ] **Step 3: Implementar.**
  - `uninstall.sh` também remove `"$SUPPORT_DIR/.DS_Store"`.
  - Em `main.swift`, toda a saída vai para stdout na ordem: linhas de resultado e depois as orientações. Só a mensagem de backup ilegível e a de uso continuam em stderr.
  - A mensagem de acesso negado ganha a frase final. pt-BR: "Depois de ativar, feche e abra de novo o app de terminal." en: "After turning it on, quit and reopen the terminal app."
- [ ] **Step 4: Rodar `bash Tests/scripts/test_uninstall.sh && swift test`.** Esperado: tudo PASS.
- [ ] **Step 5: Commit** `fix: clearer Full Disk Access guidance and tidy uninstall`

---

### Task 2: Ajuste reversível do Dock e grupos de ajustes

**Files:**
- Modify: `Sources/Retro98Settings/Tweaks/Tweak.swift`, `TweakCatalog.swift`, `System/MacSystemRefresher.swift`, `Sources/retro98-settings/main.swift`
- Test: `Tests/Retro98SettingsTests/TweakCatalogTests.swift`, `MacServicesTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum TweakGroup: String, Codable, Sendable { case base, shell }
  // Tweak ganha `public let group: TweakGroup` (init com padrão .base)
  // TweakID ganha `case dockUnderTaskbar` (no fim de allCases)
  // RefreshEffect ganha `case restartDock`
  extension TweakCatalog {
      public static func shell() -> [Tweak]                                    // [dockUnderTaskbar]
      public static func all(osMajorVersion: Int, homeDirectory: URL) -> [Tweak] // phase1 + shell
  }
  ```
- Valores de `dockUnderTaskbar` (domínio `.app("com.apple.dock")`, grupo `.shell`, efeitos `[.restartDock]`):
  - `tilesize` → `.int(16)`
  - `magnification` → `.bool(false)`
  - `autohide` → `.bool(false)`
  - `orientation` → `.string("bottom")`
  - título pt-BR "Dock pequeno sob a barra de tarefas", en "Small Dock under the taskbar"
- `MacSystemRefresher.perform`: `.restartDock` → `run("/usr/bin/killall", ["Dock"])`.
- CLI: `main.swift` usa `TweakCatalog.all(...)`. `apply` sem `--only` aplica só o grupo `.base`. `restore` sem `--only` continua restaurando tudo o que está no backup. `status` lista todos.

- [ ] **Step 1: Testes que falham**

```swift
@Test func shellCatalogPinsDockValues() {
    let dock = TweakCatalog.shell().first { $0.id == .dockUnderTaskbar }
    #expect(dock?.group == .shell)
    #expect(dock?.effects == [.restartDock])
    #expect(dock?.changes.first { $0.key.name == "tilesize" }?.target == .int(16))
    #expect(dock?.changes.first { $0.key.name == "orientation" }?.target == .string("bottom"))
}
@Test func allCatalogIsPhase1PlusShell() {
    let all = TweakCatalog.all(osMajorVersion: 27, homeDirectory: URL(filePath: "/Users/test"))
    #expect(all.map(\.id) == TweakID.allCases)
    #expect(all.filter { $0.group == .base }.count == 9)
}
@Test func refresherRestartsDock() { /* perform([.restartDock]) → runs == [["/usr/bin/killall", "Dock"]] */ }
```

- O teste da Fase 1 `listsEveryTweakOnceInOrder` passa a comparar `phase1` com `TweakID.allCases.filter { $0 != .dockUnderTaskbar }`.
- [ ] **Step 2: Rodar `swift test --filter "TweakCatalogTests|MacServicesTests"`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.** Mais o filtro de grupo no `apply` padrão da CLI.
- [ ] **Step 4: Rodar `swift test`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add reversible dockUnderTaskbar tweak and tweak groups`

---

### Task 3: `Retro98UI` — paleta, tela de pixels e relevos

**Files:**
- Modify: `Package.swift` (alvos `Retro98UI` e `Retro98UITests`)
- Create: `Sources/Retro98UI/Palette.swift`, `PixelCanvas.swift`, `Bevel.swift`
- Test: `Tests/Retro98UITests/BevelTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct PixelColor: Equatable, Sendable { public let red, green, blue: UInt8; public var cgColor: CGColor }
  public enum Palette {   // valores de Global Constraints
      public static let face, shadow, light, darkShadow, selection, selectionText, desktop, tooltip: PixelColor
      public static let activeTitle: (start: PixelColor, end: PixelColor)
      public static let inactiveTitle: (start: PixelColor, end: PixelColor)
  }
  public struct PixelImage: Sendable {      // resultado de um render 1x
      public let cgImage: CGImage
      public func color(x: Int, y: Int) -> PixelColor   // origem no canto superior esquerdo
  }
  public enum PixelCanvas {
      /// Contexto com origem no canto superior esquerdo, sem anti-aliasing e sem suavização de fonte.
      public static func render(width: Int, height: Int, _ draw: (CGContext) -> Void) -> PixelImage
  }
  open class PixelView: NSView {          // isFlipped = true
      open func drawPixels(in context: CGContext, size: CGSize)   // subclasses sobrescrevem
      // draw(_:) chama PixelCanvas.render com o tamanho em pontos e desenha o resultado com interpolação .none
  }
  public enum BevelStyle: Sendable { case raised, sunken, buttonPressed, window, field, statusField }
  public enum Bevel {
      public static func draw(_ style: BevelStyle, in rect: CGRect, context: CGContext)
      public static func fillFace(_ rect: CGRect, context: CGContext)
  }
  ```
- Relevos de 2 px, linha externa e linha interna:
  | Estilo | Topo/esquerda (externa, interna) | Base/direita (externa, interna) |
  |---|---|---|
  | `raised` | luz, face | sombra escura, sombra |
  | `buttonPressed` | sombra escura, sombra | luz, face |
  | `window` | face, luz | sombra escura, sombra |
  | `sunken` / `field` | sombra, sombra escura | luz, face |
  | `statusField` (1 px) | sombra | luz |

  `field` preenche o interior de branco.

- [ ] **Step 1: Testes que falham** (render 10×10 e conferência de pixels):

```swift
@Test func raisedBevelHasLightTopLeftAndDarkBottomRight() {
    let image = PixelCanvas.render(width: 10, height: 10) { Bevel.draw(.raised, in: CGRect(x: 0, y: 0, width: 10, height: 10), context: $0) }
    #expect(image.color(x: 0, y: 0) == Palette.light)
    #expect(image.color(x: 1, y: 1) == Palette.face)
    #expect(image.color(x: 9, y: 9) == Palette.darkShadow)
    #expect(image.color(x: 8, y: 8) == Palette.shadow)
    #expect(image.color(x: 9, y: 0) == Palette.darkShadow)   // canto superior direito pertence à borda escura
}
@Test func sunkenFieldIsInverseWithWhiteInterior() { /* (0,0)=shadow, (1,1)=darkShadow, (9,9)=light, (5,5)=WHITE */ }
@Test func pressedButtonInvertsRaised() { /* (0,0)=darkShadow, (9,9)=light */ }
@Test func canvasHasTopLeftOriginAndNoAntialiasing() {
    // preencher CGRect(x:0,y:0,w:3,h:1) de preto → (0,0)..(2,0) pretos; (0,1) intocado; nenhum pixel cinza intermediário numa linha diagonal desenhada com stroke
}
```

- [ ] **Step 2: Rodar `swift test --filter BevelTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test --filter BevelTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add Retro98UI palette, pixel canvas and bevels`

---

### Task 4: Texto pixelado e ícones

**Files:**
- Create: `Sources/Retro98UI/PixelText.swift`, `PixelIcon.swift`, `Icons.swift`
- Test: `Tests/Retro98UITests/PixelTextTests.swift`, `IconTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum PixelFont: Sendable { case regular, bold }   // Tahoma 11
  public enum PixelText {
      public static func width(of text: String, font: PixelFont) -> Int
      public static let lineHeight: Int            // 13
      /// `origin` = canto superior esquerdo da caixa da linha (coordenadas da PixelCanvas).
      public static func draw(_ text: String, font: PixelFont, color: PixelColor, at origin: CGPoint, context: CGContext)
  }
  public struct PixelIcon: Sendable {
      public init(rows: [String])                  // todas as linhas com o mesmo tamanho; chars da paleta ASCII
      public let width: Int, height: Int
      public func image() -> CGImage
      public static func appIcon(for url: URL, size: Int) -> CGImage   // NSWorkspace.icon a 1x, sem suavização
  }
  public enum Icons {   // todos originais
      public static let startLogo: PixelIcon       // 16×16
      public static let programs, documents, settings, help, run, shutDown: PixelIcon   // 32×32 (itens grandes do Iniciar)
      public static let folder, document, application, systemSettings: PixelIcon       // 16×16
      public static let batteryFull, batteryHalf, batteryLow, batteryCharging, volume, volumeMuted: PixelIcon  // 16×16
      public static let info, warning, error, question: PixelIcon                       // 32×32 (caixas de mensagem)
  }
  ```

- [ ] **Step 1: Testes que falham**

```swift
@Test func textRendersOnlyPureColors() {
    let image = PixelCanvas.render(width: 80, height: 13) { ctx in
        Bevel.fillFace(CGRect(x: 0, y: 0, width: 80, height: 13), context: ctx)
        PixelText.draw("Iniciar", font: .bold, color: PixelColor(red: 0, green: 0, blue: 0), at: .zero, context: ctx)
    }
    // todo pixel é preto ou face: prova que não há suavização
    #expect(allPixels(image).allSatisfy { $0 == Palette.face || $0 == PixelColor(red: 0, green: 0, blue: 0) })
    #expect(allPixels(image).contains(PixelColor(red: 0, green: 0, blue: 0)))
}
@Test func boldIsWiderThanRegular() { #expect(PixelText.width(of: "Iniciar", font: .bold) > PixelText.width(of: "Iniciar", font: .regular)) }
@Test func iconMapsPaletteCharacters() {
    let icon = PixelIcon(rows: ["KW", "T."])
    // pixel (0,0) preto, (1,0) branco, (0,1) #008080, (1,1) transparente (alpha 0)
}
@Test func everyBuiltInIconHasDeclaredSize() {
    #expect(Icons.startLogo.width == 16 && Icons.startLogo.height == 16)
    #expect([Icons.programs, Icons.documents, Icons.settings, Icons.help, Icons.run, Icons.shutDown,
             Icons.info, Icons.warning, Icons.error, Icons.question].allSatisfy { $0.width == 32 && $0.height == 32 })
}
@Test func appIconIsPixelatedAtRequestedSize() {
    let image = PixelIcon.appIcon(for: URL(filePath: "/System/Applications/Calculator.app"), size: 16)
    #expect(image.width == 16 && image.height == 16)
}
```

- `allPixels` é um helper de teste em `Tests/Retro98UITests/PixelTestHelpers.swift`.
- [ ] **Step 2: Rodar `swift test --filter "PixelTextTests|IconTests"`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
  - **Texto:** CoreText no contexto da PixelCanvas, com `setShouldAntialias(false)`, `setShouldSmoothFonts(false)` e texto em preto ou branco puros.
  - **Ícones:** desenho livre do construtor, original e reconhecível pela função. O logo do Iniciar **não** pode lembrar a bandeira da Microsoft. Sugestão: uma pequena janela bege com "98" em azul-marinho.
- [ ] **Step 4: Rodar `swift test --filter "PixelTextTests|IconTests"`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add pixel text and original icon set`

---

### Task 5: Botão e botão de opção

**Files:**
- Create: `Sources/Retro98UI/RetroButton.swift`, `RetroRadioButton.swift`
- Test: `Tests/Retro98UITests/ButtonTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public final class RetroButton: PixelView {
      public init(title: String, isDefault: Bool = false, icon: PixelIcon? = nil, action: @escaping () -> Void)
      public var isPressed: Bool          // visual pressionado (mouse ou "travado", como o Iniciar com menu aberto)
      public var isBold: Bool             // título em negrito
      public static func preferredSize(title: String, icon: PixelIcon?, bold: Bool) -> CGSize  // altura 23; largura mínima 75
  }
  public final class RetroRadioButton: PixelView {
      public init(title: String, isSelected: Bool, onSelect: @escaping () -> Void)
      public var isSelected: Bool
  }
  ```
- Comportamento:
  - O botão aceita foco: Tab entre controles, espaço aciona, retângulo de foco pontilhado 1 px dentro do relevo.
  - O botão padrão tem borda preta extra de 1 px e Enter o aciona; quem trata é a janela (Task 6).
  - O botão de opção é um círculo de 12×12 desenhado em pixels (relevo afundado redondo, miolo branco, ponto preto 4×4 quando selecionado).

- [ ] **Step 1: Testes que falham.** Renderizam `drawPixels` numa PixelCanvas do tamanho preferido:
  - `buttonNormalUsesRaisedBevel`: (0,0) = luz.
  - `buttonPressedUsesPressedBevel`: (0,0) = sombra escura.
  - `defaultButtonHasExtraBlackBorder`: (0,0) e (1,1) = sombra escura em botão padrão.
  - `radioSelectedShowsCenterDot`: pixel central preto; não selecionado, branco.
  - `buttonTriggersActionOnSpaceKey`: simula `keyDown` com espaço e verifica que a ação foi chamada.
- [ ] **Step 2: Rodar `swift test --filter ButtonTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test --filter ButtonTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add retro button and radio button`

---

### Task 6: Janela de diálogo, caixa de mensagem e tooltip

**Files:**
- Create: `Sources/Retro98UI/RetroWindow.swift`, `RetroMessageBox.swift`, `RetroTooltip.swift`
- Test: `Tests/Retro98UITests/WindowTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public final class RetroWindow: NSPanel {
      /// Diálogo de tamanho fixo: borda .window, barra de título 18 pt com degradê ativo/inativo,
      /// título em negrito branco, botão × (16×14) à direita. Arrasta pela barra de título.
      public init(title: String, contentSize: CGSize)
      public let contentContainer: NSView            // área interna (face), coordenadas viradas
      public var defaultButton: RetroButton?         // Enter
      public var onCancel: (() -> Void)?             // Esc e ×
      public func showCentered()                     // centraliza na tela principal, vira key sem ativar outros apps
  }
  public enum MessageBoxIcon: Sendable { case info, warning, error, question }
  public enum RetroMessageBox {
      /// Mostra e retorna o índice do botão escolhido (modal).
      @MainActor public static func run(title: String, message: String, icon: MessageBoxIcon, buttons: [String]) -> Int
  }
  public final class RetroTooltip {
      @MainActor public static func show(_ text: String, near point: CGPoint)
      @MainActor public static func hide()
  }
  ```
- A janela é `NSPanel` borderless com `canBecomeKey = true` e nível `.modalPanel`. Usa `PixelView` para a moldura e o título.
- [ ] **Step 1: Testes que falham**
  - `titleBarUsesActiveGradientEnds`: render da barra de título ativa; pixel (2, 5) próximo de `#000080`, pixel (largura-25, 5) próximo de `#1084D0`, tolerância 2 por canal.
  - `inactiveTitleUsesGrayGradient`.
  - `escapeCallsOnCancel`: `cancelOperation(nil)` chama `onCancel`.
  - `enterTriggersDefaultButton`: `keyDown` Enter na janela chama a ação do `defaultButton`.
  - `messageBoxLayoutFitsLongText`: a função interna de layout `RetroMessageBox.layout(message:buttons:)` quebra linhas em 300 pt e devolve uma altura que cresce com o texto.
- [ ] **Step 2: Rodar `swift test --filter WindowTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test --filter WindowTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add retro dialog window, message box and tooltip`

---

### Task 7: Menu em cascata

**Files:**
- Create: `Sources/Retro98UI/RetroMenu.swift`
- Test: `Tests/Retro98UITests/MenuTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct RetroMenuItem: Sendable {
      public enum Kind: Sendable { case action(@Sendable @MainActor () -> Void), submenu(@Sendable @MainActor () -> [RetroMenuItem]), separator }
      public let title: String; public let icon: PixelIcon?; public let kind: Kind; public let isEnabled: Bool
  }
  public struct RetroMenuStyle: Sendable {
      public let itemHeight: Int; public let iconSize: Int; public let banner: String?   // Iniciar: 32/32/"Retro98"; submenus: 20/16/nil
      public static let startMenu: RetroMenuStyle
      public static let standard: RetroMenuStyle
  }
  public struct MenuColumnLayout: Equatable { public let columns: [[Int]] }   // índices dos itens por coluna
  public enum RetroMenuLayout {
      public static func columns(itemHeights: [Int], maxHeight: Int) -> MenuColumnLayout
  }
  @MainActor public final class RetroMenu {
      public init(items: [RetroMenuItem], style: RetroMenuStyle)
      public func show(at topLeft: CGPoint, opensUpward: Bool, onClose: @escaping () -> Void)
      public func close()
  }
  ```
- Comportamento:
  - **Destaque:** passar o mouse destaca o item (fundo `#000080`, texto branco).
  - **Submenus:** abrem após 400 ms de mouse parado ou com um clique, à direita (ou à esquerda se não couber) e alinhados ao item.
  - **Teclado:** setas sobem e descem, → abre o submenu, ← ou Esc fecham o nível, Enter aciona.
  - **Fechar:** clique fora fecha todos os níveis.
  - **Colunas:** quando a altura passa de `visibleFrame.height`, o menu quebra em colunas.
  - **Faixa lateral:** no estilo `startMenu`, faixa de 21 pt à esquerda com degradê `#000080`→`#1084D0` de baixo para cima e o texto "Retro98" em negrito branco girado 90°.
  - **Itens:** separador de 8 pt (linha sombra + linha luz) e seta ▶ em pixels para submenus.

- [ ] **Step 1: Testes que falham**

```swift
@Test func wrapsIntoColumnsWhenTallerThanScreen() {
    let layout = RetroMenuLayout.columns(itemHeights: Array(repeating: 20, count: 50), maxHeight: 400)
    #expect(layout.columns.count == 3)
    #expect(layout.columns[0].count == 20)
    #expect(layout.columns.flatMap { $0 } == Array(0..<50))
}
@Test func singleColumnWhenItFits() { /* 5 × 20 em 400 → 1 coluna */ }
@Test func separatorsCountTheirOwnHeight() { /* alturas [20, 8, 20] em 28 → 2 colunas [[0,1],[2]] */ }
@Test func keyboardNavigationSkipsSeparatorsAndDisabledItems() {
    // função pura RetroMenuNavigation.next(from:direction:items:) → pula separador e desabilitado, dá a volta no fim
}
```

- [ ] **Step 2: Rodar `swift test --filter MenuTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.** Lógica pura em `RetroMenuLayout`/`RetroMenuNavigation`; painéis `NSPanel` não ativantes com `PixelView`.
- [ ] **Step 4: Rodar `swift test --filter MenuTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add cascading retro menu`

---

### Task 8: Modelo do menu Iniciar

**Files:**
- Modify: `Package.swift` (alvos `Retro98ShellCore` e `Retro98ShellCoreTests`; ShellCore depende só de Foundation)
- Create: `Sources/Retro98ShellCore/StartMenuModel.swift`, `ProgramsTreeBuilder.swift`, `RecentDocuments.swift`
- Test: `Tests/Retro98ShellCoreTests/StartMenuModelTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public indirect enum ProgramNode: Equatable, Sendable {
      case folder(name: String, children: [ProgramNode])
      case app(name: String, url: URL)          // name sem ".app"
  }
  public enum ProgramsTreeBuilder {
      /// Junta as raízes (na ordem dada), mescla pastas de mesmo nome, ignora o que não consegue ler,
      /// remove pastas sem apps, ordena pastas primeiro e depois por nome (localizedStandardCompare).
      public static func build(roots: [URL], fileManager: FileManager = .default) -> [ProgramNode]
      public static let standardRoots: (URL) -> [URL]   // home → [/Applications, /System/Applications, home/Applications]
  }
  public struct RecentDocument: Equatable, Sendable { public let name: String; public let url: URL }
  public protocol RecentDocumentsProvider { func recent(limit: Int) -> [RecentDocument] }
  public struct SpotlightRecentDocuments: RecentDocumentsProvider { public init() }
  // NSMetadataQuery: kMDItemLastUsedDate nos últimos 30 dias, só arquivos fora de .app; limite 15, mais recentes primeiro
  public enum StartMenuEntry: Equatable, Sendable { case programs, documents, settings, help, run, shutDown, separator }
  public enum StartMenuModel {
      public static let topLevel: [StartMenuEntry]   // [.programs, .documents, .settings, .help, .run, .separator, .shutDown]
      public static func title(_ entry: StartMenuEntry, languages: [String]) -> String
      public static let helpURL: URL                 // https://github.com/matheushchaves/retro98#readme
      public static let systemSettingsURL: URL       // /System/Applications/System Settings.app
  }
  ```
- Títulos (pt-BR / en): Programas / Programs; Documentos / Documents; Configurações / Settings; Ajuda / Help; Executar… / Run…; Desligar… / Shut Down…. Em Configurações há um único item: "Ajustes do Sistema" / "System Settings".
- Apps dentro de pastas `.app` não são varridos. Pacotes que não são `.app` e links simbólicos para `.app` contam como app.

- [ ] **Step 1: Testes que falham** (pasta temporária com estrutura falsa de `.app` vazios):

```swift
@Test func buildsTreeFromNestedFolders() {
    // root1: Safari.app, Utilities/Terminal.app, Utilities/Disk Utility.app; root2: Utilities/Console.app, Zed.app
    // → [.folder("Utilities", [Console, Disk Utility, Terminal]), .app("Safari"), .app("Zed")]
}
@Test func dropsFoldersWithoutApps() { /* pasta "Docs" só com .txt some */ }
@Test func skipsUnreadableFolders() { /* pasta com permissão 000 → ignorada, sem crash; restaurar permissão no defer */ }
@Test func keepsSameNamedAppsFromDifferentRootsOnce() { /* "Notes.app" em duas raízes → um item, URL da primeira raiz */ }
@Test func topLevelOrderAndTitles() {
    #expect(StartMenuModel.topLevel == [.programs, .documents, .settings, .help, .run, .separator, .shutDown])
    #expect(StartMenuModel.title(.run, languages: ["pt-BR"]) == "Executar…")
    #expect(StartMenuModel.title(.shutDown, languages: ["en"]) == "Shut Down…")
}
```

- [ ] **Step 2: Rodar `swift test --filter StartMenuModelTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test --filter StartMenuModelTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add Start menu model and programs tree`

---

### Task 9: Executar e ações de energia

**Files:**
- Create: `Sources/Retro98ShellCore/RunTarget.swift`, `PowerAction.swift`
- Test: `Tests/Retro98ShellCoreTests/RunTargetTests.swift`, `PowerActionTests.swift`

**Interfaces:**
- Consumes: `CommandRunner` (Retro98Settings, Task 7 da Fase 1). `Retro98ShellCore` passa a depender de `Retro98Settings`.
- Produces:
  ```swift
  public enum RunTarget: Equatable, Sendable {
      case url(URL), path(URL), app(URL), notFound(String)
      /// nil para entrada vazia ou só espaços.
      public static func resolve(_ input: String, appRoots: [URL], home: URL, fileManager: FileManager = .default) -> RunTarget?
  }
  public enum PowerAction: String, CaseIterable, Sendable { case shutDown, restart, logOut, sleep
      public func title(languages: [String]) -> String
      public var appleScriptCommand: String       // "shut down", "restart", "log out", "sleep"
      public func perform(runner: CommandRunner) -> Bool   // osascript -e 'tell application "System Events" to <comando>'
  }
  ```
- Regras de `resolve`, na ordem:
  1. Aparar espaços; vazio → nil.
  2. Contém `://` ou começa com `mailto:` → `.url`.
  3. Começa com `www.` → `.url("https://" + entrada)`.
  4. Começa com `/` ou `~` → expandir `~` para `home`; se existe, `.path`, senão `.notFound(entrada)`.
  5. Senão, procurar nas `appRoots` (recursivo, ignorando o conteúdo de `.app`) um app cujo nome, sem `.app`, seja igual à entrada sem `.app`, sem diferenciar maiúsculas e acentos (`compare(_:options:[.caseInsensitive, .diacriticInsensitive]) == .orderedSame`). Vale a primeira raiz em que aparecer → `.app`.
  6. Senão `.notFound(entrada)`.
- Títulos de energia (pt-BR / en): Desligar / Shut down; Reiniciar / Restart; Encerrar sessão / Log out; Repouso / Sleep.
- Textos do diálogo Executar (usados na Task 11):
  - pt-BR: "Digite o nome de um programa, pasta, documento ou endereço da Internet, e o Retro98 o abrirá para você."
  - en: "Type the name of a program, folder, document, or Internet address, and Retro98 will open it for you."
  - Rótulo do campo: "Abrir:" / "Open:".
  - Erro: "Não foi possível encontrar '<x>'. Verifique se o nome está correto e tente de novo." / "Cannot find '<x>'. Make sure you typed the name correctly, and then try again."
- Textos do diálogo Desligar:
  - Título "Desligar o computador" / "Shut Down Computer".
  - Pergunta "O que você deseja que o computador faça?" / "What do you want the computer to do?"
  - Falha: "O macOS não permitiu esta ação. Em Ajustes do Sistema › Privacidade e Segurança › Automação, permita que o Retro98 Shell controle o System Events." / "macOS did not allow this. In System Settings › Privacy & Security › Automation, allow Retro98 Shell to control System Events."

- [ ] **Step 1: Testes que falham** (pasta temporária com `Safari.app`, `Música.app`, `Utilities/Terminal.app` e uma segunda raiz com outro `Safari.app`):

```swift
@Test func emptyInputResolvesToNil() { #expect(RunTarget.resolve("   ", appRoots: roots, home: home) == nil) }
@Test func urlsAndWebAddresses() {
    #expect(RunTarget.resolve("https://example.com", appRoots: roots, home: home) == .url(URL(string: "https://example.com")!))
    #expect(RunTarget.resolve("www.example.com", appRoots: roots, home: home) == .url(URL(string: "https://www.example.com")!))
}
@Test func tildePathsExpandAndMustExist() { /* "~/Downloads" com home temporário contendo Downloads → .path; "~/nada" → .notFound("~/nada") */ }
@Test func appNamesIgnoreCaseAccentsAndExtension() {
    #expect(RunTarget.resolve("safari", appRoots: roots, home: home) == .app(root1Safari))
    #expect(RunTarget.resolve("Safari.app", appRoots: roots, home: home) == .app(root1Safari))
    #expect(RunTarget.resolve("musica", appRoots: roots, home: home) == .app(musicaURL))
    #expect(RunTarget.resolve("terminal", appRoots: roots, home: home) == .app(terminalURL))
}
@Test func unknownNameIsNotFound() { #expect(RunTarget.resolve("xyz", appRoots: roots, home: home) == .notFound("xyz")) }
@Test func powerActionRunsSystemEventsCommand() {
    // RecordingRunner exit 0 → PowerAction.restart.perform == true; args == ["/usr/bin/osascript","-e","tell application \"System Events\" to restart"]
}
@Test func powerActionReportsFailureWhenOsascriptFails() { /* exit 1 → false */ }
```

- [ ] **Step 2: Rodar `swift test --filter "RunTargetTests|PowerActionTests"`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test --filter "RunTargetTests|PowerActionTests"`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add Run target resolution and power actions`

---

### Task 10: Bandeja e geometria da barra

**Files:**
- Create: `Sources/Retro98ShellCore/TrayModels.swift`, `TaskbarGeometry.swift`
- Test: `Tests/Retro98ShellCoreTests/TrayModelsTests.swift`, `TaskbarGeometryTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum ClockText {
      public static func time(_ date: Date, locale: Locale, timeZone: TimeZone) -> String      // template "jj:mm"
      public static func tooltip(_ date: Date, locale: Locale, timeZone: TimeZone) -> String   // dateStyle .full
  }
  public struct BatteryState: Equatable, Sendable { public let percent: Int; public let isCharging: Bool }
  public enum BatteryIconKind: Equatable, Sendable { case full, half, low, charging }
  public func batteryIconKind(_ state: BatteryState) -> BatteryIconKind   // charging > full (≥ 70) > half (≥ 25) > low
  public struct VolumeState: Equatable, Sendable { public let level: Float; public let isMuted: Bool }
  public func volumeIsSilent(_ state: VolumeState) -> Bool                // mudo ou nível 0
  public enum TaskbarGeometry {
      public static let minimumHeight: CGFloat = 28
      /// Base da tela principal, largura total, altura = max(28, área reservada pelo Dock embaixo).
      public static func frame(screenFrame: CGRect, visibleFrame: CGRect) -> CGRect
  }
  public enum TraySettingsURL {   // abertos ao clicar
      public static let sound = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!
      public static let battery = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension")!
      public static let dateTime = URL(string: "x-apple.systempreferences:com.apple.Date-Time-Settings.extension")!
  }
  ```

- [ ] **Step 1: Testes que falham**

```swift
@Test func clockUses24HourInBrazil() {
    let date = Date(timeIntervalSince1970: 1_762_850_400)  // 2025-11-11 08:40 UTC
    #expect(ClockText.time(date, locale: Locale(identifier: "pt_BR"), timeZone: TimeZone(identifier: "UTC")!) == "08:40")
}
@Test func batteryIconThresholds() {
    #expect(batteryIconKind(BatteryState(percent: 80, isCharging: false)) == .full)
    #expect(batteryIconKind(BatteryState(percent: 40, isCharging: false)) == .half)
    #expect(batteryIconKind(BatteryState(percent: 10, isCharging: false)) == .low)
    #expect(batteryIconKind(BatteryState(percent: 10, isCharging: true)) == .charging)
}
@Test func taskbarFrameCoversDockReservedArea() {
    let frame = TaskbarGeometry.frame(screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
                                      visibleFrame: CGRect(x: 0, y: 36, width: 1470, height: 887))
    #expect(frame == CGRect(x: 0, y: 0, width: 1470, height: 36))
}
@Test func taskbarFrameUsesMinimumHeight() { /* visibleFrame.minY == 0 → altura 28 */ }
@Test func taskbarFrameFollowsScreenOrigin() { /* tela principal com origem (-1470, 0) → x = -1470 */ }
```

- [ ] **Step 2: Rodar `swift test --filter "TrayModelsTests|TaskbarGeometryTests"`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test --filter "TrayModelsTests|TaskbarGeometryTests"`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add tray models and taskbar geometry`

---

### Task 11: App Retro98 Shell — barra, Iniciar, diálogos, bandeja e atalho

**Files:**
- Modify: `Package.swift` (executável `Retro98Shell`, depende de `Retro98UI`, `Retro98ShellCore` e `Retro98Settings`)
- Create: `Sources/Retro98Shell/main.swift`, `AppDelegate.swift`, `TaskbarPanel.swift`, `StartMenuController.swift`, `RunDialog.swift`, `ShutdownDialog.swift`, `TrayView.swift`, `HotKey.swift`, `SystemReaders.swift`
- Test: `Tests/Retro98ShellCoreTests/StartMenuItemsTests.swift` (lógica de montagem dos itens, que fica em ShellCore)

**Interfaces:**
- Consumes: Tasks 3–10.
- Produces (em `Retro98ShellCore`, testável):
  ```swift
  public enum StartMenuAction: Equatable, Sendable { case open(URL), run, shutDown }
  public struct StartMenuNode: Equatable, Sendable { public let title: String; public let iconURL: URL?; public let action: StartMenuAction?; public let children: [StartMenuNode]? }
  public enum StartMenuItems {
      public static func build(programs: [ProgramNode], documents: [RecentDocument], languages: [String]) -> [StartMenuNode?]   // nil = separador
  }
  ```
- Ligação no app (executável, verificação manual):
  - **`TaskbarPanel`:** NSPanel borderless, não ativante, nível `CGWindowLevelForKey(.dockWindow) + 1`, coleção `[.canJoinAllSpaces, .stationary, .ignoresCycle]`, frame de `TaskbarGeometry.frame` na tela principal. Recalcula em `NSApplication.didChangeScreenParametersNotification` e quando o Dock reinicia (observar `NSWorkspace.didLaunchApplicationNotification` do bundle `com.apple.dock`). Topo com linha luz de 1 px sobre a face.
  - **Botão Iniciar:** `RetroButton` com `Icons.startLogo` e "Iniciar"/"Start" em negrito, 2 pt da borda esquerda, centralizado na altura. Fica pressionado enquanto o menu está aberto. Clicar com o menu aberto fecha o menu.
  - **Menu Iniciar:** `RetroMenu` estilo `.startMenu` aberto para cima a partir do topo da barra.
    - Programas e Documentos são montados ao abrir: Programas a partir da árvore em cache, reconstruída em segundo plano a cada abertura; Documentos pelo Spotlight.
    - Programas usa ícones pixelados dos apps e `Icons.folder` nas pastas. Documentos vazio mostra um item desabilitado "(Vazio)" / "(Empty)".
  - **Executar…:** `RetroWindow` 347×157 com ícone, texto, rótulo, `NSTextField` (Tahoma 11) num relevo `.field` e botões OK (padrão) e Cancelar. OK resolve `RunTarget`: abre com `NSWorkspace.open` ou mostra `RetroMessageBox` de erro. Lembra a última entrada.
  - **Desligar…:** `RetroWindow` com ícone, pergunta, 4 `RetroRadioButton` (padrão Desligar) e OK/Cancelar. OK chama `PowerAction.perform`; se falhar, `RetroMessageBox` com o texto de falha.
  - **Bandeja:** relevo `.statusField` à direita com volume, bateria (oculta sem bateria) e relógio.
    - Relógio atualiza a cada virada de minuto.
    - Bateria e volume consultados a cada 30 s e ao clicar.
    - Tooltip do relógio com a data longa.
    - Clicar abre o painel correspondente (`TraySettingsURL`).
  - **Atalho ⌃⎋** (`RegisterEventHotKey`): abre ou fecha o menu Iniciar.
  - **`SystemReaders`:** bateria via `IOPSCopyPowerSourcesInfo`/`IOPSCopyPowerSourcesList`; volume via CoreAudio (`kAudioHardwarePropertyDefaultOutputDevice`, `kAudioDevicePropertyVolumeScalar` no elemento principal, `kAudioDevicePropertyMute`).

- [ ] **Step 1: Teste que falha**

```swift
@Test func startMenuItemsFollowTopLevelOrder() {
    let items = StartMenuItems.build(programs: [.app(name: "Safari", url: safari)], documents: [], languages: ["pt-BR"])
    #expect(items.map { $0?.title } == ["Programas", "Documentos", "Configurações", "Ajuda", "Executar…", nil, "Desligar…"])
    #expect(items[0]?.children?.first?.action == .open(safari))
    #expect(items[1]?.children == [StartMenuNode(title: "(Vazio)", iconURL: nil, action: nil, children: nil)])
    #expect(items[2]?.children?.first?.action == .open(StartMenuModel.systemSettingsURL))
    #expect(items[3]?.action == .open(StartMenuModel.helpURL))
}
```

- [ ] **Step 2: Rodar `swift test --filter StartMenuItemsTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar `StartMenuItems` e o app.**
- [ ] **Step 4: Rodar `swift test`.** Esperado: PASS. Rodar também `swift build -c release --product Retro98Shell`. Esperado: sucesso, sem warnings.
- [ ] **Step 5: Commit** `feat: add Retro98 Shell taskbar app`

---

### Task 12: Recuperação automática

**Files:**
- Create: `Sources/Retro98ShellCore/LaunchHistory.swift`, `Sources/Retro98Shell/Recovery.swift`
- Modify: `Sources/Retro98Shell/AppDelegate.swift`
- Test: `Tests/Retro98ShellCoreTests/LaunchHistoryTests.swift`

**Interfaces:**
- Consumes: `FileStore`, `BackupFile`, `TweakEngine`, `CommandRunner` (Retro98Settings).
- Produces:
  ```swift
  public struct LaunchHistory {
      public static let window: TimeInterval = 60
      public static let maxLaunches = 3
      public init(url: URL, files: FileStore)            // supportDirectory/shell-launches.plist (array de Date)
      /// Registra a abertura e diz se o Shell deve desistir (≥ 3 aberturas sem saída limpa nos últimos 60 s).
      public func recordLaunch(now: Date) throws -> Bool
      public func recordCleanExit() throws               // apaga o histórico
  }
  ```
- `Recovery.giveUp()`:
  1. `TweakEngine.restore([.dockUnderTaskbar])`.
  2. Apaga o histórico.
  3. `RetroMessageBox` com aviso. pt-BR: "O Retro98 Shell parou de funcionar várias vezes e foi desligado. O Dock voltou ao normal. Para ligar de novo, rode ./install.sh." en: "Retro98 Shell stopped working several times and was turned off. The Dock is back to normal. To turn it on again, run ./install.sh."
  4. `launchctl bootout gui/<uid>/io.github.matheushchaves.retro98.shell`.
  5. `exit(0)`.
- `applicationWillTerminate` chama `recordCleanExit()`. `main.swift` chama `recordLaunch` antes de montar a UI.

- [ ] **Step 1: Testes que falham**

```swift
@Test func givesUpAfterThreeLaunchesWithinSixtySeconds() throws {
    let history = LaunchHistory(url: url, files: InMemoryFileStore())
    #expect(try history.recordLaunch(now: t0) == false)
    #expect(try history.recordLaunch(now: t0 + 10) == false)
    #expect(try history.recordLaunch(now: t0 + 20) == true)
}
@Test func oldLaunchesFallOutOfTheWindow() { /* t0, t0+50, t0+120 → false nas três */ }
@Test func cleanExitClearsHistory() { /* 2 aberturas, recordCleanExit, 1 abertura → false; arquivo some depois do clean exit */ }
@Test func corruptHistoryCountsAsEmpty() { /* lixo no arquivo → recordLaunch == false, arquivo regravado válido */ }
```

- [ ] **Step 2: Rodar `swift test --filter LaunchHistoryTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add Shell crash-loop recovery`

---

### Task 13: Empacotamento, instalador, desinstalador, README e CI

**Files:**
- Create: `scripts/build-shell-app.sh`
- Modify: `install.sh`, `uninstall.sh`, `scripts/common.sh`, `Tests/scripts/test_uninstall.sh`, `README.md`, `README.pt-BR.md`, `.github/workflows/ci.yml`

**Interfaces:**
- **Variáveis novas** em `common.sh`, todas sobrescrevíveis por ambiente para os testes:
  - `APPS_DIR` (`RETRO98_APPS_DIR`, padrão `$HOME/Applications/Retro98`)
  - `LAUNCH_AGENTS_DIR` (`RETRO98_LAUNCH_AGENTS_DIR`, padrão `$HOME/Library/LaunchAgents`)
  - `SHELL_LABEL=io.github.matheushchaves.retro98.shell`
  - `SHELL_APP="$APPS_DIR/Retro98 Shell.app"`
  - `PIECES_FILE="$SUPPORT_DIR/pieces"` (linhas `base` e/ou `shell`)
- **`build-shell-app.sh <saída.app>`:**
  1. `swift build -c release --product Retro98Shell`.
  2. Monta `Contents/MacOS/Retro98Shell` e `Contents/Info.plist` com `CFBundleIdentifier`, `CFBundleName` "Retro98 Shell", `CFBundleExecutable` "Retro98Shell", `CFBundlePackageType` APPL, `LSUIElement` true, `LSMinimumSystemVersion` 14.0 e `NSAppleEventsUsageDescription` "Retro98 Shell uses System Events to shut down, restart, log out or sleep when you choose it in Shut Down…".
  3. `codesign --force --sign - "<saída.app>"`.
- **`install.sh [--yes]`:**
  1. Pergunta as peças: "Instalar os ajustes base? [S/n]" e "Instalar a barra de tarefas e o menu Iniciar? [S/n]".
  2. Com `--yes`, usa o `PIECES_FILE` anterior ou, se não existir, todas.
  3. Grava `PIECES_FILE`.
  4. **base** → `apply`.
  5. **shell** → `apply --only dockUnderTaskbar`, monta o app em `SHELL_APP`, escreve o LaunchAgent (`ProgramArguments` = binário dentro do app, `RunAtLoad` true, `KeepAlive` = `{SuccessfulExit = false}`, `ThrottleInterval` 5, `ProcessType` Interactive), `launchctl bootout` silencioso se já carregado e depois `launchctl bootstrap gui/$(id -u) <plist>`.
- **`uninstall.sh`:**
  1. Para o Shell (`launchctl bootout gui/$(id -u)/$SHELL_LABEL`, ignorando "não carregado") e remove o plist do LaunchAgent.
  2. Roda `restore`. **Só se der 0**, remove `SHELL_APP`, `APPS_DIR` (se vazio), `PIECES_FILE` e `shell-launches.plist`, além dos arquivos que já removia.
  3. Se falhar, mantém tudo e mostra a mensagem de tentar de novo.

- [ ] **Step 1: Testes que falham** em `test_uninstall.sh`. Usam um stub `launchctl` no `PATH` que registra as chamadas num arquivo, e diretórios temporários em `RETRO98_APPS_DIR` e `RETRO98_LAUNCH_AGENTS_DIR`:
  - `shell-removed`: app falso e plist falso existem, stub de restore sai 0 → `launchctl` recebeu `bootout gui/<uid>/io.github.matheushchaves.retro98.shell`, plist removido, app removido, saída 0.
  - `shell-kept-on-failure`: restore sai 2 → plist removido (o Shell fica parado), **app e backup mantidos**, saída 2.
- [ ] **Step 2: Rodar `bash Tests/scripts/test_uninstall.sh`.** Esperado: os 2 casos novos FAIL.
- [ ] **Step 3: Implementar os scripts.**
- [ ] **Step 4: Rodar `bash Tests/scripts/test_uninstall.sh`.** Esperado: todos PASS. Verificar também `bash scripts/build-shell-app.sh "$TMPDIR/teste.app" && codesign --verify "$TMPDIR/teste.app"` sem erro e `plutil -lint` no Info.plist gerado.
- [ ] **Step 5: README** (pt-BR e en).
  - Fase 2A marcada como disponível.
  - Seção "Barra de tarefas": o que tem, atalho ⌃⎋, recuperação automática, Dock pequeno embaixo da barra e como desligar só a barra (`./uninstall.sh` desliga tudo; reinstalar só os ajustes base respondendo "n" para a barra).
  - Aviso de Automação no primeiro "Desligar…".
- [ ] **Step 6: CI.** Acrescentar `swift build -c release --product Retro98Shell` e `bash scripts/build-shell-app.sh "$RUNNER_TEMP/Retro98 Shell.app"`.
- [ ] **Step 7: Rodar `swift test && bash Tests/scripts/test_uninstall.sh`.** Esperado: tudo PASS.
- [ ] **Step 8: Commit** `feat: package and install Retro98 Shell with LaunchAgent`

---

### Aceitação pelo autor (manual, no Mac dele, depois da Task 13)

O autor roda `./install.sh` (ou autoriza explicitamente) e confere:
- [ ] Barra cinza na base da tela principal, cobrindo o Dock por inteiro, sem pedaço do Dock aparecendo. Janelas maximizadas param acima dela.
- [ ] Botão Iniciar com logo original; o menu abre para cima, com faixa "Retro98", ícones grandes e textos nítidos (sem borrado).
- [ ] Programas mostra as pastas e os apps do Mac com ícones pixelados e quebra em colunas se for muito longo. Documentos mostra arquivos recentes.
- [ ] Executar… abre `safari`, `~/Downloads`, `https://example.com` e mostra erro para `xyz`.
- [ ] Desligar… mostra as 4 opções; Cancelar não faz nada. Testar só "Repouso".
- [ ] Relógio certo, com tooltip da data; bateria e volume corretos; cliques abrem os painéis.
- [ ] ⌃⎋ abre e fecha o menu; Esc fecha.
- [ ] A barra some num app em tela cheia e aparece em outros Spaces.
- [ ] `kill -9` no Retro98 Shell → ele volta em segundos. Três vezes seguidas → aviso de desligamento e Dock normal.
- [ ] `./uninstall.sh` → barra some, Dock volta ao tamanho original, nada do Retro98 sobra em `~/Applications` e `~/Library/LaunchAgents`.
