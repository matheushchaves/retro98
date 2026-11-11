# Retro98 Fase 1 — Ajustes base: plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ferramenta `retro98-settings` que aplica os ajustes nativos da Fase 1 com backup exato e restaura o estado original, mais `install.sh`/`uninstall.sh` e README.

**Architecture:** Pacote Swift com a biblioteca `Retro98Settings`, que reúne o catálogo de ajustes, o backup e o motor apply/restore/status. O Painel de Controle da Fase 5 vai reutilizar essa biblioteca. Por cima dela, um executável CLI fino. Todo acesso ao sistema (preferências, arquivos, papel de parede, reinício de processos) passa por protocolos com implementações em memória para os testes.

**Tech Stack:** Swift 6 (tools 6.0, modo de linguagem 6), Swift Testing, CoreFoundation `CFPreferences*`, AppKit (`NSWorkspace`, `NSScreen`), bash.

**Spec:** `docs/superpowers/specs/2026-11-10-retro-desktop-design.md` (seções 2, 4, 6 "Fase 1", 7 e 8).

## Global Constraints

- `platforms: [.macOS(.v14)]`, `swift-tools-version: 6.0`. **Sem dependências de terceiros** nesta fase.
- Prefixo de identificadores: `io.github.matheushchaves.retro98`. Domínio de testes: `io.github.matheushchaves.retro98.tests`.
- Pasta de suporte: `~/Library/Application Support/Retro98/`. Backup em `backup.plist` (XML), binário em `bin/retro98-settings`. A variável de ambiente `RETRO98_SUPPORT_DIR` substitui a pasta (testes e scripts).
- **Nenhuma preferência ou arquivo é alterado antes de o valor original estar salvo no backup em disco.**
- **O backup só é apagado quando todas as restaurações deram certo.**
- O backup guarda o **primeiro** valor original de cada chave. Aplicar de novo nunca sobrescreve um original.
- Preferências são lidas e escritas no usuário atual com `kCFPreferencesAnyHost` (igual ao `defaults`). O domínio global é `kCFPreferencesAnyApplication`.
- Textos visíveis em pt-BR e en, escolhidos por `Locale.preferredLanguages.first` (prefixo `pt` → pt-BR; qualquer outro → en).
- Nada de material ou nome da Microsoft. "Windows" só aparece no README, na frase "Inspired by Windows 98 / Inspirado no Windows 98", com aviso de não afiliação.
- Sem desligar proteções do sistema. Só se escreve em preferências do usuário, na pasta de suporte e no `Index.plist` do papel de parede (apenas para restaurar).
- Commits no formato `<type>: <description>` (feat, fix, test, docs, chore, ci), sem linha de atribuição.

## Review Focus

1. **Instalar duas vezes**: rodar `apply` de novo não pode trocar os originais do backup pelos valores retrô. O `restore` tem que voltar ao estado de antes da primeira instalação. → Task 5, `applyingTwiceKeepsFirstOriginals`.
2. **Desinstalar quando a restauração falha** ou o backup está corrompido: a pasta de suporte e o backup ficam, a saída é diferente de zero e a mensagem diz como tentar de novo. → Task 6, `failedRestoreKeepsBackupEntries`; Task 9, `test_uninstall.sh` (casos 2 e 3).
3. **Valor original com tipo diferente do alvo**: por exemplo, `.int(1)` onde escrevemos `.bool(false)`, ou inteiros dentro dos dicionários do ponteiro. A restauração devolve o tipo original. → Task 6, `restorePreservesOriginalValueTypes`.
4. **Backup ausente, corrompido ou de versão mais nova**: `restore` não muda nada e explica. → Task 4 (testes de carga); Task 6, `corruptedBackupMakesRestoreThrowAndChangeNothing`.
5. **macOS recusa escrita** (`com.apple.universalaccess`): só aquele ajuste falha e é desfeito, os outros são aplicados, aparece a orientação e a saída é 2. → Task 5, `deniedWriteRollsBackOnlyThatTweak`; Task 8, `exitStatusIsTwoWhenAnyTweakFailed`.

---

## Estrutura de arquivos

```
Package.swift
Sources/Retro98Settings/
  Preferences/PreferenceValue.swift     PreferenceValue + conversão de/para property list do CF
  Preferences/PreferenceKey.swift       PreferenceDomain, PreferenceKey, PreferenceChange
  Preferences/PreferenceStore.swift     protocolo PreferenceStore, PreferenceError, InMemoryPreferenceStore
  Preferences/CFPreferenceStore.swift   implementação real (CFPreferences + verificação por releitura)
  Tweaks/Tweak.swift                    TweakID, RefreshEffect, SpecialAction, LocalizedText, Tweak
  Tweaks/TweakCatalog.swift             catálogo da Fase 1 com os valores da spec
  Backup/Backup.swift                   Backup, PreferenceBackupEntry, FileBackupEntry, BackupError
  Backup/FileStore.swift                protocolo FileStore, LocalFileStore, InMemoryFileStore
  Backup/BackupFile.swift               carregar/salvar backup.plist
  Engine/SystemServices.swift           protocolos WallpaperSetter, SystemRefresher
  Engine/TweakEngine.swift              apply / restore / status, EngineReport
  System/Retro98Paths.swift             caminhos padrão
  System/SolidColorImage.swift          PNG de cor sólida
  System/MacWallpaperSetter.swift       NSWorkspace.setDesktopImageURL em todas as telas
  System/MacSystemRefresher.swift       killall, notificações distribuídas, osascript
  CLI/SettingsCommand.swift             parser de argumentos + exitStatus
Sources/retro98-settings/
  main.swift                            ligação das peças e saída no terminal
  Messages.swift                        textos pt-BR/en da CLI
Tests/Retro98SettingsTests/             um arquivo por tarefa (nomes nas tarefas) + Fakes.swift
Tests/scripts/test_uninstall.sh
install.sh, uninstall.sh, README.md, README.pt-BR.md, LICENSE, .gitignore, .github/workflows/ci.yml
```

