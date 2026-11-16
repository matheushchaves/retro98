# Retro98 Fase 7 — Temas para apps de terceiros — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar a peça `themes` do Retro98:
- um tema do Chrome (cinza e azul-marinho, com imagens originais) pronto para carregar em `chrome://extensions`;
- um tema de interface e um esquema de cores 98 para o Sublime Text, instalados na pasta de pacotes dele;
- um perfil "Retro98 Prompt" para o Terminal (preto, cinza e a fonte VGA), para quem quiser manter o Terminal.

**Architecture:**
- **`Retro98Themes`** (biblioteca nova) gera o que não é texto: as duas imagens do tema do Chrome e o arquivo `.terminal`. O `retro98-tools themes` chama essa biblioteca.
- **`Resources/Themes/`** guarda os arquivos de texto, escritos à mão: o `manifest.json` do Chrome e os dois arquivos do Sublime Text.
- **Scripts:** o instalador junta tudo numa pasta de temas, instala a fonte VGA para o Terminal e copia o pacote do Sublime Text. O desinstalador tira o que o instalador pôs.
- Nenhum app de terceiro tem a configuração alterada: escolher o tema é sempre um gesto da pessoa, em cada app.

**Tech Stack:** Swift 6, AppKit (`NSKeyedArchiver`), CoreGraphics, Swift Testing, bash, JSON.

**Spec:** `docs/superpowers/specs/2026-11-10-retro-desktop-design.md`, seção "Fase 7 — Temas para apps de terceiros", mais a seção 5 (paleta) e a seção 7 ("Desinstalar … remove … temas instalados"). As Fases 1 a 6 estão no `main` (0.9.0).

## Global Constraints

- **Herança:** tudo das fases anteriores continua valendo: paleta clássica, só material original, pt-BR e en, só APIs públicas, os apps do macOS e de terceiros ficam intactos.
- **Testes isolados, mais estes cuidados:**
  - Nenhum teste toca em `~/Library/Fonts`, na pasta do Sublime Text, nas preferências do Terminal ou do Chrome, nem abre esses apps.
  - Os scripts de teste passam `RETRO98_FONTS_DIR` e `RETRO98_SUBLIME_PACKAGES` apontando para pastas temporárias, **em todo caso que roda `install.sh` ou `uninstall.sh`**, já existente ou novo.
  - Os testes Swift gravam só em pastas temporárias.
- **Não mexer nas preferências dos apps [minha escolha]:**
  - O Retro98 não edita `Preferences.sublime-settings`, as preferências do Terminal nem o perfil do Chrome.
  - Motivo: são arquivos da pessoa, com formato próprio (o do Sublime aceita comentários), e o app aberto regrava por cima.
  - O instalador diz o passo que falta em cada app; o README repete.
- **Pasta de temas [minha escolha]:** `~/Library/Application Support/Retro98/Themes/`, com:
  - `Chrome/manifest.json` e `Chrome/images/theme_frame.png`, `Chrome/images/theme_frame_inactive.png`;
  - `Retro98 Prompt.terminal`;
  - `.font-installed`, só quando foi o Retro98 que pôs a fonte em `~/Library/Fonts`. (Na revisão final a marca passou para `~/Library/Application Support/Retro98/font-installed`, fora da pasta que a pessoa vê.)
  - Na primeira vez que a pasta é criada, o instalador a abre no Finder (`open`). Nas seguintes, só atualiza os arquivos.
- **Chrome [minha escolha]:**
  - `manifest.json`, versão 3 do manifesto, `"name": "Retro98"`, `"version": "1.0"`.
  - **Cores** (RGB):
    - `frame` 0,0,128 · `frame_inactive` 128,128,128;
    - `background_tab` e `background_tab_inactive` 128,128,128 · `tab_background_text` e `tab_background_text_inactive` 255,255,255;
    - `toolbar` 192,192,192 · `toolbar_text`, `toolbar_button_icon`, `tab_text` e `bookmark_text` 0,0,0;
    - `omnibox_background` 255,255,255 · `omnibox_text` 0,0,0;
    - `ntp_background` 0,128,128 · `ntp_text` e `ntp_link` 255,255,255 · `ntp_header` 0,0,128;
    - `button_background` 192,192,192.
  - **Propriedade:** `ntp_logo_alternate` 1 (logotipo branco sobre o verde-azulado).
  - **Imagens:** `theme_frame` e `theme_frame_inactive`, 3200×64 px.
    - Cada uma é o degradê do título clássico da esquerda até a coluna 1599 e o mesmo degradê espelhado dali até a 3199, para repetir sem emenda em telas largas.
    - Ativa: `#000080` → `#1084D0`. Inativa: `#808080` → `#C0C0C0`.
  - **Carregar:** em `chrome://extensions`, ligar o "Modo do desenvolvedor" e arrastar a pasta `Chrome` para a página (ou "Carregar sem compactação").
