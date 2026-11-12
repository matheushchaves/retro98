# Retro98 Fase 3B — Explorer: operações de arquivo — plano de implementação

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** O Retro98 Explorer passa a mexer nos arquivos sem precisar do Finder:
- copiar, recortar e colar, inclusive de e para o Finder;
- arrastar e soltar entre janelas e com outros apps;
- renomear, criar pasta, mandar para a Lixeira, restaurar e esvaziar;
- desfazer e refazer;
- perguntar antes de substituir, e mostrar progresso com Cancelar nas operações longas.

**Architecture:**
- **`Retro98FilesCore`** ganha o motor das operações, sem AppKit:
  - Copiar e mover com `copyfile(3)`, que clona no APFS e copia em outros discos. Conflitos, progresso e cancelamento entram como funções passadas pela chamada.
  - Lixeira, exclusão, nova pasta e renomear.
  - A pilha de desfazer e o registro de onde veio cada item mandado para a Lixeira.
  - Regras puras de nomes ("cópia", "Nova pasta (2)"), de renomear e de soltar.
  - Os textos dos diálogos.
- **`Retro98UI`** ganha:
  - o diálogo de progresso, com barra e animação originais;
  - na grade: renomear no lugar, menu de contexto, itens recortados esmaecidos, arrastar e soltar.
- **`Retro98Explorer`** ganha uma central de operações única para o app. Ela roda o motor fora da thread principal, faz as perguntas com `RetroMessageBox`, mostra o progresso, registra o desfazer e cuida da área de transferência.
  - As janelas ligam menus, barra de ferramentas, teclado, menu de contexto e arrastar e soltar à central.

**Tech Stack:** Swift 6, AppKit (NSPasteboard, NSDraggingSource/Destination, NSFilePromiseReceiver, UndoManager), `copyfile(3)`, FileManager (`trashItem`), Swift Testing.

**Spec:** `docs/superpowers/specs/2026-11-10-retro-desktop-design.md`, seção "Fase 3" (3B e "Operações obrigatórias"). A Fase 3A está pronta no `main` (plano `2026-11-11-retro98-fase3a-explorer-navegar.md`).

## Global Constraints

- **Herança:** tudo das Global Constraints das Fases 1, 2A, 2B e 3A continua valendo:
  - pixel 1x, Tahoma 13 e negrito 12, paleta;
  - só material original;
  - pt-BR e en;
  - só APIs públicas;
  - o Finder fica intacto.
- **Testes isolados:** os testes nunca tocam a Lixeira real, a área de transferência geral, o Application Support real, nem abrem diálogos modais.
  - **Lixeira:** é injetada em `ExplorerEnvironment.moveToTrash`. O padrão move o item para a pasta `trash` do próprio ambiente.
  - **Área de transferência:** `NSPasteboard(name:)` com nome único, liberada no fim.
  - **Perguntas:** passam por um `ExplorerPrompter` com respostas roteirizadas.
- **Fora da thread principal:** o trabalho com arquivos nunca roda na thread principal; a janela continua respondendo durante uma cópia longa.
  - Uma pergunta de conflito por vez, modal.
  - Operações diferentes podem rodar ao mesmo tempo, cada uma com o próprio diálogo.
- **Nada some sem volta:**
  - Item substituído vai para a Lixeira, nunca é apagado direto.
  - Mover entre discos apaga a origem só depois que o item inteiro foi copiado.
  - Cancelar ou falhar no meio remove só o item que estava sendo copiado pela metade.
  - A cópia usa `COPYFILE_EXCL`, então nunca escreve por cima de nada.
- **Desfazer:**
  - É um só para o app inteiro: todas as janelas compartilham a pilha.
  - Desfazer cópia ou nova pasta manda o item para a Lixeira, como no Finder.
  - "Excluir permanentemente" e "Esvaziar Lixeira" não se desfazem.
  - Esvaziar a Lixeira limpa a pilha.
  - Desfazer e Refazer ficam desabilitados enquanto uma operação roda.
- **Atalhos:**

  | Ação | Teclas |
  |---|---|
  | Copiar, Recortar, Colar | ⌘C, ⌘X, ⌘V |
  | Mover para cá (move o que foi copiado, como no Finder) | ⌥⌘V |
  | Desfazer, Refazer | ⌘Z, ⇧⌘Z |
  | Nova pasta | ⇧⌘N |
  | Abrir | ⌘O, ⌘↓ ou duplo clique |
  | Renomear | F2 ou Enter (a spec manda; Enter deixa de abrir) |
  | Mandar para a Lixeira | ⌘⌫ ou Del (forward delete) |
  | Excluir permanentemente | ⌥⌘⌫ ou ⇧Del |
  | Esvaziar Lixeira | ⇧⌘⌫ |
  | Acima (como na 3A) | Backspace sozinho |

  Na janela da Lixeira, ⌘⌫ e Del excluem permanentemente, perguntando antes.
- **Arrastar:**
  - Mesmo disco: move. Outro disco: copia.
  - ⌥ força copiar e ⌘ força mover.
  - Soltar na Lixeira manda para a Lixeira, perguntando antes.
  - Soltar no próprio lugar não faz nada.
- **Nomes [minha escolha]:**
  - Cópia na mesma pasta segue o Finder: "foto cópia.jpg", "foto cópia 2.jpg" (en "photo copy.jpg").
  - Nova pasta segue o 98: "Nova pasta", "Nova pasta (2)" (en "New Folder", "New Folder (2)").
  - Item mandado para a Lixeira de teste ganha " 2", " 3"… se o nome já existir lá.
