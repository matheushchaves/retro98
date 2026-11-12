# Retro98 Fase 4 — Prompt — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o Retro98 Prompt:
- um terminal completo numa janela 98, rodando o shell da pessoa como login;
- fundo preto, texto cinza-claro e fonte VGA nítida;
- copiar e colar, redimensionar, histórico de rolagem, cores ANSI, Unicode e acentos;
- várias janelas (sem abas), sem virar o terminal padrão do sistema.

**Architecture:**
- **`Vendor/SwiftTerm`:** cópia do SwiftTerm 1.11.2 (MIT) como pacote local, com dois trechos trazidos da 1.19. Motivos (medidos em 2026-11-12):
  - A 1.12 em diante traz um shader Metal que exige o "Metal Toolchain". Ele não vem nas Command Line Tools e falta até neste Mac com Xcode, então o build quebra.
  - A 1.11.2 força a suavização de fonte em cada linha, o que deixa a fonte de pixel borrada (3.817 pixels cinzentos em duas linhas a 2×; 0 com o `fontSmoothing` da 1.19).
- **`Retro98Prompt`** (app novo) junta:
  - a fonte e o estilo do terminal;
  - a escolha do shell e do ambiente;
  - a janela com menus e a barra de rolagem retrô;
  - as várias janelas e a confirmação ao fechar com programa rodando.
- **`Retro98UI`:** a `RetroScroller` passa a poder comandar uma view que não é `NSScrollView`. O Prompt ganha um ícone 32/16 original.
- **Scripts:** `build-app.sh` aprende a copiar recursos. O instalador ganha a peça `prompt`, e o desinstalador a remove.

**Tech Stack:** Swift 6, AppKit, CoreText, SwiftTerm 1.11.2 (vendorizado), pseudo-terminal (`forkpty`), Swift Testing, bash.

**Spec:** `docs/superpowers/specs/2026-11-10-retro-desktop-design.md`, seção "Fase 4 — Prompt", mais a seção 5 (fonte monoespaçada). As Fases 1 a 3C e a correção do papel de parede estão no `main`.

## Global Constraints

- **Herança:** tudo das fases anteriores continua valendo:
  - pixel 1x, Tahoma 13 e negrito 12 nos menus, paleta, só material original;
  - pt-BR e en, só APIs públicas;
  - o Terminal do macOS fica intacto e os testes ficam isolados.
- **Testes isolados, mais estes cuidados:**
  - Nenhum teste usa a área de transferência geral: copiar e colar ficam com o SwiftTerm, um teste dos menus e a checagem manual.
  - Os testes que abrem processo rodam `/bin/sh`, nunca o shell da pessoa, com `HOME` numa pasta temporária, `HISTFILE=/dev/null` e sem `ENV`, para não ler nem gravar arquivos da pessoa.
  - Os scripts continuam com o `retro98-settings` falso, assinatura ad-hoc e pastas temporárias.
- **SwiftTerm [minha escolha]:**
  - Fica em `Vendor/SwiftTerm`, copiado da tag `v1.11.2` (commit `b1262db5b6bea699a8260a8c66999436c508ca56`).
  - Fica só `Sources/SwiftTerm`, sem `iOS/` e `Documentation.docc/`; mais o `LICENSE` original e um `VENDORED.md` com origem, o que saiu e os patches.
  - **Patch 1 (`fontSmoothing`, da 1.19):** `public var fontSmoothing: Bool = true { didSet { needsDisplay = true } }` na `TerminalView` do Mac. `AppleTerminalView.swift` usa esse valor no lugar dos `setShouldSmoothFonts(true)`/`setAllowsFontSmoothing(true)` do laço de linhas.
  - **Patch 2 (`reservedScrollerWidth`, da 1.19):** a largura reservada para a barra própria do SwiftTerm vale 0 quando ela está escondida. Entra em `getEffectiveWidth` (com `max(0, …)`) e em `getOptimalFrameSize`.
  - O manifesto do pacote vendorizado usa `swiftSettings: [.unsafeFlags(["-suppress-warnings"])]`, porque os avisos dele não são nossos. Os builds do projeto continuam sem nenhum aviso.
  - Um comentário no `Package.swift` raiz diz para não subir para 1.12+ enquanto o shader Metal exigir o Metal Toolchain.
- **Fonte [minha escolha]:** PxPlus IBM VGA 8x16, do *Ultimate Oldschool PC Font Pack* v2.2 de VileR (int10h.org), licença CC BY-SA 4.0.
  - É a variante "Plus" porque a Px437 (página de código 437) não tem ã nem õ.
  - Arquivo `ttf - Px (pixel outline)/PxPlus_IBM_VGA_8x16.ttf` do pacote `https://int10h.org/oldschool-pc-fonts/download/oldschool_pc_font_pack_v2.2_linux.zip` (SHA-256 `b30dc3ecc9931ad2dd8be7517dd01813c8834a1911b582ab7643191b41a3d759`).
  - A 16 pt, a célula fica exata em 8×16 (subida 12, descida 4, entrelinha 0). Cobre todos os acentos do português, desenhos de caixa, blocos, €, setas, reticências e aspas curvas.
  - Fica em `Resources/Prompt/PxPlus_IBM_VGA_8x16.ttf`, junto com `Resources/Prompt/LICENSE-PxPlus_IBM_VGA_8x16.txt`: o `LICENSE.TXT` do pacote, precedido de duas linhas de crédito (autor, link, licença).
  - Ambos vão para `Contents/Resources` do app. O crédito aparece no README e no "Sobre".