- **Sublime Text [minha escolha]:**
  - Pacote `Retro98` em `~/Library/Application Support/Sublime Text/Packages/Retro98/`, com `Retro98.sublime-theme` e `Retro98.sublime-color-scheme`. Só é instalado se a pasta `Packages` já existir.
  - **Tema de interface:** `"extends": "Default.sublime-theme"` e só a seção `"variables"`. Trocar apenas variáveis não tem como quebrar a estrutura da interface. Valores (nomes conferidos no tema padrão do build 4200):
    - `font_face` "Tahoma";
    - `base_hue` "hsl(0, 0%, 75%)" · `ui_bg`, `button_bg`, `panel_bg`, `dialog_bg`, `overlay_bg` e `tabset_light_bg` "#C0C0C0";
    - `text_fg` "#000000" · `link_fg` "#000080";
    - `sidebar_bg` "#FFFFFF" · `sidebar_label` e `sidebar_heading` "#000000" · `sidebar_row_selected` "#000080" · `sidebar_label_selected` "#FFFFFF";
    - `file_tab_selected_light_label_color` e `file_tab_unselected_light_label_color` "#000000";
    - `quick_panel_label_color` e `quick_panel_path_label_color` "#000000" · `quick_panel_matched_label_color` "#000080";
    - `quick_panel_selected_row_bg` "#000080" · `quick_panel_selected_label_color`, `quick_panel_selected_path_label_color` e `quick_panel_selected_matched_label_color` "#FFFFFF";
    - `tool_tip_bg` "#FFFFE1" · `tool_tip_fg` "#000000" · `progress_bar_fg` "#000080";
    - `scroll_bar_bg` e `scroll_bar_puck_bg` "#808080".
  - **Esquema de cores** (`"name": "Retro98"`), no estilo dos editores da época, só com as 16 cores clássicas:
    - `globals`: `background` "#FFFFFF", `foreground` "#000000", `caret` "#000000", `selection` "#000080", `selection_foreground` "#FFFFFF", `inactive_selection` "#C0C0C0", `line_highlight` "#FFFFFF", `gutter` "#C0C0C0", `gutter_foreground` "#000000", `accent` "#000080", `misspelling` "#FF0000", `find_highlight` "#FFFF00", `find_highlight_foreground` "#000000", `guide` "#C0C0C0", `active_guide` "#808080", `brackets_options` "underline", `brackets_foreground` "#000080".
    - `rules` (escopo → cor):
      - `comment, punctuation.definition.comment` → "#008000";
      - `string` → "#800000";
      - `constant.numeric, constant.language, constant.character` → "#800080";
      - `keyword, storage` → "#0000FF";
      - `entity.name.tag, meta.tag punctuation.definition.tag` → "#000080";
      - `entity.other.attribute-name` → "#008080";
      - `support, entity.other.inherited-class` → "#008080";
      - `entity.name.function, entity.name.class, entity.name.type` → "#000000" com `font_style` "bold";
      - `invalid` → "#FFFFFF" sobre `background` "#FF0000";
      - `markup.heading` → "#000080" com "bold"; `markup.bold` → "bold"; `markup.italic` → "italic";
      - `markup.inserted` → "#008000"; `markup.deleted` → "#800000"; `markup.changed` → "#800080".
  - **Escolher:** em Preferences › Select Theme… e Select Color Scheme…, escolher "Retro98".
