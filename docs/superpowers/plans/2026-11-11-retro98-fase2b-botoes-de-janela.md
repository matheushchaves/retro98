# Retro98 Fase 2B — Botões de janela na barra de tarefas: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A barra de tarefas mostra um botão por janela aberta no Space atual, com o comportamento do 98. Clicar ativa a janela; clicar na janela que já está ativa minimiza. O botão direito abre um menu com Restaurar, Minimizar e Fechar. A permissão de Acessibilidade é concedida uma única vez, porque um certificado local estável assina o app. O Dock fica totalmente escondido, sem mostrar nomes ao passar o mouse, e a barra volta aos 28 pt do 98. O Shell mantém as janelas maximizadas acima da barra.

**Architecture:**
- Lógica pura e testável em `Retro98ShellCore`: ordenação estável, layout dos botões, corte de títulos com "…", decisão do clique e quando pedir a permissão.
- O app lê e controla as janelas pela API pública de Acessibilidade (`AXUIElement`), atrás dos protocolos `WindowSource` e `WindowCommands`. É acordado por `AXObserver` e notificações do `NSWorkspace`, com uma verificação periódica de segurança.
- O instalador cria um chaveiro próprio com um certificado de assinatura autoassinado (validado em spike) e assina o Shell com ele.

**Tech Stack:** Swift 6, AppKit, ApplicationServices (Accessibility), Security/`codesign`, LibreSSL do sistema (`/usr/bin/openssl`), bash, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-10-retro-desktop-design.md` (seções 4 e 6, "Fase 2" › "Barra de tarefas"). Divisão **[minha escolha]**: 2B = botões de janela + assinatura + Acessibilidade; 2C = área de trabalho (ícones, Lixeira com Acesso Total ao Disco, esconder a área de trabalho do Finder).

## Global Constraints

- Tudo das "Global Constraints" das Fases 1 e 2A continua valendo.
- **Só APIs públicas.** A identidade de janela usa `CFEqual`/`CFHash` do próprio `AXUIElement`; **não** usar `_AXUIElementGetWindow` nem outra API privada.
- **Um botão por janela do Space atual**, com subrole `AXStandardWindow` ou `AXDialog`, de apps com `activationPolicy == .regular`, exceto o próprio Shell. Janelas minimizadas aparecem.
- **Timeout de mensagem AX** de 0,25 s por app (`AXUIElementSetMessagingTimeout`): um app travado nunca trava a barra.
- **Botão de janela:**
  - Altura 22 pt, centralizado na barra, largura máxima 160 pt e mínima 40 pt (só ícone), espaço de 3 pt entre botões.
  - A área vai de 4 pt depois do Iniciar até 4 pt antes da bandeja.
  - Ícone 16×16 do app (pixelado) e título cortado com "…".
  - Janela ativa: relevo pressionado com fundo pontilhado (xadrez de 1 px branco e face).
- **Assinatura:**
  - Chaveiro: `~/Library/Keychains/retro98-signing.keychain-db`.
  - Identidade: "Retro98 Local Signing", RSA 2048, validade de 10 anos, `extendedKeyUsage = codeSigning`.
  - Senha do chaveiro gerada aleatoriamente e guardada em `$SUPPORT_DIR/signing-password` (modo 0600).
  - **A lista de chaveiros do usuário é restaurada logo depois de criar o chaveiro.** A assinatura usa `codesign --keychain <caminho>`.
  - `RETRO98_SIGNING=adhoc` força assinatura ad-hoc (CI e testes).
- **Permissão de Acessibilidade:**
  - Sem permissão, a barra funciona sem botões de janela.
  - Uma caixa de mensagem explica e abre `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`, só uma vez por versão instalada.
  - A permissão é verificada a cada 3 s e, quando chega, os botões aparecem sem reiniciar.
- **Dock escondido** (ajuste `dockUnderTaskbar`, mesmo id, grupo `.shell`, efeito `.restartDock`):
  - `tilesize` `.int(16)`, `magnification` `.bool(false)`, `autohide` **`.bool(true)`**, `autohide-delay` **`.double(1000)`**, `autohide-time-modifier` **`.double(0)`**, `orientation` `.string("bottom")`.
  - Título pt-BR "Dock escondido sob a barra de tarefas", en "Dock hidden under the taskbar".
  - Com isso o Dock não reserva espaço e a barra fica com a altura mínima de 28 pt.
- **Guarda da área de trabalho:** com permissão de Acessibilidade, janelas da tela principal cuja base encosta na base da tela (até 6 pt de tolerância) ou passa dela são encolhidas até o topo da barra. Isso cobre maximizar, "Preencher" e lado a lado. As demais janelas não são tocadas. Só a altura muda; a posição fica como está.
- Textos novos em pt-BR/en (valores exatos nas tarefas).

## Review Focus

1. **Muitas janelas** (30 ou mais) **e títulos longos**: os botões encolhem até 40 pt. Os que não cabem ficam ocultos, sem sobrepor a bandeja, e os títulos são cortados sem passar do botão. → Task 3, `buttonsShrinkToMinimumAndOverflowIsHidden`, `titleFitsWithEllipsis`.
2. **Apps travados ou que recusam AX**: a barra continua respondendo e o app simplesmente fica sem botões. → Task 4, timeout de 0,25 s (verificação manual) e `snapshotSkipsAppsThatFail` com fonte falsa.
3. **Janelas que somem ou mudam de título entre a leitura e o clique**: o clique numa janela que já não existe não trava nem ativa a janela errada. A barra se atualiza. → Task 5, `clickOnVanishedWindowRefreshesInsteadOfActing`.
4. **Permissão negada, retirada ou concedida depois**: sem caixas repetidas a cada login, e os botões aparecem e somem conforme a permissão. → Task 6, `promptsOncePerBuild`, `buttonsFollowTrust`.
5. **Guarda das janelas**: o app recusa o tamanho, tem altura mínima maior que a área, ou a janela fica na tela secundária. Sem loop de ajuste e sem mexer em janelas que não encostam na base. → Task 7, `leavesWindowsAwayFromTheBottomAlone`, `doesNotTouchWindowsAlreadyAboveTheTaskbar`, `ignoresOtherScreens`.
6. **Reinstalar ou atualizar**: o mesmo certificado continua sendo usado, então a exigência de assinatura do app não muda e a permissão sobrevive. Desinstalar remove o chaveiro. → Task 2, `test_signing.sh` (exigência idêntica em duas montagens; lista de chaveiros intacta).

---

## Estrutura de arquivos

```
Sources/Retro98ShellCore/
  TaskbarWindows.swift      WindowSnapshot, TaskbarOrdering, TaskButtonLayout, TitleFitting, TaskButtonClick
  AccessibilityPrompt.swift quando pedir a permissão
  LaunchHistory.swift       (Task 1) desiste na 3ª queda