- **Visual do terminal [minha escolha]:**
  - Texto `#C0C0C0` sobre `#000000`; seleção `#000080`, porque a 1.11.2 não troca a cor do texto selecionado.
  - Cursor sublinhado piscando, `#C0C0C0`.
  - Paleta ANSI de 16 cores no estilo console clássico, na ordem ANSI 0–15: `000000 800000 008000 808000 000080 800080 008080 C0C0C0 808080 FF0000 00FF00 FFFF00 0000FF FF00FF 00FFFF FFFFFF`.
  - Fonte 16 pt, suavização desligada (`fontSmoothing = false`), `customBlockGlyphs = false` (blocos e caixas vêm da própria fonte).
  - Histórico de 10.000 linhas.
  - Option digita caracteres (`optionAsMetaKey = false`), para os acentos funcionarem.
- **Janela [minha escolha]:**
  - `RetroAppWindow` com o ícone 16 do Prompt.
  - Por dentro: barra de menus retrô (22) e linha gravada (2) no topo. Abaixo, o terminal e a `RetroScroller` vertical (16) à direita, que substitui a barra do SwiftTerm (escondida).
  - Tamanho inicial de 80×25: conteúdo 656×424 (640 + 16 por 22 + 2 + 400).
  - Título "Prompt", ou "Prompt - <título que o programa pedir>" (OSC 0/2).
  - Sem abas: `NSWindow.allowsAutomaticWindowTabbing = false` e `tabbingMode = .disallowed`.
- **Shell [minha escolha]:**
  - Usa `$SHELL` se for caminho absoluto de um executável; senão, o shell da conta (`getpwuid(getuid()).pw_shell`); senão `/bin/zsh`.
  - Roda como login (`argv[0]` = "-" + nome), na pasta pessoal.
  - O ambiente é o do app, mais:
    - `TERM=xterm-256color`, `COLORTERM=truecolor`, `TERM_PROGRAM=Retro98_Prompt` e `TERM_PROGRAM_VERSION` (a versão do app, ou `dev`);
    - `LANG=<idioma>_<REGIÃO>.UTF-8` do `Locale` atual (ou `en_US.UTF-8`), só quando não há `LANG`, `LC_ALL` nem `LC_CTYPE`.
- **Fim do shell [minha escolha]:**
  - Saída com código 0 fecha a janela.
  - Outro código, ou falha de E/S, deixa a janela com a linha "[Processo concluído com código N]" (en: "[Process completed with code N]"; sem código: "[Processo concluído]").
- **Fechar com programa rodando [minha escolha]:**
  - Há "programa rodando" quando o grupo de primeiro plano do pseudo-terminal (`tcgetpgrp`) não é o shell.
  - Fechar a janela pergunta (ícone de pergunta): "Fechar esta janela vai encerrar o programa em execução." / "Closing this window will end the running program.", botões "Encerrar"/"End" e "Cancelar"/"Cancel".
  - Encerrar o app pergunta uma vez se alguma janela tiver programa rodando: "Há programas em execução no Prompt. Encerrar todos?" / "Programs are running in Prompt. End them all?", com os mesmos botões.
  - Shell ocioso fecha sem perguntar.
- **Menus [minha escolha]:**
  - **Barra do macOS:**
    - "Retro98 Prompt": Sobre (com créditos), Ocultar ⌘H, Ocultar Outros ⌥⌘H, Mostrar Tudo, Encerrar ⌘Q;
    - Arquivo: Nova Janela ⌘N, Fechar ⌘W;
    - Editar: Copiar ⌘C, Colar ⌘V, Selecionar Tudo ⌘A;
    - Janela: Minimizar ⌘M, Zoom, Trazer Todas para a Frente;
    - Ajuda: "Ajuda do Retro98" (README).
  - **Dentro da janela:** Arquivo, Editar e Ajuda, com os mesmos comandos, como no Explorer.
  - Sem "Ajustes…", como no Explorer, porque não há o que ajustar nesta fase; o Painel de Controle é a Fase 5.
  - ⌘ vai para os menus; Ctrl e Option vão para o terminal.
- **Instalação [minha escolha]:**
  - **Peça `prompt`**, independente da barra de tarefas: pergunta "Instalar o Prompt (terminal retrô)?" (padrão sim). Recusar grava `noprompt` nas peças.
  - **Com `--yes`:** o arquivo de peças manda. Um arquivo sem `prompt` nem `noprompt`, gravado antes da 0.7.0, ganha `prompt`, porque peça nova chega ligada. Sem arquivo, as peças são `base shell prompt`.
  - **Onde e como:** app em `~/Applications/Retro98/Retro98 Prompt.app`, id `io.github.matheushchaves.retro98.prompt`, regular, sem esquema de URL e sem tipos de documento (não vira terminal padrão).
  - **Desmarcar ou desinstalar:** encerra, desregistra (`lsregister -u`) e apaga o app.
  - O Prompt aparece sozinho em Iniciar › Programas › Retro98, porque o menu já lê `~/Applications`.
