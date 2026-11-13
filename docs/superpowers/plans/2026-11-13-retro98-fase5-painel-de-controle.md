# Retro98 Fase 5 — Painel de Controle — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o Retro98 Control Panel (Painel de Controle):
- janela de ícones 98 com os applets Vídeo, Aparência, Mouse, Sons e Componentes, mais atalhos para painéis do macOS;
- cada ajuste do Retro98 liga e desliga sozinho, e as escolhas sobrevivem a `./install.sh --yes`;
- sons retrô originais (sintetizados) para início da barra, erro, aviso e esvaziar a Lixeira; podem ser desligados e o de alerta pode virar o alerta do macOS;
- botão "Voltar ao macOS normal".

**Architecture:**
- **`Retro98Settings`** ganha:
  - `Choices` (`choices.plist` na pasta de suporte): papel de parede escolhido, ajustes base desligados no painel, sons ligados;
  - papel de parede de qualquer cor ou imagem;
  - dois ajustes opcionais (barra de menus escondida, som de alerta);
  - `Pieces` e `ShellAgent`, para ligar e desligar a barra de tarefas sem o instalador.
- **`Retro98UI`** ganha os sons (síntese e tocador), os ícones do painel e a caixa de seleção desabilitada.
- **`Retro98ControlPanel`** (app novo): janela de ícones, diálogos dos applets com OK/Cancelar/Aplicar e um `ControlPanelModel` testável, que fala com o sistema por um protocolo (`ControlPanelServices`).
- **Shell:** item "Painel de Controle" em Iniciar › Configurações e som de início. **Explorer:** som de esvaziar a Lixeira.
- **Scripts:** o painel é sempre instalado; a peça `shelloff` mantém a barra desligada nas reinstalações.

**Tech Stack:** Swift 6, AppKit, Swift Testing, bash. Sem dependências novas.

**Spec:** `docs/superpowers/specs/2026-11-10-retro-desktop-design.md`, seção "Fase 5 — Painel de Controle", mais a seção 4 (barra de menus visível por padrão; menu do app com Sobre, Ajustes e Sair) e a seção 5 (sons originais que podem ser desligados). As Fases 1 a 4 estão no `main`.

## Global Constraints

- **Herança:** tudo das fases anteriores continua valendo:
  - pixel 1x, Tahoma 13 e negrito 12, paleta clássica, só material original;
  - pt-BR e en, só APIs públicas, testes isolados.
- **Testes isolados, mais estes cuidados:**
  - Nenhum teste toca `~/Library/Sounds`, o LaunchAgent real, o `launchctl` de verdade nem o `choices.plist`/`pieces` reais.
  - Nenhum teste toca som: `RetroSound.isEnabled` vale `{ false }` por padrão e só os `main.swift` dos apps o ligam.
  - O `ControlPanelModel` é testado com `TweakEngine` real sobre `InMemoryPreferenceStore` e `InMemoryFileStore`, com fakes de papel de parede, refresher, Shell e abrir URL.
  - Os scripts seguem com stubs, mais `RETRO98_SOUNDS_DIR` numa pasta temporária.
- **Nomes [minha escolha]:**
  - App "Retro98 Control Panel", bundle id `io.github.matheushchaves.retro98.controlpanel`, ícone `controlpanel`.
  - Título da janela "Painel de Controle" / "Control Panel".
  - Versão dos apps: 0.8.0 (8).
- **Escolhas da pessoa [minha escolha]:** ficam em `<suporte>/choices.plist`, um dicionário:
  - `wallpaper`: `{kind: "color", hex: "#008080"}` (padrão) ou `{kind: "picture", path: …, name: …}`;
  - `turnedOff`: lista de nomes dos ajustes base desligados no painel (nomes desconhecidos são ignorados ao ler);
  - `soundsOn`: `true` por padrão.
  - Arquivo ausente, ilegível ou chave faltando = valor padrão daquela chave.
  - `retro98-settings apply` sem `--only` aplica os ajustes base menos `turnedOff`, com o papel de parede escolhido. Assim `./install.sh --yes` mantém o que a pessoa mudou no painel.
- **"Ligado" no painel [minha escolha]:** um ajuste está ligado quando o backup tem entrada dele (`TweakEngine.managed()`). Não se compara valores, porque o original da pessoa pode coincidir com o valor retrô.
- **Ajustes opcionais novos [minha escolha]:** grupo `.extra`, nunca aplicados sem pedido.
  - `hiddenMenuBar`: no domínio global, `_HIHideMenuBar = true` e `AppleMenuBarVisibleInFullscreen = false`. Neste Mac (lidos em 2026-11-13) os dois valem 0 hoje. Depois de gravar, posta a notificação distribuída `AppleInterfaceMenuBarHidingChangedNotification`. A barra continua aparecendo ao levar o ponteiro ao topo.
  - `alertSound`: no domínio global, `com.apple.sound.beep.sound` = caminho de `~/Library/Sounds/Retro98.aiff`, a pasta do macOS para sons de alerta da pessoa. O painel escreve o arquivo antes de aplicar e o apaga ao desligar; o desinstalador também.
  - As chaves não são documentadas pela Apple; a checagem manual confirma o efeito no macOS 27.
- **Sons [minha escolha]:** todos sintetizados pelo projeto, AIFF PCM 16 bits mono a 22.050 Hz; receitas no Task 4.
  - Tocam: o de início ao abrir a barra; erro e aviso nas caixas de mensagem com esses ícones; o de esvaziar depois de esvaziar a Lixeira.
  - "Tocar" no painel toca mesmo com os sons desligados.
- **Papel de parede [minha escolha]:**
  - "Papel de parede do macOS" = ajuste desligado (restaura o original).
  - "Cor sólida": 16 cores, nesta ordem: `008080 000080 008000 800000 800080 808000 808080 C0C0C0 000000 FFFFFF 0000FF 00FF00 FF0000 FF00FF FFFF00 00FFFF`.
  - "Imagem": escolhida com `NSOpenPanel`, porque os diálogos retrô de abrir chegam na Fase 6. É copiada para a pasta de suporte como `wallpaper-picture-<segundos>.<ext>`, as cópias antigas são apagadas, e ela é mostrada preenchendo a tela. Copiar mantém a imagem se o original sumir; o prefixo `wallpaper-` faz o desinstalador reconhecê-la.
- **Barra de tarefas pelo painel [minha escolha]:**
  - Desligar: `launchctl bootout`, encerra cópias soltas, apaga o plist do LaunchAgent e restaura `dockUnderTaskbar`. Em `pieces`, `shell` vira `shelloff`. Os apps ficam no disco.
  - Ligar: aplica `dockUnderTaskbar`, escreve o mesmo plist do `install.sh`, `launchctl enable` e `bootstrap`. `shelloff` vira `shell`.
  - Só fica habilitado quando o Shell está instalado.
  - O instalador entende `shelloff`: atualiza Shell e Explorer, deixa a barra desligada e o Dock normal.
- **"Voltar ao macOS normal" [minha escolha]:**
  - Pergunta antes.
  - Desliga a barra (`shelloff`), tira `fileviewer` de `pieces`, restaura tudo o que está no backup, apaga o som de alerta e marca todos os ajustes base como desligados.
  - Os apps continuam instalados; o aviso final indica `./uninstall.sh` para removê-los.
- **Permissões:**
  - O painel grava as mesmas preferências que o `retro98-settings`. Se o macOS negar `com.apple.universalaccess`, a mensagem pede Acesso Total ao Disco para o Retro98 Control Panel e oferece abrir o painel.
  - O app tem `NSAppleEventsUsageDescription`, porque a troca de modo claro usa os Eventos do Sistema.
- **Menus [spec §4]:**
  - Barra do macOS: menu do app (Sobre, Ajustes… ⌘, que mostra a janela, Ocultar, Ocultar Outros, Mostrar Tudo, Sair), Arquivo, Janela e Ajuda.
  - Menu retrô dentro da janela: Arquivo (Abrir, Voltar ao macOS normal…, Fechar) e Ajuda (README, Sobre).

## Review Focus

1. **Sem Acesso Total ao Disco:** o macOS nega gravar `com.apple.universalaccess` (contraste, ponteiro). Nada pode ficar pela metade; a caixa mostra o estado real depois, e a mensagem diz o que fazer e abre o painel certo. Teste: Task 7, `deniedAccessibilityAsksForFullDiskAccess`.
2. **Reinstalar mantém as escolhas:** `./install.sh --yes` depois de mudanças no painel mantém desligados os ajustes desligados, volta a cor ou imagem escolhida e deixa desligada a barra desligada, mas atualiza os apps. Testes: Task 1, `defaultApplySkipsTurnedOff` e `catalogUsesChosenWallpaper`; Task 9, `shelloff-keeps-taskbar-off`.
3. **Imagem inválida ou sumida:** escolher um arquivo que não é imagem é recusado sem mudar nada. Se a cópia sumir depois, reaplicar falha com aviso, sem travar e sem perder o original no backup. Testes: Task 1, `notAnImageIsRefused` e `missingPictureFailsAndKeepsBackup`; Task 7, `displayRefusesNonImage`.
4. **Ligar e desligar a barra em casos difíceis:** ligar depois de o Shell ter desistido por quedas (agente desabilitado) ou com uma cópia solta aberta; desligar duas vezes. Testes: Task 3, `turnOnEnablesBeforeBootstrap` e `turnOffTwiceIsHarmless`.
5. **Voltar ao normal com backup corrompido:** nada pode ser desligado pela metade, e a mensagem diz que o backup está ilegível e onde está. Teste: Task 8, `backToNormalWithUnreadableBackupChangesNothing`.