Sources/Retro98UI/RetroMenu.swift              (Task 1) ignorar cliques por predicado
Sources/Retro98Shell/
  TrayView.swift            (Task 1) timers em .common, atualização ao acordar
  TaskbarPanel.swift        (Tasks 1, 5) área dos botões
  AXWindows.swift           AXWindowSource, AXWindowCommands, observadores
  TaskButtonsView.swift     desenho e cliques dos botões
  AccessibilityGate.swift   permissão: verificação, aviso, espera
  WorkAreaGuardian.swift    encolhe janelas que passam por baixo da barra
Sources/Retro98ShellCore/WorkAreaGuard.swift   regra pura do ajuste
Sources/Retro98Settings/Tweaks/TweakCatalog.swift   Dock escondido
scripts/signing.sh          ensure_signing_identity, sign_app, remove_signing_identity
scripts/build-shell-app.sh  usa sign_app; recusa caminhos que não terminam em .app
install.sh, uninstall.sh, README.md, README.pt-BR.md, .github/workflows/ci.yml
Tests/Retro98ShellCoreTests/{TaskbarWindowsTests,AccessibilityPromptTests}.swift
Tests/scripts/test_signing.sh
```

---

### Task 1: Pendências da 2A na barra

**Files:**
- Modify: `Sources/Retro98ShellCore/LaunchHistory.swift`, `Sources/Retro98UI/RetroMenu.swift`, `Sources/Retro98Shell/TrayView.swift`, `Sources/Retro98Shell/TaskbarPanel.swift`, `scripts/build-shell-app.sh`
- Test: `Tests/Retro98ShellCoreTests/LaunchHistoryTests.swift`, `Tests/Retro98UITests/MenuTests.swift`, `Tests/scripts/test_install.sh`

**Interfaces:**
- `LaunchHistory.recordLaunch` passa a desistir com **mais de** `maxLaunches` aberturas na janela de tempo. Uma abertura normal e depois 3 quedas dão 4 aberturas, e só então desiste. Assim fica igual ao README: "3 quedas em 1 minuto".
- `RetroMenu.ignoresClicksIn: [NSWindow]` vira `RetroMenu.ignoresClick: ((NSEvent) -> Bool)?`. O Shell ignora só cliques dentro do botão Iniciar, então clicar na bandeja ou na barra vazia fecha o menu. O menu também fecha em `NSWorkspace.didActivateApplicationNotification` (⌘Tab).
- `TrayView`:
  - Timers adicionados em `RunLoop.main` no modo `.common`, para o relógio não parar com diálogo aberto.
  - Um único timer de minuto, reagendado sem acumular.
  - Atualiza em `NSWorkspace.didWakeNotification` e `.NSSystemClockDidChange`.
- `build-shell-app.sh` sai com erro se o argumento não terminar em `.app`.

- [ ] **Step 1: Testes que falham**
  - Em `LaunchHistoryTests`, `givesUpAfterThreeLaunchesWithinSixtySeconds` vira `givesUpOnTheThirdCrash`: aberturas em t0, +10, +20 → false; +30 → true.
  - Em `MenuTests`, `ignoreClickPredicateIsConsulted`: a função pura `RetroMenu.shouldClose(clickInMenu:ignored:)` retorna false se o clique foi no menu ou foi ignorado, e true caso contrário.
  - Em `test_install.sh`, `build-script-refuses-non-app`: `bash scripts/build-shell-app.sh "$WORK/nao-e-app"` sai com código diferente de 0 e não cria nada.
- [ ] **Step 2: Rodar `swift test --filter "LaunchHistoryTests|MenuTests"` e `bash Tests/scripts/test_install.sh`.** Esperado: FAIL nesses casos.
- [ ] **Step 3: Implementar.** Mais os timers e as notificações da bandeja (verificação manual).
- [ ] **Step 4: Rodar `swift test && bash Tests/scripts/test_install.sh && bash Tests/scripts/test_uninstall.sh`.** Esperado: PASS. README (pt-BR e en): "3 vezes em 1 minuto" continua correto.
- [ ] **Step 5: Commit** `fix: Start menu closes on taskbar clicks and app switches; clock survives sleep and dialogs`

---

### Task 2: Certificado local de assinatura

**Files:**
- Create: `scripts/signing.sh`, `Tests/scripts/test_signing.sh`
- Modify: `scripts/build-shell-app.sh`, `scripts/common.sh`, `.github/workflows/ci.yml`

**Interfaces** (funções bash em `signing.sh`, carregadas por `build-shell-app.sh`, `install.sh` e `uninstall.sh`):
- `SIGNING_KEYCHAIN="${RETRO98_SIGNING_KEYCHAIN:-$HOME/Library/Keychains/retro98-signing.keychain-db}"`, `SIGNING_IDENTITY="Retro98 Local Signing"`, `SIGNING_PASSWORD_FILE="$SUPPORT_DIR/signing-password"`.
- `ensure_signing_identity`:
  - Se o chaveiro e a identidade já existem, só destrava (usando a senha do arquivo).
  - Senão, gera a senha (`/usr/bin/openssl rand -hex 24`, arquivo 0600), guarda a lista de chaveiros, cria o chaveiro e restaura a lista na hora.
  - Gera chave e certificado com `/usr/bin/openssl req -x509` e a configuração validada no spike (`basicConstraints critical,CA:false`, `keyUsage critical,digitalSignature`, `extendedKeyUsage critical,codeSigning`, CN = identidade).
  - Exporta p12 e importa com `-T /usr/bin/codesign`, roda `security set-key-partition-list -S apple-tool:,apple:,codesign: -s` e apaga os arquivos temporários de chave.
- `sign_app <caminho.app> <identificador>`: se `RETRO98_SIGNING=adhoc`, roda `codesign --force --sign -`. Senão, roda `ensure_signing_identity` e `codesign --force --sign "$SIGNING_IDENTITY" --keychain "$SIGNING_KEYCHAIN" -i <identificador>`.
- `remove_signing_identity`: `security delete-keychain` (se existir), remove o arquivo de senha e restaura a lista de chaveiros se ela tiver mudado.
- `build-shell-app.sh` passa a usar `sign_app "$OUT" io.github.matheushchaves.retro98.shell`.

- [ ] **Step 1: Teste que falha** (`Tests/scripts/test_signing.sh`). Usa `RETRO98_SIGNING_KEYCHAIN` e `RETRO98_SUPPORT_DIR` temporários, guarda `security list-keychains -d user` antes e confere:
  - `designated-uses-certificate`: depois de `sign_app` num binário de teste copiado de `/usr/bin/true` dentro de um `.app` mínimo, `codesign -dr -` contém `certificate leaf = H"`.
  - `requirement-stable-across-builds`: assinar de novo, depois de copiar o binário outra vez, produz exatamente a mesma exigência de assinatura (designated requirement).
  - `search-list-untouched`: a lista de chaveiros depois é igual à de antes.
  - `password-file-private`: `stat -f %Lp` do arquivo de senha é `600`.
  - `remove-cleans-up`: depois de `remove_signing_identity`, o chaveiro e o arquivo de senha não existem e a lista continua igual.
  - `adhoc-override`: com `RETRO98_SIGNING=adhoc`, a exigência não contém `certificate leaf`.
