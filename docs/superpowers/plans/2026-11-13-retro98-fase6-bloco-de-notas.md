# Retro98 Fase 6 — Bloco de Notas — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Entregar o Retro98 Notepad (Bloco de Notas):
- um editor de texto puro numa janela 98, com os menus Arquivo, Editar (com Hora/data), Pesquisar (Localizar, Localizar próxima) e Formatar (Quebra automática de linha);
- lê e grava UTF-8, mantendo as quebras de linha que o arquivo já tinha;
- abre e salva pelos diálogos retrô de abrir e salvar, que nascem nesta fase como peça da base.

**Architecture:**
- **`Retro98UI`** ganha as peças que faltam para diálogos:
  - `RetroTextField` (sai do Shell), `RetroDropDown` e `RetroGroupBox`;
  - `VGAFont` (sai do Prompt, porque o Bloco de Notas usa a mesma fonte);
  - o ícone do Bloco de Notas.
- **`Retro98FilesCore`** ganha `FileDialogLogic`, a regra dos diálogos sem tela: listar, entender o nome digitado e montar a lista "Examinar".
- **`Retro98Dialogs`** (biblioteca nova) monta o diálogo retrô de abrir e salvar sobre essas duas. Ele também passa a guardar o ícone de cada tipo de arquivo, que hoje fica no Explorer.
- **`Retro98Notepad`** (app novo) junta:
  - o arquivo de texto (UTF-8, quebras de linha, BOM, gravar sem estragar o original);
  - a janela com a área de texto nítida;
  - Localizar e Hora/data;
  - várias janelas e as perguntas de salvar.
- **Scripts:** a peça `notepad` no instalador, a remoção no desinstalador e os tipos de documento no `build-app.sh`, para o app aparecer em "Abrir com".

**Tech Stack:** Swift 6, AppKit (`NSTextView`), CoreText, Swift Testing, bash.

**Spec:** `docs/superpowers/specs/2026-11-10-retro-desktop-design.md`, seção "Fase 6 — Bloco de Notas (e talvez visualizador de imagens)", mais a seção 5, que lista os "diálogos de abrir e salvar próprios" entre os componentes da base. As Fases 1 a 5 e a correção das permissões estão no `main` (0.8.1).

## Global Constraints

- **Herança:** tudo das fases anteriores continua valendo:
  - pixel 1x, Tahoma 13 e negrito 12 na interface, paleta clássica, só material original;
  - pt-BR e en, só APIs públicas;
  - os apps do macOS (TextEdit incluído) ficam intactos.
- **Testes isolados, mais estes cuidados:**
  - Nenhum teste usa a área de transferência geral, as preferências reais (`NotepadPreferences.memory`) ou o LaunchServices.
  - Nenhum teste abre diálogo ou caixa de mensagem na tela: os prompters e os diálogos são roteiros.
  - Arquivos só em pastas temporárias.
  - Os scripts continuam com o `retro98-settings` falso, assinatura ad-hoc, `RETRO98_TCCUTIL`/`RETRO98_DEFAULTS` falsos e pastas temporárias.
- **Nomes [minha escolha]:**
  - App `Retro98 Notepad`, id `io.github.matheushchaves.retro98.notepad`, em `~/Applications/Retro98/Retro98 Notepad.app`.
  - Na janela: "Bloco de Notas" / "Notepad".
- **Fonte do texto [minha escolha]:**
  - PxPlus IBM VGA 8x16 a 16 pt, a mesma do Prompt, sem suavização: preto `#000000` sobre branco `#FFFFFF`.
  - Seleção `#000080` com texto branco, cursor preto.
  - É o equivalente livre da fonte de terminal que o bloco de notas clássico usava, e fica nítida em qualquer escala inteira.
  - A pasta `Resources/Prompt` passa a se chamar `Resources/Fonts`, porque os dois apps a copiam.
- **Texto [minha escolha]:**
  - **Formato:** só UTF-8, com ou sem BOM (um BOM que existia volta ao salvar).
  - **Quebras de linha:** a mais comum do arquivo entre CRLF, LF e CR; empate fica com a que aparece primeiro, e arquivo sem quebra conta como LF. Na edição tudo vira `\n`; ao salvar, todas as quebras viram a do arquivo. Isso inclui CRLF ou CR colados de fora, para nunca sair `\r\r\n`.
  - **Recusa de abrir**, com mensagem e sem abrir nada: arquivo que não é UTF-8 válido, que tem byte zero (binário) ou que passa de 10 MB (10.485.760 bytes).
  - **Arquivo novo:** UTF-8 sem BOM, LF.
- **Gravar [minha escolha]:**
  - Um link simbólico é seguido: grava no arquivo para onde ele aponta e o link continua link.
  - Arquivo que já existe é trocado com `FileManager.replaceItemAt`, que mantém permissões e data de criação. Se a gravação falhar, o original fica como estava.
  - Arquivo novo é gravado com `.withoutOverwriting`.
- **Diálogos de abrir e salvar [minha escolha]:**
  - **Janela:** `RetroWindow` modal de tamanho fixo, conteúdo 430×266. Títulos "Abrir"/"Open" e "Salvar como"/"Save As".
  - **Linha de cima:** "Examinar:"/"Look in:" (no salvar, "Salvar em:"/"Save in:"), uma lista suspensa de lugares e o botão "Um nível acima" (ícone `FileIcons.up`).
  - **Meio:** os arquivos no modo lista do `RetroIconGrid`, em moldura afundada.
  - **Embaixo:** "Nome do arquivo:"/"File name:" com campo e o botão "Abrir"/"Open" ou "Salvar"/"Save" (padrão). Depois "Arquivos do tipo:"/"Files of type:" (no salvar, "Salvar como tipo:"/"Save as type:") com lista suspensa e "Cancelar"/"Cancel".
  - **Lugares** ("Examinar"):
    - Área de Trabalho (nível 0) e cada volume montado (nível 1);
    - sob o volume da pasta atual, a cadeia de pastas até ela (nível 2 em diante, dois espaços por nível);
    - Meus Documentos (nível 1). Os nomes vêm de `ExplorerText`.
  - **O que aparece:** pastas e os arquivos que o tipo escolhido deixa passar. Ficam de fora os escondidos e os pacotes (.app e outros).
  - **Cliques e teclas:**
    - Um clique num arquivo põe o nome dele no campo.
    - Duplo clique ou Enter numa pasta entra nela; num arquivo, escolhe.
    - Esc e × cancelam.
  - **O que o campo aceita:** nome, caminho relativo, caminho absoluto ou `~/…`. Nome de pasta entra nela e limpa o campo.
    - **Abrir:** um arquivo que não existe dá aviso "<nome>\nArquivo não encontrado.\nVerifique se o nome do arquivo está correto." (en: "<name>\nFile not found.\nCheck the file name and try again.").
    - **Salvar:** sem extensão, ganha a do tipo escolhido (".txt"; "Todos os arquivos" não acrescenta nada).
      - Se já existe, pergunta "<nome> já existe.\nDeseja substituí-lo?" com Sim/Não (en: "<name> already exists.\nDo you want to replace it?", Yes/No; ícone de aviso).
      - Nome com ":" dá "<nome>\nO nome do arquivo não é válido." (en: "<name>\nThe file name is not valid.").
      - Pasta que não existe dá "<caminho>\nO caminho não existe.\nVerifique se o caminho está correto." (en: "<path>\nThe path does not exist.\nCheck the path and try again.").
  - **Pasta que o macOS recusa ou que sumiu:** "Não foi possível abrir <pasta>: o macOS não deu acesso a essa pasta ou ela não existe mais." (en: "Can't open <folder>: macOS didn't allow access to it or it no longer exists."). O diálogo fica onde estava.
  - **Fora desta fase:** "Criar nova pasta", modo detalhes e curingas (`*.log`) no campo. Pastas novas se criam no Explorer.
- **Janela do Bloco de Notas [minha escolha]:**
  - `RetroAppWindow` com o ícone 16, conteúdo 660×444.
  - Por dentro: barra de menus retrô (22) e linha gravada (2). Abaixo, a área de texto numa moldura afundada, com `RetroScroller` vertical e, sem quebra de linha, também horizontal.
  - Título "<nome do arquivo> - Bloco de Notas", ou "Sem título - Bloco de Notas" (en: "<file name> - Notepad", "Untitled - Notepad").
  - Uma janela por documento, sem abas, abrindo em cascata (22 pt).
- **Documento [minha escolha]:**
  - **Novo ⌘N** abre uma janela vazia.
  - **Abrir ⌘O** usa a janela ativa se ela estiver intocada (sem arquivo, sem alteração, vazia); senão abre outra. Um arquivo já aberto só vem para a frente.
  - **Salvar** num documento sem título vira "Salvar como". O nome sugerido é "Sem título.txt"/"Untitled.txt", selecionado.
  - **Pasta inicial dos diálogos:** a do documento; senão a última usada no app nesta sessão; senão `~/Documents`.
  - **Fechar ou encerrar com alteração** pergunta "O texto no arquivo <nome> foi alterado.\n\nDeseja salvar as alterações?" com Sim/Não/Cancelar (en: "The text in the <name> file has changed.\n\nDo you want to save the changes?", Yes/No/Cancel; ícone de aviso).
    - Cancelar, ou cancelar o "Salvar como" que veio do Sim, mantém a janela.
    - Ao encerrar, pergunta janela por janela.