- **Textos** (pt-BR | en; `<n>` = número, `'<nome>'` com aspas simples):

  | Onde | pt-BR | en |
  |---|---|---|
  | Conflito, título | Substituir arquivo | Replace File |
  | Conflito, mensagem | `Esta pasta já contém um item chamado '<nome>'.⏎⏎Deseja substituir o item existente⏎<tamanho>, modificado em <data>⏎⏎por este?⏎<tamanho>, modificado em <data>` | `This folder already contains an item named '<name>'.⏎⏎Would you like to replace the existing item⏎<size>, modified <date>⏎⏎with this one?⏎<size>, modified <date>` |
  | Conflito, botões | Sim, Sim para todos, Não, Cancelar (com um item só: Sim, Não) | Yes, Yes to All, No, Cancel (Yes, No) |
  | Lixeira, título | Confirmar exclusão | Confirm Delete |
  | Lixeira | `Tem certeza de que deseja enviar '<nome>' para a Lixeira?` / `…enviar estes <n> itens para a Lixeira?` | `Are you sure you want to send '<name>' to the Recycle Bin?` / `…send these <n> items…` |
  | Permanente | `Tem certeza de que deseja excluir '<nome>' permanentemente? Isso não pode ser desfeito.` / `…excluir estes <n> itens permanentemente?…` | `Are you sure you want to permanently delete '<name>'? This can't be undone.` / `…these <n> items…` |
  | Sem Lixeira | `'<nome>' não pode ir para a Lixeira. Deseja excluí-lo permanentemente?` | `'<name>' can't go to the Recycle Bin. Do you want to delete it permanently?` |
  | Esvaziar | `Tem certeza de que deseja excluir permanentemente os <n> itens da Lixeira?` | `Are you sure you want to permanently delete the <n> items in the Recycle Bin?` |
  | Extensão | `Se você mudar a extensão de '<.a>' para '<.b>', o arquivo pode abrir em outro app ou deixar de abrir. Deseja mudar?` (sem extensão: `''`) | `If you change the extension from '<.a>' to '<.b>', the file may open in another app or stop opening. Change it?` |
  | Nome oculto | `Nomes que começam com '.' ficam ocultos. Deseja usar este nome?` | `Names that begin with '.' are hidden. Use this name anyway?` |
  | Nome inválido | `O nome não pode conter '/' nem ':'.` · `Este nome não é válido.` · `O nome é longo demais.` | `A name can't contain '/' or ':'.` · `This name isn't valid.` · `The name is too long.` |
  | Já existe | `Já existe um item chamado '<nome>'. Escolha outro nome.` | `There is already an item named '<name>'. Choose another name.` |
  | Dentro de si | `Não é possível <copiar/mover> '<nome>': a pasta de destino está dentro dela.` | `Can't <copy/move> '<name>': the destination folder is inside it.` |
  | Substituir a origem | `Não é possível substituir '<nome>': ela contém o item que está sendo <copiado/movido>.` | `Can't replace '<name>': it contains the item being <copied/moved>.` |
  | Erro, título | Erro ao copiar · ao mover · ao renomear · ao excluir · ao desfazer · ao restaurar | Error Copying · Moving · Renaming · Deleting · Undoing · Restoring |
  | Erro, mensagem | `Não foi possível <copiar> '<nome>': <motivo do sistema>` | `Couldn't <copy> '<name>': <system reason>` |
  | Sem acesso à Lixeira (anexado ao erro de desfazer ou restaurar) | `Para tirar itens da Lixeira, dê Acesso Total ao Disco ao Retro98 Explorer, ou use "Devolver" na Lixeira do Finder.` | `To take items out of the Recycle Bin, give Retro98 Explorer Full Disk Access, or use "Put Back" in the Finder's Trash.` |
  | Progresso, título | Copiando... · Movendo... · Excluindo... | Copying... · Moving... · Deleting... |
  | Progresso, linhas | `De '<origem>' para '<destino>'` · `<n> segundos restantes` · `<n> minutos restantes` · `Calculando o tempo restante...` | `From '<source>' to '<destination>'` · `<n> seconds remaining` · `<n> minutes remaining` · `Calculating the time remaining...` |
  | Ações (menu Desfazer) | Copiar, Mover, Renomear, Nova pasta, Excluir, Restaurar → `Desfazer <ação>`, `Refazer <ação>` | Copy, Move, Rename, New Folder, Delete, Restore → `Undo <action>`, `Redo <action>` |
  | Menus novos | Abrir, Nova pasta, Renomear, Excluir, Excluir permanentemente, Restaurar, Esvaziar Lixeira, Abrir no Finder, Mover para cá | Open, New Folder, Rename, Delete, Delete Permanently, Restore, Empty Recycle Bin, Open in Finder, Move Item Here |

  Datas em `DateFormatter` curto (data e hora) no idioma; tamanhos com `StatusText.bytes`.
- **Versão:** os bundles passam a 0.5.0 (build 5).

## Review Focus

1. **Digitando com arquivos selecionados.** Com o cursor no endereço ou no campo de renomear, ⌘⌫, ⌘Z, ⌘C, ⌘V e Delete agem no texto, nunca nos arquivos. Os comandos novos (`moveToTrash:` e afins) passam do editor de texto até a janela, então precisam se desligar sozinhos. → Task 7, `fileCommandsIgnoreTextEditing`.
2. **Destino perigoso.** Colar uma pasta nela mesma ou numa subpasta, soltar no próprio lugar, ou "Sim" para substituir uma pasta que contém a origem: nada apaga nada nem entra em laço. → Task 1, `dropRules`; Task 2, `cannotCopyAFolderIntoItself` e `replacingAnAncestorOfTheSourceIsRefused`.
3. **Interrupção no meio.** Cancelar ou falhar no meio (cópia grande, pen drive arrancado, mover entre discos) deixa a origem intacta e não sobra item pela metade. → Task 2, `cancellingMidCopyRemovesThePartialItem` e `cancellingAMoveAcrossVolumesKeepsTheSource`.
4. **Desfazer depois que algo mudou.** Por exemplo, a cópia já foi apagada no Finder, ou não há Acesso Total ao Disco para tirar da Lixeira. Aparece uma mensagem clara, nada trava, e a pilha continua coerente. → Task 2, `revertOfAVanishedItemFails`; Task 3, `failedUndoDropsTheAction`; Task 6, `undoWithoutTrashAccessExplains`.
5. **Renomear de jeitos difíceis:**
   - só trocar maiúsculas e minúsculas no APFS, que não as diferencia;
   - acentos digitados em NFC sobre nomes gravados em NFD;
   - a pasta recarregar durante a edição.

   → Task 1, `renameRules`; Task 2, `renameCaseOnly`; Task 7, `renameSurvivesABackgroundReload`.

---

## Estrutura de arquivos

```
Sources/Retro98FilesCore/
  FileRules.swift          (novo) FileNames, RenameRules, DropRules, DropTarget, FileEntry.isFileItem
  FileOperations.swift     (novo) motor: transferir, Lixeira, excluir, nova pasta, renomear, reverter
  FileCopy.swift           (novo) copyfile(3) com progresso e cancelamento
  FileUndoStack.swift      (novo) pilha de desfazer e refazer
  TrashOrigins.swift       (novo) de onde veio cada item da Lixeira
  Prompts.swift            (novo) Prompt e os textos dos diálogos; ProgressEstimate
  ExplorerText.swift       + menus e ações novos
  ExplorerModel.swift      ExplorerEnvironment ganha supportDirectory, moveToTrash, isSameVolume; Voltar recupera
  FolderListing.swift      + Volumes.same(_:_:)
Sources/Retro98UI/
  RetroProgressBar.swift, FileOperationAnimation.swift, RetroProgressDialog.swift   (novos)
  RetroIconGrid.swift      renomear (Enter/F2), menu de contexto, esmaecidos, clique em seleção múltipla
  RetroIconGrid+Editing.swift, RetroIconGrid+DragDrop.swift                       (novos, extensões)
  PixelIcon.swift          + drawDimmed
Sources/Retro98Explorer/
  ExplorerOperations.swift (novo) central do app: motor em segundo plano, perguntas, progresso, desfazer, área de transferência
  ExplorerUndoManager.swift (novo) UndoManager que expõe a FileUndoStack aos menus do macOS
  ExplorerPrompter.swift   (novo) protocolo + RetroPrompter (RetroMessageBox)
  ExplorerCommands.swift   (novo) extensão da janela: ações, validação, menu de contexto, renomear, nova pasta
  ExplorerDragDrop.swift   (novo) extensão da janela: origem e destino de arrastar
  ExplorerMenus.swift, ExplorerWindowController.swift, AppDelegate.swift
```

Trabalhar num branch `fase3b-explorer-operacoes` a partir do `main`.

---

### Task 1: Regras puras — nomes, renomear e soltar

**Files:** Create `Sources/Retro98FilesCore/FileRules.swift`. Test `Tests/Retro98FilesCoreTests/FileRulesTests.swift`.