- **Versão:** 0.7.0 (build 7).

## Review Focus

1. **`$SHELL` inválido, relativo ou ausente** (comum quando o app é aberto pelo Finder ou por um LaunchAgent): o Prompt deve abrir com o shell da conta ou `/bin/zsh`, nunca com uma janela morta. Testes da Task 3.
2. **Fechar ou encerrar com programa rodando** (vim, ssh, top): deve perguntar, e cancelar mantém tudo. Com o shell ocioso, fecha sem perguntar. Testes das Tasks 5 e 6.
3. **Shell que sai com erro ou nem inicia:** a janela fica com a mensagem e o código, em vez de sumir. Teste da Task 5.
4. **Acentos por Option ou teclas mortas** (ABNT2, US-Internacional): `optionAsMetaKey` tem que estar desligado. O teste da Task 2 confere a configuração, e a checagem manual digita "ação" e "pão".
5. **Saída enorme** (`yes | head -n 100000`): o histórico fica em 10.000 linhas e a barra de rolagem fica no fim. Testes das Tasks 2 e 5.

## Estrutura de arquivos

| Arquivo | Responsabilidade |
|---|---|
| `Vendor/SwiftTerm/` (`Package.swift`, `LICENSE`, `VENDORED.md`, `Sources/SwiftTerm/…`) | Motor do terminal vendorizado, com os dois patches |
| `Package.swift` | Dependência local `Vendor/SwiftTerm`; alvos `Retro98Prompt` e `Retro98PromptTests` |
| `Resources/Prompt/` | Fonte e licença dela, copiadas para o app |
| `Sources/Retro98Prompt/PromptFont.swift` | Registrar a fonte e criar a `NSFont` |
| `Sources/Retro98Prompt/PromptStyle.swift` | Paleta e configuração da `TerminalView` |
| `Sources/Retro98Prompt/ShellLaunch.swift` | Shell, `argv[0]`, ambiente e pasta inicial |
| `Sources/Retro98Prompt/PromptText.swift` | Textos pt-BR/en |
| `Sources/Retro98Prompt/PromptWindowController.swift` | Janela, terminal, barra de rolagem, título, fim do shell e fechar |
| `Sources/Retro98Prompt/PromptPrompter.swift` | Perguntas (caixa de mensagem 98; roteiro nos testes) |
| `Sources/Retro98Prompt/PromptMenus.swift` | Menus do macOS e da janela |
| `Sources/Retro98Prompt/AppDelegate.swift`, `main.swift` | Várias janelas, reabrir, encerrar, "Sobre" |
| `Sources/Retro98UI/RetroScroller.swift` | `onScroll` para views que não são `NSScrollView` |
| `Sources/Retro98UI/FileIcons.swift`, `Sources/retro98-tools/main.swift` | Ícone do Prompt e o `iconset prompt` |
| `scripts/build-app.sh`, `scripts/common.sh`, `install.sh`, `uninstall.sh` | Recursos no app, peça `prompt`, remoção |
| `Tests/Retro98PromptTests/…`, `Tests/Retro98UITests/…`, `Tests/scripts/…` | Testes |

---

### Task 1: SwiftTerm vendorizado e a fonte VGA

**Files:** Create `Vendor/SwiftTerm/**`, `Resources/Prompt/PxPlus_IBM_VGA_8x16.ttf`, `Resources/Prompt/LICENSE-PxPlus_IBM_VGA_8x16.txt`, `Sources/Retro98Prompt/PromptFont.swift`, `Sources/Retro98Prompt/main.swift` (provisório: só `import AppKit`, até a Task 6); Modify `Package.swift`. Test `Tests/Retro98PromptTests/PromptFontTests.swift`, `Tests/Retro98PromptTests/TestSupport.swift`.