- [ ] **Step 2: Rodar `bash Tests/scripts/test_signing.sh`.** Esperado: FAIL (`signing.sh` não existe).
- [ ] **Step 3: Implementar `signing.sh` e usar em `build-shell-app.sh`.** O CI define `RETRO98_SIGNING=adhoc` nos passos de build e de `test_install.sh`, e roda `test_signing.sh` à parte.
- [ ] **Step 4: Rodar `bash Tests/scripts/test_signing.sh && bash Tests/scripts/test_install.sh`.** Esperado: tudo PASS. `test_install.sh` exporta `RETRO98_SIGNING=adhoc`.
- [ ] **Step 5: Commit** `feat: sign Retro98 Shell with a stable local certificate`

---

### Task 3: Lógica dos botões de janela

**Files:**
- Create: `Sources/Retro98ShellCore/TaskbarWindows.swift`
- Test: `Tests/Retro98ShellCoreTests/TaskbarWindowsTests.swift`

**Interfaces:**
```swift
public struct WindowSnapshot<ID: Hashable & Sendable>: Equatable, Sendable {
    public let id: ID; public let title: String; public let appName: String; public let appURL: URL?
    public let isMinimized: Bool; public let isFocused: Bool
}
public enum TaskbarOrdering {
    /// Janelas já conhecidas mantêm a ordem anterior; as novas entram no fim, na ordem recebida.
    public static func order<ID>(previous: [ID], current: [WindowSnapshot<ID>]) -> [WindowSnapshot<ID>]
}
public enum TaskButtonLayout {
    public static let maxWidth: CGFloat = 160, minWidth: CGFloat = 40, gap: CGFloat = 3, height: CGFloat = 22
    /// Um frame por botão, ou nil quando não cabe (oculto). Larguras iguais, arredondadas para baixo.
    public static func frames(count: Int, area: CGRect) -> [CGRect?]
}
public enum TitleFitting {
    /// O título inteiro se couber; senão o maior prefixo + "…" que caiba; "" se nem "…" couber.
    public static func fit(_ title: String, maxWidth: Int, measure: (String) -> Int) -> String
}
public enum TaskButtonAction: Equatable, Sendable { case activate, minimize }
public enum TaskButtonClick {
    public static func action(isFocused: Bool, isMinimized: Bool) -> TaskButtonAction   // ativa e visível → minimizar
}
public enum TaskButtonMenuText {   // pt-BR / en
    public static func restore(_ languages: [String]) -> String    // "Restaurar" / "Restore"
    public static func minimize(_ languages: [String]) -> String   // "Minimizar" / "Minimize"
    public static func close(_ languages: [String]) -> String      // "Fechar" / "Close"
}
```
O título vazio vira o nome do app, regra aplicada pela fonte (Task 4).