- **Erros de arquivo [minha escolha]** (ícone de erro):
  - **Não é UTF-8:** "Não foi possível abrir <nome>: o arquivo não é texto em UTF-8." / "Can't open <name>: the file isn't UTF-8 text."
  - **Binário:** "Não foi possível abrir <nome>: o arquivo não parece ser texto." / "Can't open <name>: the file doesn't look like text."
  - **Grande demais:** "Não foi possível abrir <nome>: o arquivo passa de 10 MB, o limite do Bloco de Notas." / "Can't open <name>: the file is over 10 MB, Notepad's limit."
  - **Ilegível:** "Não foi possível abrir <nome>: o arquivo não pôde ser lido." / "Can't open <name>: the file couldn't be read."
  - **Falha ao salvar:** "Não foi possível salvar <nome>. Verifique se você pode gravar nessa pasta e se há espaço no disco." / "Couldn't save <name>. Check that you can write to that folder and that the disk has room."
- **Menus [minha escolha]** (iguais na barra do macOS e dentro da janela, como no Prompt):
  - **Arquivo:** Novo ⌘N, Abrir… ⌘O, Salvar ⌘S, Salvar como… ⇧⌘S, —, Fechar ⌘W.
  - **Editar:** Desfazer ⌘Z, Refazer ⇧⌘Z, —, Recortar ⌘X, Copiar ⌘C, Colar ⌘V, Excluir, —, Selecionar tudo ⌘A, Hora/data F5.
  - **Pesquisar:** Localizar… ⌘F, Localizar próxima ⌘G.
  - **Formatar:** Quebra automática de linha (com marca).
  - **Ajuda:** Ajuda do Retro98 (README), —, Sobre o Retro98 Notepad.
  - **Só na barra do macOS:**
    - menu do app: Sobre (crédito da fonte), Ocultar ⌘H, Ocultar Outros ⌥⌘H, Mostrar Tudo, Encerrar ⌘Q;
    - Janela: Minimizar ⌘M, Zoom, Trazer Tudo para a Frente.
  - Os títulos em inglês seguem o Prompt e o Explorer: File/New/Open…/Save/Save As…/Close, Edit/Undo/Redo/Cut/Copy/Paste/Delete/Select All/Time/Date, Search/Find…/Find Next, Format/Word Wrap, Help.
  - A quebra de linha começa desligada, vale para todas as janelas e é lembrada entre aberturas (`UserDefaults` do app, chave `WordWrap`).
  - Sem "Ajustes…", como no Prompt e no Explorer, porque não há o que ajustar.
  - Fora desta fase: Imprimir e Configurar página. O texto continua imprimível pelo TextEdit.
- **Hora/data [minha escolha]:**
  - Insere "<hora curta> <data curta>" do idioma e fuso do Mac, no lugar da seleção, e pode ser desfeita.
  - Exemplos: pt-BR "14:05 13/11/2026"; en-US "2:05 PM 11/13/26". Antes de "PM", o macOS põe um espaço estreito (U+202F), medido em 2026-11-13.
- **Localizar [minha escolha]:**
  - Janela retrô sem modal, flutuante, uma só para o app.
  - Conteúdo: "Localizar:"/"Find what:" com campo; "Diferenciar maiúsculas e minúsculas"/"Match case"; grupo "Direção"/"Direction" com "Acima"/"Up" e "Abaixo"/"Down" (padrão Abaixo); botões "Localizar próxima"/"Find Next" (padrão, desligado com o campo vazio) e "Cancelar"/"Cancel".
  - A busca parte da seleção e não dá a volta no texto. Sem resultado, avisa "Não foi possível localizar "<texto>"" / "Cannot find "<texto>"" (ícone de informação, título "Bloco de Notas"/"Notepad").
  - "Localizar próxima" sem texto buscado abre a janela.
- **Abrir de fora [minha escolha]:**
  - O app declara `public.plain-text` como tipo de documento, com papel Editor e `LSHandlerRank` `Alternate`. Assim aparece em "Abrir com" (Finder e Explorer) e aceita arquivos arrastados para o ícone ou `open -a`, sem virar o app padrão do .txt.
- **Instalação [minha escolha]:**
  - **Peça `notepad`**: pergunta "Instalar o Bloco de Notas?" (padrão sim). Recusar grava `nonotepad`.
  - **Com `--yes`:** um arquivo de peças sem `notepad` nem `nonotepad` ganha `notepad`, porque peça nova chega ligada. Sem arquivo, as peças são `base shell prompt notepad`.
  - **Desmarcar ou desinstalar:** encerra, desregistra e apaga o app. O desinstalador também apaga as permissões dele (`forget_permissions`).
  - O app aparece sozinho em Iniciar › Programas › Retro98.
- **Fora desta fase:** o visualizador de imagens, que a spec marca como opcional.
- **Versão:** 0.9.0 (build 10).

## Review Focus

1. **Salvar por cima de um arquivo que já existe** (com CRLF, com BOM, permissão 0600, através de um link simbólico, numa pasta sem escrita):
   - o arquivo continua o que era, só com o texto novo;
   - uma falha deixa o original intacto e avisa.
   - Testes das Tasks 1 e 5.
2. **Abrir algo que não é texto UTF-8** (binário, Latin-1, 50 MB): mensagem clara, nada aberto, e nenhuma chance de salvar lixo por cima. Testes das Tasks 1 e 5.
3. **Fechar ou encerrar com alterações**, inclusive cancelando o "Salvar como" que veio do "Sim": o texto nunca se perde. Testes das Tasks 5 e 7.
4. **Pastas que o macOS recusa** (Mesa ou Documentos sem permissão, pasta sem leitura) **e caminhos inexistentes digitados no diálogo:** aviso, e o diálogo fica onde estava. Testes das Tasks 3 e 4.
5. **Colar texto com quebras do Windows** num documento LF ou CRLF: o arquivo salvo sai com uma só quebra, nunca `\r\r\n`. Teste da Task 1.

## Estrutura de arquivos

| Arquivo | Responsabilidade |
|---|---|
| `Package.swift` | Alvos `Retro98Dialogs`, `Retro98Notepad` e os de teste; o Explorer passa a depender de `Retro98Dialogs` |
| `Resources/Fonts/` (antes `Resources/Prompt/`) | Fonte VGA e licença, copiadas para o Prompt e o Bloco de Notas |
| `Sources/Retro98UI/VGAFont.swift` | Registrar e criar a fonte VGA (sai de `Retro98Prompt/PromptFont.swift`) |
| `Sources/Retro98UI/RetroTextField.swift` | Campo de texto branco afundado (sai de `Retro98Shell/RunDialog.swift`) |
| `Sources/Retro98UI/RetroDropDown.swift` | Lista suspensa: campo com ícone, texto e seta, abrindo um `RetroMenu` |
| `Sources/Retro98UI/RetroGroupBox.swift` | Moldura gravada com título |
| `Sources/Retro98UI/FileIcons.swift`, `Sources/retro98-tools/main.swift` | Ícone do Bloco de Notas e o `iconset notepad` |
| `Sources/Retro98FilesCore/FileDialogLogic.swift` | Filtro de tipo, listagem, nome digitado → ação, lugares |
| `Sources/Retro98Dialogs/FileKindIcons.swift` | `FileKind.iconKind` (sai de `ExplorerIcons`) |
| `Sources/Retro98Dialogs/FileDialogText.swift` | Textos pt-BR/en dos diálogos |
| `Sources/Retro98Dialogs/FileDialogPrompter.swift` | Perguntas e avisos dos diálogos (caixa 98; roteiro nos testes) |
| `Sources/Retro98Dialogs/FileDialogController.swift` | A janela do diálogo e o comportamento dela |
| `Sources/Retro98Dialogs/RetroFileDialog.swift` | `run(...)` modal |
| `Sources/Retro98Notepad/TextFile.swift` | Ler, decodificar, codificar e gravar o arquivo |
| `Sources/Retro98Notepad/NotepadText.swift` | Textos pt-BR/en, título, Hora/data, tipos de arquivo |
| `Sources/Retro98Notepad/NotepadPreferences.swift` | Quebra de linha lembrada |
| `Sources/Retro98Notepad/NotepadServices.swift` | Protocolos de diálogos e perguntas, com as versões reais |
| `Sources/Retro98Notepad/NotepadTextView.swift` | `NSTextView` nítida e configurada para texto puro |
| `Sources/Retro98Notepad/NotepadWindowController.swift` | Janela, documento, salvar, fechar, Hora/data, quebra de linha |
| `Sources/Retro98Notepad/TextSearch.swift`, `FindDialog.swift` | Busca e a janela Localizar |
| `Sources/Retro98Notepad/NotepadMenus.swift`, `AppDelegate.swift`, `main.swift` | Menus, várias janelas, abrir de fora, encerrar |
| `scripts/build-app.sh`, `scripts/common.sh`, `install.sh`, `uninstall.sh` | Tipos de documento, peça `notepad`, remoção, versão |
| `README.md`, `README.pt-BR.md` | Seção do Bloco de Notas, situação, créditos |
| `Tests/…` | Testes de cada parte |