**Interfaces:**
```swift
public enum FileNames {
    /// "foto cópia.jpg", "foto cópia 2.jpg"…; pastas comuns não têm extensão ("v1.2 cópia"); pacotes sim ("Calc cópia.app").
    public static func copyName(for item: URL, isFolder: Bool, existing: Set<String>, languages: [String]) -> String
    /// "Nova pasta", "Nova pasta (2)"…
    public static func newFolderName(existing: Set<String>, languages: [String]) -> String
    /// O próprio nome, ou "<base> 2<.ext>", "<base> 3<.ext>"… (Lixeira de teste e restauração)
    public static func available(_ name: String, isFolder: Bool, existing: Set<String>) -> String
}
public enum RenameCheck: Equatable, Sendable {
    case unchanged, accept(String), invalid(String), confirmExtensionChange(from: String, to: String), confirmHidden(String)
}
public enum RenameRules {
    /// Apara espaços nas pontas; compara com == do Swift (NFC == NFD).
    public static func check(original: String, typed: String, isFolder: Bool, languages: [String]) -> RenameCheck
}
public enum DropTarget: Equatable, Sendable { case folder(URL), trash }
public enum DropRules {
    /// nil = não faz nada (destino é a origem ou está dentro dela; mover para onde já está).
    public static func operation(sources: [URL], destination: URL, sameVolume: Bool,
                                 forceCopy: Bool, forceMove: Bool) -> FileOperationKind?
    /// Item sob o ponteiro (nil = fundo) → onde a coisa vai parar.
    public static func target(entry: FileEntry?, at location: Location, home: URL, trash: URL) -> DropTarget?
}
public enum FileOperationKind: Equatable, Sendable { case copy, move }
extension FileEntry { public var isFileItem: Bool }   // falso para Meu Computador, Meus Documentos (fixo), Lixeira e volumes
```
- [ ] **Step 1: Testes que falham**
  - `copyNamesFollowFinder`:
    - "foto.jpg", com {"foto.jpg"}, dá "foto cópia.jpg"; com {"foto.jpg", "foto cópia.jpg"}, dá "foto cópia 2.jpg".
    - A pasta "v1.2" dá "v1.2 cópia"; "Leia-me" dá "Leia-me cópia"; "Calc.app" dá "Calc cópia.app".
    - Em en: "photo copy.jpg".
  - `newFolderNamesCount`: {} → "Nova pasta"; {"Nova pasta"} → "Nova pasta (2)"; {"Nova pasta", "Nova pasta (2)"} → "Nova pasta (3)"; en → "New Folder".
  - `renameRules` (original → digitado ⇒ resultado):

    | Original | Digitado | Resultado |
    |---|---|---|
    | a.txt | a.txt | `.unchanged` |
    | a.txt | "   " | `.unchanged` |
    | a.txt | " b.txt " | `.accept("b.txt")` |
    | a.txt | A.txt | `.accept("A.txt")` |
    | Relatório.txt (NFD) | Relatório.txt (NFC) | `.unchanged` |
    | a.txt | b/c, b:c, `..`, 256×"a" | `.invalid` com o texto da tabela |
    | a.txt | a.md | `.confirmExtensionChange(from: ".txt", to: ".md")` |
    | a.txt | a | `.confirmExtensionChange(from: ".txt", to: "")` |
    | Fotos (pasta) | Fotos.old | `.accept` |
    | a.txt | .a.txt | `.confirmHidden(".a.txt")` |
  - `dropRules` (com /A/x.txt e /A/Sub):
    - Destino /A/Sub com a origem /A/Sub, ou /A/Sub/deep: nil.
    - /A/x.txt para /B no mesmo disco: `.move`; em outro disco: `.copy`.
    - `forceCopy` dá `.copy`; `forceMove` dá `.move`.
    - /A/x.txt para /A sem força: nil; com `forceCopy`: `.copy`.
  - `dropTargets`:
    - Item pasta: `.folder(url)`. Meus Documentos: `.folder(home/Documents)`. Lixeira fixa: `.trash`. Volume: `.folder(raiz)`. Arquivo de texto: nil.
    - Fundo de `.desktop`: `.folder(home/Desktop)`. Fundo de `.myComputer`: nil. Fundo de `.trash`: `.trash`.
  - `onlyRealFilesCanBeEdited`: `isFileItem` por tipo.
- [ ] **Step 2: Rodar `swift test --filter FileRulesTests`.** Esperado: FAIL (tipos não existem).
- [ ] **Step 3: Implementar**, mais as chaves novas em `ExplorerText`: as ações, os menus novos e as mensagens de nome inválido da tabela.
- [ ] **Step 4: Rodar `swift test --filter FileRulesTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: file naming, rename and drop rules`

---

### Task 2: O motor das operações

**Files:** Create `Sources/Retro98FilesCore/FileOperations.swift`, `FileCopy.swift`; Modify `ExplorerModel.swift` (ambiente), `FolderListing.swift` (`Volumes.same`). Test `Tests/Retro98FilesCoreTests/FileOperationsTests.swift`.

**Interfaces:**
```swift
// ExplorerEnvironment ganha (init com padrões; os testes da 3A seguem compilando):
public let supportDirectory: URL                         // nil → <home>/Library/Application Support/Retro98
public let moveToTrash: @Sendable (URL) throws -> URL    // devolve onde o item foi parar; nil → move para `trash` com FileNames.available
public let isSameVolume: @Sendable (URL, URL) -> Bool    // nil → Volumes.same (volumeIdentifierKey)
// .live: Retro98Paths.standard(home:environment:).supportDirectory e FileManager.trashItem(at:resultingItemURL:)

public struct TransferRequest: Equatable, Sendable { public let kind: FileOperationKind; public let items: [URL]; public let destination: URL }
public enum ConflictChoice: Equatable, Sendable { case replace, replaceAll, skip, cancel }
public struct FileConflict: Equatable, Sendable { public let source: URL; public let existing: URL; public let remaining: Int }
public struct OperationProgress: Equatable, Sendable { public let item: URL; public let completed: Int64; public let total: Int64 } // bytes ao copiar; itens no resto
public enum FileChange: Equatable, Sendable {
    case created(URL)                          // desfazer: Lixeira
    case moved(from: URL, to: URL)             // desfazer: volta ao caminho exato (também renomear e restaurar)
    case trashed(original: URL, trashed: URL)  // desfazer: devolve ao lugar
}
public enum OperationFailure: Equatable, Sendable {
    case cancelled, intoItself(URL), replacesItsOwnSource(URL), alreadyExists(URL), cannotTrash([URL]), failed(URL, String)
}
public struct OperationOutcome: Equatable, Sendable {
    public var changes: [FileChange]; public var failure: OperationFailure?
    public var results: [URL] { get }          // itens no lugar final (destinos de created/moved), na ordem
}
public final class OperationControl: @unchecked Sendable { public init(); public func cancel(); public var isCancelled: Bool { get } }

/// Tudo síncrono e bloqueante: o app chama fora da thread principal; os testes chamam direto.
public struct FileOperations: Sendable {
    public init(environment: ExplorerEnvironment)
    public func transfer(_ request: TransferRequest, control: OperationControl,
                         resolve: @Sendable (FileConflict) -> ConflictChoice,
                         progress: @Sendable (OperationProgress) -> Void) -> OperationOutcome
    public func trash(_ items: [URL], control: OperationControl, progress: @Sendable (OperationProgress) -> Void) -> OperationOutcome
    public func deletePermanently(_ items: [URL], control: OperationControl, progress: @Sendable (OperationProgress) -> Void) -> OperationOutcome
    public func newFolder(in folder: URL, languages: [String]) -> OperationOutcome      // [.created(pasta)]
    public func rename(_ item: URL, to name: String) -> OperationOutcome                // [.moved(from:to:)]
    public func revert(_ changes: [FileChange], control: OperationControl,
                       progress: @Sendable (OperationProgress) -> Void) -> OperationOutcome   // ordem inversa; para no primeiro erro
}
```
**Comportamento:**
- **Antes de começar:**
  - Soma o total de bytes, respeitando o cancelamento.
  - Recusa destino igual a um item ou dentro dele (`.intoItself`).
  - Copiar para a própria pasta usa `FileNames.copyName`, sem perguntar.
  - Mover para a própria pasta não faz nada.
- **Conflito** (o nome já existe no destino):
  - Chama `resolve`. "Sim para todos" vale para o resto da operação.
  - Se o existente contém a origem, falha com `.replacesItsOwnSource`, sem perguntar.
  - Substituir manda o existente para a Lixeira com `moveToTrash` (registra `.trashed`) e só depois copia ou move.