## Arquivos

- **Novos em `Retro98Settings`:**
  - `Choices/Choices.swift` (`WallpaperChoice`, `Choices`, `ChoicesFile`, `TweakSelection`)
  - `Choices/Pieces.swift`
  - `System/PictureWallpaper.swift`
  - `System/ShellAgent.swift`
- **Novos em `Retro98UI`:** `RetroSound.swift`, `ControlPanelIcons.swift`.
- **App novo `Sources/Retro98ControlPanel/`:**
  - `main.swift`, `AppDelegate.swift`, `ControlPanelText.swift`, `Applet.swift`, `ControlPanelMenus.swift`
  - `ControlPanelWindowController.swift`, `ControlPanelServices.swift`, `ControlPanelModel.swift`, `ControlPanelPrompter.swift`
  - `AppletDialog.swift`, `DisplayApplet.swift`, `TweakListApplet.swift` (Aparência e Mouse), `SoundsApplet.swift`, `ComponentsApplet.swift`
- **Testes novos:**
  - `Tests/Retro98SettingsTests/`: `ChoicesTests`, `PictureWallpaperTests`, `ExtraTweakTests`, `PiecesTests`, `ShellAgentTests`
  - `Tests/Retro98UITests/`: `RetroSoundTests`, `ControlPanelIconTests`
  - `Tests/Retro98ControlPanelTests/`: `TestSupport`, `AppletTests`, `ControlPanelWindowTests`, `ModelTweakTests`, `ModelWallpaperTests`, `ModelComponentsTests`, `AppletDialogTests`

---

### Task 1: Escolhas da pessoa e papel de parede escolhido

**Files:**
- Create: `Sources/Retro98Settings/Choices/Choices.swift`, `Sources/Retro98Settings/System/PictureWallpaper.swift`
- Modify:
  - `Tweaks/Tweak.swift`: novo caso de `SpecialAction`.
  - `Tweaks/TweakCatalog.swift`: parâmetro `wallpaper`; título do ajuste vira "Papel de parede do Retro98" / "Retro98 wallpaper".
  - `Engine/SystemServices.swift`, `System/MacWallpaperSetter.swift`: `setPicture`.
  - `Engine/TweakEngine.swift`: aplica imagem; `managed()`.
  - `System/Retro98Paths.swift`, `System/SystemEngine.swift`, `Sources/retro98-settings/main.swift`.
- Test: `ChoicesTests.swift`, `PictureWallpaperTests.swift`; ajustar `Fakes.swift` (`FakeWallpaperSetter.pictures`), `TweakCatalogTests.swift` (título), `TweakEngineApplyTests.swift`, `MacServicesTests.swift`.

**Interfaces:**
- Produces:
  - `public enum WallpaperChoice: Codable, Equatable, Sendable { case color(hex: String); case picture(path: String, name: String); static let standard = .color(hex: "#008080") }`
  - `public struct Choices: Equatable, Sendable { let wallpaper: WallpaperChoice; let turnedOff: Set<TweakID>; let soundsOn: Bool; static let standard }`
    - Métodos que devolvem cópia: `with(wallpaper:)`, `with(soundsOn:)`, `turning(_ id: TweakID, on: Bool)`, `turningOff(_ ids: Set<TweakID>)`.
  - `public struct ChoicesFile { init(url: URL, files: FileStore); static func live() -> ChoicesFile; func load() -> Choices; func save(_ choices: Choices) throws }`
  - `public enum TweakSelection { static func defaultApply(catalog: [Tweak], choices: Choices) -> Set<TweakID> }`: grupo `.base` menos `turnedOff`.
  - `Retro98Paths.choicesFile` (`<suporte>/choices.plist`).
  - `SpecialAction.pictureWallpaper(path: String)`.
  - `WallpaperSetter.setPicture(_ url: URL) throws`: preenche a tela (`Fit.fill`); lança erro se o arquivo não existe.
  - `TweakCatalog.phase1(osMajorVersion:homeDirectory:wallpaper: WallpaperChoice = .standard)` e o mesmo parâmetro em `all(...)`.
  - `TweakEngine.managed() throws -> Set<TweakID>` (= `backup.tweakIDs`).
  - `public enum PictureWallpaper { static func adopt(_ source: URL, paths: Retro98Paths, now: Date = Date()) throws -> WallpaperChoice }`, que lança `PictureWallpaperError.notAnImage` quando `NSImage(contentsOf:)` falha.
  - `SystemEngine.make` monta o catálogo com `ChoicesFile(url: paths.choicesFile, files:).load().wallpaper`.

- [ ] **Step 1: Escrever os testes que falham**

`ChoicesTests.swift`:
- `missingOrBrokenChoicesFileGivesStandard`: `InMemoryFileStore` vazio → `load() == .standard`; `Data("lixo".utf8)` no arquivo → `.standard`.
- `choicesRoundTrip`: grava `Choices.standard.with(wallpaper: .picture(path: "/s/wallpaper-picture-1.png", name: "praia.png")).turning(.pointer, on: false).with(soundsOn: false)`; o `load()` devolve igual.
- `unknownTurnedOffNamesAreIgnored`: plist `{turnedOff: ["pointer", "naoExiste"]}` sem as outras chaves → `turnedOff == [.pointer]`, `wallpaper == .standard`, `soundsOn == true`.
- `defaultApplySkipsTurnedOff`: `defaultApply(catalog: TweakCatalog.all(...), choices: .standard.turning(.pointer, on: false))` == ids do grupo `.base` menos `.pointer`. Nunca inclui `dockUnderTaskbar` nem `explorerFileViewer`.
- `catalogUsesChosenWallpaper`: com `.color(hex: "#800000")`, o `special` do ajuste `.wallpaper` == `.solidWallpaper(hex: "#800000")`. Com `.picture(path: "/x/wallpaper-picture-1.png", name: "a.png")` → `.pictureWallpaper(path: "/x/wallpaper-picture-1.png")`.

`TweakEngineApplyTests.swift`:
- `appliesPictureWallpaper`: catálogo com imagem → `FakeWallpaperSetter.pictures == [URL(filePath: path)]` e o backup tem a entrada do `Index.plist`.
- `missingPictureFailsAndKeepsBackup`: `setPicture` lança erro → `report.failed == [.wallpaper]` com `.wallpaperFailed`; o índice não mudou e o backup não ganhou entrada de arquivo.
- `managedListsTweaksInBackup`: `apply([.pointer, .wallpaper])` → `managed() == [.pointer, .wallpaper]`; depois de `restore([.pointer])` → `[.wallpaper]`.

`MacServicesTests.swift`:
- `setPictureFillsScreenAndRefusesMissingFile`: com `setDesktopImage` que registra, um arquivo existente dá `[(url, .fill)]`. Um arquivo ausente lança erro e não registra nada.

`PictureWallpaperTests.swift` (pasta de suporte numa pasta temporária):
- `adoptCopiesWithStampAndRemovesOldCopies`: a pasta tem `wallpaper-picture-5.png` e `wallpaper-008080.png`; a origem é um PNG de `SolidColorImage.pngData(hex:)` chamado `Praia.PNG`. `adopt(now: Date(timeIntervalSince1970: 100))`:
  - devolve `.picture(path: <suporte>/wallpaper-picture-100.png, name: "Praia.PNG")`;
  - a cópia tem os mesmos bytes;
  - `wallpaper-picture-5.png` sumiu e `wallpaper-008080.png` ficou.
- `notAnImageIsRefused`: um `.txt` lança `PictureWallpaperError.notAnImage` e nenhum arquivo novo aparece no suporte.

- [ ] **Step 2: Rodar e ver falhar**

Run: `swift test --filter Retro98SettingsTests 2>&1 | tail -20`
Expected: falha de compilação (`WallpaperChoice`, `Choices`, `managed` não existem).

- [ ] **Step 3: Implementar**

Os tipos e as mudanças das Interfaces:
- `Choices` tem `Codable` próprio, com as chaves de Global Constraints.
- No `TweakEngine`, `capturesIndex` vale para os dois casos de papel de parede, e `performChanges` chama `setPicture` no caso `.pictureWallpaper`.
- `retro98-settings apply` sem `--only` usa `TweakSelection.defaultApply` com `ChoicesFile.live()`.

- [ ] **Step 4: Rodar e ver passar**