**Interfaces:**
```swift
enum PromptFont {
    static let fileName = "PxPlus_IBM_VGA_8x16.ttf"
    static let postScriptName = "PxPlus_IBM_VGA_8x16"
    static let size: CGFloat = 16
    /// Registra para este processo (idempotente). false se o arquivo não existe ou não é fonte.
    @discardableResult static func register(at url: URL) -> Bool
    /// O arquivo dentro do app (Contents/Resources), se houver.
    static var bundledURL: URL? { get }
    /// A VGA 16 pt se registrada; senão a monoespaçada do sistema a 16 pt.
    static func make() -> NSFont
}
// TestSupport.swift (só testes):
let repoRoot: URL                       // a partir de #filePath
let vgaFontURL: URL                     // repoRoot/Resources/Prompt/PxPlus_IBM_VGA_8x16.ttf
/// Desenha a view a 2× (cacheDisplay num NSBitmapImageRep de 2× o tamanho) e conta as cores RGB distintas nas `rows`
/// linhas de texto de cima. Texto nítido tem só o fundo e as cores usadas; suavização cria dezenas de tons.
func distinctColors(_ view: NSView, rows: Int) -> Int
/// /bin/sh com HOME temporário, HISTFILE=/dev/null e sem ENV (ex.: sh(["-c", "exit 3"], home:), sh(["-i"], home:)).
func sh(_ arguments: [String], home: URL) -> ShellLaunch       // a partir da Task 3
```
- [ ] **Step 1: Vendorizar e baixar a fonte.**
  - Clonar a tag `v1.11.2` numa pasta temporária. Copiar `Sources/SwiftTerm` (sem `iOS/` e sem `Documentation.docc/`) e o `LICENSE`.
  - Escrever `Vendor/SwiftTerm/Package.swift`: tools 5.9, macOS 13, produto e alvo `SwiftTerm` em `Sources/SwiftTerm`, `exclude: ["Mac/README.md"]` e a flag de suprimir avisos.
  - Aplicar os patches 1 e 2 das Global Constraints e escrever o `VENDORED.md`.
  - Baixar o zip da fonte numa pasta temporária vazia e conferir o SHA-256. Extrair só o TTF e o `LICENSE.TXT` para `Resources/Prompt/`, a licença com as linhas de crédito no topo.
  - No `Package.swift` raiz: `.package(path: "Vendor/SwiftTerm")`; `.executableTarget(name: "Retro98Prompt", dependencies: ["Retro98UI", "Retro98Settings", .product(name: "SwiftTerm", package: "SwiftTerm")])`; `.testTarget(name: "Retro98PromptTests", dependencies: ["Retro98Prompt", "Retro98UI", .product(name: "SwiftTerm", package: "SwiftTerm")])`; produto executável `Retro98Prompt`.
- [ ] **Step 2: Testes que falham.**
  - `vgaFontHasAnExactCell`: `register(at: vgaFontURL)` dá true. `make()` tem `fontName == postScriptName`, avanço de "W" 8, e subida + descida + entrelinha = 16.
  - `vgaFontCoversPortuguese`: todos os caracteres de `"ãõçÃÕÇáéíóúâêôàüÁÉÍÓÚÂÊÔÀ€─│┌┐└┘█░▒▓→…“”"` têm glifo.
  - `missingFontFallsBackToSystemMonospace`: `register(at:)` de um caminho inexistente dá false, e `make()` continua devolvendo uma fonte de 16 pt de largura fixa.
  - `vendoredTerminalDrawsCrispPixels`: `TerminalView(frame: 640×400, font: make())` com fundo preto, texto `#C0C0C0`, `fontSmoothing = false` e `customBlockGlyphs = false`, recebendo "C:\\> Olá, ação: ãõç ┌──┐ █▓▒░\r\n", dá `distinctColors(view, rows: 1) == 2`. Medido no protótipo: com a suavização ligada, a mesma linha tinha 15 cores.
  - `hiddenScrollerLeavesEightyColumns`: a mesma view, com a `NSScroller` interna escondida e o tamanho reaplicado, fica com 80 colunas e 25 linhas.
- [ ] **Step 3: Rodar `swift test --filter PromptFontTests`.** Esperado: FAIL (`PromptFont` não existe).
- [ ] **Step 4: Implementar `PromptFont`.** Use `CTFontManagerRegisterFontsForURL(url, .process, &error)`. Já registrada (erro `kCTFontManagerErrorAlreadyRegistered`) conta como sucesso. `bundledURL` = `Bundle.main.url(forResource:withExtension:)`.
- [ ] **Step 5: Rodar `swift test --filter PromptFontTests`.** Esperado: PASS. `swift build -c release --product Retro98Prompt` sem nenhum `warning:`.
- [ ] **Step 6: Commit** `feat: vendor SwiftTerm 1.11.2 with crisp-text backports and add the VGA font`

---

### Task 2: Estilo do terminal

**Files:** Create `Sources/Retro98Prompt/PromptStyle.swift`. Test `Tests/Retro98PromptTests/PromptStyleTests.swift`.

**Interfaces:**
```swift
enum PromptStyle {
    static let foreground: NSColor          // #C0C0C0
    static let background: NSColor          // #000000
    static let selection: NSColor           // #000080
    static let ansiHex: [String]            // as 16 cores das Global Constraints, ANSI 0–15
    static var palette: [SwiftTerm.Color] { get }   // ansiHex em 16 bits por componente (0xC0 → 0xC0C0)
    static let scrollbackLines = 10_000
    static let columns = 80, rows = 25
    static let cellSize = CGSize(width: 8, height: 16)
    /// Fonte, cores, paleta, cursor, histórico, Option, suavização, blocos e a barra própria escondida.
    @MainActor static func apply(to view: TerminalView)
}
```
- [ ] **Step 1: Testes que falham.**
  - `paletteIsTheClassicConsole`: `ansiHex` igual à lista das Global Constraints. `palette[7]` tem `red == 0xC0C0`, e `palette[12]` é (0, 0, 0xFFFF).
  - `applyConfiguresTheTerminal`: depois de `apply`, numa `TerminalView` de 640×400:
    - `optionAsMetaKey == false`, `fontSmoothing == false`, `customBlockGlyphs == false`;
    - `getTerminal().options.scrollback == 10_000`;
    - `getTerminal().options.cursorStyle == .blinkUnderline`;
    - 80 colunas e 25 linhas;
    - nenhuma `NSScroller` visível entre as subviews.
  - `historyKeepsTenThousandLines`: depois de alimentar 20.000 linhas numeradas, o buffer tem no máximo 10.000 + 25 linhas, e a primeira guardada é a 9.976 ou posterior.
  - `colorsStayCrisp`: com `apply`, o texto "\e[1;33mamarelo\e[0m \e[34mazul\e[0m ação\r\n" dá `distinctColors(view, rows: 1) == 4` (preto, cinza, amarelo claro e azul). Negrito usa a cor clara e a mesma fonte, sem traço sintético; isso foi conferido no protótipo.