- **Terminal [minha escolha]:**
  - Perfil de nome "Retro98 Prompt" (o nome completo deixa claro de onde veio), arquivo `Retro98 Prompt.terminal`.
  - Mesmo visual do Retro98 Prompt: texto `#C0C0C0` sobre `#000000`, seleção `#000080`, cursor sublinhado piscando em `#C0C0C0`, as 16 cores ANSI do Prompt, fonte PxPlus IBM VGA 8x16 a 16 pt sem suavização, 80×25.
  - Chaves do arquivo: `name`, `type` "Window Settings", `ProfileCurrentVersion` 2.07, `BackgroundColor`, `TextColor`, `TextBoldColor` (`#FFFFFF`), `CursorColor`, `SelectionColor`, `Font`, `FontAntialias` false, `FontWidthSpacing` 1, `FontHeightSpacing` 1, `UseBoldFonts` false, `UseBrightBold` true, `CursorType` 1, `CursorBlink` true, `columnCount` 80, `rowCount` 25, e as 16 `ANSI…Color` (`ANSIBlackColor`, `ANSIRedColor`, `ANSIGreenColor`, `ANSIYellowColor`, `ANSIBlueColor`, `ANSIMagentaColor`, `ANSICyanColor`, `ANSIWhiteColor` e as oito `ANSIBright…Color`).
  - Cores e fonte vão como o Terminal espera: `NSColor` e `NSFont` arquivados com `NSKeyedArchiver`.
  - **Adicionar:** dois cliques no arquivo, ou Terminal › Ajustes › Perfis › ⚙ › Importar. O perfil padrão do Terminal não muda.
- **Fonte para o Terminal [minha escolha]:**
  - O instalador copia `PxPlus_IBM_VGA_8x16.ttf` para `~/Library/Fonts/`, só se não houver lá um arquivo com esse nome, e grava `.font-installed`.
  - Uma fonte que a pessoa já tinha nunca é trocada nem apagada.
- **Instalação [minha escolha]:**
  - **Peça `themes`**: pergunta "Instalar os temas para Chrome, Sublime Text e Terminal?" (padrão sim). Recusar grava `nothemes`.
  - **Com `--yes`:** um arquivo de peças sem `themes` nem `nothemes` ganha `themes`. Sem arquivo, as peças são `base shell prompt notepad themes`.
  - **Mensagens depois de instalar** (pt / en):
    - "Temas do Retro98 em <pasta>." / "Retro98 themes are in <folder>."
    - "Chrome: abra chrome://extensions, ligue o Modo do desenvolvedor e arraste a pasta Chrome para a página." / "Chrome: open chrome://extensions, turn on Developer mode and drag the Chrome folder onto the page."
    - "Terminal: dê dois cliques em \"Retro98 Prompt.terminal\" para adicionar o perfil." / "Terminal: double-click \"Retro98 Prompt.terminal\" to add the profile."
    - Com o Sublime: "Sublime Text: escolha Retro98 em Preferences › Select Theme… e em Select Color Scheme…" / "Sublime Text: pick Retro98 in Preferences › Select Theme… and in Select Color Scheme…"
    - Sem o Sublime: "Sublime Text não encontrado: o tema dele não foi instalado." / "Sublime Text not found: its theme was not installed."
  - **Recusar depois ou desinstalar** remove: os arquivos da pasta de temas, o pacote `Retro98` do Sublime (só os dois arquivos; a pasta sai se ficar vazia) e a fonte, se houver `.font-installed`.
  - **Desinstalador**, quando havia temas, avisa (pt / en): "Temas removidos. No Chrome, remova o Retro98 em chrome://extensions. No Terminal, apague o perfil Retro98 Prompt em Ajustes › Perfis. No Sublime Text, escolha outro tema se o Retro98 estava em uso." / "Themes removed. In Chrome, remove Retro98 in chrome://extensions. In Terminal, delete the Retro98 Prompt profile in Settings › Profiles. In Sublime Text, pick another theme if Retro98 was in use."
- **Versão:** 0.10.0 (build 11).

## Review Focus

1. **A pessoa já tinha a fonte VGA em `~/Library/Fonts`:** instalar não troca o arquivo, e desinstalar não o apaga. Testes da Task 3.
2. **Sublime Text ausente:** o instalador avisa e não cria nada em `Application Support/Sublime Text`. Teste da Task 3.
3. **Reinstalar várias vezes com `--yes`:** os arquivos são atualizados, a marca da fonte continua e a pasta não é aberta de novo no Finder. Teste da Task 3.
4. **Recusar a peça depois de instalada (`nothemes`):** tudo o que o instalador pôs sai, e só isso. Teste da Task 3.
5. **Pasta `Packages/Retro98` com arquivos que a pessoa acrescentou:** os dois arquivos do Retro98 saem, e os dela e a pasta ficam. Teste da Task 3.

## Estrutura de arquivos