Run: `swift test --filter Retro98SettingsTests 2>&1 | tail -5`
Expected: todos passam.

- [ ] **Step 5: Commit**

```bash
git add Sources/Retro98Settings Sources/retro98-settings Tests/Retro98SettingsTests
git commit -m "feat: remember Control Panel choices and allow any wallpaper"
```

### Task 2: Ajustes opcionais: barra de menus escondida e som de alerta

**Files:**
- Modify:
  - `Tweaks/Tweak.swift`: `TweakID.hiddenMenuBar`, `.alertSound`; `TweakGroup.extra`; `RefreshEffect.notifyMenuBarChange`.
  - `Tweaks/TweakCatalog.swift`: `extra(alertSoundPath:)`; `all` acrescenta `extra` no fim.
  - `System/MacSystemRefresher.swift`, `System/Retro98Paths.swift`, `System/SystemEngine.swift`.
- Test: `ExtraTweakTests.swift`; ajustar `TweakCatalogTests` (ordem e contagem) e `MacServicesTests`.

**Interfaces:**
- Produces:
  - `TweakCatalog.extra(alertSoundPath: String) -> [Tweak]`.
  - `all(osMajorVersion:homeDirectory:wallpaper:alertSoundPath: String? = nil)`: nil usa `<home>/Library/Sounds/Retro98.aiff`.
  - `Retro98Paths.soundsDirectory`: `RETRO98_SOUNDS_DIR` ou `<home>/Library/Sounds`.
  - `Retro98Paths.alertSoundFile`: `soundsDirectory/Retro98.aiff`.
  - Títulos:
    - `hiddenMenuBar`: "Barra de menus do macOS escondida" / "macOS menu bar hidden".
    - `alertSound`: "Som de alerta do Retro98 no macOS" / "Retro98 alert sound for macOS".

- [ ] **Step 1: Escrever os testes que falham**
  - `hiddenMenuBarPinsBothKeys`: `changes` == global `_HIHideMenuBar` `.bool(true)` e global `AppleMenuBarVisibleInFullscreen` `.bool(false)`; `effects == [.notifyMenuBarChange]`; `group == .extra`.
  - `alertSoundPointsAtRetro98File`: `extra(alertSoundPath: "/Users/ana/Library/Sounds/Retro98.aiff")` → global `com.apple.sound.beep.sound` `.string(...)` com esse caminho; `group == .extra`; `special == nil`.
  - `extraTweaksAreNeverAppliedByDefault`: `TweakSelection.defaultApply(..., .standard)` não contém nenhum dos dois.
  - `soundsDirectoryFollowsOverride`:
    - `Retro98Paths.standard(home: /Users/ana, environment: [:]).alertSoundFile.path == "/Users/ana/Library/Sounds/Retro98.aiff"`;
    - com `RETRO98_SOUNDS_DIR=/tmp/s` → `/tmp/s/Retro98.aiff`.
  - `menuBarChangeIsBroadcast`: `MacSystemRefresher(post:)` que registra, depois `perform([.notifyMenuBarChange])` → `["AppleInterfaceMenuBarHidingChangedNotification"]`.

- [ ] **Step 2: Rodar e ver falhar**

Run: `swift test --filter Retro98SettingsTests 2>&1 | tail -20`
Expected: falha de compilação (`hiddenMenuBar` não existe).

- [ ] **Step 3: Implementar** as Interfaces; `SystemEngine.make` passa `paths.alertSoundFile.path`.

- [ ] **Step 4: Rodar e ver passar**

Run: `swift test --filter Retro98SettingsTests 2>&1 | tail -5`
Expected: todos passam (incluindo `listsEveryTweakOnceInOrder` ajustado com os dois novos no fim).

- [ ] **Step 5: Commit**

```bash
git add Sources/Retro98Settings Tests/Retro98SettingsTests
git commit -m "feat: optional hidden menu bar and retro alert sound tweaks"
```

### Task 3: Peças e liga/desliga da barra de tarefas

**Files:**
- Create: `Sources/Retro98Settings/Choices/Pieces.swift`, `Sources/Retro98Settings/System/ShellAgent.swift`
- Modify: `System/Retro98Paths.swift`; `Sources/Retro98ShellCore/LaunchHistory.swift` (`ShellIdentity.label = ShellAgent.label`).
- Test: `PiecesTests.swift`, `ShellAgentTests.swift`.

**Interfaces:**
- Produces:
  - `public struct Pieces: Equatable, Sendable`:
    - `init(line: String)` e `var line: String` (palavras separadas por um espaço);
    - `contains(_:)`, `adding(_:)`, `removing(_:)`;
    - `replacing(_ old: String, with new: String) -> Pieces`: troca no lugar; se `old` falta, acrescenta `new` (sem duplicar).
  - `public struct PiecesFile { init(url: URL, files: FileStore); func load() -> Pieces; func save(_ pieces: Pieces) throws }`: o arquivo guarda `line + "\n"`, e um arquivo ausente vira linha vazia.
  - `public protocol ShellSwitch { var isInstalled: Bool { get }; var isOn: Bool { get }; func turnOn() throws; func turnOff() }`
  - `public struct ShellAgent: ShellSwitch`:
    - `static let label = "io.github.matheushchaves.retro98.shell"`;
    - `init(paths:files:runner:uid: uid_t = getuid(), exists: @escaping (URL) -> Bool = <FileManager>, stopCopies: @escaping () -> Void = ShellAgent.terminateRunningCopies)`;
    - `static func plist(executable: String) throws -> Data`;
    - `static func terminateRunningCopies()`: `NSRunningApplication` pelo bundle id; `terminate()`, depois `forceTerminate()` após 5 s;
    - `public enum ShellAgentError: Error, Equatable { case notInstalled, launchctlFailed(Int32) }`.
    - `isInstalled` = `exists(paths.shellApp)`; `isOn` = `files.read(paths.launchAgentPlist)` não é nil (assim os testes com `InMemoryFileStore` enxergam o plist).
  - Novos em `Retro98Paths`:
    - `appsDirectory` (`RETRO98_APPS_DIR` ou `<home>/Applications/Retro98`) e `launchAgentsDirectory` (`RETRO98_LAUNCH_AGENTS_DIR` ou `<home>/Library/LaunchAgents`);
    - `piecesFile`, `shellApp`, `explorerApp`, `controlPanelApp` ("Retro98 Control Panel.app") e `launchAgentPlist`.

- [ ] **Step 1: Escrever os testes que falham**
  - `piecesKeepOrderAndSpacing`:
    - `Pieces(line: " base  shell prompt\n").line == "base shell prompt"`;
    - `.replacing("shell", with: "shelloff").line == "base shelloff prompt"`;
    - `adding("fileviewer")` duas vezes acrescenta uma vez só, e `removing("fileviewer")` volta ao anterior;
    - `Pieces(line: "base prompt").replacing("shelloff", with: "shell").line == "base prompt shell"`.
  - `piecesFileRoundTrip`: ausente → `line == ""`; `save(Pieces(line: "base shell"))` grava `"base shell\n"`.
  - `plistMatchesInstaller`: o plist decodificado tem:
    - `Label` = label e `ProgramArguments` = `[exe]`;
    - `RunAtLoad` true e `KeepAlive` = `{SuccessfulExit: false}`;
    - `ThrottleInterval` 5 e `ProcessType` "Interactive".
  - `turnOnEnablesBeforeBootstrap`: runner que registra, uid 501. `turnOn()` grava o plist em `paths.launchAgentPlist`. Comandos == `[["/bin/launchctl","enable","gui/501/<label>"], ["/bin/launchctl","bootstrap","gui/501",<plist>]]`.
  - `turnOffStopsCopiesAndRemovesAgent`: depois de `turnOn()`, `turnOff()`:
    - o último comando é `["/bin/launchctl","bootout","gui/501/<label>"]`;
    - `stopCopies` é chamado uma vez, depois do `bootout`;
    - o plist sumiu e `isOn == false`.
  - `turnOffTwiceIsHarmless`: `turnOff()` sem plist não lança e ainda chama `stopCopies`, por causa das cópias soltas.
  - `turnOnFailsWhenNotInstalled`: `exists` falso → lança `.notInstalled` e não roda comando.
  - `bootstrapFailureIsReported`: runner devolve 5 no `bootstrap` → lança `.launchctlFailed(5)`; o plist fica, para o próximo login.
  - `appPathsFollowOverrides`: com `RETRO98_APPS_DIR=/tmp/a` e `RETRO98_LAUNCH_AGENTS_DIR=/tmp/l` → `shellApp.path == "/tmp/a/Retro98 Shell.app"` e `launchAgentPlist.path == "/tmp/l/<label>.plist"`; sem eles, tudo fica dentro da pasta pessoal.

- [ ] **Step 2: Rodar e ver falhar**

Run: `swift test --filter Retro98SettingsTests 2>&1 | tail -20`
Expected: falha de compilação (`Pieces`, `ShellAgent` não existem).