- [ ] **Step 1: Testes que falham** (com `Int` como ID)

```swift
@Test func knownWindowsKeepTheirOrderAndNewOnesGoLast() {
    let current = [snap(3), snap(1), snap(2)]
    #expect(TaskbarOrdering.order(previous: [1, 2], current: current).map(\.id) == [1, 2, 3])
}
@Test func closedWindowsDisappearFromTheOrder() { /* previous [1,2,3], current [3,1] → [1,3] */ }
@Test func buttonsUseMaxWidthWhenThereIsRoom() {
    let frames = TaskButtonLayout.frames(count: 2, area: CGRect(x: 100, y: 7, width: 1000, height: 22))
    #expect(frames == [CGRect(x: 100, y: 7, width: 160, height: 22), CGRect(x: 263, y: 7, width: 160, height: 22)])
}
@Test func buttonsShrinkToMinimumAndOverflowIsHidden() {
    let frames = TaskButtonLayout.frames(count: 30, area: CGRect(x: 0, y: 0, width: 430, height: 22))
    #expect(frames.compactMap { $0 }.count == 10)            // 10×40 + 9×3 = 427 ≤ 430
    #expect(frames.compactMap { $0 }.allSatisfy { $0.width == 40 && $0.maxX <= 430 })
    #expect(frames[10] == nil)
}
@Test func titleFitsWithEllipsis() {
    let measure = { (s: String) in s.count * 6 }
    #expect(TitleFitting.fit("Relatório", maxWidth: 100, measure: measure) == "Relatório")
    #expect(TitleFitting.fit("Relatório anual de vendas", maxWidth: 60, measure: measure) == "Relatóri…")
    #expect(TitleFitting.fit("Qualquer", maxWidth: 4, measure: measure) == "")
}
@Test func clickingTheActiveWindowMinimizesIt() {
    #expect(TaskButtonClick.action(isFocused: true, isMinimized: false) == .minimize)
    #expect(TaskButtonClick.action(isFocused: false, isMinimized: false) == .activate)
    #expect(TaskButtonClick.action(isFocused: true, isMinimized: true) == .activate)
}
@Test func menuTexts() { /* Restaurar/Minimizar/Fechar em pt-BR; Restore/Minimize/Close em en */ }
```