- [ ] **Step 2: Rodar `swift test --filter PromptStyleTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar `apply`.**
  - Ordem: `font` → `nativeForegroundColor`/`nativeBackgroundColor` → `installColors(palette)` → `selectedTextBackgroundColor`, `caretColor` → as flags → esconder a `NSScroller` interna (`subviews.compactMap { $0 as? NSScroller }`) e reaplicar o tamanho (`setFrameSize`) → `getTerminal().changeHistorySize(scrollbackLines)` e `setCursorStyle(.blinkUnderline)` por último. O `font` refaz as opções e voltaria o histórico para 500.
- [ ] **Step 4: Rodar `swift test --filter PromptStyleTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: classic console style for the Prompt terminal`

---

### Task 3: Shell e ambiente

**Files:** Create `Sources/Retro98Prompt/ShellLaunch.swift`; Modify `Tests/Retro98PromptTests/TestSupport.swift` (`sh(_:home:)`). Test `Tests/Retro98PromptTests/ShellLaunchTests.swift`.

**Interfaces:**
```swift
struct ShellLaunch: Equatable {
    let executable: String
    let arguments: [String]          // vazio para o shell da pessoa
    let execName: String             // argv[0]; "-zsh" para login
    let environment: [String]        // "CHAVE=valor", em ordem de chave
    let directory: String
    static let fallbackShell = "/bin/zsh"
    /// O shell da pessoa como login. `isExecutable` e `accountShell` vêm de fora para os testes.
    static func userShell(environment: [String: String], accountShell: String?, home: String, locale: Locale,
                          version: String, isExecutable: (String) -> Bool) -> ShellLaunch
    static func language(for locale: Locale) -> String   // "pt_BR.UTF-8"; sem região ou idioma: "en_US.UTF-8"
}
```
- [ ] **Step 1: Testes que falham.**
  - `usesTheUserShellAsLogin`: com `SHELL=/bin/bash` executável, dá `executable == "/bin/bash"`, `execName == "-bash"`, `arguments == []` e `directory == home`.
  - `fallsBackWhenShellIsBad`: `SHELL` relativo ("zsh"), ausente e não executável caem em `accountShell` ("/bin/ksh", executável). Sem `accountShell`, caem em "/bin/zsh".
  - `setsTerminalVariables`: o ambiente tem `TERM=xterm-256color`, `COLORTERM=truecolor`, `TERM_PROGRAM=Retro98_Prompt` e `TERM_PROGRAM_VERSION=0.7.0`. Mantém `PATH` e `HOME` de entrada e troca um `TERM=dumb` herdado.
  - `addsLangOnlyWhenMissing`: sem `LANG`/`LC_ALL`/`LC_CTYPE` e locale `pt_BR`, entra `LANG=pt_BR.UTF-8`. Com `LC_ALL=C` (ou `LANG` já presente), `LANG` não muda nem é criado.
  - `languageForLocales`: `pt_BR` dá "pt_BR.UTF-8", `en` dá "en_US.UTF-8" e `fr_FR` dá "fr_FR.UTF-8".
- [ ] **Step 2: Rodar `swift test --filter ShellLaunchTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.** Em produção, o app chama `userShell` com `ProcessInfo` (ambiente), `getpwuid(getuid())` (shell da conta), `FileManager.isExecutableFile` e a versão do `Info.plist` (`dev` sem bundle).
- [ ] **Step 4: Rodar `swift test --filter ShellLaunchTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: login shell and terminal environment for the Prompt`

---

### Task 4: Barra de rolagem retrô para views que não são `NSScrollView`

**Files:** Modify `Sources/Retro98UI/RetroScroller.swift`. Test `Tests/Retro98UITests/RetroScrollerTests.swift` (criar, ou somar ao arquivo de testes da barra se já existir).

**Interfaces:**
```swift
public enum Request: Equatable, Sendable { case lineUp, lineDown, pageUp, pageDown, position(Double) }  // RetroScroller.Request
public var onScroll: ((Request) -> Void)?    // na RetroScroller; com ele, cliques e arrastos viram pedidos em vez de mover uma NSScrollView
```
- [ ] **Step 1: Testes que falham.**
  - `scrollerSendsRequestsWithoutAScrollView`: com `onScroll` e sem `scrollView`, as partes seta-acima, seta-abaixo, trilho acima e trilho abaixo dão `.lineUp`, `.lineDown`, `.pageUp` e `.pageDown`. Mover o botão até 0,25 dá `.position(0.25)`; valores fora de 0…1 chegam limitados.
  - `scrollViewScrollingIsUnchanged`: sem `onScroll`, com uma `NSScrollView` da fábrica, seta-abaixo continua descendo 16 pt.