- [ ] **Step 3: Implementar** as Interfaces. Um comentário no `ShellAgent.plist` e outro no heredoc do `install.sh` apontam um para o outro: os dois precisam continuar iguais.

- [ ] **Step 4: Rodar e ver passar**

Run: `swift test --filter "Retro98SettingsTests|Retro98ShellCoreTests" 2>&1 | tail -5`
Expected: todos passam.

- [ ] **Step 5: Commit**

```bash
git add Sources/Retro98Settings Sources/Retro98ShellCore install.sh Tests/Retro98SettingsTests
git commit -m "feat: turn the taskbar on and off without the installer"
```

### Task 4: Sons retrô

**Files:**
- Create: `Sources/Retro98UI/RetroSound.swift`
- Modify:
  - `Retro98UI/RetroMessageBox.swift`: toca o som do ícone.
  - `Retro98Shell/AppDelegate.swift`: `.startup` depois de `taskbar.show()`.
  - `Retro98Explorer/ExplorerOperations.swift`: parâmetro `playSound` no `init`, com padrão `RetroSound.play`; toca `.emptyTrash` depois de esvaziar.
  - `main.swift` do Shell, do Explorer e do Prompt: `RetroSound.isEnabled = { ChoicesFile.live().load().soundsOn }`.
- Test: `RetroSoundTests.swift`; em `ExplorerOperationsTests.swift`, `emptyingTrashPlaysTheSound`.

**Interfaces:**
- Produces:
  - `public enum RetroSoundKind: String, CaseIterable, Sendable { case startup, error, warning, emptyTrash, alert }`
  - `public enum RetroSound`:
    - `static let sampleRate = 22_050`;
    - `static func samples(_ kind: RetroSoundKind) -> [Int16]`, `static func duration(_ kind: RetroSoundKind) -> TimeInterval`;
    - `static func aiff(_ kind: RetroSoundKind) -> Data`, `static func extended80(_ value: Double) -> [UInt8]`;
    - `@MainActor static var isEnabled: () -> Bool = { false }`;
    - `@MainActor static func play(_ kind:, isEnabled: () -> Bool = RetroSound.isEnabled, output: (Data) -> Void = RetroSound.output)`;
    - `@MainActor static func preview(_ kind:, output: (Data) -> Void = RetroSound.output)`;
    - a saída padrão toca com `NSSound(data:)` e guarda a referência até terminar.
  - `MessageBoxIcon.sound: RetroSoundKind?`: `.error` → `.error`, `.warning` → `.warning`, os outros → nil.
- Receitas (ondas a 22.050 Hz; envelope = pico × min(1, t/0,005 s) × e^(−decaimento × t), com t contado desde o início de cada nota):

| Som | Onda | Pico | Notas (Hz, s) | Decaimento | Total |
|---|---|---|---|---|---|
| startup | quadrada | 0,25 | 523,25 0,12 · 659,25 0,12 · 783,99 0,12 · 1046,50 0,50 | 6 (a última: 3) | 0,86 s |
| error | quadrada | 0,30 | 220,00 0,10 · 164,81 0,22 | 8 | 0,32 s |
| warning | quadrada | 0,25 | 440 0,07 · silêncio 0,04 · 440 0,11 | 10 | 0,22 s |
| emptyTrash | ruído | 0,20 | 0,40 s de ruído (LCG `x = x &* 1103515245 &+ 12345`, `UInt32`, semente 98, amostra = `(x >> 16)` levado a [−1, 1], média das últimas 4) | 9 | 0,40 s |
| alert | senoide | 0,30 | 880 0,05 · 1318,51 0,15 | 12 | 0,20 s |

- [ ] **Step 1: Escrever os testes que falham**
  - `soundsHaveExactLengthAndStayQuiet`: para cada som, `samples(k).count == Int((duration(k) * 22050).rounded())`, com as durações da tabela. O pico absoluto fica ≤ `Int16(0.31 * 32767)` e não é tudo zero.
  - `soundsAreDeterministicAndDistinct`: duas chamadas dão o mesmo resultado; os 5 sons diferem dois a dois.
  - `aiffHeaderIsValid`: em `aiff(.alert)`:
    - os bytes 0..<4 são "FORM", e o tamanho do FORM é `count - 8`; os bytes 8..<12 são "AIFF";
    - o `COMM` tem 1 canal, frames = número de amostras, 16 bits e taxa `extended80(22050)`;
    - `extended80(22050) == [0x40,0x0D,0xAC,0x44,0,0,0,0,0,0]` e `extended80(44100) == [0x40,0x0E,0xAC,0x44,0,0,0,0,0,0]`;
    - os dados do `SSND` medem `8 + 2 × frames`, com amostras big-endian.
  - `appKitReadsTheSound`: para cada som, `NSSound(data: aiff(k))` não é nil, com `duration` a até 0,01 s da tabela.
  - `playRespectsSwitchButPreviewDoesNot`: com `isEnabled: { false }`, `play` não chama `output`; com `{ true }`, chama uma vez. `preview` chama sempre.
  - `messageBoxSounds`: o mapeamento de `MessageBoxIcon.sound` acima.
  - `emptyingTrashPlaysTheSound` (Explorer): `playSound` que registra. Confirmar o esvaziamento registra `[.emptyTrash]` depois da remoção; recusar não registra nada.

- [ ] **Step 2: Rodar e ver falhar**

Run: `swift test --filter "Retro98UITests|Retro98ExplorerTests" 2>&1 | tail -20`
Expected: falha de compilação (`RetroSound` não existe).

- [ ] **Step 3: Implementar** as Interfaces e as receitas. `RetroMessageBox.run` chama `RetroSound.play(icon.sound)` ao mostrar a caixa.

- [ ] **Step 4: Rodar e ver passar**

Run: `swift test 2>&1 | grep -E "Test run with|✘" | tail -8`
Expected: todos passam.

- [ ] **Step 5: Commit**

```bash
git add Sources/Retro98UI Sources/Retro98Shell Sources/Retro98Explorer Sources/Retro98Prompt Tests/Retro98UITests Tests/Retro98ExplorerTests
git commit -m "feat: original retro sounds for startup, errors, warnings and emptying the Recycle Bin"
```

### Task 5: Ícones do painel e caixa de seleção desabilitada

**Files:**
- Create: `Sources/Retro98UI/ControlPanelIcons.swift`
- Modify:
  - `Retro98UI/FileIcons.swift`: `Sketch` deixa de ser `private`, para os ícones do painel usarem a mesma grade de 16.
  - `Retro98UI/RetroCheckBox.swift`: `isEnabled`.
  - `retro98-tools/main.swift`: ícone `controlpanel` e o texto de uso.
- Test: `ControlPanelIconTests.swift`; no arquivo que já testa a `RetroCheckBox`, `disabledCheckBoxIgnoresClicksAndDrawsGray`.

**Interfaces:**
- Produces:
  - `public enum ControlPanelIcon: CaseIterable, Sendable { case display, appearance, mouse, sounds, components, network, printers, keyboard, dateTime, users }`
  - `public enum ControlPanelIcons`:
    - `static let app: PixelIcon` (32) e `static let appSmall: PixelIcon` (16);
    - `static func icon(_ kind: ControlPanelIcon, size: Int) -> PixelIcon`, com cache como em `FileIcons`.
  - `RetroCheckBox.isEnabled: Bool = true`: desabilitada, ignora clique e espaço, não aceita foco e desenha o texto em `Palette.shadow`.
- Desenhos originais, só com a paleta:
  - **app:** painel cinza com dois controles deslizantes (trilho preto, botão azul-marinho) e um botão redondo com marca vermelha;
  - **display:** monitor de moldura cinza, tela verde-água e pé cinza;
  - **appearance:** janelinha (título azul-marinho) com três pingos de tinta, vermelho, amarelo e azul;
  - **mouse:** mouse branco de contorno preto, com a linha dos botões e o fio subindo;
  - **sounds:** alto-falante cinza com cone preto e duas ondas;
  - **components:** duas caixas empilhadas (verde e azul-marinho) ligadas por um plugue amarelo;
  - **network:** dois monitores pequenos de tela verde-água ligados por um cabo;
  - **printers:** impressora cinza com folha branca saindo em cima e uma luz verde;
  - **keyboard:** teclado cinza com fileiras de teclas brancas;
  - **dateTime:** relógio branco de aro preto, ponteiros azul-marinho e marca vermelha no 12;
  - **users:** duas silhuetas (azul-marinho e verde-água), cabeça e ombros.

- [ ] **Step 1: Escrever os testes que falham**
  - `controlPanelIconsAreOriginalPixelArt`:
    - `app` mede 32×32 e `appSmall` 16×16, e cada tipo mede 16×16 e 32×32 nos dois tamanhos;
    - todos têm proporção opaca acima de 1/8 (o helper de `FileIconTests` vai para um arquivo comum dos testes);
    - os 10 tipos a 32 diferem dois a dois nos pixels.
  - `disabledCheckBoxIgnoresClicksAndDrawsGray`: com `isEnabled = false`, `performClick()` não muda `isOn` e não chama `onChange`; `acceptsFirstResponder == false`. Renderizada, tem pixels `#808080` no texto e nenhum preto fora da caixa.