- [ ] **Step 2: Rodar `swift test --filter TaskbarWindowsTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test --filter TaskbarWindowsTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add taskbar window button logic`

---

### Task 4: Leitura e controle de janelas via Acessibilidade

**Files:**
- Create: `Sources/Retro98ShellCore/WindowSource.swift` (protocolos e fonte falsa para testes), `Sources/Retro98Shell/AXWindows.swift`
- Test: `Tests/Retro98ShellCoreTests/WindowSourceTests.swift`

**Interfaces:**
```swift
// ShellCore
public protocol WindowSource<ID> { associatedtype ID: Hashable & Sendable; func snapshot() -> [WindowSnapshot<ID>] }
public protocol WindowCommands<ID> {
    associatedtype ID: Hashable & Sendable
    func activate(_ id: ID) -> Bool; func minimize(_ id: ID) -> Bool; func close(_ id: ID) -> Bool   // false = janela sumiu ou recusou
}
/// Junta as janelas de vários apps; um app que falha é ignorado e os outros continuam.
public enum WindowCollector {
    public static func collect<ID>(apps: [() throws -> [WindowSnapshot<ID>]]) -> [WindowSnapshot<ID>]
}
// App (Retro98Shell/AXWindows.swift)
struct AXWindowID: Hashable, @unchecked Sendable { let element: AXUIElement; let pid: pid_t }  // ==/hash via CFEqual/CFHash
final class AXWindowSource: WindowSource { /* NSWorkspace.runningApplications regulares, exceto o próprio pid */ }
final class AXWindowCommands: WindowCommands { /* raise + activate; kAXMinimizedAttribute; kAXCloseButtonAttribute + AXPress */ }
final class WindowChangeMonitor { init(onChange: @escaping @MainActor () -> Void) }
```

**Detalhes da implementação AX:**
- Subroles aceitos: `kAXStandardWindowSubrole` e `kAXDialogSubrole`.
- Título vazio vira `NSRunningApplication.localizedName`.
- `isFocused` = o app é o `frontmostApplication` e a janela é igual (`CFEqual`) ao `kAXFocusedWindowAttribute` dele.
- `activate`: se minimizada, `kAXMinimizedAttribute = false`; depois `AXUIElementPerformAction(kAXRaiseAction)` e `NSRunningApplication.activate()`.
- **Monitor de mudanças:**
  - `AXObserver` por app, para `kAXWindowCreatedNotification`, `kAXUIElementDestroyedNotification`, `kAXTitleChangedNotification`, `kAXWindowMiniaturizedNotification`, `kAXWindowDeminiaturizedNotification` e `kAXFocusedWindowChangedNotification`.
  - Notificações do `NSWorkspace`: `didLaunchApplication`, `didTerminateApplication`, `didActivateApplication`, `activeSpaceDidChange`.
  - Juntar avisos próximos e atualizar uma vez, 100 ms depois do último.
  - Verificação de segurança a cada 5 s.
  - Os callbacks C usam o padrão estático do `HotKey`.

- [ ] **Step 1: Teste que falha**

```swift
@Test func snapshotSkipsAppsThatFail() {
    struct Boom: Error {}
    let windows = WindowCollector.collect(apps: [
        { [snap(1)] }, { throw Boom() }, { [snap(2), snap(3)] },
    ])
    #expect(windows.map(\.id) == [1, 2, 3])
}
```