- [ ] **Step 2: Rodar `swift test --filter RetroScrollerTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.** `Part` e `perform(_:)` passam a `internal`, para os testes. `perform` e `setScrollValue` chamam `onScroll` quando ele existe. Para o arrasto, crie `func moveKnob(to value: Double)` (internal), usado por `trackKnob` e pelo teste.
- [ ] **Step 4: Rodar `swift test --filter RetroScrollerTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: retro scroller can drive views other than scroll views`

---

### Task 5: Janela do Prompt

**Files:** Create `Sources/Retro98Prompt/PromptWindowController.swift`, `Sources/Retro98Prompt/PromptPrompter.swift`, `Sources/Retro98Prompt/PromptText.swift`. Test `Tests/Retro98PromptTests/PromptWindowTests.swift`.

**Interfaces:**
```swift
@MainActor protocol PromptPrompter: AnyObject {
    func confirmEnd(title: String, message: String, languages: [String]) -> Bool  // true = Encerrar
}
@MainActor final class RetroPromptPrompter: PromptPrompter            // RetroMessageBox, ícone de pergunta
@MainActor final class PromptWindowController: NSObject, NSWindowDelegate {
    static let menuHeight: CGFloat = 22
    static let contentSize = CGSize(width: 656, height: 424)
    let window: RetroAppWindow
    let terminal: PromptTerminalView              // LocalProcessTerminalView que avisa rolagem e saída nova
    let scroller: RetroScroller
    var onClose: (() -> Void)?
    init(launch: ShellLaunch, languages: [String], prompter: PromptPrompter)
    func start()                                  // abre o processo; o app chama depois de pôr a janela na tela
    var hasRunningProgram: Bool { get }           // tcgetpgrp(childfd) válido e != shellPid
    func endProcess()                             // sem perguntar (o app usa ao encerrar)
    func windowShouldClose(_ sender: NSWindow) -> Bool   // pergunta se hasRunningProgram
}
extension PromptWindowController: @preconcurrency LocalProcessTerminalViewDelegate   // título, tamanho, fim do processo
enum PromptText {   // pt-BR/en
    static func windowTitle(_ program: String?, _ l: [String]) -> String    // "Prompt" / "Prompt - vim"
    static func processEnded(code: Int32?, _ l: [String]) -> String         // "[Processo concluído com código 3]"
    static func confirmCloseMessage(_ l: [String]) -> String
    static func confirmQuitMessage(_ l: [String]) -> String
    static func end(_ l: [String]) -> String
    static func cancel(_ l: [String]) -> String
    // + títulos de menu da Task 6
}
```
- [ ] **Step 1: Testes que falham.** Use um `ScriptedPrompter` que guarda as perguntas e responde de uma lista. Use também `waitUntil(_ seconds: Double = 5, _ condition: () -> Bool) async -> Bool` (em `TestSupport`), que verifica a cada 20 ms com `Task.sleep`. Os processos vêm de `sh(_:home:)`.
  - `opensEightyByTwentyFive`: a janela sai com conteúdo 656×424, o terminal com 80×25, a barra com 16 de largura na borda direita e a barra de menus no topo.
  - `shellOutputAppears`: `printf 'ol\303\241 a\303\247\303\243o\n'; sleep 5` mostra "olá ação" numa linha do terminal.
  - `cleanExitClosesTheWindow`: `exit 0` chama `onClose` e fecha a janela.
  - `failedExitKeepsTheWindow`: `exit 3` deixa a janela aberta e mostra "[Processo concluído com código 3]".
  - `titleFollowsTheProgram`: `printf '\033]0;vim\007'; sleep 5` deixa o título da janela "Prompt - vim".
  - `scrollBarFollowsTheOutput`:
    - `seq 1 200; sleep 5` deixa a barra habilitada, com proporção < 1 e valor 1.
    - `.lineUp` vindo da barra deixa a posição do terminal < 1.
    - `.position(0)` leva ao topo.
  - `resizingChangesColumnsAndRows`: com conteúdo 816×520, ficam 100 colunas ((816 − 16) / 8) e 31 linhas ((520 − 24) / 16).
  - `closingAnIdleShellDoesNotAsk`: com `/bin/sh -i` ocioso, `windowShouldClose` dá true sem perguntar.
  - `closingWithARunningProgramAsks`:
    - Com `/bin/sh -i` (`PS1=''`, `HISTFILE=/dev/null`), enviar `sleep 30\n` faz `hasRunningProgram` ficar true.
    - Fechar pergunta; "Cancelar" deixa a janela aberta e o processo vivo.
    - Fechar de novo com "Encerrar" encerra o processo e fecha a janela.
- [ ] **Step 2: Rodar `swift test --filter PromptWindowTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
  - **Layout:**
    - `RetroMenuBar(menus: [])` e `EtchedLine`; a Task 6 põe os menus, com `menuBar.menus = PromptMenus.retroMenus(...)`;
    - abaixo, `terminal` (largura − 16) e `scroller` (16), com `autoresizingMask`;
    - `PromptStyle.apply(to: terminal)` e `terminal.processDelegate = self`.
  - **Barra:** `scroller.onScroll` vira `scrollUp(lines: 1)`, `scrollDown(lines: 1)`, `pageUp()`, `pageDown()` ou `scroll(toPosition:)`. Uma subclasse `PromptTerminalView: LocalProcessTerminalView` sobrescreve `scrolled(source:position:)` e `dataReceived(slice:)`, chama o `super` e avisa o controller para sincronizar `isEnabled`, `doubleValue` e `knobProportion` a partir de `canScroll`, `scrollPosition` e `scrollThumbsize`.
  - **Fim do processo:** código 0 fecha (`window.close()` → `onClose`); senão `feed(text: "\r\n" + PromptText.processEnded(...) + "\r\n")`.
  - **Encerrar:** `terminate()` do processo.
  - A janela recusa abas.