| Arquivo | Responsabilidade |
|---|---|
| `Package.swift` | Alvos `Retro98Themes` e `Retro98ThemesTests`; `retro98-tools` passa a depender de `Retro98Themes` |
| `Sources/Retro98UI/ConsolePalette.swift` | As cores do console (texto, fundo, seleção, 16 ANSI), antes só no Prompt |
| `Sources/Retro98Prompt/PromptStyle.swift` | Passa a ler as cores de `ConsolePalette` |
| `Sources/Retro98Themes/ChromeThemeImages.swift` | As duas imagens do quadro do Chrome |
| `Sources/Retro98Themes/TerminalProfile.swift` | O conteúdo do arquivo `.terminal` |
| `Sources/Retro98Themes/ThemeFiles.swift` | Grava os arquivos gerados numa pasta |
| `Sources/retro98-tools/main.swift` | Comando `themes <fonte.ttf> <pasta>` |
| `Resources/Themes/Chrome/manifest.json` | Manifesto do tema do Chrome |
| `Resources/Themes/Sublime Text/Retro98.sublime-theme`, `Retro98.sublime-color-scheme` | Tema e esquema de cores do Sublime Text |
| `scripts/common.sh`, `install.sh`, `uninstall.sh`, `scripts/build-app.sh` | Peça `themes`, remoção, versão |
| `README.md`, `README.pt-BR.md` | Seção dos temas, situação |
| `Tests/Retro98ThemesTests/…`, `Tests/scripts/…` | Testes |

---

### Task 1: Imagens do Chrome e perfil do Terminal

**Files:**
- Create `Sources/Retro98UI/ConsolePalette.swift`, `Sources/Retro98Themes/ChromeThemeImages.swift`, `Sources/Retro98Themes/TerminalProfile.swift`, `Sources/Retro98Themes/ThemeFiles.swift`.
- Modify:
  - `Package.swift`:
    - `.library(name: "Retro98Themes", targets: ["Retro98Themes"])`;
    - `.target(name: "Retro98Themes", dependencies: ["Retro98UI"])`;
    - `.testTarget(name: "Retro98ThemesTests", dependencies: ["Retro98Themes", "Retro98UI"])`;
    - `retro98-tools` depends on `["Retro98UI", "Retro98Themes"]`.
  - `Sources/Retro98Prompt/PromptStyle.swift`: `ansiHex`, `foreground`, `background` and `selection` come from `ConsolePalette`.
  - `Sources/retro98-tools/main.swift`: new `themes` command.
- Test `Tests/Retro98ThemesTests/ChromeThemeImagesTests.swift`, `TerminalProfileTests.swift`, `ThemeFilesTests.swift`, and a `TestSupport.swift` with `repoRoot` and `vgaFontURL` (`Resources/Fonts/PxPlus_IBM_VGA_8x16.ttf`).

**Interfaces:**
```swift
// Retro98UI
public enum ConsolePalette {
    public static let foregroundHex = "C0C0C0", backgroundHex = "000000", selectionHex = "000080"
    /// ANSI 0–15, the list PromptStyle.ansiHex had.
    public static let ansiHex: [String]
    public static func color(_ hex: String) -> NSColor          // sRGB
}

// Retro98Themes
public enum ChromeThemeImages {
    public static let size = (width: 3200, height: 64)
    /// The classic title gradient up to the middle column, then mirrored back, so it tiles without a seam.
    public static func frame(active: Bool) -> PixelImage
    public static func png(_ image: PixelImage) -> Data?
}
public enum TerminalProfile {
    public static let name = "Retro98 Prompt"
    public static let fileName = "Retro98 Prompt.terminal"
    /// The names Terminal uses for ANSI 0–15, in order.
    public static let ansiKeys: [String]
    /// An XML property list Terminal imports as a profile.
    public static func data(font: NSFont) throws -> Data
}
public enum ThemeFiles {
    public enum Failure: Error, Equatable { case fontNotFound, imageNotDrawn }
    /// Writes Chrome/images/theme_frame.png, Chrome/images/theme_frame_inactive.png and the .terminal file
    /// into `folder` (created if needed), registering the VGA font at `fontURL` first.
    public static func write(to folder: URL, fontURL: URL) throws
}
```
`retro98-tools themes <font.ttf> <folder>`: calls `ThemeFiles.write`; exit 0, or 1 with the error on stderr. The usage text lists both commands.