- **Copiar:** `copyfile(origem, destino, estado, COPYFILE_ALL | COPYFILE_RECURSIVE | COPYFILE_CLONE | COPYFILE_EXCL | COPYFILE_NOFOLLOW_SRC)`.
  - A função de status soma os bytes de cada arquivo terminado (`COPYFILE_RECURSE_FILE` + `COPYFILE_FINISH`) e os parciais (`COPYFILE_COPY_DATA` + `COPYFILE_PROGRESS`).
  - A mesma função devolve `COPYFILE_QUIT` quando `control.isCancelled`.
  - Em falha ou cancelamento, apaga o item de destino incompleto, criado por ela mesma.
- **Mover:**
  - Mesmo disco (`isSameVolume(origem, pasta de destino)`): `FileManager.moveItem`.
  - Outro disco: copia como acima e só então remove a origem. Se a remoção falhar, registra `.created(destino)` e `.failed(origem, motivo)`.
- **Lixeira:** `moveToTrash` item a item. Os recusados viram `.cannotTrash` com todos eles; os aceitos continuam registrados.
- **Renomear:**
  - Usa `rename(2)` na mesma pasta.
  - Se o destino existe e é outro arquivo (`fileResourceIdentifierKey` diferente), falha com `.alreadyExists`.
  - Só mudar maiúsculas e minúsculas passa.
- **Reverter:** `.created` vai para a Lixeira; `.moved(a→b)` move b para a; `.trashed(o, t)` move t para o.
  - Pastas-mãe que sumiram são recriadas.
  - Se o alvo já existe: `.alreadyExists`. Se a origem sumiu: `.failed`.
- **Erros:** `.failed(item de nível de cima, error.localizedDescription)`.

- [ ] **Step 1: Testes que falham** (`TempTree`, Lixeira de teste do ambiente)
  - **Copiar e mover:**
    - `copiesIntoAnotherFolder`: changes == `[.created(B/a.txt)]`, origem intacta, mesmo conteúdo.
    - `copyIntoTheSameFolderMakesACopyName`.
    - `copiesFoldersWithLinksAndAttributes`: subpastas (uma vazia) copiadas; um link simbólico continua link; um xattr `io.retro98.test` é copiado.
    - `moveOnTheSameVolumeRenames`: o `fileResourceIdentifierKey` é igual antes e depois.
    - `moveAcrossVolumesCopiesThenRemoves`: com `isSameVolume` sempre falso.
  - **Conflitos:**
    - `conflictReplacesIntoTheTrash`: changes == `[.trashed(original: B/a.txt, trashed: <Lixeira>/a.txt), .created(B/a.txt)]`; o conteúdo antigo está na Lixeira.
    - `replaceAllAsksOnce`: 3 conflitos, `resolve` chamado uma vez.
    - `skipKeepsTheExistingItem`.
    - `cancelStopsBeforeTheNextItem`: dá `.cancelled` e só o 1º item feito.
  - **Destino perigoso:**
    - `cannotCopyAFolderIntoItself`: copiar A para A/Sub dá `.intoItself(A)`, sem mudanças.
    - `replacingAnAncestorOfTheSourceIsRefused`: mover /T/A/B/A para /T, com /T/A existente e `resolve` → `.replace`, dá `.replacesItsOwnSource`; nada vai para a Lixeira.
  - **Interrupções:**
    - `cancellingMidCopyRemovesThePartialItem`: pasta com 50 arquivos, cancelar no 5º progresso; dá `.cancelled` e não existe B/Pasta.
    - `cancellingAMoveAcrossVolumesKeepsTheSource`: cancelar no meio de um mover entre discos; a origem fica completa.
    - `failureMidCopyRemovesThePartialItem`: uma subpasta com chmod 000 dá `.failed(A)`; B/A não existe; desfazer o chmod no fim.
    - `progressReachesTheTotal`: o último progresso tem `completed == total` == soma dos tamanhos.
  - **Lixeira, exclusão, nova pasta:**
    - `trashRecordsWhereItemsWent`.
    - `refusedTrashIsReported`: `moveToTrash` lança erro e dá `.cannotTrash([a])`.
    - `deletePermanentlyRemoves`.
    - `newFolderCountsUp`: "Nova pasta" e depois "Nova pasta (2)".
  - **Renomear:**
    - `renameChangesOnlyTheName`.
    - `renameCaseOnly`: "a.txt" para "A.txt"; a listagem mostra "A.txt".
    - `renameOntoAnotherItemFails`: dá `.alreadyExists`.
  - **Reverter:**
    - `revertUndoesAReplace`: reverter o resultado de `conflictReplacesIntoTheTrash` deixa B/a.txt com o conteúdo antigo e a cópia nova na Lixeira.
    - `revertOfAVanishedItemFails`: a cópia apagada antes dá `.failed`.
- [ ] **Step 2: Rodar `swift test --filter FileOperationsTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test`.** Esperado: tudo PASS, inclusive os testes da 3A.
- [ ] **Step 5: Commit** `feat: file operations engine (copy, move, trash, rename, revert)`

---

### Task 3: Pilha de desfazer e origem dos itens da Lixeira

**Files:** Create `Sources/Retro98FilesCore/FileUndoStack.swift`, `TrashOrigins.swift`. Test `Tests/Retro98FilesCoreTests/UndoAndTrashTests.swift`.

**Interfaces:**
```swift
public enum FileActionName: Equatable, Sendable { case copy, move, rename, newFolder, delete, restore }
public struct FileAction: Equatable, Sendable { public let name: FileActionName; public let changes: [FileChange] }
@MainActor public final class FileUndoStack {
    public init()
    public var onChange: (() -> Void)?
    public private(set) var isBusy: Bool                 // algum trabalho ou desfazer rodando
    public var canUndo: Bool { get }; public var canRedo: Bool { get }   // falsos enquanto isBusy
    public var undoName: FileActionName? { get }; public var redoName: FileActionName? { get }
    public func record(_ action: FileAction)              // ignora changes vazias; limpa o refazer
    public func beginWork(); public func endWork()         // contador; isBusy enquanto > 0
    /// Tira a ação do topo, roda `revert(changes)`, e empilha no outro lado o que de fato mudou (nada, se nada mudou).
    public func undo(_ revert: ([FileChange]) async -> OperationOutcome) async -> OperationOutcome?
    public func redo(_ revert: ([FileChange]) async -> OperationOutcome) async -> OperationOutcome?
    public func removeAll()
}
@MainActor public final class TrashOrigins {
    public init(file: URL, trash: URL)                    // JSON [{trashed, original}] ; arquivo ruim = vazio
    public func origin(of trashed: URL) -> URL?           // nil se desconhecido ou se o item saiu da Lixeira
    /// .trashed(o, t) → t ↦ o; .moved(x → y) com y dentro de `trash` ou de uma pasta ".Trashes" → y ↦ x. Grava na hora.
    public func record(_ changes: [FileChange])
}
```
Refazer é reverter o que o desfazer fez. Por isso as duas usam a mesma função `revert`.

- [ ] **Step 1: Testes que falham** (`revert` falso que devolve mudanças roteirizadas)
  - **Pilha:**
    - `recordingClearsRedo` e `emptyActionsAreNotRecorded`.
    - `undoMovesTheActionToRedo`: o nome vai junto; `redoName == .copy`.
    - `redoRunsRevertOnTheUndoResult`: o `revert` do refazer recebe as mudanças que o desfazer devolveu.
    - `busyDisablesUndo`: dentro do `revert` falso, `canUndo` e `canRedo` são falsos.
    - `failedUndoDropsTheAction`: o `revert` não muda nada; a ação sai do desfazer e nada entra no refazer.
  - **Origens:**
    - `remembersWhereTrashedItemsCameFrom`: uma instância nova lendo o mesmo arquivo também sabe.
    - `redoOfARestoreRemembersAgain`: com `.moved(from: /A/x, to: <trash>/x)`.
    - `forgetsItemsThatLeftTheTrash`.
    - `corruptFileStartsEmpty`.