- [ ] **Step 4: Rodar `swift test --filter PromptWindowTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: Prompt window with retro scroll bar, title and safe close`

---

### Task 6: Menus, várias janelas e o app

**Files:** Create `Sources/Retro98Prompt/PromptMenus.swift`, `Sources/Retro98Prompt/AppDelegate.swift`; Modify `Sources/Retro98Prompt/main.swift`, `PromptText.swift`, `PromptWindowController.swift` (menus retrô de verdade). Test `Tests/Retro98PromptTests/PromptAppTests.swift`.

**Interfaces:**
```swift
@MainActor enum PromptMenus {
    static let helpURL = URL(string: "https://github.com/matheushchaves/retro98#readme")!
    struct Command { let title: String; let key: String; let modifiers: NSEvent.ModifierFlags; let selector: Selector }
    static func groups(_ l: [String]) -> [(title: String, commands: [Command?])]   // Arquivo, Editar, Ajuda
    static func mainMenu(languages l: [String]) -> NSMenu
    static func windowMenu(in main: NSMenu, languages: [String]) -> NSMenu?
    static func retroMenus(languages: [String]) -> [RetroMenuBarMenu]
}
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    init(launch: @escaping () -> ShellLaunch = AppDelegate.userShell, prompter: PromptPrompter = RetroPromptPrompter())
    var presentsWindows: Bool                       // false nos testes: não põe na tela
    var windowControllers: [PromptWindowController] { get }
    @objc func newWindow(_ sender: Any?)            // ⌘N
    @objc func closeWindow(_ sender: Any?)          // ⌘W: performClose da janela ativa
    @objc func showAbout(_ sender: Any?)            // orderFrontStandardAboutPanel com créditos
    @objc func openHelp(_ sender: Any?)
    static func aboutCredits(_ l: [String]) -> String
}
```
- [ ] **Step 1: Testes que falham.**
  - `menusHaveTheShortcuts`: o menu do macOS tem ⌘N `newWindow:`, ⌘W `closeWindow:`, ⌘C `copy:`, ⌘V `paste:`, ⌘A `selectAll:`, ⌘Q `terminate:` e ⌘M `performMiniaturize:` ou `miniaturize:`, e não tem item de abas.
  - `retroMenusMirrorTheGroups`: os menus da janela têm os mesmos títulos e comandos de `groups`.
  - `newWindowOpensAnother`: com `presentsWindows = false` e `launch` = `/bin/sh -i` ocioso, duas chamadas de `newWindow` dão duas janelas. Fechar uma deixa uma.
  - `quittingAsksOnceWhenSomethingRuns`:
    - Duas janelas, uma com `sleep 30` rodando: `applicationShouldTerminate` pergunta uma vez. "Cancelar" dá `.terminateCancel`; "Encerrar" dá `.terminateNow` e encerra os processos.
    - Sem nada rodando, dá `.terminateNow` sem perguntar.
  - `windowTabsAreOff`: `NSWindow.allowsAutomaticWindowTabbing == false` depois de `applicationWillFinishLaunching`, e cada janela com `tabbingMode == .disallowed`.
  - `aboutCreditsTheFontAndTerminal`: os créditos têm "PxPlus IBM VGA 8x16", "VileR", "CC BY-SA 4.0" e "SwiftTerm".
- [ ] **Step 2: Rodar `swift test --filter PromptAppTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar, seguindo o `ExplorerMenus` e o `AppDelegate` do Explorer.**
  - **Abrir e reabrir:** `applicationDidFinishLaunching` registra a fonte do bundle e abre uma janela. `applicationShouldHandleReopen` sem janelas abre outra.
  - `applicationShouldTerminateAfterLastWindowClosed` dá false.
  - **Posição:** as janelas novas saem em cascata a partir da ativa.
  - **Fechar:** `closeWindow` usa `performClose`, que passa pela pergunta.
  - **`main.swift`:** como o do Explorer, com `PromptMenus.mainMenu` e `windowMenu`.
- [ ] **Step 4: Rodar `swift test --filter PromptAppTests` e depois a suíte toda (`swift test`).** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: Prompt menus, multiple windows and quit confirmation`