---

### Task 1: Pacote, repositório e `PreferenceValue`

**Files:**
- Create: `Package.swift`, `.gitignore` (`.build/`, `.swiftpm/`, `*.xcodeproj`, `.DS_Store`), `LICENSE` (MIT, `Copyright (c) 2026 matheushchaves`)
- Create: `Sources/Retro98Settings/Preferences/PreferenceValue.swift`
- Create: `Sources/retro98-settings/main.swift` (placeholder: `print("retro98-settings")`)
- Test: `Tests/Retro98SettingsTests/PreferenceValueTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public enum PreferenceValue: Codable, Equatable, Sendable {
      case bool(Bool), int(Int), double(Double), string(String)
      case data(Data), date(Date)
      case array([PreferenceValue]), dictionary([String: PreferenceValue])
      public init?(propertyList: Any)      // nil para tipos não suportados
      public var propertyList: Any { get } // objeto compatível com CFPropertyList
  }
  ```
- `Package.swift`: produto biblioteca `Retro98Settings`, executável `retro98-settings` (depende da biblioteca), alvo de teste `Retro98SettingsTests`.

- [ ] **Step 1: `git init`, criar `Package.swift`, `.gitignore`, `LICENSE`, placeholder do `main.swift`**
- [ ] **Step 2: Escrever os testes que falham**

```swift
@Test func roundTripsScalarsKeepingTypes() {
    for value: PreferenceValue in [.bool(true), .int(1), .int(-1), .double(1.0), .string("Always"),
                                   .data(Data([1, 2])), .date(Date(timeIntervalSince1970: 0))] {
        #expect(PreferenceValue(propertyList: value.propertyList) == value)
    }
}
@Test func distinguishesBoolIntAndDouble() {
    #expect(PreferenceValue(propertyList: kCFBooleanTrue as Any) == .bool(true))
    #expect(PreferenceValue(propertyList: NSNumber(value: 1)) == .int(1))
    #expect(PreferenceValue(propertyList: NSNumber(value: 0.5)) == .double(0.5))
    #expect(PreferenceValue(propertyList: PreferenceValue.bool(true).propertyList) != .int(1))
}
@Test func roundTripsNestedCollections() {
    let value = PreferenceValue.dictionary(["alpha": .double(1), "red": .int(0), "list": .array([.string("a")])])
    #expect(PreferenceValue(propertyList: value.propertyList) == value)
}
@Test func rejectsUnsupportedObjects() {
    #expect(PreferenceValue(propertyList: NSObject()) == nil)
}
```

- [ ] **Step 3: Rodar `swift test --filter PreferenceValueTests`.** Esperado: FAIL (tipo não definido).
- [ ] **Step 4: Implementar `PreferenceValue`.** Bool é detectado com `CFGetTypeID(obj) == CFBooleanGetTypeID()` **antes** de NSNumber; int ou double com `CFNumberIsFloatType`.
- [ ] **Step 5: Rodar `swift test --filter PreferenceValueTests`.** Esperado: PASS. Rodar também `swift build`. Esperado: sucesso.
- [ ] **Step 6: Commit** `feat: add Swift package and PreferenceValue`

---

### Task 2: Chaves e lojas de preferências

**Files:**
- Create: `Sources/Retro98Settings/Preferences/PreferenceKey.swift`, `PreferenceStore.swift`, `CFPreferenceStore.swift`
- Test: `Tests/Retro98SettingsTests/PreferenceStoreTests.swift`

**Interfaces:**
- Consumes: `PreferenceValue` (Task 1)
- Produces:
  ```swift
  public enum PreferenceDomain: Codable, Hashable, Sendable { case global; case app(String) }
  public struct PreferenceKey: Codable, Hashable, Sendable { public let domain: PreferenceDomain; public let name: String }
  public struct PreferenceChange: Equatable, Sendable { public let key: PreferenceKey; public let target: PreferenceValue? } // nil = remover a chave
  public enum PreferenceError: Error, Equatable { case writeDenied(PreferenceKey) }
  public protocol PreferenceStore {
      func value(for key: PreferenceKey) -> PreferenceValue?
      func write(_ value: PreferenceValue?, for key: PreferenceKey) throws   // nil = remover
  }
  public final class InMemoryPreferenceStore: PreferenceStore {
      public init(_ initial: [PreferenceKey: PreferenceValue] = [:], deniedKeys: Set<PreferenceKey> = [])
      public var snapshot: [PreferenceKey: PreferenceValue] { get }
      public var deniedKeys: Set<PreferenceKey>   // ajustável pelos testes
  }
  public struct CFPreferenceStore: PreferenceStore { public init() }
  ```

- [ ] **Step 1: Escrever os testes que falham**

```swift
let testDomain = PreferenceDomain.app("io.github.matheushchaves.retro98.tests")

@Test func cfStoreWritesReadsAndRemoves() throws {
    let store = CFPreferenceStore()
    let key = PreferenceKey(domain: testDomain, name: "probe-\(UUID().uuidString)")
    try store.write(.dictionary(["alpha": .double(1), "red": .int(0)]), for: key)
    #expect(store.value(for: key) == .dictionary(["alpha": .double(1), "red": .int(0)]))
    try store.write(nil, for: key)
    #expect(store.value(for: key) == nil)
}
@Test func inMemoryStoreDeniesConfiguredKeysWithoutChangingThem() {
    let key = PreferenceKey(domain: .global, name: "X")
    let store = InMemoryPreferenceStore([key: .int(1)], deniedKeys: [key])
    #expect(throws: PreferenceError.writeDenied(key)) { try store.write(.int(2), for: key) }
    #expect(store.value(for: key) == .int(1))
}
```