---

### Task 1: O arquivo de texto

**Files:**
- Create `Sources/Retro98Notepad/TextFile.swift` and `Sources/Retro98Notepad/main.swift`. The second is temporary (only `import AppKit`) until Task 7.
- Modify `Package.swift`:
  - `.executable(name: "Retro98Notepad", targets: ["Retro98Notepad"])`;
  - `.executableTarget(name: "Retro98Notepad", dependencies: ["Retro98UI", "Retro98FilesCore", "Retro98Settings"])`;
  - `.testTarget(name: "Retro98NotepadTests", dependencies: ["Retro98Notepad", "Retro98UI"])`.
- Test `Tests/Retro98NotepadTests/TextFileTests.swift` and `Tests/Retro98NotepadTests/TestSupport.swift`. The second provides `temporaryFolder() throws -> URL` (under `FileManager.default.temporaryDirectory`, `retro98-notepad-<UUID>`) and `repoRoot`.

**Interfaces:**
```swift
enum LineEnding: String, Equatable, Sendable { case lf = "\n", crlf = "\r\n", cr = "\r" }
enum TextFileError: Error, Equatable { case notUTF8, notText, tooLarge, unreadable }

struct TextFile: Equatable, Sendable {
    static let maximumSize = 10_485_760
    static let empty = TextFile(text: "", lineEnding: .lf, hasBOM: false)
    /// Line breaks are always "\n" here.
    var text: String
    var lineEnding: LineEnding
    var hasBOM: Bool
    static func decode(_ data: Data) throws(TextFileError) -> TextFile
    /// Stray "\r\n" and "\r" in `text` (pasted from elsewhere) count as line breaks too.
    func encoded() -> Data
    /// Checks the size before reading (fileSize resource value).
    static func read(from url: URL) throws(TextFileError) -> TextFile
    /// Follows a symlink; replaces an existing file keeping its permissions; a failure leaves it untouched.
    func write(to url: URL) throws
}
```

- [ ] **Step 1: Write the failing tests** in `TextFileTests.swift`:
  - `decodeUsesTheFilesLineEnding`: `"a\r\nb\r\n"` → text `"a\nb\n"`, `.crlf`; `"a\rb"` → `.cr`; `"a"` → `.lf`.
  - `decodeTakesTheMostCommonEnding`: `"a\r\nb\nc\nd"` → `.lf`, text `"a\nb\nc\nd"`.
  - `decodeTieGoesToTheFirstEnding`: `"a\rb\nc"` → `.cr`.
  - `decodeKeepsTheBOM`: `Data([0xEF, 0xBB, 0xBF]) + Data("oi".utf8)` → text `"oi"`, `hasBOM == true`, and `encoded()` gives the same bytes back.
  - `roundTripIsExact`: `decode(d).encoded() == d` for each of `"a\r\nb\r\n"`, `"a\nb"`, `"a\rb\r"`, `"\u{FEFF}ação\r\n"`, `""` (as UTF-8 data).
  - `decodeRefusesNonUTF8`: `Data([0x61, 0xE7, 0x61])` throws `.notUTF8`.
  - `decodeRefusesBinary`: `Data("a\u{0}b".utf8)` throws `.notText`.
  - `encodedNormalizesPastedBreaks`: `TextFile(text: "a\r\nb\rc\n", lineEnding: .crlf, hasBOM: false).encoded() == Data("a\r\nb\r\nc\r\n".utf8)`.
  - `readRefusesFilesOverTheLimit`: a file of `maximumSize + 1` bytes, made sparse with `FileHandle.truncate(atOffset:)`, throws `.tooLarge`. A file of exactly `maximumSize` zero bytes throws `.notText` (it passed the size check).
  - `readMissingFileIsUnreadable`: throws `.unreadable`.
  - `writeKeepsPermissions`: existing file with `0o600` → `write` → content is the new bytes and `posixPermissions == 0o600`.
  - `writeThroughSymlinkKeepsTheLink`: `link → real.txt`; write via `link` → `link` is still a symlink (`destinationOfSymbolicLink` unchanged) and `real.txt` has the new bytes.
  - `writeCreatesNewFile`.
  - `failedWriteLeavesTheOriginal`: the folder has an existing file and is `chmod 0o500` → `write` throws and the original bytes are unchanged. Restore `0o700` in `defer`.
- [ ] **Step 2: Run** `swift test --filter TextFileTests`. Expected: FAIL (`TextFile` not found).
- [ ] **Step 3: Implement `TextFile` in `Sources/Retro98Notepad/TextFile.swift`**:
  - **Decode:** strip the BOM, then `String(data:encoding: .utf8)`. Refuse NUL with `data.contains(0)` before decoding.
  - **Line endings:** count them on the UTF-8 bytes in one pass (`\r\n` as one).
  - **Write:** use `resolvingSymlinksInPath()`. For an existing target, write a temporary copy in `FileManager.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: target, create: true)`, then `replaceItemAt(target, withItemAt:)`. Remove the temporary folder in `defer`.
- [ ] **Step 4: Run** `swift test --filter TextFileTests`. Expected: PASS (14 tests).
- [ ] **Step 5: Commit** `feat: Notepad text file with UTF-8, line endings and safe saving`.

### Task 2: Peças da base (fonte, campo, lista suspensa, moldura, ícone)

**Files:**
- **Create in `Sources/Retro98UI/`:** `VGAFont.swift`, `RetroTextField.swift`, `RetroDropDown.swift`, `RetroGroupBox.swift`.
- **Modify:**
  - `Sources/Retro98UI/RetroButton.swift` (`isEnabled`, needed by the dialog's up button and Find's "Localizar próxima");
  - `Sources/Retro98UI/FileIcons.swift` and `Sources/retro98-tools/main.swift` (new `notepad` icon);
  - `Sources/Retro98Shell/RunDialog.swift` (drop its private `RetroTextField`);
  - `Sources/Retro98Prompt/*` (`PromptFont` → `VGAFont`; delete `PromptFont.swift`);
  - `install.sh:163` (`Resources/Fonts`);
  - both READMEs' credits line (path, and "Prompt and Notepad font" / "Fonte do Prompt e do Bloco de Notas").
- **Move** `git mv Resources/Prompt Resources/Fonts`.
- **Tests:**
  - Create `Tests/Retro98UITests/VGAFontTests.swift`, moved from `Tests/Retro98PromptTests/PromptFontTests.swift` (delete that file);
  - create `Tests/Retro98UITests/DialogControlsTests.swift`;
  - modify `Tests/Retro98UITests/FileIconTests.swift`;
  - modify `Tests/Retro98PromptTests/TestSupport.swift`, where `vgaFontURL` points to `Resources/Fonts`.

**Interfaces:**
```swift
public enum VGAFont {                       // same API PromptFont had, now public
    public static let fileName = "PxPlus_IBM_VGA_8x16.ttf"
    public static let postScriptName = "PxPlus_IBM_VGA_8x16"
    public static let size: CGFloat = 16
    @discardableResult public static func register(at url: URL) -> Bool
    public static var bundledURL: URL? { get }
    public static func make() -> NSFont
}
@MainActor public final class RetroTextField: PixelView, NSTextFieldDelegate {   // RunDialog's, now public
    public static let height: CGFloat = 23
    public override init(frame: CGRect)
    public var text: String { get set }
    public var onSubmit: (() -> Void)?
    public var onChange: (() -> Void)?        // every edit (controlTextDidChange)
    public func focus(in window: NSWindow)    // first responder, text selected
}
@MainActor public final class RetroDropDown: PixelView {
    public static let height: CGFloat = 22
    public static let arrowWidth: CGFloat = 16
    public var items: () -> [RetroMenuItem]
    public private(set) var text: String
    public init(items: @escaping () -> [RetroMenuItem])
    public func set(text: String, icon: PixelIcon?)
    /// The arrow button, inside the 2-pt field border on the right.
    nonisolated public static func arrowFrame(in bounds: CGRect) -> CGRect
}
@MainActor public final class RetroGroupBox: PixelView {
    public init(title: String)
}
extension RetroButton {
    /// Off: the title is drawn in shadow gray; clicks, Space, Enter (as default button) and performClick do nothing.
    public var isEnabled: Bool { get set }   // stored property on the class, default true
}
extension FileIcons {
    public static let notepadApp: PixelIcon       // 32
    public static let notepadAppSmall: PixelIcon  // 16
}
```