- [ ] **Step 1: Write the failing tests:**
  - **`ChromeThemeImagesTests`:**
    - `frameIsTheTitleGradientMirrored`: the active image is 3200×64. Pixel (0, 0) is `#000080`, (1599, 0) is `#1084D0`, (1600, 0) is `#1084D0`, (3199, 0) is `#000080`. Rows 0 and 63 are equal at x = 0, 800 and 1599.
    - `inactiveFrameIsGray`: (0, 0) is `#808080`, (1599, 0) is `#C0C0C0`.
    - `pngKeepsTheSize`: `NSBitmapImageRep(data: png)` has `pixelsWide == 3200` and `pixelsHigh == 64`.
  - **`TerminalProfileTests`** (register the font from `vgaFontURL`, build with `VGAFont.make()`, parse with `PropertyListSerialization`):
    - `profileHasTheBasics`: `name == "Retro98 Prompt"`, `type == "Window Settings"`, `columnCount == 80`, `rowCount == 25`, `FontAntialias == false`, `CursorType == 1`, `CursorBlink == true`, `UseBoldFonts == false`.
    - `colorsAreArchivedNSColors`: unarchiving `BackgroundColor`, `TextColor`, `SelectionColor`, `CursorColor` and `TextBoldColor` with `NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from:)` gives `#000000`, `#C0C0C0`, `#000080`, `#C0C0C0`, `#FFFFFF` (compare 8-bit sRGB components).
    - `fontIsTheVGAFont`: unarchiving `Font` as `NSFont` gives `fontName == VGAFont.postScriptName` and `pointSize == 16`.
    - `ansiColorsFollowThePrompt`: `ansiKeys.count == 16`, the first is `ANSIBlackColor` and the last `ANSIBrightWhiteColor`. Each key unarchives to the color at the same index of `ConsolePalette.ansiHex`.
  - **`ThemeFilesTests`:**
    - `writesEveryGeneratedFile`: into a temporary folder → the three files exist and are non-empty; the `.terminal` parses as a property list.
    - `missingFontIsAnError`: a font URL that doesn't exist throws `.fontNotFound` and writes nothing.
  - **`Tests/Retro98PromptTests/PromptStyleTests.swift`:** keeps passing unchanged (it pins `PromptStyle.ansiHex`).
- [ ] **Step 2: Run** `swift test --filter "ChromeThemeImagesTests|TerminalProfileTests|ThemeFilesTests"`. Expected: FAIL (module `Retro98Themes` not found).
- [ ] **Step 3: Implement:**
  - **`ConsolePalette`:** move the hex list and the three colors; `PromptStyle` forwards to it (`static let ansiHex = ConsolePalette.ansiHex`, and so on).
  - **`ChromeThemeImages.frame`:** `PixelCanvas.render` and, for each half, `RetroWindow.drawTitleGradient(active:in:context:)` on a 1600-wide rect. The second half is drawn mirrored: column `c` in 1600…3199 takes the color of column `3199 - c`.
  - **`png`:** `NSBitmapImageRep(cgImage:).representation(using: .png, properties: [:])`.
  - **`TerminalProfile.data`:** a dictionary serialized with `PropertyListSerialization` (`.xml`). Colors and font go through `NSKeyedArchiver.archivedData(withRootObject:requiringSecureCoding: false)`.
  - **`ThemeFiles.write`:** `VGAFont.register(at:)` (false → `.fontNotFound`, before creating anything), then create the folders and write the three files atomically.