- [ ] **Step 2: Rodar `swift test --filter WindowSourceTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar `WindowCollector` e os tipos AX.** `AXWindowSource.snapshot` usa `WindowCollector`, com uma closure por app que lança erro quando a cópia AX falha.
- [ ] **Step 4: Rodar `swift test`** e `swift build -c release --product Retro98Shell` sem warnings. Esperado: PASS.
- [ ] **Step 5: Commit** `feat: read and control windows through the Accessibility API`

---

### Task 5: Botões de janela na barra

**Files:**
- Create: `Sources/Retro98Shell/TaskButtonsView.swift`, `Sources/Retro98ShellCore/TaskButtonsModel.swift`
- Modify: `Sources/Retro98Shell/TaskbarPanel.swift`
- Test: `Tests/Retro98ShellCoreTests/TaskButtonsModelTests.swift`

**Interfaces:**
```swift
// ShellCore: estado testável da faixa de botões, genérico na fonte e nos comandos
@MainActor public final class TaskButtonsModel<Source: WindowSource, Commands: WindowCommands> where Source.ID == Commands.ID {
    public init(source: Source, commands: Commands)
    public private(set) var windows: [WindowSnapshot<Source.ID>]
    public var onChange: (() -> Void)?
    public func refresh()                      // aplica TaskbarOrdering
    public func click(_ id: Source.ID)         // TaskButtonClick; se o comando falhar → refresh()
    public func restore(_ id: Source.ID); public func minimize(_ id: Source.ID); public func close(_ id: Source.ID)
}
```
- **`TaskButtonsView`** (PixelView) desenha os botões nos frames de `TaskButtonLayout.frames`:
  - relevo `.raised`, ou `.buttonPressed` com xadrez branco/face quando ativo;
  - ícone 16 do app (cache por URL), título com `TitleFitting.fit` na largura do botão menos ícone e margens.
- **Cliques:** clique esquerdo chama `click`. Clique direito abre um `RetroMenu` padrão com Restaurar (habilitado se minimizada), Minimizar (habilitado se não minimizada) e Fechar.
- **`TaskbarController`:** cria a view entre o Iniciar e a bandeja e refaz o layout quando a barra ou a bandeja mudam de tamanho.

- [ ] **Step 1: Testes que falham** (fonte e comandos falsos com `Int`)

```swift
@MainActor @Test func clickActivatesOrMinimizesThroughCommands() { /* focada → minimize(1); outra → activate(2) */ }
@MainActor @Test func clickOnVanishedWindowRefreshesInsteadOfActing() {
    // commands.activate retorna false → model chama source.snapshot() de novo; windows reflete a nova lista
}
@MainActor @Test func refreshKeepsOrderAcrossUpdates() { /* [1,2] e depois a fonte devolve [2,1,3] → [1,2,3] */ }
@MainActor @Test func onChangeFiresOnlyWhenWindowsChange() { /* duas atualizações idênticas → onChange 1 vez */ }
```

- [ ] **Step 2: Rodar `swift test --filter TaskButtonsModelTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar o modelo, a view e a ligação.**
- [ ] **Step 4: Rodar `swift test`** e o build release. Esperado: PASS.
- [ ] **Step 5: Commit** `feat: show window buttons on the taskbar`

---

### Task 6: Permissão de Acessibilidade

**Files:**
- Create: `Sources/Retro98ShellCore/AccessibilityPrompt.swift`, `Sources/Retro98Shell/AccessibilityGate.swift`
- Modify: `Sources/Retro98Shell/AppDelegate.swift`
- Test: `Tests/Retro98ShellCoreTests/AccessibilityPromptTests.swift`

**Interfaces:**
```swift
public enum AccessibilityPrompt {
    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    /// Mostrar o aviso só quando não há permissão e esta versão ainda não avisou.
    public static func shouldShow(isTrusted: Bool, lastPromptedBuild: String?, currentBuild: String) -> Bool
    public static func message(languages: [String]) -> String
    public static let lastPromptedKey = "lastAccessibilityPromptBuild"   // UserDefaults do Shell
}
public enum TrustTransition: Equatable, Sendable { case none, granted, revoked }
public func trustTransition(was: Bool, now: Bool) -> TrustTransition
```
- Mensagem:
  - pt-BR: "Para mostrar as janelas abertas na barra de tarefas e manter as janelas maximizadas acima dela, o Retro98 Shell precisa da permissão de Acessibilidade. Vou abrir Ajustes do Sistema › Privacidade e Segurança › Acessibilidade: ative o Retro98 Shell lá. A barra continua funcionando enquanto isso."
  - en: "To show your open windows on the taskbar and keep maximized windows above it, Retro98 Shell needs Accessibility permission. I'll open System Settings › Privacy & Security › Accessibility: turn on Retro98 Shell there. The taskbar keeps working meanwhile."
- **`AccessibilityGate`** (app):
  - Ao iniciar, lê `AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt: false])`.
  - Se `shouldShow`, mostra `RetroMessageBox` (info, OK), abre `settingsURL` e grava a versão (`CFBundleVersion`) em `lastPromptedKey`.
  - Verifica a cada 3 s. `granted` liga a faixa de botões e o monitor; `revoked` os desliga e esconde.

- [ ] **Step 1: Testes que falham**