- [ ] **Step 1: Write the failing tests:**
  - **`VGAFontTests`:** the old `PromptFontTests` cases, now on `VGAFont`, with the font at `Resources/Fonts/PxPlus_IBM_VGA_8x16.ttf`.
  - **`DialogControlsTests`:**
    - `textFieldReportsEdits`: setting `text` then sending `controlTextDidChange` calls `onChange`. `text` round-trips.
    - `dropDownArrowSitsInsideTheBorder`: `arrowFrame(in: CGRect(x: 0, y: 0, width: 200, height: 22)) == CGRect(x: 182, y: 2, width: 16, height: 18)`.
    - `dropDownDrawsItsText`: render a 200×22 drop-down after `set(text: "Documentos", icon: nil)`. Use the existing pixel helpers in `PixelTestHelpers.swift`. The field interior has white and black pixels, and the arrow has face pixels.
    - `groupBoxDrawsAnEtchedFrame`: in a 120×60 box titled "Direção", the pixel at (0, 30) is shadow `#808080` and at (1, 30) is white. The top line at y = 7 is shadow beyond the title (x = 100).
    - `disabledButtonDoesNothing`: with `isEnabled = false`, `performClick()` doesn't run the action. A 75×23 render has shadow-gray text pixels and no black ones inside the bevel.
  - **`FileIconTests`:**
    - `notepadIconIsAPageWithBlueLines`: the 16 icon has white pixels and blue `#0000FF` pixels.
    - The `iconset` tool's art covers `notepad`: add `"notepad"` to the existing iconset case list.
- [ ] **Step 2: Run** `swift test --filter "VGAFontTests|DialogControlsTests|FileIconTests"`. Expected: FAIL (types not found).
- [ ] **Step 3: Implement:**
  - **Moves:** `VGAFont` is `PromptFont` moved and made public. `RetroTextField` is RunDialog's class moved, plus `onChange` and `height`. The Shell and Prompt use them, and `Resources/Prompt` becomes `Resources/Fonts`.
  - **`RetroDropDown`:**
    - Draw: `Bevel.draw(.field, …)` around a white interior, the icon at x 4, the text after it (x 4, or 24 with an icon) cut with `RetroText.fit`, and a raised arrow button with a black down triangle.
    - Click: a mouse-down anywhere opens a `RetroMenu(items: items(), style: .standard)` under the box. While open, a click on the box closes it, as the Explorer's `AddressBar` does.
  - **`RetroGroupBox`:** etched rectangle (shadow line, then white line 1 pt right and down) from y = 7. The title sits at x 8 on the face color with 2 pt padding.
  - **`RetroButton.isEnabled`:** a stored `var` with `didSet { needsDisplay = true }`. Guard `performClick`, `mouseUp` and `keyDown` with it; `acceptsFirstResponder` returns it; the title is drawn in `Palette.shadow` when off, like `RetroCheckBox`.
  - **Notepad icon:** on the 16 grid:
    - a white page `box(2, 1, 12, 14)` with black outline;
    - a dark-gray spiral of rings at y 0–2 (x 4, 7, 10);
    - blue lines at y 5, 7, 9, 11 from x 4 to 11.
    - Add `case "notepad"` to `retro98-tools`, including its usage and error texts.
- [ ] **Step 4: Run** `swift test`. Expected: PASS (whole suite, since the Prompt and Shell moved). Also run `bash Tests/scripts/test_install.sh`, which checks `prompt-has-font` from the new folder. Expected: all PASS.
- [ ] **Step 5: Commit** `feat: shared text field, drop-down, group box and VGA font in the retro kit`.

### Task 3: A regra dos diálogos (sem tela)

**Files:**
- Create `Sources/Retro98FilesCore/FileDialogLogic.swift`.
- Modify `Sources/Retro98FilesCore/FolderListing.swift` to add a `public init` to `VolumeInfo`.
- Test `Tests/Retro98FilesCoreTests/FileDialogLogicTests.swift`, using the existing `TempTree.swift`.

**Interfaces:**
```swift
public enum FileDialogMode: Sendable { case open, save }

public struct FileTypeFilter: Equatable, Sendable {
    public let title: String
    /// Lowercased, no dot; empty lets every file through.
    public let extensions: [String]
    public init(title: String, extensions: [String])
    public var defaultExtension: String? { get }       // extensions.first
    public func matches(_ url: URL) -> Bool             // case-insensitive extension
}

public enum FileDialogOutcome: Equatable, Sendable {
    case nothing                    // empty field
    case navigate(URL)              // a folder: show it
    case choose(URL)                // done
    case confirmReplace(URL)        // save over an existing file: ask first
    case notFound(String)           // open: no such file (the typed text)
    case invalidName(String)        // save: ":" in the name
    case folderNotFound(String)     // save: the folder part doesn't exist (its path)
}

public struct FileDialogPlace: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case desktop, documents, volume(VolumeKind), folder }
    public let url: URL
    public let name: String
    public let kind: Kind
    public let depth: Int
}

public enum FileDialogLogic {
    /// Subfolders and the files `filter` lets through; no hidden files, no packages; folders first.
    public static func entries(of folder: URL, filter: FileTypeFilter, fileManager: FileManager = .default)
        throws(FolderListingError) -> [FileEntry]
    /// What pressing Open/Save with `text` in the name field does, from `folder`.
    public static func resolve(_ text: String, in folder: URL, mode: FileDialogMode, filter: FileTypeFilter, home: URL,
                               fileManager: FileManager = .default) -> FileDialogOutcome
    /// Desktop; each volume, with the current folder's chain under its own volume; My Documents.
    public static func places(current: URL, home: URL, volumes: [VolumeInfo], languages: [String]) -> [FileDialogPlace]
}
```

- [ ] **Step 1: Write the failing tests.** The temp tree holds `b.txt`, `A.TXT`, `c.md`, `sub/`, `.hidden.txt` and `App.app/Contents/`.
  - **Listing:**
    - `entriesFilterByTypeAndSkipHiddenAndPackages`: names with `["txt"]` == `["sub", "A.TXT", "b.txt"]`; with `[]` == `["sub", "A.TXT", "b.txt", "c.md"]`.
    - `entriesOfUnreadableFolderThrow`: a folder with `chmod 0o000` throws `.permissionDenied` (restore in `defer`). A missing folder throws `.notFound`.
  - **`resolveForOpen`:**
    - `"b.txt"` → `.choose(root/b.txt)`; `"sub"` → `.navigate(root/sub)`; `"~"` → `.navigate(home)`;
    - `"<root>/b.txt"` (absolute) → `.choose`;
    - `"  "` → `.nothing`; `"nope.txt"` → `.notFound("nope.txt")`.
  - **`resolveForSave`:**
    - with the txt filter: `"nota"` → `.choose(root/nota.txt)`; `"nota.md"` → `.choose(root/nota.md)`;
    - with the all-files filter: `"nota"` → `.choose(root/nota)`;
    - `"b"` → `.confirmReplace(root/b.txt)`;
    - `"a:b"` → `.invalidName("a:b")`;
    - `"missing/x.txt"` → `.folderNotFound(root/missing path)`;
    - `"sub"` → `.navigate(root/sub)`.
  - **`placesNestTheCurrentFolderUnderItsVolume`:**
    - Input: volumes `/` "Macintosh HD" (internal) and `/Volumes/PEN` "PEN" (removable); current `/Volumes/PEN/fotos/2024`; home `/Users/u`.
    - Names and depths: `[("Área de Trabalho", 0), ("Macintosh HD", 1), ("PEN", 1), ("fotos", 2), ("2024", 3), ("Meus Documentos", 1)]` with languages `["pt-BR"]`.
    - Kinds: `.desktop`, `.volume(.internal)`, `.volume(.removable)`, `.folder`, `.folder`, `.documents`.
    - Desktop and documents URLs are `home/Desktop` and `home/Documents`.
  - `placesAtAVolumeRootHaveNoChain`: current `/Volumes/PEN` gives no folder rows.
- [ ] **Step 2: Run** `swift test --filter FileDialogLogicTests`. Expected: FAIL (`FileDialogLogic` not found).
- [ ] **Step 3: Implement:**
  - **`entries`:** filter `FolderListing.entries(of:showHidden: false)`.
    - Keep `.folder`. Drop `.application` and any other entry that is a directory (`fileExists(atPath:isDirectory:)`).
    - Keep files that `filter.matches`.
  - **`resolve`:** trim spaces. Expand a leading `~` with `home`; absolute paths stay; anything else is relative to `folder`. Then `standardizedFileURL`.
    - An existing directory → `.navigate`.
    - Open: an existing file → `.choose`; else `.notFound(trimmed)`.
    - Save:
      - a name containing ":" → `.invalidName`;
      - a parent that isn't an existing directory → `.folderNotFound(parent.path)`;
      - no extension → add `filter.defaultExtension`;
      - the target is a directory → `.navigate`; it exists → `.confirmReplace`; else `.choose`.
  - **`places`:** the volume of `current` is `Volumes.containing(path:in:)`. Folder names come from `FileManager.default.displayName(atPath:)`. Desktop and My Documents names come from `ExplorerText.desktop` and `.myDocuments`.