- [ ] **Step 2: Rodar e ver falhar**

Run: `swift test --filter Retro98UITests 2>&1 | tail -20`
Expected: falha de compilação (`ControlPanelIcons` não existe).

- [ ] **Step 3: Implementar** as Interfaces e os desenhos.

- [ ] **Step 4: Rodar e ver passar**

Run: `swift test --filter Retro98UITests 2>&1 | tail -5 && swift build -c release --product retro98-tools 2>&1 | tail -2 && .build/release/retro98-tools iconset controlpanel "$(mktemp -d)/x.iconset" && echo ICONSET-OK`
Expected: testes passam e `ICONSET-OK`.

- [ ] **Step 5: Commit**

```bash
git add Sources/Retro98UI Sources/retro98-tools Tests/Retro98UITests
git commit -m "feat: Control Panel icons and disabled check boxes"
```

### Task 6: App Painel de Controle: janela de ícones e atalhos do macOS

**Files:**
- Modify `Package.swift`:
  - `.executableTarget(name: "Retro98ControlPanel", dependencies: ["Retro98UI", "Retro98Settings"])`;
  - `.testTarget(name: "Retro98ControlPanelTests", dependencies: ["Retro98ControlPanel", "Retro98Settings", "Retro98UI"])`;
  - o produto executável.
- Create em `Sources/Retro98ControlPanel/`: `main.swift`, `AppDelegate.swift`, `ControlPanelText.swift`, `Applet.swift`, `ControlPanelMenus.swift`, `ControlPanelWindowController.swift`, `ControlPanelServices.swift`, `ControlPanelPrompter.swift`.
- Modify no Shell:
  - `Retro98ShellCore/StartMenuModel.swift`: `controlPanelBundleID`.
  - `Retro98ShellCore/StartMenuItems.swift`: `build(..., controlPanelURL: URL? = nil)` e `StartMenuSymbol.controlPanel`.
  - `Retro98Shell/StartMenuController.swift`: acha o app com `NSWorkspace.urlForApplication(withBundleIdentifier:)`; ícone `ControlPanelIcons.app`/`appSmall`.
  - `Retro98Shell/Recovery.swift`, só o texto: "Para ligar de novo, use Componentes no Painel de Controle ou rode ./install.sh." / "To turn it on again, use Components in Control Panel or run ./install.sh."
- Test: `Tests/Retro98ControlPanelTests/TestSupport.swift`, `AppletTests.swift`, `ControlPanelWindowTests.swift`; em `Retro98ShellCoreTests`, `settingsListsControlPanelFirstWhenInstalled`.

**Interfaces:**
- Consumes (Tasks 1–5): `ChoicesFile`, `PiecesFile`, `ShellSwitch`, `ShellAgent`, `PictureWallpaper`, `TweakCatalog.all`, `Retro98Paths`, `RetroSound`, `ControlPanelIcons`.
- Produces:
  - `enum Applet: CaseIterable { case display, appearance, mouse, sounds, components, network, printers, keyboard, dateTime, users, systemSettings }`:
    - `func title(_ l: [String]) -> String` e `func description(_ l: [String]) -> String`;
    - `var icon: PixelIcon` (`systemSettings` usa `Icons.systemSettings`);
    - `var settingsURL: URL?` (nil nos applets do Retro98).
  - `enum MacOSPanel { case displays, appearance, mouse, trackpad, sound, fullDiskAccess; var url: URL }`.
  - `@MainActor protocol ControlPanelServices: AnyObject`:
    - `var languages: [String]`, `var paths: Retro98Paths`;
    - `func makeEngine() -> TweakEngine` (motor novo a cada chamada, com o catálogo do papel de parede gravado) e `func catalog() -> [Tweak]`;
    - `var choices: ChoicesFile`, `var pieces: PiecesFile`, `var shell: ShellSwitch`, `var explorerInstalled: Bool`;
    - `func open(_ url: URL)`, `func adoptPicture(_ url: URL) throws -> WallpaperChoice`;
    - `func writeAlertSound() throws` (grava `RetroSound.aiff(.alert)` em `paths.alertSoundFile`), `func removeAlertSound()`, `func preview(_ sound: RetroSoundKind)`.
  - `final class LiveControlPanelServices: ControlPanelServices`: `SystemEngine.make()`, `LocalFileStore`, `ShellAgent`, `NSWorkspace`, `PictureWallpaper.adopt`.
  - `@MainActor protocol ControlPanelPrompter { func show(title: String, message: String, icon: MessageBoxIcon, buttons: [String]) -> Int }`, com `RetroControlPanelPrompter` (usa `RetroMessageBox`).
  - `ControlPanelWindowController(services:prompter:)`:
    - `window`, `grid`, `statusBar`;
    - `func open(_ applet: Applet)`: atalho do macOS → `services.open(url)`; applet do Retro98 → `onOpenApplet?(applet)`;
    - `var onOpenApplet: ((Applet) -> Void)?`.
- Textos:
  - Títulos: Vídeo/Display, Aparência/Appearance, Mouse/Mouse, Sons/Sounds, Componentes/Components, Rede/Network, Impressoras/Printers, Teclado/Keyboard, Data/Hora / Date/Time, Usuários/Users, Ajustes do Sistema/System Settings.
  - Descrições dos applets:
    - **display:** "Muda o papel de parede e a cor da área de trabalho." / "Changes the desktop wallpaper and color."
    - **appearance:** "Liga e desliga os ajustes de aparência do Retro98, um a um." / "Turns Retro98's appearance tweaks on and off, one by one."
    - **mouse:** "Muda o ponteiro do mouse." / "Changes the mouse pointer."
    - **sounds:** "Liga e desliga os sons do Retro98 e o som de alerta." / "Turns Retro98 sounds and the alert sound on and off."
    - **components:** "Liga e desliga a barra de tarefas, o Explorer como padrão e a barra de menus escondida." / "Turns the taskbar, Explorer as default and the hidden menu bar on and off."
  - Atalhos do macOS: "Abre <painel> nos Ajustes do Sistema do macOS." / "Opens <panel> in macOS System Settings.", com os nomes Rede/Network, Impressoras e Scanners/Printers & Scanners, Teclado/Keyboard, Data e Hora/Date & Time, Usuários e Grupos/Users & Groups.
  - Ajustes do Sistema: "Abre os Ajustes do Sistema do macOS." / "Opens macOS System Settings."
- Endereços (`x-apple.systempreferences:` + bundle id do painel; ids lidos neste Mac em 2026-11-13):
  - network `com.apple.Network-Settings.extension`, printers `com.apple.Print-Scan-Settings.extension`, keyboard `com.apple.Keyboard-Settings.extension`, dateTime `com.apple.Date-Time-Settings.extension`, users `com.apple.Users-Groups-Settings.extension`;
  - displays `com.apple.Displays-Settings.extension`, appearance `com.apple.Appearance-Settings.extension`, mouse `com.apple.Mouse-Settings.extension`, trackpad `com.apple.Trackpad-Settings.extension`, sound `com.apple.Sound-Settings.extension`;
  - fullDiskAccess `com.apple.preference.security?Privacy_AllFiles`;
  - systemSettings: `file:///System/Applications/System%20Settings.app`.
- Janela [minha escolha]:
  - `RetroAppWindow` de conteúdo 480×360 com o ícone `ControlPanelIcons.appSmall`.
  - De cima para baixo: barra de menus retrô (22), linha gravada (2), `RetroIconGrid` em ícones grandes, faixa de 32 com o botão "Voltar ao macOS normal…" / "Back to macOS normal…" à esquerda (ação no Task 8), e `RetroStatusBar` (20).
  - A barra de status mostra a descrição do item selecionado, ou "11 objeto(s)" / "11 object(s)" sem seleção.
  - Duplo clique ou Enter abre o item.
- App:
  - Uma janela só; fechar a última encerra o app; reabrir mostra a janela.
  - Ajustes… (⌘,) mostra a janela. Sobre usa o painel padrão. Ajuda abre o README.
  - `main.swift` liga `RetroSound.isEnabled` como os outros apps.