- [ ] **Step 2: Rodar `swift test --filter UndoAndTrashTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test --filter UndoAndTrashTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: undo stack and Recycle Bin origins`

---

### Task 4: Diálogo de progresso e caixas com quatro botões

**Files:** Create `Sources/Retro98UI/RetroProgressBar.swift`, `FileOperationAnimation.swift`, `RetroProgressDialog.swift`; `Sources/Retro98FilesCore/Prompts.swift` (só `ProgressEstimate` aqui; `Prompt` na Task 6). Test `Tests/Retro98UITests/ProgressTests.swift`, `Tests/Retro98FilesCoreTests/ProgressEstimateTests.swift`.

**Interfaces:**
```swift
public final class RetroProgressBar: PixelView {           // campo afundado; blocos #000080 de 8 pt com 2 pt de vão, 2 pt de margem
    public var fraction: Double                            // 0...1
    public static func blockCount(fraction: Double, width: CGFloat) -> Int
}
public final class FileOperationAnimation: PixelView {     // arte original
    public enum Style: Sendable { case folderToFolder, folderToBin }
    public static let frameCount = 8                       // 100 ms por quadro
    public init(style: Style)
    public var frameIndex: Int
    public func start(); public func stop()
    /// Folha 16×16 em arco entre o ícone 32 da esquerda (pasta) e o da direita (pasta ou Lixeira).
    public static func pageOrigin(frame: Int, width: CGFloat) -> CGPoint
}
@MainActor public final class RetroProgressDialog {        // RetroWindow com nível .normal (não modal), conteúdo 360×176
    public init(title: String, style: FileOperationAnimation.Style, cancelTitle: String)
    public let window: RetroWindow
    public var onCancel: (() -> Void)?                      // botão Cancelar, Esc e ×
    public func update(item: String, detail: String, fraction: Double, remaining: String)
    public func show(); public func close()
}
public enum ProgressEstimate {                              // FilesCore
    /// nil antes de 2 s ou sem nada feito (o texto vira "Calculando o tempo restante...").
    public static func remaining(completed: Int64, total: Int64, elapsed: TimeInterval) -> TimeInterval?
    public static func text(_ remaining: TimeInterval?, languages: [String]) -> String   // < 60 s: segundos (arredonda para cima); senão minutos
}
```
**Layout do diálogo** (coordenadas do conteúdo, de cima para baixo):
- animação em (12, 8, 336, 48);
- linha do item em y 64; linha "De … para …" em y 80, as duas cortadas com `RetroText.fit` em 336;
- barra em (12, 100, 336, 18);
- tempo em y 124;
- Cancelar alinhado à direita em (273, 141).

- [ ] **Step 1: Testes que falham**
  - `progressBlocksFillProportionally`: com largura 336, `fraction` 0 dá 0 blocos e 1 dá 33. `fraction` 0.5 dá 16. Valores fora de 0...1 são limitados.
  - `animationPageArcs`:
    - 8 quadros, com o x subindo a cada quadro.
    - O topo do arco (menor y, coordenadas viradas) fica nos quadros 3 e 4.
    - O quadro 0 começa sobre a pasta da esquerda e o 7 termina sobre o ícone da direita.
  - `dialogCancelCallsBack`: `window.onCancel` (Esc e ×) chama `onCancel`.
  - `messageBoxFitsFourButtons`: `RetroMessageBox.layout` com ["Sim", "Sim para todos", "Não", "Cancelar"] cabe os quatro mais as margens.
  - `messageBoxKeepsBlankLines`: "a\n\nb" dá 3 linhas.
  - `remainingTimeTexts`:
    - `remaining(completed: 50, total: 100, elapsed: 10)` == 10.
    - Com `elapsed: 1`: nil.
    - Textos: `text(10)` == "10 segundos restantes"; `text(61)` == "2 minutos restantes"; `text(nil)` == "Calculando o tempo restante..."; en "10 seconds remaining".
- [ ] **Step 2: Rodar `swift test --filter ProgressTests` e `--filter ProgressEstimateTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar os mesmos filtros.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: progress dialog with an original animation`

---

### Task 5: Grade — renomear, menu de contexto, recortados, arrastar e soltar

**Files:** Modify `Sources/Retro98UI/RetroIconGrid.swift`, `PixelIcon.swift`; Create `RetroIconGrid+Editing.swift`, `RetroIconGrid+DragDrop.swift`. Test `Tests/Retro98UITests/GridInteractionTests.swift`.

**Interfaces:**
```swift
public protocol RetroIconGridDataSource {                  // + dois métodos com padrão em extensão
    func grid(_ grid: RetroIconGrid, isDimmedAt index: Int) -> Bool                          // padrão false
    func grid(_ grid: RetroIconGrid, pasteboardWriterAt index: Int) -> NSPasteboardWriting?  // padrão nil = não arrasta
}
@MainActor public protocol RetroIconGridDropDelegate: AnyObject {
    func grid(_ grid: RetroIconGrid, validateDrop info: NSDraggingInfo, onItem index: Int?) -> RetroIconGrid.DropResponse
    func grid(_ grid: RetroIconGrid, acceptDrop info: NSDraggingInfo, onItem index: Int?) -> Bool
}
extension RetroIconGrid {
    public struct DropResponse: Equatable { public let operation: NSDragOperation; public let highlightsItem: Bool }
}
// RetroIconGrid ganha:
public var onRename: ((Int) -> Void)?                 // Enter ou F2 (keyCode 120) com um item em foco; Enter não abre mais
public var onContextMenu: ((Int?, NSEvent) -> Void)?  // botão direito ou ctrl-clique; item fora da seleção vira a seleção antes
public var onEndEditing: ((Int, String?) -> Void)?    // nil = cancelado
public weak var dropDelegate: RetroIconGridDropDelegate?   // ao definir, registra .fileURL e NSFilePromiseReceiver.readableDraggedTypes
public private(set) var editingIndex: Int?
public private(set) var dropTargetIndex: Int?
public func beginEditing(at index: Int, text: String, selecting range: NSRange)
public func endEditing(commit: Bool)
public func moveEditing(to index: Int?)               // depois de recarregar; nil cancela
public enum IconGridClick {
    /// Clique simples num item já selecionado de uma seleção múltipla mantém o grupo (para arrastar) e só estreita no mouseUp.
    public static func mouseDown(on index: Int, selection: IndexSet, extend: Bool) -> (selection: IndexSet, narrowOnMouseUp: Bool)
}
// PixelIcon: public func drawDimmed(at: CGPoint, context: CGContext)   // ícone com xadrez de pixels brancos (x+y ímpar)
```
**Comportamento:**
- **Campo de edição:**
  - `NSTextField` Tahoma 13, fundo branco e borda preta de 1 px, sobre o rótulo.
  - Largura `min(max(84, texto + 8), 168)`, centrado na célula; altura `lineHeight + 4`.
  - Enter confirma, Esc cancela, perder o foco confirma. O rótulo do item não é desenhado enquanto edita.
- **Arrastar:**
  - Começa depois de 4 pt de movimento a partir de um item.
  - Leva os itens selecionados que têm `pasteboardWriter`, com a imagem de cada ícone na posição da célula.
  - Máscara: dentro do app `[.copy, .move, .generic]`; fora `[.copy, .move, .link, .generic]`.
- **Soltar:**
  - O item-alvo aparece como selecionado enquanto `highlightsItem`.
  - Rola sozinho perto das bordas. Limpa o destaque ao sair ou concluir.