- [ ] **Step 2: Rodar `swift test --filter PreferenceStoreTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.** `CFPreferenceStore.write` faz: `CFPreferencesSetValue` → `CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)` → relê com `CFPreferencesCopyValue`. Se a releitura for diferente do valor escrito (ou não for nil, quando a escrita foi uma remoção), lança `.writeDenied(key)`.
- [ ] **Step 4: Rodar `swift test --filter PreferenceStoreTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add preference keys and stores`

---

### Task 3: Modelo de ajuste e catálogo da Fase 1

**Files:**
- Create: `Sources/Retro98Settings/Tweaks/Tweak.swift`, `TweakCatalog.swift`
- Test: `Tests/Retro98SettingsTests/TweakCatalogTests.swift`

**Interfaces:**
- Consumes: `PreferenceKey`, `PreferenceChange`, `PreferenceValue`
- Produces:
  ```swift
  public enum TweakID: String, Codable, CaseIterable, Sendable {
      case wallpaper, lightAppearance, colors, contrast, pointer, scrollBars, windowAnimations, titleBarDoubleClick, finderExplorer
  }
  public enum RefreshEffect: Hashable, Sendable { case restartFinder, notifyColorChange, notifyScrollBarChange, syncAppearance, restartWallpaperAgent }
  public enum SpecialAction: Equatable, Sendable { case solidWallpaper(hex: String) }
  public struct LocalizedText: Equatable, Sendable {
      public let en: String; public let ptBR: String
      public func resolve(for languages: [String]) -> String   // primeiro idioma com prefixo "pt" → ptBR, senão en
  }
  public struct Tweak: Equatable, Sendable {
      public let id: TweakID; public let title: LocalizedText
      public let changes: [PreferenceChange]; public let special: SpecialAction?; public let effects: Set<RefreshEffect>
  }
  public enum TweakCatalog { public static func phase1(osMajorVersion: Int, homeDirectory: URL) -> [Tweak] }
  ```

**Valores (copiar exatamente; `UA` = `.app("com.apple.universalaccess")`, `F` = `.app("com.apple.finder")`):**

| id | título pt-BR / en | mudanças | special / effects |
|---|---|---|---|
| wallpaper | Fundo verde-água sólido / Solid teal desktop | — | `.solidWallpaper(hex: "#008080")` |
| lightAppearance | Modo claro / Light mode | global `AppleInterfaceStyle` → remover; global `AppleInterfaceStyleSwitchesAutomatically` → `.bool(false)` | `[.syncAppearance]` |
| colors | Destaque grafite e seleção azul-marinho / Graphite accent and navy selection | global `AppleAccentColor` → `.int(-1)`; `AppleAquaColorVariant` → `.int(6)`; `AppleHighlightColor` → `.string("0.000000 0.000000 0.501961 Other")` | `[.notifyColorChange]` |
| contrast | Menos transparência e mais contraste / Reduced transparency and increased contrast | UA `reduceTransparency` → `.bool(true)`; UA `increaseContrast` → `.bool(true)` | — |
| pointer | Ponteiro branco com contorno preto / White pointer with black outline | UA `cursorIsCustomized` → `.bool(true)`; UA `cursorFill` → dict `alpha/red/green/blue` = `.double(1)`; UA `cursorOutline` → dict `alpha` `.double(1)`, `red/green/blue` `.double(0)` | — |
| scrollBars | Barras de rolagem sempre visíveis / Always-visible scroll bars | global `AppleShowScrollBars` → `.string("Always")` | `[.notifyScrollBarChange]` |
| windowAnimations | Sem animações de janela / No window animations | global `NSAutomaticWindowAnimationsEnabled` → `.bool(false)` | — |
| titleBarDoubleClick | Duplo clique na barra de título maximiza / Double-click title bar to maximize | global `AppleActionOnDoubleClick` → `.string("Fill")` se `osMajorVersion >= 15`, senão `.string("Maximize")` | — |
| finderExplorer | Finder no jeito do Explorer / Explorer-like Finder | global `AppleShowAllExtensions` → `.bool(true)`; F `ShowStatusBar` → `.bool(true)`; F `ShowPathbar` → `.bool(true)`; F `_FXSortFoldersFirst` → `.bool(true)`; F `FXPreferredViewStyle` → `.string("Nlsv")`; F `NewWindowTarget` → `.string("PfHm")`; F `NewWindowTargetPath` → `.string(homeDirectory.absoluteString)` com `/` no fim | `[.restartFinder]` |

A ordem do catálogo é a de `TweakID.allCases`.

- [ ] **Step 1: Escrever os testes que falham.** Helper local `target(_ id: TweakID, _ domain: PreferenceDomain, _ name: String) -> PreferenceChange?`.

```swift
let catalog = TweakCatalog.phase1(osMajorVersion: 27, homeDirectory: URL(filePath: "/Users/test"))
@Test func listsEveryTweakOnceInOrder() { #expect(catalog.map(\.id) == TweakID.allCases) }
@Test func pinsColorsAndAppearance() {
    #expect(target(.colors, .global, "AppleHighlightColor")?.target == .string("0.000000 0.000000 0.501961 Other"))
    #expect(target(.colors, .global, "AppleAccentColor")?.target == .int(-1))
    #expect(target(.colors, .global, "AppleAquaColorVariant")?.target == .int(6))
    #expect(target(.lightAppearance, .global, "AppleInterfaceStyle") != nil)
    #expect(target(.lightAppearance, .global, "AppleInterfaceStyle")?.target == nil)
}
@Test func pinsWallpaperPointerAndFinder() {
    #expect(catalog.first { $0.id == .wallpaper }?.special == .solidWallpaper(hex: "#008080"))
    #expect(target(.pointer, .app("com.apple.universalaccess"), "cursorOutline")?.target
            == .dictionary(["alpha": .double(1), "red": .double(0), "green": .double(0), "blue": .double(0)]))
    #expect(target(.finderExplorer, .app("com.apple.finder"), "NewWindowTargetPath")?.target == .string("file:///Users/test/"))
    #expect(catalog.first { $0.id == .finderExplorer }?.effects == [.restartFinder])
}
@Test func doubleClickValueDependsOnMacOSVersion() {
    let sonoma = TweakCatalog.phase1(osMajorVersion: 14, homeDirectory: URL(filePath: "/Users/test"))
    #expect(sonoma.first { $0.id == .titleBarDoubleClick }?.changes.first?.target == .string("Maximize"))
    #expect(target(.titleBarDoubleClick, .global, "AppleActionOnDoubleClick")?.target == .string("Fill"))
}
@Test func resolvesLanguage() {
    let text = LocalizedText(en: "Light mode", ptBR: "Modo claro")
    #expect(text.resolve(for: ["pt-BR"]) == "Modo claro")
    #expect(text.resolve(for: ["fr-FR", "pt-BR"]) == "Light mode")
    #expect(text.resolve(for: []) == "Light mode")
}
```

- [ ] **Step 2: Rodar `swift test --filter TweakCatalogTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar `Tweak.swift` e `TweakCatalog.swift` com a tabela acima.**
- [ ] **Step 4: Rodar `swift test --filter TweakCatalogTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add Phase 1 tweak catalog`