- [ ] **Step 4: Run** `swift test --filter FileDialogLogicTests`. Expected: PASS (6 tests).
- [ ] **Step 5: Commit** `feat: file dialog rules for listing, typed names and places`.

### Task 4: O diálogo retrô de abrir e salvar

**Files:**
- **Create in `Sources/Retro98Dialogs/`:** `FileKindIcons.swift`, `FileDialogText.swift`, `FileDialogPrompter.swift`, `FileDialogController.swift`, `RetroFileDialog.swift`.
- **Modify `Package.swift`:**
  - `.library(name: "Retro98Dialogs", targets: ["Retro98Dialogs"])`;
  - `.target(name: "Retro98Dialogs", dependencies: ["Retro98UI", "Retro98FilesCore", "Retro98Settings"])`;
  - `.testTarget(name: "Retro98DialogsTests", dependencies: ["Retro98Dialogs", "Retro98FilesCore", "Retro98UI"])`;
  - add `"Retro98Dialogs"` to `Retro98Explorer`'s dependencies.
- **Modify the Explorer:** `Sources/Retro98Explorer/ExplorerWindowController.swift` deletes `enum ExplorerIcons` and uses `kind.iconKind`. `ExplorerTree.swift:106` does the same, and both `import Retro98Dialogs`.
- **Test** `Tests/Retro98DialogsTests/FileDialogControllerTests.swift`, with a copy of `TempTree.swift`.

**Interfaces:**
```swift
extension FileKind { public var iconKind: FileIconKind }      // ExplorerIcons.kind(for:) moved

@MainActor public protocol FileDialogPrompter: AnyObject {
    /// True for Yes.
    func confirmReplace(_ message: String, title: String, languages: [String]) -> Bool
    func tell(_ message: String, title: String, icon: MessageBoxIcon, languages: [String])
}
@MainActor public final class RetroFileDialogPrompter: FileDialogPrompter { public init() }  // RetroMessageBox: Sim/Não, OK

@MainActor public final class FileDialogController: RetroIconGridDataSource {
    public static let contentSize = CGSize(width: 430, height: 266)
    public let window: RetroWindow
    public private(set) var folder: URL
    public private(set) var entries: [FileEntry]
    public private(set) var filterIndex: Int
    /// The chosen file once the dialog finished with Open/Save; nil after Cancel.
    public private(set) var result: URL?
    public var onFinish: (() -> Void)?
    let nameField: RetroTextField
    let grid: RetroIconGrid
    let lookIn: RetroDropDown
    let typeBox: RetroDropDown
    let upButton: RetroButton
    let okButton: RetroButton
    /// Shows `folder`, or silently `home` when `folder` can't be listed.
    public init(mode: FileDialogMode, folder: URL, fileName: String, filters: [FileTypeFilter], languages: [String],
                home: URL = FileManager.default.homeDirectoryForCurrentUser,
                volumes: @escaping () -> [VolumeInfo] = { Volumes.mounted() },
                prompter: FileDialogPrompter = RetroFileDialogPrompter())
    /// Lists `folder`; false (with a message, staying where it was) when macOS refuses it or it's gone.
    @discardableResult public func show(_ folder: URL) -> Bool
    public func goUp()
    public func chooseFilter(at index: Int)
    /// Double-click or Enter on an item.
    public func activate(itemAt index: Int)
    /// The Open/Save button, and Enter in the name field.
    public func submit()
    public func cancel()
    func selectionChanged(_ selection: IndexSet)
    func placeItems() -> [RetroMenuItem]
}

public enum RetroFileDialog {
    /// Modal; the chosen file, or nil when cancelled.
    @MainActor public static func run(mode: FileDialogMode, folder: URL, fileName: String, filters: [FileTypeFilter],
                                      languages: [String]) -> URL?
}
```

- [ ] **Step 1: Write the failing tests** in `FileDialogControllerTests.swift`:
  - **Setup:** a temp tree with `b.txt`, `c.md` and `sub/`. A `ScriptedPrompter` records `told: [String]` and answers `confirmReplace` from a queue. Filters are txt (`["txt"]`) and all (`[]`). Use `volumes: { [] }` and the temp root as `home`.
  - **Listing and the name field:**
    - `listsTheFolderThroughTheFilter`: `entries.map(\.name) == ["sub", "b.txt"]`. After `chooseFilter(at: 1)`: `["sub", "b.txt", "c.md"]`.
    - `clickingAFileFillsTheName`: `selectionChanged([1])` gives `nameField.text == "b.txt"`. `selectionChanged([0])` (a folder) leaves it unchanged.
    - `typingAFolderOpensIt`: text `"sub"`, `submit()` → `folder` is `root/sub`, `nameField.text == ""`, `result == nil`.
  - **Open mode:**
    - `openChoosesAnExistingFile`: text `"b.txt"`, `submit()` → `result == root/b.txt`, and `onFinish` is called once.
    - `openMissingFileWarnsAndStays`: text `"x.txt"`, `submit()` → `told.last` contains `"x.txt"` and `"Arquivo não encontrado"` (languages `["pt-BR"]`). `result == nil` and `onFinish` is not called.
    - `activatingAFolderOpensItAndAFileChoosesIt`: `activate(itemAt: 0)` moves into `sub`. Back at the root, `activate(itemAt: 1)` gives `result == root/b.txt`.
  - **Save mode:**
    - `saveAddsTheTypesExtension`: text `"nota"` → `result == root/nota.txt`.
    - `saveOverExistingFileAsks`: text `"b.txt"`. Answer `false` → `result == nil` and the dialog stays. Answer `true` → `result == root/b.txt`.
    - `saveKeepsTheTypedNameWhenOpeningAFolder`: text `"nota"`, then `activate(itemAt: 0)` → `folder` is `sub` and `nameField.text == "nota"`.
  - **Folders and buttons:**
    - `refusedFolderWarnsAndStays`: `show(root/locked)` with `chmod 0o000` → `false`, `folder` unchanged, and `told.last` contains `"não deu acesso"`.
    - `upGoesToTheParentAndStopsAtRoot`: from `sub`, `goUp()` → root. `show(URL(filePath: "/"))` disables `upButton` (`isEnabled == false`).
    - `lookInListsPlacesIndented`: built with `volumes: { [VolumeInfo(url: URL(filePath: "/"), name: "Disco", kind: .internal, totalBytes: nil, freeBytes: nil, isEjectable: false)] }`. The titles of `placeItems()` include `"Área de Trabalho"`, `"  Disco"` and the temp root's name preceded by two spaces per level of its depth.
    - `cancelEndsWithNoFile`: `cancel()` → `result == nil` and `onFinish` is called.
    - `titlesFollowTheMode`: open → `window.title == "Abrir"`; save → `"Salvar como"`.
- [ ] **Step 2: Run** `swift test --filter FileDialogControllerTests`. Expected: FAIL (module `Retro98Dialogs` not found).
- [ ] **Step 3: Implement:**
  - **Text and the prompter:**
    - `FileDialogText` holds every string from Global Constraints → Diálogos, pt-BR/en via `LocalizedText`, plus `upOneLevel` ("Um nível acima"/"Up One Level") as the up button's tooltip.
    - `RetroFileDialogPrompter` uses `RetroMessageBox.run`: Sim/Não (`.warning`) for the replace question, OK for the rest.
  - **Layout (content coordinates, flipped):**
    - label at (8, 12); `lookIn` at (72, 8, 260, 22); up button (`FileIcons.up`, 23×22) at (338, 8);
    - list in a `FieldFrame` at (8, 38, 414, 150), with the grid in `RetroScroller.makeScrollView` and `style = .list`;
    - name label at (8, 202); `nameField` at (100, 198, 230, 23); OK button at (347, 198, 75);
    - type label at (8, 231); `typeBox` at (100, 228, 230, 22); Cancel at (347, 227, 75).
  - **Grid hooks:**
    - `grid.onOpen` and `grid.onRename` (Enter) call `activate`; `grid.onSelectionChange` calls `selectionChanged`.
    - Small icons are `FileIcons.icon(entry.kind.iconKind, size: 16)`.
  - **Window and keys:**
    - `window.defaultButton = okButton`; `nameField.onSubmit = submit`; `window.onCancel = cancel`.
    - When the window shows, the name field has focus with its text selected.
  - **`lookIn`:** shows the current folder's display name and icon. Its items are `places`, with `String(repeating: "  ", count: depth)` before each name and the place icon (desktop, myDocuments, hard or removable or network disk, folder). Choosing one calls `show(place.url)`.
  - **Filter and up button:** `typeBox` lists the filter titles, and choosing one calls `chooseFilter`. `upButton.isEnabled = folder.path != "/"`.
  - **`RetroFileDialog.run`:**
    - build the controller and set `onFinish = { NSApp.stopModal() }`;
    - then `window.showCentered()`, focus the field, `NSApp.runModal(for: window)`, `window.orderOut(nil)`;
    - return `result`.