- [ ] **Step 1: Testes que falham** (eventos sintéticos de `NSEvent.keyEvent` e `mouseEvent`)
  - `enterAndF2AskToRename`, `enterNoLongerOpens`.
  - `editingCommitsAndCancels`:
    - `beginEditing` cria o campo com o texto e o intervalo selecionado.
    - `endEditing(commit: true)` chama `onEndEditing(i, "novo")`; `commit: false` chama com nil.
    - `editingIndex` volta a nil.
  - `moveEditingFollowsTheItem`: depois de `moveEditing(to: 3)`, o campo fica sobre a célula 3 e mantém o texto.
  - `rightClickSelectsTheItemUnderThePointer` e `rightClickKeepsAMultipleSelection`.
  - `clickOnASelectedGroupNarrowsOnMouseUp`: `IconGridClick.mouseDown(on: 2, selection: [1, 2], extend: false)` dá ([1, 2], true); fora da seleção dá ([5], false); com ⌘ alterna.
  - `dimmedIconsAreGhosted`: num ícone esmaecido, os pixels com x+y ímpar ficam brancos e os pares mantêm a cor.
- [ ] **Step 2: Rodar `swift test --filter GridInteractionTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test`.** Esperado: PASS, inclusive os testes da grade da 3A.
- [ ] **Step 5: Commit** `feat: grid rename, context menu, dimmed items and drag and drop`

---

### Task 6: Central de operações do app

**Files:** Create `Sources/Retro98Explorer/ExplorerOperations.swift`, `ExplorerUndoManager.swift`, `ExplorerPrompter.swift`; complete `Sources/Retro98FilesCore/Prompts.swift`. Test `Tests/Retro98ExplorerTests/ExplorerOperationsTests.swift`.

**Interfaces:**
```swift
// FilesCore
public enum PromptIcon: Sendable { case question, warning, error }
public struct Prompt: Equatable, Sendable { public let title: String; public let message: String; public let icon: PromptIcon; public let buttons: [String] }
public enum Prompts {   // textos da tabela das Global Constraints; o índice do botão é a resposta
    public static func replace(_ conflict: FileConflict, existing: (size: Int64?, modified: Date?), incoming: (size: Int64?, modified: Date?),
                               languages: [String], locale: Locale, timeZone: TimeZone) -> Prompt   // 0 replace, 1 replaceAll, 2 skip, 3 cancel (um item: 0 replace, 1 skip)
    public static func trash(names: [String], languages: [String]) -> Prompt                    // 0 = Sim
    public static func deletePermanently(names: [String], languages: [String]) -> Prompt
    public static func cannotTrash(names: [String], languages: [String]) -> Prompt
    public static func emptyTrash(count: Int, languages: [String]) -> Prompt
    public static func extensionChange(from: String, to: String, languages: [String]) -> Prompt
    public static func hiddenName(languages: [String]) -> Prompt
    public static func invalidName(_ message: String, languages: [String]) -> Prompt
    public static func failure(_ failure: OperationFailure, action: FileActionName, isUndo: Bool, languages: [String]) -> Prompt?   // nil para .cancelled
}
// App
@MainActor protocol ExplorerPrompter: AnyObject { func ask(_ prompt: Prompt) -> Int }
@MainActor final class RetroPrompter: ExplorerPrompter          // RetroMessageBox.run (question→.question, warning→.warning, error→.error)
@MainActor final class ExplorerUndoManager: UndoManager {       // fachada: nunca recebe registros
    init(stack: FileUndoStack, languages: [String], perform: @escaping @MainActor (_ redo: Bool) -> Void)
    // sobrescreve canUndo, canRedo, undo(), redo(), undoActionName, redoActionName,
    // undoMenuItemTitle, redoMenuItemTitle ("Desfazer Copiar" / "Undo Copy"; sem ação: "Desfazer" / "Undo")
}
@MainActor final class ExplorerOperations {
    static let didChange = Notification.Name("Retro98ExplorerOperationsDidChange")   // pilha, recorte, fim de operação
    init(environment: ExplorerEnvironment, pasteboard: NSPasteboard = .general,
         prompter: ExplorerPrompter = RetroPrompter(), progressDelay: TimeInterval = 1)
    let undoStack: FileUndoStack
    let undoManager: ExplorerUndoManager
    let trashOrigins: TrashOrigins                     // arquivo <supportDirectory>/trash-origins.json
    private(set) var progressDialogsShown: Int         // para testes
    func copy(_ urls: [URL]); func cut(_ urls: [URL])
    func isCut(_ url: URL) -> Bool                     // vale enquanto pasteboard.changeCount for o do recorte
    var canPaste: Bool { get }                         // há URLs de arquivo na área de transferência
    func paste(into folder: URL, forceMove: Bool = false) async -> [URL]
    func transfer(_ urls: [URL], kind: FileOperationKind, into folder: URL) async -> [URL]
    func trash(_ urls: [URL]) async                    // pergunta; recusados → oferece excluir permanentemente
    func deletePermanently(_ urls: [URL]) async        // pergunta
    func emptyTrash(count: Int) async                  // pergunta; apaga tudo em environment.trash; limpa a pilha
    func restore(_ urls: [URL]) async -> [URL]         // ação .restore
    func canRestore(_ url: URL) -> Bool
    func newFolder(in folder: URL) async -> URL?
    func rename(_ entry: FileEntry, to typed: String) async -> URL?   // RenameRules + perguntas; app: edita sem ".app" e recoloca
    func undo() async; func redo() async
}
```
**Comportamento:**
- **Fluxo de cada operação:**
  1. `undoStack.beginWork()`.
  2. Roda o motor numa fila global com `.userInitiated`.
  3. `resolve` bloqueia a fila e pergunta na thread principal; `progress` é repassado à principal, no máximo a cada 100 ms.
  4. Ao terminar: `endWork()`, `record` na pilha, `trashOrigins.record`, mostra a falha (se houver) e posta `didChange`.
- **Progresso:** se a operação ainda roda depois de `progressDelay`, abre um `RetroProgressDialog`.
  - Copiar e mover usam a animação `folderToFolder`; Lixeira e exclusão, `folderToBin`.
  - Cancelar chama `control.cancel()`.
- **Área de transferência:**
  - `copy` e `cut` escrevem `[NSURL]` com `writeObjects`, o mesmo formato que o Finder lê e escreve.
  - `cut` guarda o `changeCount`. Colar um recorte move, depois limpa a área e esquece o recorte.
  - `paste` lê com `readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])`.
- **`undo`/`redo`:** chamam `undoStack.undo { await revert($0) }`. Uma falha mostra `Prompts.failure(isUndo: true)`; se for de permissão dentro da Lixeira, anexa o texto "Sem acesso à Lixeira".

- [ ] **Step 1: Testes que falham** (pasteboard único, `ScriptedPrompter` que grava os `Prompt` e devolve respostas da fila, ambiente de `TempTree`)
  - **Área de transferência:**
    - `copyWritesFileURLsTheFinderReads`: depois de `copy([a])`, `readObjects(NSURL)` == [a].
    - `pasteReadsWhatTheFinderCopied`: escrever `[NSURL]` direto e `paste(into: B)` cria B/a.
    - `cutThenPasteMoves`: a origem sai; a área fica vazia; `isCut(a)` falso.
    - `cutIsForgottenWhenSomethingElseIsCopied`: com o `changeCount` mudado, colar copia.
    - `moveItemHereMovesCopiedFiles`: `forceMove: true` move.
  - **Lixeira:**
    - `trashAsksFirst`: com "Não" nada muda. Com "Sim" o item vai para a Lixeira de teste e `canRestore(t)` fica verdadeiro. O prompt é igual a `Prompts.trash(names: ["a.txt"], …)`.
    - `refusedTrashOffersPermanentDelete`: com `moveToTrash` lançando erro, responder "Sim" apaga o item.
    - `emptyTrashAsksAndClearsUndo`.
    - `restorePutsItemsBack`: o arquivo volta; `canRestore` fica falso.
  - **Desfazer:**
    - `undoAfterPasteSendsTheCopyToTheTrash` e `redoBringsItBack`. O título do menu é "Desfazer Copiar" e depois "Refazer Copiar".
    - `undoWithoutTrashAccessExplains`: a Lixeira de teste com chmod 000 depois de excluir faz o desfazer mostrar um erro com o texto "Sem acesso à Lixeira".
  - **Conflitos e falhas:**
    - `conflictPromptShowsBothItems`: a mensagem contém os dois tamanhos e as duas datas formatados. O fuso fixo do teste é `TimeZone(identifier: "America/Sao_Paulo")!`, passado a `Prompts.replace`.
    - `failuresAreShownOnce`: copiar uma origem que sumiu dá um prompt de erro com o nome do item.
  - **Progresso:** `longOperationsShowAProgressDialog`: com `progressDelay: 0` e 300 arquivos, `progressDialogsShown == 1` e o diálogo fecha no fim.
  - **Renomear:** `renameAsksBeforeChangingTheExtension`: "Não" mantém o nome; "Sim" renomeia.