- [ ] **Step 1: Escrever os testes que falham**
  - `TestSupport.swift`: `TestServices: ControlPanelServices` com:
    - `InMemoryPreferenceStore` e `InMemoryFileStore`;
    - motor real com `TweakCatalog.all(osMajorVersion: 27, homeDirectory: /Users/ana, wallpaper: choices.load().wallpaper)`;
    - fakes de papel de parede (`hexes`, `pictures`, `restoredIndexes`) e refresher;
    - `FakeShell` (`isInstalled`, `isOn`, `turnOnCalls`, `turnOffCalls`, erro opcional);
    - registros de `opened`, `previewed`, `alertSoundWritten` e `alertSoundRemoved`.
    - Mais `ScriptedPrompter`, que guarda as mensagens e devolve respostas definidas.
  - `appletsInOrderWithTitlesAndLinks`:
    - `Applet.allCases` na ordem acima, com os títulos de `["pt-BR"]`;
    - `Applet.network.settingsURL?.absoluteString == "x-apple.systempreferences:com.apple.Network-Settings.extension"`;
    - `Applet.display.settingsURL == nil`, e `systemSettings` é um arquivo;
    - toda descrição é não vazia em pt e en.
  - `windowShowsEveryApplet`: a grade tem 11 itens com os títulos na ordem.
  - `statusBarDescribesSelection`: sem seleção, "11 objeto(s)"; selecionar Vídeo mostra a descrição dele.
  - `openingMacOSShortcutOpensSettings`: `open(.keyboard)` → `opened == [<url do teclado>]`.
  - `openingRetroAppletAsksForItsDialog`: `open(.sounds)` chama `onOpenApplet` com `.sounds` e não abre URL.
  - `appMenuHasAboutSettingsQuit`: o primeiro submenu do `mainMenu` tem Sobre, um item com ⌘, e Sair (`terminate:`).
  - `settingsListsControlPanelFirstWhenInstalled` (ShellCore): com `controlPanelURL`, os filhos de Configurações são `[Painel de Controle, Ajustes do Sistema]` (símbolos `.controlPanel` e `.systemSettings`); sem a URL, só Ajustes do Sistema.

- [ ] **Step 2: Rodar e ver falhar**

Run: `swift test --filter "Retro98ControlPanelTests|Retro98ShellCoreTests" 2>&1 | tail -20`
Expected: falha (alvo e tipos não existem).

- [ ] **Step 3: Implementar** as Interfaces, a janela, os menus e o item do menu Iniciar.

- [ ] **Step 4: Rodar e ver passar**

Run: `swift test --filter "Retro98ControlPanelTests|Retro98ShellCoreTests" 2>&1 | tail -5 && swift build -c release --product Retro98ControlPanel 2>&1 | grep -c "warning:"`
Expected: testes passam; `0` avisos.

- [ ] **Step 5: Commit**

```bash
git add Package.swift Sources/Retro98ControlPanel Sources/Retro98ShellCore Sources/Retro98Shell Tests/Retro98ControlPanelTests Tests/Retro98ShellCoreTests
git commit -m "feat: Control Panel window with applets and macOS shortcuts"
```

### Task 7: Diálogos Vídeo, Aparência e Mouse

**Files:**
- Create: `Sources/Retro98ControlPanel/ControlPanelModel.swift`, `AppletDialog.swift`, `DisplayApplet.swift`, `TweakListApplet.swift`
- Modify: `ControlPanelText.swift`; `ControlPanelWindowController.swift` (`onOpenApplet` abre o diálogo; abrir de novo traz o que já está aberto para frente).
- Test: `ModelTweakTests.swift`, `ModelWallpaperTests.swift`, `AppletDialogTests.swift`.

**Interfaces:**
- Consumes: `ControlPanelServices`, `ControlPanelPrompter` (Task 6); `managed()`, `Choices`, `WallpaperChoice` (Task 1).
- Produces:
  - `enum Problem: Equatable`, com os casos:
    - `failed(TweakFailure)`, `warning(EngineWarning)`;
    - `backupUnreadable(path: String)`, `notAnImage(name: String)`;
    - `shellNotInstalled`, `shellFailed(String)`, `fileFailed(String)`.
  - `@MainActor final class ControlPanelModel`:
    - `init(services: ControlPanelServices)`;
    - `func managed() throws -> Set<TweakID>` e `func title(of id: TweakID) -> String`;
    - `func setTweaks(on: Set<TweakID>, off: Set<TweakID>) -> [Problem]`: aplica `on` e restaura `off`. Nos ajustes base que deram certo, tira de `turnedOff` (ligados) ou põe (desligados). Os outros grupos nunca entram em `turnedOff`.
    - `func wallpaper() throws -> WallpaperChoice?` (nil = papel de parede do macOS, ajuste não gerenciado);
    - `func setWallpaper(_ choice: WallpaperChoice?) -> [Problem]`:
      - com uma escolha, grava `choices.wallpaper` antes, depois aplica `.wallpaper` e tira de `turnedOff`;
      - nil restaura e põe em `turnedOff`.
  - `ControlPanelText.problems(_ problems: [Problem], model: ControlPanelModel, languages: [String]) -> (message: String, icon: MessageBoxIcon, offersFullDiskAccess: Bool)?`: nil quando não há problema.
    - `offersFullDiskAccess` vale quando alguma falha é `writeDenied` com chave do domínio `com.apple.universalaccess`.
    - Nesse caso, os botões são "Abrir Ajustes"/"Open Settings" e "OK"; o primeiro chama `services.open(MacOSPanel.fullDiskAccess.url)`.
  - `@MainActor class AppletDialog`:
    - `RetroWindow` de nível normal com OK, Cancelar e Aplicar embaixo à direita;
    - `init(title:contentSize:)`, `var contentView: NSView`, `var onApply: () -> Void`, `var onClose: (() -> Void)?`;
    - `func performOK()` aplica e fecha, `func performApply()` aplica e fica, `func performCancel()` fecha sem aplicar.
  - `TweakListApplet(ids: [TweakID], extraButtons: [(String, MacOSPanel)], model:services:prompter:)`:
    - **Aparência:** `[.lightAppearance, .colors, .contrast, .scrollBars, .windowAnimations, .titleBarDoubleClick, .finderExplorer]`, mais a nota "O papel de parede fica em Vídeo e o ponteiro em Mouse." / "The wallpaper is in Display and the pointer in Mouse." e o botão "Aparência do macOS…" / "macOS Appearance…".
    - **Mouse:** `[.pointer]`, com os botões "Mouse do macOS…" / "macOS Mouse…" e "Trackpad do macOS…" / "macOS Trackpad…".
    - Uma caixa por ajuste, com o título do catálogo, marcada se `managed()` contém o ajuste.
    - Ao aplicar, chama `setTweaks` com o que mudou, mostra os problemas e relê o estado.
  - `DisplayApplet(model:services:prompter:pickPicture: @escaping () -> URL? = <NSOpenPanel só de imagens>)`, com:
    - prévia de monitor (152×112): a cor, a imagem reduzida ou o texto "macOS" na tela;
    - opções "Papel de parede do macOS" / "macOS wallpaper", "Cor sólida" / "Solid color", "Imagem" / "Picture";
    - 16 amostras de cor na ordem de Global Constraints (clicar seleciona "Cor sólida");
    - nome do arquivo e botão "Procurar…" / "Browse…" (escolher seleciona "Imagem");
    - botão "Monitores do macOS…" / "macOS Displays…".
- Textos de problema:
  - Falha: "Não foi possível mudar: <títulos separados por vírgula>." / "Couldn't change: <titles>."
  - Acesso Total ao Disco: "O macOS não deixou mudar os ajustes de acessibilidade. Dê Acesso Total ao Disco ao Retro98 Control Panel em Ajustes do Sistema › Privacidade e Segurança e tente de novo." / "macOS didn't allow changing the accessibility settings. Give Retro98 Control Panel Full Disk Access in System Settings › Privacy & Security and try again."
  - Backup ilegível: "O backup dos ajustes está ilegível (<caminho>). Nada foi mudado." / "The settings backup can't be read (<path>). Nothing was changed."
  - Arquivo que não é imagem: "\"<nome>\" não é uma imagem que o macOS consiga abrir." / "\"<name>\" isn't an image macOS can open."
  - Avisos do motor: os mesmos textos de `Sources/retro98-settings/Messages.swift`, copiados.

- [ ] **Step 1: Escrever os testes que falham**

`ModelTweakTests.swift`:
- `turningOnAppliesAndForgetsTurnedOff`: com `turnedOff == [.pointer]`, `setTweaks(on: [.pointer], off: [])` aplica os valores do ponteiro na loja, `managed()` contém `.pointer` e `turnedOff` fica vazio.
- `turningOffRestoresAndRemembers`: depois, `setTweaks(on: [], off: [.pointer])` devolve os originais, tira `.pointer` de `managed()` e grava `turnedOff == [.pointer]`.
- `extraTweaksAreNotRememberedAsTurnedOff`: ligar e desligar `.hiddenMenuBar` não muda `turnedOff`.
- `deniedAccessibilityAsksForFullDiskAccess`: a loja nega `com.apple.universalaccess`/`cursorFill`. `setTweaks(on: [.pointer], off: [])`:
  - devolve `[.failed(…pointer, .writeDenied…)]`;
  - as chaves do ponteiro ficam como antes, `managed()` não contém `.pointer` e `turnedOff` não muda;
  - `ControlPanelText.problems(...)?.offersFullDiskAccess == true`.
- `unreadableBackupChangesNothing`: um backup ilegível faz `setTweaks` devolver `[.backupUnreadable(path:)]`, e a loja não muda.