```swift
@Test func promptsOncePerBuild() {
    #expect(AccessibilityPrompt.shouldShow(isTrusted: false, lastPromptedBuild: nil, currentBuild: "3"))
    #expect(!AccessibilityPrompt.shouldShow(isTrusted: false, lastPromptedBuild: "3", currentBuild: "3"))
    #expect(AccessibilityPrompt.shouldShow(isTrusted: false, lastPromptedBuild: "2", currentBuild: "3"))
    #expect(!AccessibilityPrompt.shouldShow(isTrusted: true, lastPromptedBuild: nil, currentBuild: "3"))
}
@Test func buttonsFollowTrust() {
    #expect(trustTransition(was: false, now: true) == .granted)
    #expect(trustTransition(was: true, now: false) == .revoked)
    #expect(trustTransition(was: true, now: true) == .none)
}
@Test func messageMentionsTheSettingsPath() { /* pt-BR contém "Privacidade e Segurança › Acessibilidade" */ }
```

- [ ] **Step 2: Rodar `swift test --filter AccessibilityPromptTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar o modelo e o portão no app.**
- [ ] **Step 4: Rodar `swift test`** e o build release. Esperado: PASS.
- [ ] **Step 5: Commit** `feat: ask for Accessibility once and react when it is granted`

---

### Task 7: Dock escondido e guarda das janelas maximizadas

**Files:**
- Modify: `Sources/Retro98Settings/Tweaks/TweakCatalog.swift`, `Tests/Retro98SettingsTests/TweakCatalogTests.swift`
- Create: `Sources/Retro98ShellCore/WorkAreaGuard.swift`, `Sources/Retro98Shell/WorkAreaGuardian.swift`
- Modify: `Sources/Retro98Shell/AXWindows.swift` (observar também `kAXWindowMovedNotification` e `kAXWindowResizedNotification`), `Sources/Retro98Shell/AccessibilityGate.swift` (ligar e desligar o guardião junto com os botões)
- Test: `Tests/Retro98ShellCoreTests/WorkAreaGuardTests.swift`

**Interfaces:**
```swift
// ShellCore. Coordenadas de Acessibilidade: origem no canto superior esquerdo da tela principal, y para baixo.
public enum WorkAreaGuard {
    public static let bottomTolerance: CGFloat = 6
    /// Novo tamanho quando a janela encosta na base da tela (ou passa dela) e invade a barra; nil para não mexer.
    public static func adjustedSize(window: CGRect, screen: CGRect, taskbarHeight: CGFloat) -> CGSize?
}
```
- Regra:
  - `workBottom = screen.maxY - taskbarHeight`.
  - Retorna `CGSize(width: window.width, height: workBottom - window.minY)` só quando `window.intersects(screen)`, `window.maxY >= screen.maxY - bottomTolerance`, `window.maxY > workBottom + 1` e `window.minY < workBottom`.
- **`WorkAreaGuardian`** (app):
  - Ao receber janela criada, movida ou redimensionada (via `WindowChangeMonitor`), lê `kAXPositionAttribute` e `kAXSizeAttribute` e aplica `adjustedSize` com a tela principal em coordenadas AX (`CGRect(origin: .zero, size: NSScreen.screens[0].frame.size)`) e a altura atual da barra.
  - Se houver ajuste, grava `kAXSizeAttribute`. Se o app recusar, não tenta de novo até a próxima mudança da janela.
  - Também passa por todas as janelas quando a permissão é concedida e quando a barra muda de altura.

- [ ] **Step 1: Testes que falham**

```swift
private let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)