---

### Task 7: Ícone, empacotamento, instalador e documentação

**Files:** Modify `Sources/Retro98UI/FileIcons.swift`, `Sources/retro98-tools/main.swift`, `scripts/build-app.sh`, `scripts/common.sh`, `install.sh`, `uninstall.sh`, `README.md`, `README.pt-BR.md`. Test `Tests/Retro98UITests/FileIconTests.swift`, `Tests/scripts/test_install.sh`, `Tests/scripts/test_uninstall.sh`.

**Interfaces:**
```swift
public static let promptApp: PixelIcon        // 32×32, FileIcons
public static let promptAppSmall: PixelIcon   // 16×16
// retro98-tools: case "prompt" (e a mensagem de erro lista explorer, shell ou prompt)
```
```bash
# build-app.sh: 9º argumento opcional = pasta de recursos; os arquivos dela vão para Contents/Resources antes de assinar
# common.sh:
PROMPT_ID="io.github.matheushchaves.retro98.prompt"
PROMPT_APP="$APPS_DIR/Retro98 Prompt.app"
remove_prompt()   # stop_executable + lsregister -u + rm -rf, no-op sem o app
```
- [ ] **Step 1: Testes que falham.**
  - **Ícone, `promptAppIsOriginalPixelArt`:** 32×32 e 16×16 com mais de 1/8 de pixels opacos, como o teste do Explorer.
  - **`test_install.sh`:**
    - `prompt-built`: assinado.
    - `prompt-is-regular-app`.
    - `prompt-has-font`: o TTF e a licença em `Contents/Resources`.
    - `prompt-has-icon`.
    - `prompt-not-default-terminal`: sem `CFBundleDocumentTypes` e sem `CFBundleURLTypes`.
    - `pieces-recorded` passa a esperar `base shell prompt`.
    - `old-pieces-get-prompt`: `base shell` gravado antes reinstala com o Prompt.
    - `declined-prompt-stays-off`: `base shell noprompt` não monta o Prompt e apaga um que exista, com `lsregister -u`.
  - **`test_uninstall.sh`:** `uninstall-removes-prompt` (o app some e é desregistrado).
- [ ] **Step 2: Rodar `bash Tests/scripts/test_install.sh`, `bash Tests/scripts/test_uninstall.sh` e `swift test --filter FileIconTests`.** Esperado: FAIL nos novos.
- [ ] **Step 3: Implementar.**
  - **Ícone:** janelinha 98 original, com barra de título azul-marinho, corpo preto e "C:\>_" ou ">_" em cinza.
  - **`install.sh`:**
    - a pergunta da peça e a regra do `--yes`, nas Global Constraints;
    - o Prompt é montado com `build-app.sh Retro98Prompt "$PROMPT_ID" "Retro98 Prompt" "$PROMPT_APP" regular "" prompt "" "$RETRO98_ROOT/Resources/Prompt"`, independente da peça `shell`;
    - sem a peça, chama `remove_prompt`.
  - **`uninstall.sh`:** chama `remove_prompt` junto com `remove_explorer`.
  - **`build-app.sh`:** `VERSION="0.7.0"`, `BUILD="7"`.
  - **README e README.pt-BR:**
    - seção do Prompt: o que faz, que não substitui o Terminal, atalhos e Option para acentos;
    - "Créditos": a fonte (VileR, int10h.org, CC BY-SA 4.0, a licença no app) e o SwiftTerm (MIT, vendorizado em 1.11.2, os dois patches e o motivo);
    - a nova pergunta do instalador.
- [ ] **Step 4: Rodar os três scripts de teste (com a lista de chaveiros conferida antes e depois), `swift test` e os builds release de `Retro98Prompt`, `Retro98Explorer` e `Retro98Shell`.** Esperado: tudo PASS e nenhum `warning:`.
- [ ] **Step 5: Commit** `feat: install Retro98 Prompt as its own piece` e, separado, `docs: Retro98 Prompt and third-party credits (Phase 4)`

---

## Checagem manual (para o autor, depois do `./install.sh` interativo)

1. Iniciar › Programas › Retro98 › Retro98 Prompt abre uma janela 80×25 preta, com texto cinza e fonte VGA nítida, e o seu prompt do zsh.
2. `ls -G`, `git log --oneline --graph --color` e `htop` ou `top`: cores e desenhos certos.
3. Digitar "ação", "pão" e "você" (com Option ou teclas mortas) e `echo 'olá'`.
4. Selecionar com o mouse, ⌘C, ⌘V em outra janela (⌘N); arrastar a borda e ver as linhas se ajustarem (`tput cols`).
5. `seq 1 20000`: rolar pela barra retrô e pela roda do mouse; o histórico volta até ~10.000 linhas.
6. Com `vim` aberto, ⌘W pergunta; Cancelar mantém. `exit` fecha a janela.
7. O Terminal do macOS continua sendo o que abre arquivos `.command` e `.sh`.