`ModelWallpaperTests.swift`:
- `macOSWallpaperWhenNotManaged`: `wallpaper() == nil` no início.
- `choosingColorSavesThenApplies`: `setWallpaper(.color(hex: "#800000"))`:
  - `hexes == ["#800000"]`, `choices.wallpaper == .color(hex: "#800000")`;
  - `wallpaper() == .color(hex: "#800000")` e `turnedOff` sem `.wallpaper`.
- `changingColorKeepsFirstOriginal`: com o índice valendo "original", escolher A e depois B mantém o original no backup; `hexes == [A, B]`.
- `macOSRestoresAndRemembers`: `setWallpaper(nil)` faz `restoredIndexes == ["original"]`, põe `.wallpaper` em `turnedOff` e deixa `wallpaper() == nil`.
- `pictureChoiceIsApplied`: `.picture(path: "/s/wallpaper-picture-1.png", name: "praia.png")` → `pictures == [URL(filePath: "/s/wallpaper-picture-1.png")]`.

`AppletDialogTests.swift`:
- `okAppliesAndClosesCancelDoesNot`: `performOK()` → `onApply` uma vez e `onClose` chamado; `performCancel()` → `onApply` nenhuma vez.
- `applyKeepsDialogOpen`: `performApply()` → `onApply` uma vez e `onClose` não chamado.
- `appearanceListsSevenTweaksWithState`:
  - 7 caixas com os títulos do catálogo, na ordem;
  - com `.colors` aplicado antes, só a caixa de cores começa marcada;
  - desmarcar cores, marcar rolagem e dar OK deixa `managed()` com `.scrollBars` e sem `.colors`.
- `mouseListsPointer`: uma caixa, a do ponteiro.
- `displayPicksColorFromSwatches`:
  - 16 amostras na ordem fixada;
  - clicar na quarta seleciona "Cor sólida"; OK → `hexes == ["#800000"]`.
- `displayRefusesNonImage`: com `pickPicture` devolvendo um `.txt` de verdade, "Procurar…" mostra a mensagem de "não é uma imagem" e não muda a escolha nem chama o setter.

- [ ] **Step 2: Rodar e ver falhar**

Run: `swift test --filter Retro98ControlPanelTests 2>&1 | tail -20`
Expected: falha de compilação (`ControlPanelModel`, `AppletDialog` não existem).

- [ ] **Step 3: Implementar** as Interfaces. Os diálogos usam `RetroRadioButton`, `RetroCheckBox`, `RetroButton` e `RetroLabel`; o leiaute fica com quem implementa, dentro de 360×300 de conteúdo.

- [ ] **Step 4: Rodar e ver passar**

Run: `swift test --filter Retro98ControlPanelTests 2>&1 | tail -5`
Expected: todos passam.

- [ ] **Step 5: Commit**

```bash
git add Sources/Retro98ControlPanel Tests/Retro98ControlPanelTests
git commit -m "feat: Display, Appearance and Mouse applets"
```

### Task 8: Sons, Componentes e "Voltar ao macOS normal"

**Files:**
- Create: `Sources/Retro98ControlPanel/SoundsApplet.swift`, `ComponentsApplet.swift`
- Modify: `ControlPanelModel.swift`, `ControlPanelText.swift`, `ControlPanelWindowController.swift` (botão e item de menu "Voltar ao macOS normal…").
- Test: `ModelComponentsTests.swift`; em `AppletDialogTests.swift` e `ControlPanelWindowTests.swift`, os testes abaixo.

**Interfaces:**
- Consumes: `ShellSwitch`, `Pieces`/`PiecesFile` (Task 3); `alertSound`, `hiddenMenuBar` (Task 2); `RetroSoundKind` (Task 4).
- Produces em `ControlPanelModel`:
  - `func soundsOn() -> Bool` e `func setSounds(on: Bool) -> [Problem]`;
  - `func setAlertSound(on: Bool) -> [Problem]`:
    - ligar: `writeAlertSound()`, depois aplica `.alertSound`; se aplicar falha, apaga o arquivo;
    - desligar: restaura, depois `removeAlertSound()`.
  - `enum Availability: Equatable { case on, off, notInstalled }`
  - `struct ComponentsState: Equatable { let taskbar: Availability; let fileViewer: Availability; let hiddenMenuBar: Bool }`
  - `func components() throws -> ComponentsState`:
    - `taskbar` vem de `shell.isInstalled` e `shell.isOn`;
    - `fileViewer` vem de `explorerInstalled` e `managed()`;
    - `hiddenMenuBar` vem de `managed()`.
  - `func setTaskbar(on: Bool) -> [Problem]`, sem efeito (só `[.shellNotInstalled]`) quando o Shell não está instalado:
    - ligar: aplica `.dockUnderTaskbar`, depois `shell.turnOn()`; `pieces.replacing("shelloff", with: "shell")`;
    - desligar: `shell.turnOff()`, depois restaura `.dockUnderTaskbar`; `pieces.replacing("shell", with: "shelloff")`.
  - `func setFileViewer(on: Bool) -> [Problem]`: aplica ou restaura `.explorerFileViewer` e põe ou tira `fileviewer` em `pieces`.
  - `func backToNormal() -> [Problem]`, nesta ordem:
    1. lê `managed()`; se o backup estiver ilegível, devolve `[.backupUnreadable]` sem mexer em nada;
    2. se o Shell estiver ligado, `turnOff()` e `shell` → `shelloff`;
    3. tira `fileviewer` de `pieces`;
    4. `restore(nil)` e `removeAlertSound()`;
    5. `turnedOff` = todos os ids do grupo `.base`.
- `SoundsApplet`:
  - caixa "Tocar os sons do Retro98" / "Play Retro98 sounds";
  - uma linha por som com o nome e o botão "Tocar" / "Play" (`services.preview`). Nomes: Início do Retro98/Retro98 startup, Erro/Error, Aviso/Warning, Esvaziar a Lixeira/Empty Recycle Bin, Alerta/Alert;
  - caixa do `alertSound`, com o título do catálogo;
  - botão "Som do macOS…" / "macOS Sound…".
- `ComponentsApplet`:
  - caixas "Barra de tarefas e menu Iniciar" / "Taskbar and Start menu", depois o título do catálogo de `explorerFileViewer`, depois o de `hiddenMenuBar`;
  - item não instalado: caixa desabilitada e a nota "Não instalado: rode ./install.sh para instalar." / "Not installed: run ./install.sh to install it."
- "Voltar ao macOS normal":
  - Pergunta (ícone de pergunta): "Isto desliga a barra de tarefas, devolve o Dock e restaura todos os ajustes que o Retro98 mudou. Os apps do Retro98 continuam instalados." / "This turns off the taskbar, gives back the Dock and restores every setting Retro98 changed. Retro98's apps stay installed."
  - Botões "Voltar ao normal" / "Back to normal" e "Cancelar" / "Cancel".
  - Depois, fecha os diálogos abertos e mostra (informação): "Pronto: o macOS voltou ao normal. Para remover os apps do Retro98, rode ./uninstall.sh." / "Done: macOS is back to normal. To remove Retro98's apps, run ./uninstall.sh."
  - Se houver problemas, mostra a mensagem de problemas em vez disso.

- [ ] **Step 1: Escrever os testes que falham**

`ModelComponentsTests.swift`:
- `soundsSwitchIsSaved`: `setSounds(on: false)` → `choices.load().soundsOn == false`.
- `alertSoundWritesFileThenApplies`: ligar faz `alertSoundWritten` e grava o caminho em `com.apple.sound.beep.sound`; o arquivo é escrito antes, porque o fake registra a ordem. Desligar restaura a chave e apaga o arquivo.
- `alertSoundFileFailureChangesNothing`: `writeAlertSound` lança erro → `[.fileFailed]` e a loja não muda.
- `taskbarOffStopsAgentRestoresDockAndMarksShelloff`: com `pieces` "base shell prompt", o Shell ligado e o Dock aplicado, `setTaskbar(on: false)`:
  - `turnOffCalls == 1`;
  - as chaves do Dock voltam ao original;
  - `pieces` fica "base shelloff prompt".
- `taskbarOnAppliesDockStartsAgentAndMarksShell`: com "base shelloff prompt", ligar:
  - o Dock já está aplicado quando `turnOn` roda (o fake lê a loja);
  - `turnOnCalls == 1`;
  - `pieces` fica "base shell prompt".
- `taskbarNotInstalledIsReported`: `isInstalled == false` → `[.shellNotInstalled]`, sem mudanças.
- `fileViewerFollowsPieces`: ligar grava `NSFileViewer` e `pieces` ganha `fileviewer`; desligar desfaz os dois.
- `backToNormalRestoresEverything`: comece com tudo ligado (ajustes base, Dock, `fileviewer`, `hiddenMenuBar`, `alertSound`), Shell ligado e `pieces` "base shell fileviewer prompt". `backToNormal()`:
  - devolve a loja igual ao início;
  - `turnOffCalls == 1`, `pieces == "base shelloff prompt"`, `alertSoundRemoved`;
  - `turnedOff` = todos os ids base, e nenhum problema.