@Test func maximizedWindowStopsAtTheTaskbar() {
    #expect(WorkAreaGuard.adjustedSize(window: CGRect(x: 0, y: 34, width: 1470, height: 922), screen: screen, taskbarHeight: 28)
            == CGSize(width: 1470, height: 894))
}
@Test func windowsPastTheBottomAreClampedToo() {
    #expect(WorkAreaGuard.adjustedSize(window: CGRect(x: 100, y: 500, width: 600, height: 500), screen: screen, taskbarHeight: 28)
            == CGSize(width: 600, height: 428))
}
@Test func leavesWindowsAwayFromTheBottomAlone() {
    #expect(WorkAreaGuard.adjustedSize(window: CGRect(x: 100, y: 100, width: 600, height: 400), screen: screen, taskbarHeight: 28) == nil)
}
@Test func doesNotTouchWindowsAlreadyAboveTheTaskbar() {
    #expect(WorkAreaGuard.adjustedSize(window: CGRect(x: 0, y: 34, width: 1470, height: 894), screen: screen, taskbarHeight: 28) == nil)
}
@Test func ignoresOtherScreens() {
    #expect(WorkAreaGuard.adjustedSize(window: CGRect(x: 1470, y: 0, width: 800, height: 956), screen: screen, taskbarHeight: 28) == nil)
}
@Test func windowEntirelyBehindTheTaskbarIsLeftAlone() {
    #expect(WorkAreaGuard.adjustedSize(window: CGRect(x: 0, y: 940, width: 300, height: 16), screen: screen, taskbarHeight: 28) == nil)
}
```
  - Em `TweakCatalogTests.shellCatalogPinsDockValues`, atualizar as mudanças esperadas e o título para os valores de Global Constraints.

- [ ] **Step 2: Rodar `swift test --filter "WorkAreaGuardTests|TweakCatalogTests"`.** Esperado: FAIL.
- [ ] **Step 3: Implementar o catálogo, a regra e o guardião.**
- [ ] **Step 4: Rodar `swift test`** e o build release, sem warnings. Esperado: PASS.
- [ ] **Step 5: Commit** `feat: hide the Dock completely and keep maximized windows above the taskbar`

---

### Task 8: Instalador, desinstalador, README e CI

**Files:**
- Modify: `install.sh`, `uninstall.sh`, `scripts/build-shell-app.sh` (versão `CFBundleVersion` = `3`, `CFBundleShortVersionString` = `0.3.0`), `Tests/scripts/test_install.sh`, `Tests/scripts/test_uninstall.sh`, `README.md`, `README.pt-BR.md`, `.github/workflows/ci.yml`

**Interfaces:**
- **`install.sh`:** na peça `shell`, depois de carregar o LaunchAgent, mostra:
  - pt-BR: "Na primeira vez, o Retro98 Shell vai pedir a permissão de Acessibilidade para mostrar as janelas na barra. Ative-o em Ajustes do Sistema › Privacidade e Segurança › Acessibilidade."
  - en: equivalente.
- **`uninstall.sh`:** depois de restaurar com sucesso, chama `remove_signing_identity` e avisa:
  - pt-BR: "Se quiser, remova o Retro98 Shell da lista em Ajustes do Sistema › Privacidade e Segurança › Acessibilidade."
  - en: equivalente.
- **Testes de script:** `test_uninstall.sh` usa `RETRO98_SIGNING_KEYCHAIN` temporário e confere que o chaveiro some. `test_install.sh` usa `RETRO98_SIGNING=adhoc`.

- [ ] **Step 1: Testes que falham**
  - `test_uninstall.sh`, caso `signing-removed`: o chaveiro falso criado pelo próprio teste com `security create-keychain` no diretório temporário (restaurando a lista de chaveiros depois) não existe mais depois de um uninstall com restore OK, e a lista de chaveiros não mudou.
  - `test_install.sh`, caso `accessibility-hint`: a saída da instalação com a peça shell contém "Acessibilidade" (ou "Accessibility").
- [ ] **Step 2: Rodar os dois testes.** Esperado: FAIL nos casos novos.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: README** (pt-BR e en):
  - Fase 2B disponível.
  - Seção "Botões de janela": clique, minimizar, menu do botão direito, só o Space atual.
  - Dock escondido enquanto a barra estiver ligada, janelas maximizadas param na barra (com Acessibilidade) e ⌘Tab continua funcionando.
  - Permissão de Acessibilidade, uma vez só, graças ao certificado local.
  - O que o instalador cria (chaveiro `retro98-signing`) e o que o desinstalador remove.
- [ ] **Step 5: Rodar `swift test && bash Tests/scripts/test_install.sh && bash Tests/scripts/test_uninstall.sh && bash Tests/scripts/test_signing.sh`.** Esperado: tudo PASS.
- [ ] **Step 6: Commit** `feat: install the signed Shell, guide Accessibility, clean up signing on uninstall`

---

### Aceitação pelo autor (manual, no Mac dele, depois da Task 8)

O autor roda `./install.sh --yes` (ou autoriza explicitamente) e confere:
- [ ] Na primeira abertura aparece o aviso de Acessibilidade uma vez e os Ajustes abrem no lugar certo. Depois de ativar o Retro98 Shell, os botões aparecem sem reiniciar.
- [ ] Um botão por janela do Space atual, com ícone e título; títulos longos terminam em "…"; a janela ativa aparece pressionada.
- [ ] Clicar ativa a janela; clicar de novo minimiza; clicar na minimizada restaura.
- [ ] O botão direito mostra Restaurar, Minimizar e Fechar, e Fechar fecha a janela.
- [ ] Abrir e fechar janelas, renomear (abas do navegador) e trocar de Space atualizam a barra em menos de 1 s.
- [ ] Rodar `./install.sh --yes` de novo **não** pede a permissão outra vez.
- [ ] O menu Iniciar fecha ao clicar na bandeja ou usar ⌘Tab. O relógio está certo depois de fechar e abrir a tampa.
- [ ] O Dock não aparece mais, nem mostra nomes ao passar o mouse na barra ou na borda inferior. A barra está com 28 pt.
- [ ] Maximizar, "Preencher" e lado a lado param no topo da barra; janelas soltas no meio da tela não são mexidas.
- [ ] `./uninstall.sh` remove a barra, o Dock volta como era e o chaveiro `retro98-signing` some.