- [ ] **Step 4: Run** `swift test`. Expected: PASS (whole suite; the Explorer now gets its icons from `Retro98Dialogs`).
- [ ] **Step 5: Commit** `feat: retro open and save dialogs`.

### Task 5: A janela do Bloco de Notas

**Files:**
- **Create in `Sources/Retro98Notepad/`:** `NotepadText.swift`, `NotepadPreferences.swift`, `NotepadServices.swift`, `NotepadTextView.swift`, `NotepadWindowController.swift`.
- **Modify `Package.swift`:** add `"Retro98Dialogs"` to `Retro98Notepad`'s and `Retro98NotepadTests`' dependencies.
- **Test:** `Tests/Retro98NotepadTests/NotepadWindowTests.swift`. Add to `TestSupport.swift`:
  - `ScriptedNotepadPrompter`, which records `told: [String]` and answers `askToSave` from a queue;
  - `ScriptedNotepadDialogs`, which returns queued URLs and records the folder and name it was asked with;
  - `distinctColors(_:rows:)`, copied from the Prompt's test support.

**Interfaces:**
```swift
enum SaveAnswer: Equatable { case save, discard, cancel }

@MainActor protocol NotepadPrompter: AnyObject {
    func askToSave(_ message: String, languages: [String]) -> SaveAnswer        // Sim / Não / Cancelar, warning icon
    func tell(_ message: String, icon: MessageBoxIcon, languages: [String])
}
@MainActor protocol NotepadDialogs: AnyObject {
    func chooseFileToOpen(in folder: URL, languages: [String]) -> URL?
    func chooseSaveLocation(in folder: URL, name: String, languages: [String]) -> URL?
}
// RetroNotepadPrompter (RetroMessageBox, title "Bloco de Notas") and RetroNotepadDialogs (RetroFileDialog.run with NotepadText.filters) are the live ones.

final class NotepadPreferences: @unchecked Sendable {          // the ExplorerPreferences pattern
    init(defaults: UserDefaults)
    static func memory(wordWrap: Bool = false) -> NotepadPreferences
    var wordWrap: Bool { get set }                              // key "WordWrap", default false
}

enum NotepadText {
    static let appName = "Retro98 Notepad"
    static func windowTitle(fileName: String?, _ l: [String]) -> String
    static func untitledFileName(_ l: [String]) -> String       // "Sem título.txt" / "Untitled.txt"
    static func askToSave(fileName: String?, _ l: [String]) -> String
    static func openError(_ error: TextFileError, fileName: String, _ l: [String]) -> String
    static func saveError(fileName: String, _ l: [String]) -> String
    static func notFound(_ needle: String, _ l: [String]) -> String
    static func timeDate(_ date: Date, locale: Locale, timeZone: TimeZone) -> String
    static func filters(_ l: [String]) -> [FileTypeFilter]      // text (*.txt) first, then all files
    // plus every menu title and the About credit, pt-BR/en
}

final class NotepadTextView: NSTextView {}   // configured in init(frame:); draws without antialiasing or font smoothing

@MainActor final class NotepadWindowController: NSObject, NSWindowDelegate, NSTextViewDelegate {
    static let contentSize = CGSize(width: 660, height: 444)
    let window: RetroAppWindow
    let textView: NotepadTextView
    let scrollView: NSScrollView
    let menuBar: RetroMenuBar
    private(set) var fileURL: URL?
    /// The open file's line ending and BOM (its text lives in the view).
    private(set) var file: TextFile
    private(set) var isModified: Bool
    var onClose: (() -> Void)?
    var wordWrap: Bool { get set }
    /// No file, no change, nothing typed: Open may reuse this window.
    var isUntouched: Bool { get }
    init(languages: [String], preferences: NotepadPreferences, dialogs: NotepadDialogs, prompter: NotepadPrompter,
         startFolder: @escaping () -> URL, folderUsed: @escaping (URL) -> Void)
    @discardableResult func load(_ url: URL) -> Bool
    @discardableResult func save() -> Bool
    @discardableResult func saveAs() -> Bool
    /// Asks when modified; true when the window may close (saved or discarded).
    func confirmDiscardingChanges() -> Bool
    func insertTimeDate(_ date: Date)
    @objc func saveDocument(_ sender: Any?)
    @objc func saveDocumentAs(_ sender: Any?)
    @objc func insertTimeDate(_ sender: Any?)
}
```

- [ ] **Step 1: Write the failing tests** in `NotepadWindowTests.swift`. Use `languages ["pt-BR"]`, memory preferences, scripted dialogs and prompter, and temp folders. Register the font from `repoRoot/Resources/Fonts`.
  - **The text view:**
    - `textViewIsPlainVGAText`:
      - `isRichText == false` and `allowsUndo == true`;
      - `font?.fontName == VGAFont.postScriptName`;
      - quote, dash and text substitution, spelling correction and continuous spell checking all off;
      - `backgroundColor` white and `textColor` black.
    - `textIsCrisp`: a 300×40 text view with string `"ação AÇÃO 123"`, not first responder → `distinctColors(textView, rows: 1) <= 2`.
    - `selectionIsNavyWithWhiteText`: `selectedTextAttributes[.backgroundColor]` is `#000080` and `[.foregroundColor]` is white.
    - `wordWrapFollowsThePreference`: `wordWrap = true` → `textContainer.widthTracksTextView == true` and `scrollView.hasHorizontalScroller == false`. `false` gives the opposite.
  - **Loading:**
    - `loadingKeepsTheFilesEnding`:
      - write `"a\r\nb"` and `load` it → `textView.string == "a\nb"`, `window.title == "<name> - Bloco de Notas"`, `isModified == false`;
      - `textView.insertText("x", replacementRange: NSRange(location: 3, length: 0))` → `isModified == true`;
      - `save()` → file bytes are `"a\r\nbx"` and `isModified == false`.
    - `loadingNonUTF8TellsAndKeepsTheWindow`: a Latin-1 file → `load` is `false`; `told.last` contains the file name and `"UTF-8"`; `fileURL == nil`; `window.title == "Sem título - Bloco de Notas"`.
    - `loadingClearsUndo`: after `load`, `textView.undoManager?.canUndo == false`.
  - **Saving:**
    - `savingUntitledAsksWhere`: dialogs answer `root/nota.txt`; type `"oi"`; `save()` → `true`.
      - The file holds `"oi"` and `fileURL == root/nota.txt`.
      - The dialogs were asked with `name == "Sem título.txt"`.
      - `folderUsed` got `root`.
    - `cancelledSaveAsKeepsChanges`: dialogs answer `nil` → `save()` is `false` and `isModified == true`.
    - `failedSaveTellsAndKeepsChanges`: save into a `0o500` folder (restore in `defer`) → `false`; `told.last` contains `"Não foi possível salvar"`; `isModified == true`.
  - **Closing:**
    - `closingModifiedAsks`. Modified untitled window, `windowShouldClose`:
      - prompter `.cancel` → `false`;
      - `.discard` → `true`;
      - `.save`, then dialogs `nil` → `false`;
      - `.save`, then dialogs `root/x.txt` → `true` and the file exists.
    - `closingUnmodifiedDoesNotAsk`: `windowShouldClose` → `true` and the prompter is never asked.
  - **Time/date:** `timeDateIsInsertedAndUndoable`:
    - `insertTimeDate(date)` puts `NotepadText.timeDate(date, locale: .current, timeZone: .current)` into the text and sets `isModified`;
    - `undoManager?.undo()` removes it.
  - **`timeDateFormats`:** for `Date(timeIntervalSince1970: 1_794_589_500)` (13/11/2026 14:05 in São Paulo):
    - locale `pt_BR`, zone `America/Sao_Paulo` → `"14:05 13/11/2026"`;
    - locale `en_US` → `"2:05\u{202F}PM 11/13/26"` (both values measured on this Mac on 2026-11-13).
- [ ] **Step 2: Run** `swift test --filter NotepadWindowTests`. Expected: FAIL (`NotepadWindowController` not found).
- [ ] **Step 3: Implement:**
  - **`NotepadTextView`:**
    - Plain text with the VGA font from `VGAFont.make()`.
    - Turn off every automatic substitution and checking.
    - `usesFindBar = false`, `isIncrementalSearchingEnabled = false`.
    - Navy and white `selectedTextAttributes`, `insertionPointColor = .black`.
    - `textContainerInset = NSSize(width: 2, height: 2)`, `layoutManager?.allowsNonContiguousLayout = true`.
    - `draw(_:)` sets `NSGraphicsContext.current?.shouldAntialias = false` and `cgContext.setShouldSmoothFonts(false)` / `setAllowsFontSmoothing(false)` before calling `super`.
  - **Window controller, building the window:**
    - Lay out the menu bar, the etched line and a `FieldFrame` wrapping `RetroScroller.makeScrollView(document: textView)`, as the Prompt does.
    - `window.tabbingMode = .disallowed`; set `taskbarHeight` as in the Prompt.
    - `textView.delegate = self`; `textDidChange` sets `isModified = true`.
  - **Window controller, load and save:**
    - `load`: use `TextFile.read`, put the text in with `textView.string = …`, then `undoManager?.removeAllActions()`, and update the title.
    - `save`/`saveAs`:
      - build `TextFile(text: textView.string, lineEnding: file.lineEnding, hasBOM: file.hasBOM)` and call `write(to:)`;
      - the save dialog starts in the file's folder, or `startFolder()`;
      - after success, call `folderUsed(url.deletingLastPathComponent())`.
  - **Window controller, closing and time/date:**
    - `windowShouldClose` calls `confirmDiscardingChanges`.
    - `insertTimeDate` uses `textView.insertText(_:replacementRange: textView.selectedRange())`, so undo and `textDidChange` both work.
    - The retro menus come from `NotepadMenus` (Task 7). Until then, `menuBar.menus = []`.