- [ ] **Step 4: Run** `swift test`. Expected: PASS (whole suite, since the Prompt's palette moved).
- [ ] **Step 5: Commit** `feat: Chrome frame images and Terminal profile generators`.

### Task 2: Os arquivos de texto dos temas

**Files:**
- Create `Resources/Themes/Chrome/manifest.json`, `Resources/Themes/Sublime Text/Retro98.sublime-theme`, `Resources/Themes/Sublime Text/Retro98.sublime-color-scheme`.
- Test `Tests/Retro98ThemesTests/ThemeResourcesTests.swift`.

**Interfaces:** the three files hold exactly the values in Global Constraints → Chrome and → Sublime Text. All three are strict JSON (no comments, no trailing commas), so any JSON parser reads them.

- [ ] **Step 1: Write the failing tests** (each parses the file under `repoRoot/Resources/Themes` with `JSONSerialization`):
  - `chromeManifestIsAThemeWithTheClassicColors`:
    - `manifest_version == 3`, `name == "Retro98"`, `version == "1.0"`;
    - `theme.colors.frame == [0, 0, 128]`, `toolbar == [192, 192, 192]`, `ntp_background == [0, 128, 128]`, `tab_text == [0, 0, 0]`, `tab_background_text == [255, 255, 255]`;
    - `theme.images.theme_frame == "images/theme_frame.png"` and `theme_frame_inactive == "images/theme_frame_inactive.png"`;
    - `theme.properties.ntp_logo_alternate == 1`;
    - every color is an array of three integers from 0 to 255.
  - `chromeManifestOnlyNamesImagesTheToolWrites`: the image paths are exactly the two that `ThemeFiles` writes.
  - `sublimeThemeOnlyOverridesVariables`: the top-level keys are exactly `extends` and `variables`; `extends == "Default.sublime-theme"`; `variables.ui_bg == "#C0C0C0"`, `sidebar_row_selected == "#000080"`, `font_face == "Tahoma"`.
  - `sublimeColorSchemeIsBlackOnWhiteWithNavySelection`: `name == "Retro98"`; `globals.background == "#FFFFFF"`, `foreground == "#000000"`, `selection == "#000080"`, `selection_foreground == "#FFFFFF"`. The rules include scopes starting with `comment`, `string` and `keyword`, with `#008000`, `#800000` and `#0000FF`.
  - `sublimeColorsComeFromTheClassicPalette`: every `#RRGGBB` value in the color scheme is one of the 16 classic colors (`ConsolePalette.ansiHex`).
- [ ] **Step 2: Run** `swift test --filter ThemeResourcesTests`. Expected: FAIL (files not found).
- [ ] **Step 3: Write the three files** with the values from Global Constraints.
- [ ] **Step 4: Run** `swift test --filter ThemeResourcesTests`. Expected: PASS (5 tests).
- [ ] **Step 5: Commit** `feat: Chrome manifest and Sublime Text theme and color scheme`.

### Task 3: Instalar, desinstalar, README e versão

**Files:**
- Modify `scripts/common.sh`, `install.sh`, `uninstall.sh`, `scripts/build-app.sh` (`VERSION="0.10.0"`, `BUILD="11"`), `README.md`, `README.pt-BR.md`.
- Test `Tests/scripts/test_install.sh`, `Tests/scripts/test_uninstall.sh`.

**Interfaces (in `scripts/common.sh`):**
```bash
THEMES_DIR="$SUPPORT_DIR/Themes"
FONTS_DIR="${RETRO98_FONTS_DIR:-$HOME/Library/Fonts}"
SUBLIME_PACKAGES="${RETRO98_SUBLIME_PACKAGES:-$HOME/Library/Application Support/Sublime Text/Packages}"
VGA_FONT_FILE="PxPlus_IBM_VGA_8x16.ttf"

# Builds retro98-tools, writes the themes folder, installs the font (when absent) and the Sublime package
# (when Sublime Text is there), and says the step left in each app. Opens the folder the first time only.
install_themes()
# Removes what install_themes put: the theme files, the Sublime package's two files, and the font when the
# marker says Retro98 installed it. Returns 0 when there were themes to remove, 1 when there were none.
remove_themes()
```
- **`install.sh`:** the question after the Notepad's, the `themes`/`nothemes` migration line, the default `base shell prompt notepad themes`; `install_themes` or `remove_themes` after the Notepad block; the header comment lists the themes.
- **`uninstall.sh`:** `remove_themes` before the support folder is emptied; its hint is printed at the end when it returned 0.

- [ ] **Step 1: Write the failing script tests.** First, in **both** test files, export `RETRO98_FONTS_DIR="$WORK/fonts"` and `RETRO98_SUBLIME_PACKAGES="$WORK/sublime/Packages"` next to the other overrides, so no existing case can reach the real folders.
  - **`test_install.sh`** (create `$WORK/sublime/Packages` before the first install):
    - The four expected piece lines gain ` themes` at the end (`base shell prompt notepad themes`, and so on). The declined-Notepad case expects `base shell nonotepad prompt themes`.
    - `themes-written`: `Themes/Chrome/manifest.json`, both PNGs and `Themes/Retro98 Prompt.terminal` exist and are non-empty; `plutil -lint` accepts the `.terminal`.
    - `themes-font-installed`: `$WORK/fonts/PxPlus_IBM_VGA_8x16.ttf` equals the repo's font (`cmp`), and `Themes/.font-installed` exists.
    - `themes-sublime-installed`: both files are in `$WORK/sublime/Packages/Retro98/`.
    - `themes-steps-told`: the output mentions `chrome://extensions` and `Retro98 Prompt.terminal`.
    - `themes-folder-opened-once`: the first install logs `open $WORK/support/Themes`. After `: > "$WORK_LOG"` and a second install, that line is absent and `.font-installed` is still there.
    - New case `themes-keep-the-persons-font`: a fresh support folder and a fonts folder holding a different file under the font's name → after installing, that file is unchanged and there is no `.font-installed`.
    - New case `themes-without-sublime`: `RETRO98_SUBLIME_PACKAGES` pointing to a missing folder → the output says "Sublime Text não encontrado|Sublime Text not found" and the folder still doesn't exist.
    - New case `declined-themes-are-removed`: pieces `base nothemes` after an install with themes, plus an extra `minha.txt` put in `Packages/Retro98/`:
      - `Themes` is gone, and so is the font;
      - the Sublime package's two files are gone, while `minha.txt` and its folder stay;
      - the pieces file keeps `nothemes`.
  - **`test_uninstall.sh`:**
    - `run_shell_case` plants the themes folder (manifest, two PNGs, `.terminal`, `.font-installed`), the font and the Sublime package. When the apps are removed it expects all of that gone and the support folder gone. When the restore failed (`expected_app == present`), everything is still there.
    - New `themes_note_case`: with themes, the output has "Temas removidos|Themes removed". Without themes, it doesn't.
    - New case `uninstall-keeps-the-persons-font`: the font present without the marker survives the uninstall.
- [ ] **Step 2: Run** `bash Tests/scripts/test_install.sh; bash Tests/scripts/test_uninstall.sh`. Expected: the new checks FAIL, and nothing is created in the real `~/Library/Fonts` or Sublime Text folder.
- [ ] **Step 3: Implement** the script changes.
  - **`install_themes`:**
    - `swift build -c release --product retro98-tools`, then `retro98-tools themes "$RETRO98_ROOT/Resources/Fonts/$VGA_FONT_FILE" "$THEMES_DIR"`;
    - copy `manifest.json` into `Themes/Chrome/`;
    - font and Sublime package as in Global Constraints;
    - `open "$THEMES_DIR"` only when the folder didn't exist before this run.
  - **`remove_themes`:** delete only the named files, then `rmdir` each folder (silently, so a folder with someone's files stays).
  - **READMEs (both languages, same content):**
    - "Situação": phase 7 "✅ disponível" / "✅ available".
    - New section "Temas (Fase 7)" / "Themes (Phase 7)" after the Notepad's:
      - what each theme looks like;
      - the step to turn each one on (Chrome, Sublime Text, Terminal) and how to turn it off again;
      - that the font goes to `~/Library/Fonts` only if it wasn't there;
      - that Retro98 never edits those apps' settings.
    - Install and uninstall sections mention the themes piece. Credits: the font line also names the Terminal profile.
- [ ] **Step 4: Run** `bash Tests/scripts/test_install.sh && bash Tests/scripts/test_uninstall.sh && bash Tests/scripts/test_signing.sh`. Expected: every line PASS; `security list-keychains -d user` unchanged; `ls ~/Library/Fonts | grep -c PxPlus` and the listing of Sublime's `Packages` the same as before the run. Then `swift test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: install the themes for Chrome, Sublime Text and Terminal (0.10.0)`.

---

## Checagem manual (depois do merge, no Mac do autor)

1. `./install.sh --yes` → a pasta de temas abre no Finder, com `Chrome` e `Retro98 Prompt.terminal`.
2. Chrome: em `chrome://extensions`, ligar o Modo do desenvolvedor e arrastar a pasta `Chrome` → moldura azul-marinho em degradê, barra cinza, nova aba verde-azulada. Conferir a leitura das abas em segundo plano e a janela inativa.
3. Sublime Text: Preferences › Select Theme… › Retro98 e Select Color Scheme… › Retro98 → interface cinza com Tahoma, árvore branca com seleção azul-marinho, código preto no branco com palavras-chave azuis e comentários verdes.
4. Terminal: dois cliques em `Retro98 Prompt.terminal` → janela preta 80×25 com a fonte VGA nítida; o perfil padrão continua o mesmo.
5. `./uninstall.sh` → o aviso dos temas aparece; a fonte e o pacote do Sublime somem; Chrome, Terminal e Sublime continuam abrindo.