- [ ] **Step 2: Rodar `swift test --filter ExplorerOperationsTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test --filter ExplorerOperationsTests`.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: Explorer operations center (clipboard, trash, undo, progress)`

---

### Task 7: Comandos na janela — menus, barra de ferramentas, teclado, menu de contexto

**Files:** Create `Sources/Retro98Explorer/ExplorerCommands.swift`; Modify `ExplorerMenus.swift`, `ExplorerWindowController.swift`, `AppDelegate.swift`, `Sources/Retro98FilesCore/ExplorerModel.swift`. Test `Tests/Retro98ExplorerTests/ExplorerCommandsTests.swift`, `Tests/Retro98FilesCoreTests/ExplorerControllerModelTests.swift`.

**Interfaces:**
```swift
// ExplorerWindowController
init(start: Location, languages: [String], environment: ExplorerEnvironment? = nil, operations: ExplorerOperations? = nil)
func windowWillReturnUndoManager(_ window: NSWindow) -> UndoManager?   // operations.undoManager (o mesmo em todas as janelas)
// ações (@objc; ficam na cadeia de resposta como delegado da janela) + NSMenuItemValidation:
openSelection(_:) newFolder(_:) renameSelection(_:) moveToTrash(_:) deletePermanently(_:)
restoreFromTrash(_:) emptyTrash(_:) openTrashInFinder(_:) cut(_:) copy(_:) paste(_:) moveItemHere(_:)
func contextMenuItems(at index: Int?) -> [RetroMenuItem]
// ExplorerMenus
static func validated(_ command: Command) -> (title: String, isEnabled: Bool)   // valida pelo alvo como o AppKit faz
```
**Menus:**
- **Arquivo:** Abrir ⌘O, Nova janela ⌘N, Nova pasta ⇧⌘N, —, Renomear, Excluir ⌘⌫, Excluir permanentemente ⌥⌘⌫, —, Restaurar, Esvaziar Lixeira ⇧⌘⌫, Abrir no Finder, —, Fechar ⌘W.
- **Editar:** Desfazer ⌘Z, Refazer ⇧⌘Z, —, Recortar ⌘X, Copiar ⌘C, Colar ⌘V, Mover para cá ⌥⌘V, —, Selecionar tudo ⌘A.
- **Teclas no menu:** ⌘⌫ é `"\u{8}"` com `.command`. Renomear não tem tecla no menu (Enter e F2 ficam só na grade).

**Barra de menus da janela:** cada item usa `ExplorerMenus.validated`, que dá o título e o estado do alvo. Assim "Desfazer Copiar" aparece igual ao do macOS.

**Validação:**
- Tudo desligado se o primeiro respondedor da janela é um `NSText`, ou seja, se há texto sendo editado.
- **Seleção:** Copiar, Recortar, Excluir e Renomear pedem seleção de itens com `isFileItem`; Renomear pede exatamente um.
- **Destino:** Colar, Mover para cá e Nova pasta pedem `canPaste` (só as duas primeiras) e um destino: `DropRules.target(entry: nil, …)` com `.folder`.
- **Lixeira:**
  - Restaurar só na Lixeira, com todos os selecionados em `canRestore`.
  - Esvaziar Lixeira só com a Lixeira legível e com itens.
  - Abrir no Finder só na Lixeira.
  - Na Lixeira, ⌘⌫ e Del levam a `deletePermanently`.

**Barra de ferramentas:**
- Recortar, Copiar, Colar, Desfazer e Excluir passam a funcionar, com o mesmo estado dos menus.
- Propriedades e Modos continuam desabilitados (3C).
- Atualiza ao mudar a seleção, ao receber `didChange` e ao virar janela principal.

**Teclado** (`handleKey` + grade):
- Del (117): Lixeira; ⇧Del: permanente.
- `grid.onRename`: renomear.
- ⌘↓: abrir, como na 3A.

**Menu de contexto** (`RetroMenu` na posição do clique, estilo `.standard`):
- **Item de arquivo:** Abrir, (Restaurar na Lixeira), —, Recortar, Copiar, (Colar se for pasta), —, Excluir, Renomear, —, Propriedades (desabilitado).
- **Fundo:** Colar, Mover para cá, —, Nova pasta, —, Atualizar. Na Lixeira: Esvaziar Lixeira e Abrir no Finder.
- **Ícone da Lixeira na Área de Trabalho:** Abrir, Esvaziar Lixeira.
- **Meu Computador e volumes:** Abrir.

**Depois de uma operação:**
- A janela que pediu recarrega o modelo e seleciona os `results`.
- Nova pasta já entra renomeando, com o nome todo selecionado.
- Renomear seleciona o item com o nome novo.
- No campo de renomear, o texto selecionado é o nome sem a extensão. Pastas e apps selecionam o nome todo.
- Os itens em `isCut` aparecem esmaecidos.

**`refresh()` com renomeação ativa:** move o campo para o novo índice do mesmo URL, ou cancela se o item sumiu.

**`ExplorerModel`:** Voltar ou Avançar para uma pasta que não existe mais usa `NavigationHistory.recover`, como o `reload`.

- [ ] **Step 1: Testes que falham** (controlador com `ExplorerOperations` de teste: pasteboard único e `ScriptedPrompter`)
  - **Estado dos comandos:**
    - `fileCommandsFollowTheSelection`: sem seleção, `copy:` e `moveToTrash:` ficam desabilitados. Com um arquivo, habilitados. Com Meu Computador na seleção, desabilitados.
    - `fileCommandsIgnoreTextEditing`: com o endereço em edição e um arquivo selecionado, `validateMenuItem(moveToTrash:)` é falso. `NSApp.sendAction(moveToTrash:)` não muda nada no disco.
    - `retroEditMenuShowsTheUndoTitle`: depois de colar, o 1º item do Editar da janela é ("Desfazer Copiar", habilitado).
    - `menusHaveTheFileShortcuts`: ⌘O, ⇧⌘N, ⌘⌫, ⌥⌘⌫, ⇧⌘⌫ e ⌥⌘V com os seletores certos.
  - **Fluxos:**
    - `newFolderStartsRenaming`: aparece "Nova pasta" selecionada e `grid.editingIndex` aponta para ela.
    - `renamingCommitsThroughTheGrid`: `onEndEditing` com "b.txt" renomeia e seleciona b.txt.
    - `renameSurvivesABackgroundReload`: editando "b.txt", criar "a.txt" e `reload()`; `editingIndex` aponta para b.txt e o texto continua.
    - `pastedItemsAreSelected`.
    - `desktopPasteGoesToTheDesktopFolder`.
    - `cutItemsLookDimmed`.
  - **Menus de contexto:**
    - `contextMenuOnBackgroundOffersPasteAndNewFolder`: títulos e estados.
    - `trashViewOffersRestoreAndEmpty`: Restaurar habilitado só para item com origem conhecida.
  - **Modelo:** `backToADeletedFolderRecovers`, em FilesCore.
- [ ] **Step 2: Rodar `swift test --filter ExplorerCommandsTests` e `--filter ExplorerControllerModelTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.** `AppDelegate` cria uma `ExplorerOperations(environment: .live(languages:))` e passa a todas as janelas. Atualizar o comentário do topo de `ExplorerMenus`.
- [ ] **Step 4: Rodar `swift test` e `swift build -c release --product Retro98Explorer` sem warnings.** Esperado: PASS.
- [ ] **Step 5: Commit** `feat: file commands in Explorer windows (menus, toolbar, keys, context menu)`