---

### Task 4: Backup em disco

**Files:**
- Create: `Sources/Retro98Settings/Backup/Backup.swift`, `FileStore.swift`, `BackupFile.swift`
- Test: `Tests/Retro98SettingsTests/BackupTests.swift`

**Interfaces:**
- Consumes: `TweakID`, `PreferenceKey`, `PreferenceValue`
- Produces:
  ```swift
  public struct PreferenceBackupEntry: Codable, Equatable, Sendable { public let tweak: TweakID; public let key: PreferenceKey; public let original: PreferenceValue? } // nil = chave não existia
  public struct FileBackupEntry: Codable, Equatable, Sendable { public let tweak: TweakID; public let path: String; public let original: Data? }      // nil = arquivo não existia
  public struct Backup: Codable, Equatable, Sendable {
      public static let currentVersion = 1
      public static let empty: Backup
      public let version: Int; public let preferences: [PreferenceBackupEntry]; public let files: [FileBackupEntry]
      public func recording(_ entry: PreferenceBackupEntry) -> Backup   // ignora se a chave já existe (mantém o original mais antigo)
      public func recording(_ entry: FileBackupEntry) -> Backup         // ignora se o path já existe
      public func removing(tweaks: Set<TweakID>) -> Backup
      public var tweakIDs: Set<TweakID> { get }
      public var isEmpty: Bool { get }
  }
  public enum BackupError: Error, Equatable { case corrupted(String), unsupportedVersion(Int) }
  public protocol FileStore {
      func read(_ url: URL) throws -> Data?          // nil = não existe
      func write(_ data: Data?, to url: URL) throws  // nil = apagar; cria pastas; escrita atômica
  }
  public struct LocalFileStore: FileStore { public init() }
  public final class InMemoryFileStore: FileStore { public init(_ files: [URL: Data] = [:]); public var snapshot: [URL: Data] { get } }
  public struct BackupFile {
      public init(url: URL, files: FileStore)
      public func load() throws -> Backup   // arquivo ausente → .empty; ilegível → .corrupted; version > currentVersion → .unsupportedVersion
      public func save(_ backup: Backup) throws  // XML plist; backup vazio → apaga o arquivo
  }
  ```

- [ ] **Step 1: Escrever os testes que falham** (todos com `InMemoryFileStore`, exceto o último):

```swift
@Test func keepsEarliestOriginal() {
    let key = PreferenceKey(domain: .global, name: "AppleInterfaceStyle")
    let backup = Backup.empty
        .recording(PreferenceBackupEntry(tweak: .lightAppearance, key: key, original: .string("Dark")))
        .recording(PreferenceBackupEntry(tweak: .lightAppearance, key: key, original: nil))
    #expect(backup.preferences.map(\.original) == [.string("Dark")])
}
@Test func missingFileLoadsEmpty() throws { #expect(try backupFile().load() == .empty) }
@Test func savesAndLoadsRoundTrip() throws { /* entradas com original nil, dictionary e FileBackupEntry com Data → load() == salvo */ }
@Test func savingEmptyBackupDeletesFile() throws { /* save(non-empty) e depois save(.empty) → files.snapshot[url] == nil */ }
@Test func corruptedFileThrowsAndIsLeftUntouched() throws {
    let garbage = Data("not a plist".utf8)
    let files = InMemoryFileStore([url: garbage])
    #expect(throws: BackupError.self) { try BackupFile(url: url, files: files).load() }
    #expect(files.snapshot[url] == garbage)
}
@Test func newerVersionThrowsUnsupportedVersion() throws { /* plist com version 2 → .unsupportedVersion(2) */ }
@Test func localFileStoreWritesAtomicallyAndDeletes() throws { /* pasta temporária: write cria pastas intermediárias; write(nil) apaga; read de arquivo ausente == nil */ }
```