- [ ] **Step 4: Run** `swift test --filter "NotepadWindowTests|TextFileTests"`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: Notepad window with crisp text, saving and change prompts`.

### Task 6: Localizar

**Files:**
- Create `Sources/Retro98Notepad/TextSearch.swift` and `Sources/Retro98Notepad/FindDialog.swift`.
- Test `Tests/Retro98NotepadTests/FindTests.swift`.

**Interfaces:**
```swift
enum TextSearch {
    /// The next match after the selection (forward) or before it (backward); nil when none. Never wraps.
    static func find(_ needle: String, in text: String, selection: NSRange, forward: Bool, matchCase: Bool) -> NSRange?
}

@MainActor final class FindDialog {
    let window: RetroWindow
    let field: RetroTextField
    let matchCase: RetroCheckBox
    let up: RetroRadioButton
    let down: RetroRadioButton
    let findNextButton: RetroButton
    var needle: String { get }
    init(languages: [String], prompter: NotepadPrompter, target: @escaping () -> NSTextView?)
    /// Modeless and floating; focuses the field with its text selected.
    func show()
    /// Selects and scrolls to the match in the target; tells "Não foi possível localizar" when there is none.
    @discardableResult func findNext() -> Bool
}
```

- [ ] **Step 1: Write the failing tests** in `FindTests.swift`:
  - **`TextSearch`:**
    - `findsForwardFromTheSelectionEnd`: in `"ab ab ab"` with selection `(0, 2)`, finding `"ab"` gives `(3, 2)`.
    - `findsBackwardBeforeTheSelection`: selection `(6, 2)`, `forward: false` gives `(3, 2)`.
    - `ignoresCaseUnlessAsked`: `"Ação"` finds `"ação"` with `matchCase: false`, and not with `true`.
    - `neverWraps`: selection at the last match, forward → `nil`.
    - `emptyNeedleFindsNothing`.
    - `rangesAreUTF16`: `"😀 a"` finding `"a"` from `(0, 0)` gives `(3, 1)`.
  - **`FindDialog`:**
    - `findNextSelectsTheMatch`: a `NSTextView` holding `"um dois um"` with selection `(0, 0)`. Set `field.text = "um"`; first `findNext()` → `selectedRange == (0, 2)`; second → `(8, 2)`; third → `false` and `told.last == "Não foi possível localizar \"um\""`.
    - `upSearchesBackward`: `up.select()` from the end finds `(8, 2)`, then `(0, 2)`.
    - `findNextIsOffWhileTheFieldIsEmpty`: with `field.text = ""` and `onChange` fired, `findNextButton` is disabled. It is enabled again after typing.
- [ ] **Step 2: Run** `swift test --filter FindTests`. Expected: FAIL (`TextSearch` not found).
- [ ] **Step 3: Implement:**
  - **`TextSearch`:** `(text as NSString).range(of:options:range:)` with `.caseInsensitive` when `!matchCase` and `.backwards` going up. The forward range runs from the selection's end to the text's end; the backward one from 0 to the selection's start.
  - **`FindDialog`:**
    - `RetroWindow(title: "Localizar"/"Find", contentSize: CGSize(width: 372, height: 96))`, `level = .floating`, `hidesOnDeactivate = true`.
    - Layout:
      - label at (8, 12); field at (78, 8, 176, 23);
      - "Localizar próxima" (default) at (266, 8, 98) and "Cancelar" at (266, 37, 98);
      - checkbox at (8, 68);
      - group box "Direção" at (150, 36, 104, 52) with the radios "Acima" and "Abaixo" inside.
    - Cancel and Esc close it.
    - The match is selected with `setSelectedRange` + `scrollRangeToVisible`, and the target window comes to the front.
- [ ] **Step 4: Run** `swift test --filter FindTests`. Expected: PASS (9 tests).
- [ ] **Step 5: Commit** `feat: Notepad Find dialog`.

### Task 7: O app (várias janelas, menus, abrir de fora)

**Files:**
- Create `Sources/Retro98Notepad/AppDelegate.swift` and `Sources/Retro98Notepad/NotepadMenus.swift`.
- Modify `Sources/Retro98Notepad/main.swift` (the real one, like the Prompt's) and `Sources/Retro98Notepad/NotepadWindowController.swift` (`menuBar.menus = NotepadMenus.retroMenus(…)`).
- Test `Tests/Retro98NotepadTests/NotepadAppTests.swift`.

**Interfaces:**
```swift
@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    static let cascadeOffset: CGFloat = 22
    let languages: [String]
    var presentsWindows: Bool                       // tests: false
    var windowControllers: [NotepadWindowController] { get }
    /// Where the dialogs start when the document has no folder: the last folder used, first ~/Documents.
    private(set) var lastFolder: URL
    let findDialog: FindDialog                      // lazy is fine
    init(preferences: NotepadPreferences = NotepadPreferences(defaults: .standard),
         dialogs: NotepadDialogs = RetroNotepadDialogs(), prompter: NotepadPrompter = RetroNotepadPrompter(),
         home: URL = FileManager.default.homeDirectoryForCurrentUser, languages: [String] = Locale.preferredLanguages)
    @discardableResult func openWindow() -> NotepadWindowController
    /// An open file comes to the front; an untouched active window takes it; otherwise a new window. False when it can't be read.
    @discardableResult func open(_ url: URL) -> Bool
    func application(_ application: NSApplication, open urls: [URL])
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply
    @objc func newDocument(_ sender: Any?)
    @objc func openDocument(_ sender: Any?)
    @objc func closeWindow(_ sender: Any?)
    @objc func toggleWordWrap(_ sender: Any?)
    @objc func showFind(_ sender: Any?)
    @objc func findNext(_ sender: Any?)
    @objc func showAbout(_ sender: Any?)
    @objc func openHelp(_ sender: Any?)
}