---

### Task 8: Arrastar e soltar na janela

**Files:** Create `Sources/Retro98Explorer/ExplorerDragDrop.swift`. Test `Tests/Retro98ExplorerTests/ExplorerDragDropTests.swift`.

**Interfaces:**
```swift
enum DropPlan: Equatable { case transfer(FileOperationKind, into: URL), trash }
extension ExplorerWindowController: RetroIconGridDropDelegate {
    /// forceCopy: a máscara da origem só tem .copy (⌥); forceMove: tem .move ou .generic e não .copy (⌘).
    func dropPlan(for urls: [URL], onItem index: Int?, forceCopy: Bool, forceMove: Bool) -> DropPlan?
    func performDrop(_ plan: DropPlan, urls: [URL]) async -> [URL]
}
// a grade recebe pasteboardWriter = entry.url as NSURL para itens com isFileItem (os outros não arrastam)
```
**Comportamento:**
- **Validação:**
  - Lê as URLs de arquivo do `draggingPasteboard`.
  - Calcula `dropPlan`: o alvo vem de `DropRules.target`, a operação de `DropRules.operation` com `environment.isSameVolume(primeira origem, destino)`.
  - Responde `.copy` ou `.move` (`.move` para a Lixeira); um item-alvo fica destacado.
- **Soltar:** chama `performDrop`. `.trash` passa por `operations.trash`, que pergunta; transferências passam por `operations.transfer`. Depois a janela seleciona os resultados.
- **Promessas de arquivo** (Fotos, Mail): sem URLs, mas com `NSFilePromiseReceiver`, recebe na pasta-alvo com `receivePromisedFiles(atDestination:options:operationQueue:reader:)`, sem perguntas nem desfazer.

- [ ] **Step 1: Testes que falham**
  - `dropPlansFollowTheItemUnderThePointer`:
    - Sobre uma pasta: `.transfer(.move, into: pasta)`.
    - Sobre um arquivo comum: vale o fundo, a pasta atual (nil se a origem já está nela).
    - Sobre a Lixeira na Área de Trabalho: `.trash`.
    - Sobre Meus Documentos: transfere para home/Documents.
    - Fundo de Meu Computador: nil. Sobre o próprio item arrastado: nil. Com `forceCopy` na própria pasta: `.transfer(.copy, …)`.
  - `droppingOnTheRecycleBinAsksFirst`: "Não" mantém; "Sim" manda para a Lixeira de teste.
  - `droppedItemsAreSelected`.
  - `onlyFilesAreDraggable`: o writer de um arquivo é `NSURL` com o caminho; o de Meu Computador é nil.
- [ ] **Step 2: Rodar `swift test --filter ExplorerDragDropTests`.** Esperado: FAIL.
- [ ] **Step 3: Implementar.**
- [ ] **Step 4: Rodar `swift test`.** Esperado: tudo PASS.
- [ ] **Step 5: Commit** `feat: drag and drop in Explorer windows`

---

### Task 9: Versão, instalador e README

**Files:** Modify `scripts/build-app.sh`, `install.sh` (texto do aviso de Acesso Total ao Disco, pt-BR e en), `README.md`, `README.pt-BR.md`.

- [ ] **Step 1: Versão 0.5.0, build 5.**
- [ ] **Step 2: Novo aviso de Acesso Total ao Disco.**
  - pt-BR: "Para o Explorer mostrar, restaurar e esvaziar a Lixeira, dê Acesso Total ao Disco só ao Retro98 Explorer em Ajustes do Sistema › Privacidade e Segurança › Acesso Total ao Disco (opcional; o resto funciona sem isso, e o Retro98 Shell não precisa)."
  - en: equivalente.
  - O caso `explorer-fda-hint` continua passando.
- [ ] **Step 3: README** (pt-BR e en):
  - Na tabela, 3B fica "✅ disponível".
  - A seção "Explorer" ganha as operações e a tabela de atalhos das Global Constraints. Destaques: Enter renomeia, ⌥⌘V move o que foi copiado, Desfazer vale para o app inteiro.
  - Limites:
    - "Restaurar" só conhece itens mandados para a Lixeira pelo Explorer; os outros voltam pelo "Devolver" do Finder.
    - A janela da Lixeira mostra e esvazia só a Lixeira do disco do usuário; itens apagados de pen drives o Finder esvazia.
    - Arrastar de Fotos ou do Mail não entra no Desfazer.
  - "Nas próximas entregas" fica só com a 3C.
- [ ] **Step 4: Rodar `swift test`, depois os três scripts no bash do sistema.** Esperado: tudo PASS e lista de chaveiros inalterada.
- [ ] **Step 5: Commit** `docs: Explorer file operations (Phase 3B)`

---

### Aceitação pelo autor (manual, no Mac dele, depois da Task 9)

O autor roda `./install.sh --yes` (ou autoriza explicitamente) e confere:

- [ ] **Com o Finder:**
  - Copiar no Explorer e colar no Finder funciona, e o contrário também.
  - ⌥⌘V no Explorer move o que foi copiado no Finder.
- [ ] **Recortar:** recortar e colar move, e o ícone fica esmaecido até colar.
- [ ] **Conflito:** colar por cima de um arquivo existente pergunta "Substituir arquivo". Sim, Sim para todos, Não e Cancelar fazem o que dizem, e o item substituído aparece na Lixeira.
- [ ] **Progresso:** copiar uma pasta grande (alguns GB, de preferência para um pen drive) mostra o diálogo com a animação, a barra e o tempo.
  - Cancelar para tudo e não deixa item pela metade.
  - A janela continua usável durante a cópia.
- [ ] **Arrastar:**
  - Entre duas janelas do Explorer, do Explorer para o Finder e do Finder para o Explorer.
  - ⌥ copia e ⌘ move.
  - Soltar sobre uma pasta, sobre Meus Documentos e sobre a Lixeira (pergunta antes).
  - Arrastar uma foto do Fotos ou um anexo do Mail para o Explorer.
- [ ] **Renomear e nova pasta:**
  - F2 e Enter renomeiam.
  - Mudar a extensão pergunta, e só trocar maiúsculas funciona.
  - Nova pasta (⇧⌘N e menu de contexto) já entra renomeando.
- [ ] **Lixeira:**
  - ⌘⌫ e Del perguntam e mandam para a Lixeira.
  - Na Lixeira, Restaurar devolve itens excluídos pelo Explorer, e Esvaziar Lixeira pergunta e esvazia (com Acesso Total ao Disco).
- [ ] **Desfazer:** ⌘Z e o botão Desfazer revertem colar, mover, renomear, nova pasta e excluir; ⇧⌘Z refaz. O menu do macOS mostra "Desfazer <ação>".
- [ ] **Digitando:** com o cursor no endereço, ⌘⌫, ⌘Z, ⌘C e ⌘V mexem só no texto.
- [ ] **Desinstalar:** `./uninstall.sh` continua removendo tudo.