- [ ] **Step 2: Rodar `swift test --filter BackupTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.** Usar `PropertyListEncoder` com `outputFormat = .xml`. Erro de decodificação vira `.corrupted(String(describing: error))`.
- [ ] **Step 4: Rodar `swift test --filter BackupTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add backup model and persistence`

---

### Task 5: Motor — aplicar e status

**Files:**
- Create: `Sources/Retro98Settings/Engine/SystemServices.swift`, `Sources/Retro98Settings/Engine/TweakEngine.swift`
- Create: `Tests/Retro98SettingsTests/Fakes.swift`
- Test: `Tests/Retro98SettingsTests/TweakEngineApplyTests.swift`

**Interfaces:**
- Consumes: Tasks 2–4
- Produces:
  ```swift
  public protocol WallpaperSetter { func setSolidColor(hex: String) throws }
  public protocol SystemRefresher {
      func switchAppearance(toDark dark: Bool) -> Bool   // chamado ANTES das escritas; false = não conseguiu ao vivo
      func perform(_ effects: Set<RefreshEffect>)        // chamado uma vez, DEPOIS das escritas
  }
  public enum FailureReason: Equatable { case writeDenied([PreferenceKey]), wallpaperFailed(String), fileWriteFailed(String) }
  public struct TweakFailure: Equatable { public let id: TweakID; public let reason: FailureReason }
  public enum EngineWarning: Equatable { case appearanceNeedsLogout }
  public struct EngineReport: Equatable { public let succeeded: [TweakID]; public let failed: [TweakFailure]; public let warnings: [EngineWarning] }
  public enum TweakState: Equatable { case applied, partial, notApplied }
  public struct TweakStatus: Equatable { public let id: TweakID; public let state: TweakState }
  public struct TweakEngine {
      public init(catalog: [Tweak], store: PreferenceStore, files: FileStore, backupFile: BackupFile,
                  wallpaperIndex: URL, wallpaper: WallpaperSetter, refresher: SystemRefresher)
      public func apply(_ ids: Set<TweakID>? = nil) throws -> EngineReport   // nil = todos; lança só erros de backup
      public func status() throws -> [TweakStatus]
  }
  ```
- `Fakes.swift`:
  - `FakeWallpaperSetter`: `hexes: [String]`, `error: Error?` (lança esse erro, se definido).
  - `RecordingRefresher`: `calls: [String]` com entradas `"switchAppearance(true|false)"` e `"perform(<efeitos ordenados>)"`, e `switchAppearanceResult: Bool` (padrão `true`).
  - `ObservingPreferenceStore(wrapping:onWrite:)`: envolve outra loja e chama `onWrite(key)` antes de cada escrita. Para registrar a ordem em relação ao refresher, as duas fakes podem compartilhar um log.

**Algoritmo de `apply`, por ajuste, na ordem do catálogo:**
1. Carregar o backup.
2. Para cada mudança cuja chave **ainda não** está no backup, registrar o valor atual. No ajuste `wallpaper`, registrar o conteúdo atual de `wallpaperIndex` (se o path ainda não estiver no backup).
3. **Salvar o backup.**
4. Escrever as mudanças.
5. Se uma escrita falhar, devolver as chaves já escritas desse ajuste ao valor que tinham antes desta execução, retirar do backup as entradas criadas nesta execução para esse ajuste e salvar. O ajuste entra em `failed`.
6. Em `special`, chamar `wallpaper.setSolidColor`. Se der erro, `.wallpaperFailed` e retirar a entrada de arquivo nova.

Antes do primeiro ajuste com `.syncAppearance`, chamar `refresher.switchAppearance(toDark:)` com `toDark` = alvo de `AppleInterfaceStyle == .string("Dark")`. Se a chamada retornar `false`, adicionar `.appearanceNeedsLogout`. No fim, `perform` recebe a união dos `effects` dos ajustes que deram certo.

**Status:** `applied` se todas as chaves estão no alvo; `partial` se só algumas; `notApplied` se nenhuma. O ajuste `wallpaper` é `applied` quando o backup tem entrada de arquivo para `.wallpaper`.

- [ ] **Step 1: Escrever os testes que falham.** O helper `makeEngine(store:files:catalog:)` usa `InMemoryFileStore` e as fakes. O catálogo real usa `osMajorVersion: 27` e `home /Users/test`. Os valores iniciais imitam este Mac: `AppleInterfaceStyle = "Dark"`, `AppleInterfaceStyleSwitchesAutomatically = .bool(true)`, `cursorFill` com `.double(0.994845449924469)`, `NewWindowTarget = "PfAF"`, `Index.plist` com `Data("aerials".utf8)`.

```swift
@Test func applyWritesEveryTargetAndRecordsOriginals() throws { /* apply() → status() todos .applied; backup tem AppleInterfaceStyle original .string("Dark") */ }
@Test func applyingTwiceKeepsFirstOriginals() throws {
    _ = try engine.apply(); _ = try engine.apply()
    let entry = try backupFile.load().preferences.first { $0.key.name == "AppleInterfaceStyle" }
    #expect(entry?.original == .string("Dark"))
}
@Test func backupIsOnDiskBeforeFirstWrite() throws {
    // ObservingPreferenceStore: a cada escrita, carrega o backup e exige uma entrada para aquela chave
}
@Test func deniedWriteRollsBackOnlyThatTweak() throws {
    // store nega UA "increaseContrast"; reduceTransparency original ausente
    let report = try engine.apply([.contrast, .scrollBars])
    #expect(report.succeeded == [.scrollBars])
    #expect(report.failed == [TweakFailure(id: .contrast, reason: .writeDenied([increaseContrastKey]))])
    #expect(store.value(for: reduceTransparencyKey) == nil)
    #expect(try backupFile.load().tweakIDs == [.scrollBars])
}
@Test func appearanceSwitchHappensBeforeWritesAndWarnsWhenItFails() throws {
    // refresher.switchAppearanceResult = false → calls.first == "switchAppearance(false)"; report.warnings == [.appearanceNeedsLogout]
}
@Test func effectsComeOnlyFromSucceededTweaks() throws { /* falha em finderExplorer → perform não recebe .restartFinder */ }
@Test func wallpaperBacksUpIndexAndSetsTeal() throws { /* setter.hexes == ["#008080"]; entrada de arquivo com Data("aerials".utf8) */ }
@Test func wallpaperFailureLeavesNoFileEntry() throws { /* o setter lança erro → failed .wallpaperFailed; backup sem entrada de arquivo */ }
@Test func statusReportsPartial() throws { /* uma das 3 chaves de colors no alvo → .partial */ }
```

- [ ] **Step 2: Rodar `swift test --filter TweakEngineApplyTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar `SystemServices.swift` e `TweakEngine.apply`/`status` seguindo o algoritmo.**
- [ ] **Step 4: Rodar `swift test --filter TweakEngineApplyTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add tweak engine apply and status`