@MainActor enum NotepadMenus {
    static let helpURL: URL                          // the README, as in the Prompt
    struct Command { let title: String; let key: String; let modifiers: NSEvent.ModifierFlags; let selector: Selector }
    static func groups(_ l: [String]) -> [(title: String, commands: [Command?])]   // Arquivo, Editar, Pesquisar, Formatar, Ajuda
    static func mainMenu(languages: [String]) -> NSMenu
    static func windowMenu(in main: NSMenu, languages: [String]) -> NSMenu?
    static func retroMenus(languages: [String], wordWrap: @escaping @MainActor () -> Bool) -> [RetroMenuBarMenu]
}
```

- [ ] **Step 1: Write the failing tests** in `NotepadAppTests.swift`. Use `presentsWindows = false`, memory preferences, the scripted prompter and dialogs, and a temp home.
  - **Opening:**
    - `launchOpensOneUntitledWindow`: `applicationDidFinishLaunching` gives 1 controller with `fileURL == nil`.
    - `openingAFileReusesTheUntouchedWindow`: after launch, `open(a.txt)` gives 1 controller with `fileURL == a.txt`.
    - `openingAgainBringsTheSameWindow`: `open(a.txt)` twice gives 1 controller.
    - `openingWithAModifiedWindowMakesANewOne`: type into the window, then `open(a.txt)` gives 2 controllers.
    - `filesFromOutsideOpenBeforeLaunchFinishes`: `application(_:open: [a, b])`, then `applicationDidFinishLaunching` → exactly 2 controllers, with no extra untitled one.
    - `unreadableFileOpensNoWindow`: `open(binary)` with no windows → `false`, 0 controllers, and the prompter was told.
  - **Quitting:**
    - `quittingAsksForEachModifiedWindow`. Two modified windows:
      - prompter `[.cancel]` → `.terminateCancel`;
      - `[.discard, .discard]` → `.terminateNow`.
  - **Word wrap:** `wordWrapTogglesEveryWindow`: `toggleWordWrap(nil)` → `preferences.wordWrap == true` and every controller has `wordWrap == true`. The retro Format menu's item `mark == .check`.
  - **Dialogs and folders:** `dialogsStartInTheLastFolderUsed`. After `open(root/x/a.txt)`, a new window's Save As asks dialogs with folder `root/x`. Before any file, they start at `home/Documents`.
  - **Menus:**
    - `retroMenusMatchTheSpec`: titles `["Arquivo", "Editar", "Pesquisar", "Formatar", "Ajuda"]`.
    - `macMenuBarHasShortcuts`: the main menu's top items are the app name, Arquivo, Editar, Pesquisar, Formatar, Janela, Ajuda.
      - "Abrir…" has `keyEquivalent "o"`.
      - "Salvar como…" has `"s"` with `[.command, .shift]`.
      - "Localizar próxima" has `"g"`.
      - "Hora/data" has key `String(UnicodeScalar(NSF5FunctionKey)!)` with no modifiers.
- [ ] **Step 2: Run** `swift test --filter NotepadAppTests`. Expected: FAIL (`AppDelegate` not found).
- [ ] **Step 3: Implement**, following the Prompt's `AppDelegate`/`PromptMenus`/`main.swift`.
  - **Window rules:**
    - `applicationWillFinishLaunching` sets `NSWindow.allowsAutomaticWindowTabbing = false`.
    - `applicationDidFinishLaunching` registers `VGAFont.bundledURL` and opens a window only when there is none.
    - `applicationShouldTerminateAfterLastWindowClosed` is `false`. Reopen opens a window.
  - **Already open:** "already open" compares `resolvingSymlinksInPath().standardizedFileURL` paths.
  - **Failed load:** a window created for a file that fails to load is dropped without asking (never shown). An untouched window that failed to take the file stays as it was.
  - **`openDocument`:** asks the active controller's dialogs (folder: its file's folder, or `lastFolder`), then calls `open`.
  - **`closeWindow`:** `active?.window.performClose(nil)`.
  - **Find:** `showFind` shows the find dialog targeted at `active?.textView`. `findNext` calls `findDialog.findNext()` when there is a needle, else `showFind`.
  - **About:** `showAbout` uses the standard About panel with the font credit: "Fonte: PxPlus IBM VGA 8x16, de VileR (int10h.org), CC BY-SA 4.0." / "Font: PxPlus IBM VGA 8x16 by VileR (int10h.org), CC BY-SA 4.0."
  - **Menus:**
    - Window-level commands (`saveDocument:`, `saveDocumentAs:`, `insertTimeDate:`) reach the controller as the window's delegate.
    - Edit commands use the `NSText`/`NSResponder` selectors: `undo:`, `redo:`, `cut:`, `copy:`, `paste:`, `delete:`, `selectAll:`.
    - `validateMenuItem` sets the Word Wrap item's `state`.
  - **`main.swift`:** `RetroSound.isEnabled` from `ChoicesFile`, the regular activation policy, `mainMenu` and `windowsMenu`, as in the Prompt.
- [ ] **Step 4: Run** `swift test`. Expected: PASS (whole suite). Also `swift build -c release --product Retro98Notepad 2>&1 | grep -c warning`. Expected: `0`.
- [ ] **Step 5: Commit** `feat: Retro98 Notepad app with menus, multiple windows and Open With`.

### Task 8: Instalar, desinstalar, README e versão

**Files:**
- Modify `scripts/build-app.sh`, `scripts/common.sh`, `install.sh`, `uninstall.sh`, `README.md`, `README.pt-BR.md`.
- Test `Tests/scripts/test_install.sh` and `Tests/scripts/test_uninstall.sh`.

**Interfaces:**
- **`build-app.sh`:**
  - A 10th optional argument: document types, as space-separated UTIs. When given, `Info.plist` gets `CFBundleDocumentTypes` with one dict:
    - `CFBundleTypeName` "Text", `CFBundleTypeRole` "Editor", `LSHandlerRank` "Alternate";
    - `LSItemContentTypes` = the UTIs.
  - `VERSION="0.9.0"`, `BUILD="10"`. Update the usage comment and line.
- **`common.sh`:** `NOTEPAD_ID="io.github.matheushchaves.retro98.notepad"`, `NOTEPAD_APP="$APPS_DIR/Retro98 Notepad.app"`, and `remove_notepad()` like `remove_prompt`. Also add `"$NOTEPAD_ID|$NOTEPAD_APP"` to `forget_permissions`.
- **`install.sh`:**
  - Pieces as in Global Constraints: the question after the Prompt one, the `nonotepad` migration line, and the default `base shell prompt notepad`.
  - Build: `build-app.sh Retro98Notepad "$NOTEPAD_ID" "Retro98 Notepad" "$NOTEPAD_APP" regular "" notepad "" "$RETRO98_ROOT/Resources/Fonts" "public.plain-text"`, then `lsregister -f`; otherwise `remove_notepad`.
  - The header comment lists the Notepad.
- **`uninstall.sh`:** `remove_notepad` next to `remove_prompt`.

- [ ] **Step 1: Write the failing script tests:**
  - **`test_install.sh`:**
    - `pieces-recorded` expects `"base shell prompt notepad"`.
    - The shelloff case expects `"base shelloff prompt notepad"`.
    - `old-pieces-get-prompt` expects `"base shell prompt notepad"`.
    - The declined-prompt case expects `"base shell noprompt notepad"`.
    - New checks:
      - `notepad-built` (`codesign --verify`);
      - `notepad-is-regular-app`;
      - `notepad-has-font` (font and license in `Contents/Resources`);
      - `notepad-has-icon`;
      - `notepad-opens-plain-text-without-being-default`: `CFBundleDocumentTypes:0:LSItemContentTypes:0 == public.plain-text` and `CFBundleDocumentTypes:0:LSHandlerRank == Alternate`;
      - `notepad-registered`.
    - New case: pieces `"base shell nonotepad"` → `declined-notepad-stays-off`: no app, `lsregister -u` logged, and the pieces become `"base shell nonotepad prompt"`. The Prompt migration line runs first and appends at the end; the Notepad line then sees `nonotepad` and adds nothing.
    - `old-pieces-get-notepad`: pieces `"base shell prompt"` → the app exists and the pieces become `"base shell prompt notepad"`.
  - **`test_uninstall.sh`:**
    - The installed-apps fixture gains `Retro98 Notepad.app`.
    - `run_shell_case` also expects `tccutil reset All io.github.matheushchaves.retro98.notepad` (before the first `lsregister -u`), `lsregister -u <apps>/Retro98 Notepad.app`, and the app gone.
- [ ] **Step 2: Run** `bash Tests/scripts/test_install.sh; bash Tests/scripts/test_uninstall.sh`. Expected: the new checks FAIL.
- [ ] **Step 3: Implement** the script changes.
  - **READMEs (both languages, same content):**
    - **"Situação":** phase 6 "✅ disponível" / "✅ available".
    - **New section "Bloco de Notas (Fase 6)" / "Notepad (Phase 6)" after the Control Panel's.** It covers:
      - what it does;
      - the menus and shortcuts (F5 Hora/data, ⌘F/⌘G);
      - UTF-8 only, with the original line breaks and BOM kept, and the 10 MB limit;
      - that it shows up in "Abrir com" without becoming the default for .txt;
      - the retro open/save dialogs, and that they don't create folders (use the Explorer);
      - "Instalar o Bloco de Notas?" in the installer.
    - **Install and uninstall sections:** mention the Notepad piece.
- [ ] **Step 4: Run** `bash Tests/scripts/test_install.sh && bash Tests/scripts/test_uninstall.sh && bash Tests/scripts/test_signing.sh`. Expected: every line PASS, and `security list-keychains -d user` unchanged before and after. Then run `swift test`. Expected: PASS.
- [ ] **Step 5: Commit** `feat: install Retro98 Notepad as its own piece (0.9.0)`.

---

## Checagem manual (depois do merge, no Mac do autor)

1. `./install.sh --yes` → "Retro98 Notepad" aparece em Iniciar › Programas › Retro98 e abre "Sem título - Bloco de Notas".
2. Digitar "ação, pão, coração" → texto nítido em fonte VGA, acentos certos; ⌘Z desfaz.
3. F5 insere a hora e a data; Formatar › Quebra automática de linha quebra linhas longas e some a barra horizontal.
4. ⌘S → diálogo retrô "Salvar como": navegar pela lista e por "Salvar em", subir um nível, salvar "teste" → vira `teste.txt`; salvar de novo por cima pergunta antes.
5. ⌘O → diálogo "Abrir": "Todos os arquivos" mostra `.md`; abrir um arquivo de texto do Windows (CRLF), editar, salvar e conferir no Prompt com `file teste.txt` que continua "with CRLF line terminators".
6. ⌘F → Localizar com "Acima"/"Abaixo" e "Diferenciar maiúsculas e minúsculas"; texto ausente avisa.
7. Fechar com alteração pergunta Sim/Não/Cancelar; ⌘Q com duas janelas alteradas pergunta para cada uma.
8. No Explorer, clique direito num `.txt` › Abrir com › Retro98 Notepad abre o arquivo; o duplo clique continua abrindo no app padrão.
9. Abrir um binário (por exemplo `/bin/ls` com "Todos os arquivos") → mensagem de "não parece ser texto", nada aberto.