- `backToNormalWithUnreadableBackupChangesNothing`: backup ilegível → `[.backupUnreadable(path:)]`, `turnOffCalls == 0`, `pieces` sem mudança.
- `backToNormalWithoutShellInstalled`: com o Shell não instalado, restaura os ajustes e não mexe em `shell` em `pieces`.

Diálogos e janela:
- `soundsAppletPreviewsEachSound`: 5 linhas na ordem; "Tocar" da segunda → `previewed == [.error]`, mesmo com `soundsOn == false`.
- `soundsAppletAppliesBothSwitches`: desmarcar os sons, marcar o alerta e dar OK → `soundsOn == false` e `managed()` com `.alertSound`.
- `componentsDisablesMissingPieces`: Shell não instalado → a caixa da barra fica com `isEnabled == false` e a nota aparece; o mesmo para o Explorer.
- `backToNormalAsksFirst`: com o `ScriptedPrompter` respondendo Cancelar, nada muda. Respondendo "Voltar ao normal": `turnOffCalls == 1`, a mensagem final é a de "Pronto" e os diálogos abertos fecharam.

- [ ] **Step 2: Rodar e ver falhar**

Run: `swift test --filter Retro98ControlPanelTests 2>&1 | tail -20`
Expected: falha de compilação (`setTaskbar`, `SoundsApplet` não existem).

- [ ] **Step 3: Implementar** as Interfaces.

- [ ] **Step 4: Rodar e ver passar**

Run: `swift test 2>&1 | grep -E "Test run with|✘" | tail -8`
Expected: todos passam.

- [ ] **Step 5: Commit**

```bash
git add Sources/Retro98ControlPanel Tests/Retro98ControlPanelTests
git commit -m "feat: Sounds and Components applets and back-to-normal button"
```

### Task 9: Instalador, desinstalador e README

**Files:**
- Modify:
  - `scripts/common.sh`: `CONTROL_PANEL_ID`, `CONTROL_PANEL_APP`, `SOUNDS_DIR="${RETRO98_SOUNDS_DIR:-$HOME/Library/Sounds}"`, `remove_control_panel`.
  - `scripts/build-app.sh`: `VERSION="0.8.0"`, `BUILD="8"`.
  - `install.sh`:
    - funções `build_shell_apps` e `apply_fileviewer_choice`, usadas pelos ramos `shell` e `shelloff`;
    - ramo `shelloff`;
    - painel sempre montado e registrado.
  - `uninstall.sh`: `remove_control_panel`; apaga `"$SOUNDS_DIR/Retro98.aiff"`, `choices.plist` e `"$SUPPORT_DIR"/wallpaper-*` (qualquer extensão).
  - `README.md`, `README.pt-BR.md`.
- Test: `Tests/scripts/test_install.sh`, `Tests/scripts/test_uninstall.sh`.

**Interfaces:**
- Consumes: o app `Retro98ControlPanel` (Task 6) e a peça `shelloff` (Tasks 3 e 8).
- O painel é montado com:

```bash
"$RETRO98_ROOT/scripts/build-app.sh" Retro98ControlPanel "$CONTROL_PANEL_ID" "Retro98 Control Panel" "$CONTROL_PANEL_APP" regular "" controlpanel \
    "Retro98 Control Panel uses System Events to switch between light and dark mode right away."
"$LSREGISTER" -f "$CONTROL_PANEL_APP" || status=$?
```

- O ramo `shelloff`, entre o ramo `shell` e o de remoção, faz isto. Comentário: "Turned off in the Control Panel: keep both apps current, the taskbar off and the Dock normal."
  - `build_shell_apps` e `lsregister -f` do Explorer;
  - `stop_shell` e `"$BIN" restore --only dockUnderTaskbar`;
  - `apply_fileviewer_choice`.

- [ ] **Step 1: Escrever os testes que falham**

`test_install.sh`:
- Depois da primeira instalação:
  - `control-panel-built`: `codesign --verify` passa;
  - `control-panel-is-regular-app`: sem `LSUIElement`;
  - `control-panel-has-icon`: `AppIcon.icns` não vazio;
  - `control-panel-apple-events-usage`: `NSAppleEventsUsageDescription` não vazio;
  - `control-panel-registered`: `lsregister -f <app>` no log.
- Caso `shelloff-keeps-taskbar-off`: `echo "base shelloff prompt" > pieces`, `: > log` e `install.sh --yes`. Confere:
  - o `Retro98 Shell.app` foi refeito e nenhum `bootstrap` aparece no log;
  - `settings restore --only dockUnderTaskbar` e `bootout gui/$(id -u)/$LABEL` aparecem no log;
  - o plist do agente não existe, e `pieces` continua "base shelloff prompt".

`test_uninstall.sh`, no `run_shell_case`:
- com sucesso, o painel sai e é desregistrado (`lsregister -u`), e somem `"$SOUNDS_DIR/Retro98.aiff"`, `choices.plist` e `wallpaper-picture-1.png`;
- com falha na restauração, tudo fica.

- [ ] **Step 2: Rodar e ver falhar**

Run: `bash Tests/scripts/test_install.sh 2>&1 | grep -E "^FAIL" ; bash Tests/scripts/test_uninstall.sh 2>&1 | grep -E "^FAIL"`
Expected: `FAIL control-panel-built`, `FAIL shelloff-keeps-taskbar-off` e as falhas novas do desinstalador.

- [ ] **Step 3: Implementar** os scripts e o README:
  - **Seção do Painel de Controle:** o que cada applet faz e os atalhos do macOS.
  - **Fase 5:** marcada como disponível.
  - **Sons:** como ligar e desligar os sons e o som de alerta.
  - **Reinstalar:** as escolhas feitas no painel continuam valendo depois de `./install.sh --yes`; a barra desligada fica desligada (`shelloff`).
  - **Permissão:** o aviso de Acesso Total ao Disco para contraste e ponteiro mudados pelo painel.
  - **"Voltar ao macOS normal" × `./uninstall.sh`:** o primeiro restaura os ajustes e deixa os apps; o segundo remove tudo.

- [ ] **Step 4: Rodar tudo e ver passar**

Run: `swift test 2>&1 | grep -E "Test run with|✘"; for p in Retro98ControlPanel Retro98Shell Retro98Explorer Retro98Prompt retro98-settings; do swift build -c release --product $p 2>&1 | grep -c "warning:"; done; for t in install uninstall signing; do bash Tests/scripts/test_$t.sh | grep -cE "^PASS"; bash Tests/scripts/test_$t.sh | grep -E "^FAIL"; done`
Expected: todas as suítes Swift passam; `0` avisos em cada build; nenhum `FAIL` nos scripts.

- [ ] **Step 5: Commit**

```bash
git add scripts install.sh uninstall.sh README.md README.pt-BR.md Tests/scripts
git commit -m "feat: install Retro98 Control Panel and keep a turned-off taskbar off"
```

---

## Checagem manual (no Mac, depois de `./install.sh`)

1. Iniciar › Configurações › Painel de Controle abre a janela 98 com 11 ícones nítidos; a barra de status descreve o item selecionado. ⌘, também mostra a janela.
2. Rede, Impressoras, Teclado, Data/Hora, Usuários e Ajustes do Sistema abrem o painel certo do macOS.
3. Vídeo:
   - Escolha outra cor e dê OK: o fundo muda.
   - Escolha uma imagem: ela aparece preenchendo a tela.
   - "Papel de parede do macOS" volta o original. Com o backup antigo contaminado, volta o padrão do macOS, com aviso.
4. Aparência: desligue "Barras de rolagem sempre visíveis" e veja as barras do Finder voltarem a sumir; ligue de novo. Desligue "Finder no jeito do Explorer": o Finder reinicia sem barra de status.
5. Mouse: desligue o ponteiro retrô e veja o ponteiro normal voltar. Se aparecer o aviso de Acesso Total ao Disco, siga-o e repita.
6. Sons:
   - "Tocar" em cada som.
   - Com os sons ligados, uma caixa de erro do Explorer toca o som de erro; desligados, fica muda.
   - Ligue o som de alerta: em Ajustes do Sistema › Som, o alerta aparece como "Retro98", e `printf '\a'` no Terminal toca o som retrô.
7. Componentes:
   - Desligue a barra de tarefas: ela some na hora e o Dock volta. Ligue de novo: ela volta, com o som de início.
   - Esconda a barra de menus: ela some e aparece ao levar o ponteiro ao topo. Mostre de novo. Se só mudar depois de sair e entrar na conta, me avise.
8. Rode `./install.sh --yes` depois dessas mudanças: tudo fica como você deixou, incluindo a barra desligada.
9. "Voltar ao macOS normal": pergunta antes, depois tudo volta ao macOS normal; os apps continuam em `~/Applications/Retro98`.
10. No Explorer, esvazie a Lixeira e ouça o som de esvaziar.