---

### Task 6: Motor — restaurar

**Files:**
- Modify: `Sources/Retro98Settings/Engine/TweakEngine.swift`
- Test: `Tests/Retro98SettingsTests/TweakEngineRestoreTests.swift`

**Interfaces:**
- Produces: `public func restore(_ ids: Set<TweakID>? = nil) throws -> EngineReport` (nil = tudo o que está no backup).

**Algoritmo:**
1. Carregar o backup. Se estiver corrompido ou for de versão nova, lançar o erro **sem tocar em nada**.
2. Para cada ajuste selecionado que está no backup, na ordem do catálogo, escrever os originais (`nil` remove). Arquivos voltam com `files.write(original, to:)`.
3. Se alguma escrita falhar, o ajuste entra em `failed` e **as entradas dele ficam no backup**.
4. Os ajustes que deram certo saem do backup. Salvar (backup vazio apaga o arquivo).
5. Se `lightAppearance` for restaurado, chamar antes `switchAppearance(toDark: original == .string("Dark"))`.
6. `perform` recebe a união dos efeitos dos ajustes restaurados, mais `.restartWallpaperAgent` se `wallpaper` foi restaurado.

- [ ] **Step 1: Escrever os testes que falham**

```swift
@Test func applyThenRestoreReturnsExactOriginalState() throws {
    _ = try engine.apply(); _ = try engine.restore()
    #expect(store.snapshot == initialPreferences)
    #expect(files.snapshot[indexURL] == Data("aerials".utf8))
    #expect(files.snapshot[backupURL] == nil)
}
@Test func restorePreservesOriginalValueTypes() throws {
    // AppleInterfaceStyleSwitchesAutomatically inicial .int(1); cursorOutline inicial com "red": .int(0)
    #expect(store.value(for: autoSwitchKey) == .int(1))
    #expect(store.value(for: cursorOutlineKey) == initialCursorOutline)
}
@Test func restoreSubsetLeavesOthersApplied() throws { /* apply(); restore([.colors]) → colors original, scrollBars no alvo, backup.tweakIDs não contém .colors */ }
@Test func failedRestoreKeepsBackupEntries() throws {
    _ = try engine.apply(); store.deniedKeys = [increaseContrastKey]
    let report = try engine.restore()
    #expect(report.failed.map(\.id) == [.contrast])
    #expect(try backupFile.load().tweakIDs == [.contrast])
}
@Test func corruptedBackupMakesRestoreThrowAndChangeNothing() throws {
    // apply(); sobrescrever o backup com lixo; restore() lança BackupError; store.snapshot inalterado
}
@Test func restoreWithoutBackupIsANoOp() throws { /* report vazio, nenhuma chamada ao refresher */ }
@Test func restoringWallpaperRewritesIndexAndRestartsAgent() throws { /* perform recebe .restartWallpaperAgent */ }
@Test func restoringAppearanceSwitchesToOriginalDarkMode() throws { /* calls contém "switchAppearance(true)" antes de qualquer escrita */ }
```

- [ ] **Step 2: Rodar `swift test --filter TweakEngineRestoreTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar `restore`.**
- [ ] **Step 4: Rodar `swift test`** (a suíte inteira). Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add tweak engine restore`

---

### Task 7: Serviços reais do Mac

**Files:**
- Create: `Sources/Retro98Settings/System/Retro98Paths.swift`, `SolidColorImage.swift`, `MacWallpaperSetter.swift`, `MacSystemRefresher.swift`
- Test: `Tests/Retro98SettingsTests/MacServicesTests.swift`

**Interfaces:**
- Consumes: `WallpaperSetter`, `SystemRefresher`, `RefreshEffect`
- Produces:
  ```swift
  public struct Retro98Paths: Equatable {
      public let supportDirectory: URL; public let wallpaperIndex: URL
      public var backupFile: URL { get }                       // supportDirectory/backup.plist
      public func wallpaperImage(hex: String) -> URL           // supportDirectory/wallpaper-008080.png (sem "#", minúsculo)
      public static func standard(home: URL, environment: [String: String]) -> Retro98Paths
      // supportDirectory = RETRO98_SUPPORT_DIR ou home/Library/Application Support/Retro98
      // wallpaperIndex = home/Library/Application Support/com.apple.wallpaper/Store/Index.plist
  }
  public enum SolidColorImage {
      public static func pngData(hex: String, size: Int = 16) throws -> Data   // hex "#RRGGBB"; inválido → SolidColorImageError.invalidHex
  }
  public struct MacWallpaperSetter: WallpaperSetter { public init(paths: Retro98Paths, files: FileStore) }
  public protocol CommandRunner { func run(_ executable: String, _ arguments: [String]) -> Int32 }
  public struct ProcessCommandRunner: CommandRunner { public init() }
  public struct MacSystemRefresher: SystemRefresher {
      public init(runner: CommandRunner = ProcessCommandRunner(), post: @escaping (String) -> Void = { name in
          DistributedNotificationCenter.default().postNotificationName(.init(name), object: nil, userInfo: nil, deliverImmediately: true) })
  }
  ```
- Mapeamento de efeitos (valores exatos):
  - `.restartFinder` → `run("/usr/bin/killall", ["Finder"])`
  - `.restartWallpaperAgent` → `run("/usr/bin/killall", ["WallpaperAgent"])`
  - `.notifyColorChange` → post `"AppleColorPreferencesChangedNotification"` e `"AppleAquaColorVariantChanged"`
  - `.notifyScrollBarChange` → post `"AppleShowScrollBarsSettingChanged"`
  - `.syncAppearance` não faz nada em `perform`; o efeito é tratado em `switchAppearance`.
  - `switchAppearance(toDark:)` → `run("/usr/bin/osascript", ["-e", "tell application \"System Events\" to tell appearance preferences to set dark mode to \(dark)"]) == 0`
- `MacWallpaperSetter.setSolidColor` grava o PNG em `paths.wallpaperImage(hex:)` e, para cada `NSScreen.screens`, chama `NSWorkspace.shared.setDesktopImageURL(_:for:options:)` com `[.imageScaling: NSImageScaling.scaleAxesIndependently.rawValue, .allowClipping: true]`.

- [ ] **Step 1: Escrever os testes que falham**

```swift
@Test func solidColorPngHasExactPixels() throws {
    let data = try SolidColorImage.pngData(hex: "#008080")
    // decodificar com CGImageSource: 16×16, pixel (0,0) RGB = (0, 128, 128)
}
@Test func invalidHexThrows() { #expect(throws: SolidColorImageError.invalidHex("#GG0000")) { try SolidColorImage.pngData(hex: "#GG0000") } }
@Test func pathsHonorSupportDirOverride() {
    let paths = Retro98Paths.standard(home: URL(filePath: "/Users/t"), environment: ["RETRO98_SUPPORT_DIR": "/tmp/r98"])
    #expect(paths.backupFile.path == "/tmp/r98/backup.plist")
    #expect(paths.wallpaperImage(hex: "#008080").lastPathComponent == "wallpaper-008080.png")
    #expect(paths.wallpaperIndex.path == "/Users/t/Library/Application Support/com.apple.wallpaper/Store/Index.plist")
}
@Test func refresherMapsEffectsToCommandsAndNotifications() {
    // RecordingRunner + posted:[String] → perform([.restartFinder, .notifyColorChange])
    // runs == [["/usr/bin/killall","Finder"]]; posted contém as duas notificações
}
@Test func switchAppearanceReportsFailureFromOsascript() {
    // runner retorna 1 → switchAppearance(toDark: false) == false; argumentos com "set dark mode to false"
}
```

- [ ] **Step 2: Rodar `swift test --filter MacServicesTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test --filter MacServicesTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: add macOS wallpaper and refresh services`

---

### Task 8: CLI `retro98-settings`

**Files:**
- Create: `Sources/Retro98Settings/CLI/SettingsCommand.swift`
- Modify: `Sources/retro98-settings/main.swift`
- Create: `Sources/retro98-settings/Messages.swift`
- Test: `Tests/Retro98SettingsTests/SettingsCommandTests.swift`

**Interfaces:**
- Consumes: tudo das Tasks 3–7
- Produces:
  ```swift
  public enum SettingsCommand: Equatable { case status; case apply(only: Set<TweakID>?); case restore(only: Set<TweakID>?)
      public static func parse(_ arguments: [String]) throws -> SettingsCommand }   // sem argv[0]
  public enum SettingsCommandError: Error, Equatable { case usage, unknownTweak(String) }
  public func exitStatus(for report: EngineReport) -> Int32   // 0 se failed vazio, senão 2
  ```
- Códigos de saída do executável: `0` ok; `1` uso inválido; `2` algum ajuste falhou; `3` backup corrompido ou de versão nova.
- Saída:
  - `status`: uma linha por ajuste, `[x]` aplicado, `[~]` parcial, `[ ]` não aplicado, com o título no idioma do sistema.
  - `apply` e `restore`: uma linha por ajuste com `OK` ou `FALHOU`/`FAILED`.
- Orientações (textos exatos em `Messages.swift`):
  - **Escrita negada em `com.apple.universalaccess`**: pt-BR "O macOS não deixou mudar este ajuste. Abri Ajustes do Sistema › Acessibilidade › Tela: ative lá manualmente." / en "macOS did not allow this change. I opened System Settings › Accessibility › Display: turn it on there manually." Depois executa `/usr/bin/open "x-apple.systempreferences:com.apple.Accessibility-Settings.extension"`.
  - **`.appearanceNeedsLogout`**: pt-BR "Para o modo claro aparecer em tudo, saia e entre de novo na sua conta." / en "Log out and back in for light mode to show everywhere."
  - **Exit 3**: pt-BR "O backup em <caminho> está ilegível. Nada foi alterado. Não apague esse arquivo; abra uma issue no GitHub." / en "The backup at <path> is unreadable. Nothing was changed. Don't delete that file; please open a GitHub issue."
- Ligação em `main.swift`:
  - `Retro98Paths.standard(home: FileManager.default.homeDirectoryForCurrentUser, environment: ProcessInfo.processInfo.environment)`
  - `TweakCatalog.phase1(osMajorVersion: ProcessInfo.processInfo.operatingSystemVersion.majorVersion, homeDirectory: …)`
  - `CFPreferenceStore()`, `LocalFileStore()`, `MacWallpaperSetter`, `MacSystemRefresher()`

- [ ] **Step 1: Escrever os testes que falham**

```swift
@Test func parsesCommands() throws {
    #expect(try SettingsCommand.parse(["status"]) == .status)
    #expect(try SettingsCommand.parse(["apply"]) == .apply(only: nil))
    #expect(try SettingsCommand.parse(["apply", "--only", "colors,pointer"]) == .apply(only: [.colors, .pointer]))
    #expect(try SettingsCommand.parse(["restore", "--only", "wallpaper"]) == .restore(only: [.wallpaper]))
}
@Test func rejectsBadArguments() {
    #expect(throws: SettingsCommandError.usage) { try SettingsCommand.parse([]) }
    #expect(throws: SettingsCommandError.usage) { try SettingsCommand.parse(["apply", "--only"]) }
    #expect(throws: SettingsCommandError.unknownTweak("nope")) { try SettingsCommand.parse(["apply", "--only", "nope"]) }
}
@Test func exitStatusIsTwoWhenAnyTweakFailed() {
    #expect(exitStatus(for: EngineReport(succeeded: [.colors], failed: [], warnings: [])) == 0)
    #expect(exitStatus(for: EngineReport(succeeded: [], failed: [TweakFailure(id: .contrast, reason: .writeDenied([]))], warnings: [])) == 2)
}
```

- [ ] **Step 2: Rodar `swift test --filter SettingsCommandTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar `SettingsCommand`, `exitStatus`, `Messages.swift` e `main.swift`.**
- [ ] **Step 4: Rodar `swift test`.** Esperado: PASS.
- [ ] **Step 5: Verificar sem mudar nada no Mac:** `swift run retro98-settings status`. Esperado: 9 linhas, sem erro. Esse comando só lê. **Não rodar `apply` no Mac do autor nesta tarefa.**
- [ ] **Step 6: Commit** `feat: add retro98-settings CLI`

---

### Task 9: Scripts de instalação, README e CI

**Files:**
- Create: `install.sh`, `uninstall.sh` (executáveis, `set -euo pipefail`)
- Create: `Tests/scripts/test_uninstall.sh`
- Create: `README.md` (en), `README.pt-BR.md`
- Create: `.github/workflows/ci.yml`

**Interfaces:**
- Consumes: executável `retro98-settings` e seus códigos de saída (Task 8)
- Variáveis de ambiente respeitadas pelos scripts:
  - `RETRO98_SUPPORT_DIR`: pasta de suporte; padrão `~/Library/Application Support/Retro98`
  - `RETRO98_SETTINGS_BIN`: se definida, usa esse binário e **não compila**
- `install.sh [--yes]`:
  1. Exige macOS 14 ou mais novo (`sw_vers -productVersion`).
  2. Exige `xcode-select -p`. Se faltar, sai com a instrução `xcode-select --install`.
  3. Roda `swift build -c release --product retro98-settings` e copia o binário para `$RETRO98_SUPPORT_DIR/bin/`.
  4. Pergunta "Aplicar os ajustes base agora? [S/n]" (en: "Apply the base tweaks now? [Y/n]"). Com `--yes`, aplica direto.
  5. Roda `apply` e sai com o código dele.
- `uninstall.sh`:
  1. Roda `restore`.
  2. **Se sair 0**, apaga `$RETRO98_SUPPORT_DIR` e sai 0.
  3. **Se sair diferente de 0**, mantém a pasta, imprime "Backup mantido em <pasta>. Corrija o que foi indicado acima e rode ./uninstall.sh de novo." (en equivalente) e sai com o mesmo código.
- Idioma dos scripts: `defaults read -g AppleLanguages` começando com `pt` → pt-BR, senão en.

- [ ] **Step 1: Escrever o teste que falha** (`Tests/scripts/test_uninstall.sh`). Cria um binário falso que sai com o código de `$STUB_EXIT` e roda `uninstall.sh` com `RETRO98_SETTINGS_BIN` e `RETRO98_SUPPORT_DIR` apontando para uma pasta temporária com um `backup.plist`.
  - Caso 1: stub sai 0 → a pasta some, saída 0.
  - Caso 2: stub sai 2 → a pasta e o `backup.plist` continuam, saída 2.
  - Caso 3: stub sai 3 → a pasta continua, saída 3.
  - Imprime `PASS` ou `FAIL` por caso e sai diferente de 0 se algum falhar.
- [ ] **Step 2: Rodar `bash Tests/scripts/test_uninstall.sh`.** Esperado: FAIL (`uninstall.sh` não existe).
- [ ] **Step 3: Implementar `install.sh` e `uninstall.sh`.**
- [ ] **Step 4: Rodar `bash Tests/scripts/test_uninstall.sh`.** Esperado: 3× PASS.
- [ ] **Step 5: Escrever os READMEs.**
  - Seções: o que é o Retro98 (Fase 1 disponível; próximas fases listadas), requisitos (macOS 14+, Xcode Command Line Tools), instalar, desinstalar, tabela dos 9 ajustes (título e o que muda), permissões (pode aparecer o aviso "Terminal quer controlar System Events" para o modo claro), problemas conhecidos (alguns apps só mostram as mudanças depois de reabertos), aviso "Inspired by Windows 98. Not affiliated with or endorsed by Microsoft." e licença MIT.
  - Os dois arquivos linkam um para o outro.
- [ ] **Step 6: CI.** `.github/workflows/ci.yml` em `push` e `pull_request`, `runs-on: macos-14`: `swift build`, `swift test`, `bash Tests/scripts/test_uninstall.sh`.
- [ ] **Step 7: Rodar `swift test && bash Tests/scripts/test_uninstall.sh`.** Esperado: tudo PASS.
- [ ] **Step 8: Commit** `feat: add install and uninstall scripts, README and CI`

---

### Aceitação pelo autor (manual, no Mac dele, depois da Task 9)

O autor roda (ou autoriza explicitamente) `./install.sh` e confere:
- [ ] Fundo verde-água em todas as telas e em outro Space.
- [ ] Modo claro ligado; seleção de texto azul-marinho; controles em grafite.
- [ ] Bordas marcadas e sem transparência; ponteiro branco com contorno preto.
- [ ] Barras de rolagem sempre visíveis; duplo clique na barra de título maximiza.
- [ ] Finder com barra de status, barra de caminho, extensões, pastas primeiro e nova janela na pasta pessoal.
- [ ] `./uninstall.sh` → papel de parede aéreo original, modo escuro automático, ponteiro e Finder como antes, e a pasta `~/Library/Application Support/Retro98` removida.

Se algum item não aparecer, registrar qual e voltar para ajustar antes da Fase 2.
