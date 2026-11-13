import Foundation
import Retro98FilesCore
import Retro98Settings

/// The Notepad's words in Brazilian Portuguese or English, following the system language.
enum NotepadText {
    private static func text(_ l: [String], _ ptBR: String, _ en: String) -> String {
        LocalizedText(en: en, ptBR: ptBR).resolve(for: l)
    }

    static let appName = "Retro98 Notepad"

    /// The name in window titles and message boxes.
    static func name(_ l: [String]) -> String { text(l, "Bloco de Notas", "Notepad") }
    static func untitled(_ l: [String]) -> String { text(l, "Sem título", "Untitled") }
    static func untitledFileName(_ l: [String]) -> String { untitled(l) + ".txt" }

    /// "notas.txt - Bloco de Notas", or "Sem título - Bloco de Notas" before the first save.
    static func windowTitle(fileName: String?, _ l: [String]) -> String {
        "\(fileName ?? untitled(l)) - \(name(l))"
    }

    static func askToSave(fileName: String?, _ l: [String]) -> String {
        let file = fileName ?? untitled(l)
        return text(l, "O texto no arquivo \(file) foi alterado.\n\nDeseja salvar as alterações?",
                    "The text in the \(file) file has changed.\n\nDo you want to save the changes?")
    }

    static func openError(_ error: TextFileError, fileName: String, _ l: [String]) -> String {
        switch error {
        case .notUTF8:
            text(l, "Não foi possível abrir \(fileName): o arquivo não é texto em UTF-8.",
                 "Can't open \(fileName): the file isn't UTF-8 text.")
        case .notText:
            text(l, "Não foi possível abrir \(fileName): o arquivo não parece ser texto.",
                 "Can't open \(fileName): the file doesn't look like text.")
        case .tooLarge:
            text(l, "Não foi possível abrir \(fileName): o arquivo passa de 10 MB, o limite do Bloco de Notas.",
                 "Can't open \(fileName): the file is over 10 MB, Notepad's limit.")
        case .unreadable:
            text(l, "Não foi possível abrir \(fileName): o arquivo não pôde ser lido.",
                 "Can't open \(fileName): the file couldn't be read.")
        }
    }

    static func saveError(fileName: String, _ l: [String]) -> String {
        text(l, "Não foi possível salvar \(fileName). Verifique se você pode gravar nessa pasta e se há espaço no disco.",
             "Couldn't save \(fileName). Check that you can write to that folder and that the disk has room.")
    }

    static func notFound(_ needle: String, _ l: [String]) -> String {
        text(l, "Não foi possível localizar \"\(needle)\"", "Cannot find \"\(needle)\"")
    }

    /// The short time, a space and the short date, as the Mac's language writes them.
    static func timeDate(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        let time = formatter.string(from: date)
        formatter.timeStyle = .none
        formatter.dateStyle = .short
        return time + " " + formatter.string(from: date)
    }

    /// The open and save dialogs' file types: text first, then everything.
    static func filters(_ l: [String]) -> [FileTypeFilter] {
        [FileTypeFilter(title: text(l, "Documentos de texto (*.txt)", "Text Documents (*.txt)"), extensions: ["txt"]),
         FileTypeFilter(title: text(l, "Todos os arquivos (*.*)", "All Files (*.*)"), extensions: [])]
    }

    static func yes(_ l: [String]) -> String { text(l, "Sim", "Yes") }
    static func no(_ l: [String]) -> String { text(l, "Não", "No") }
    static func cancel(_ l: [String]) -> String { text(l, "Cancelar", "Cancel") }

    // MARK: Find

    static func findTitle(_ l: [String]) -> String { text(l, "Localizar", "Find") }
    static func findWhat(_ l: [String]) -> String { text(l, "Localizar:", "Find what:") }
    static func matchCase(_ l: [String]) -> String { text(l, "Diferenciar maiúsculas e minúsculas", "Match case") }
    static func direction(_ l: [String]) -> String { text(l, "Direção", "Direction") }
    static func up(_ l: [String]) -> String { text(l, "Acima", "Up") }
    static func down(_ l: [String]) -> String { text(l, "Abaixo", "Down") }

    // MARK: Menus (the Prompt's and the Explorer's wording)

    static func menuFile(_ l: [String]) -> String { text(l, "Arquivo", "File") }
    static func menuEdit(_ l: [String]) -> String { text(l, "Editar", "Edit") }
    static func menuSearch(_ l: [String]) -> String { text(l, "Pesquisar", "Search") }
    static func menuFormat(_ l: [String]) -> String { text(l, "Formatar", "Format") }
    static func menuWindow(_ l: [String]) -> String { text(l, "Janela", "Window") }
    static func menuHelp(_ l: [String]) -> String { text(l, "Ajuda", "Help") }
    static func new(_ l: [String]) -> String { text(l, "Novo", "New") }
    static func open(_ l: [String]) -> String { text(l, "Abrir…", "Open…") }
    static func save(_ l: [String]) -> String { text(l, "Salvar", "Save") }
    static func saveAs(_ l: [String]) -> String { text(l, "Salvar como…", "Save As…") }
    static func close(_ l: [String]) -> String { text(l, "Fechar", "Close") }
    static func undo(_ l: [String]) -> String { text(l, "Desfazer", "Undo") }
    static func redo(_ l: [String]) -> String { text(l, "Refazer", "Redo") }
    static func cut(_ l: [String]) -> String { text(l, "Recortar", "Cut") }
    static func copy(_ l: [String]) -> String { text(l, "Copiar", "Copy") }
    static func paste(_ l: [String]) -> String { text(l, "Colar", "Paste") }
    static func delete(_ l: [String]) -> String { text(l, "Excluir", "Delete") }
    static func selectAll(_ l: [String]) -> String { text(l, "Selecionar tudo", "Select All") }
    static func timeDateItem(_ l: [String]) -> String { text(l, "Hora/data", "Time/Date") }
    static func find(_ l: [String]) -> String { text(l, "Localizar…", "Find…") }
    static func findNext(_ l: [String]) -> String { text(l, "Localizar próxima", "Find Next") }
    static func wordWrap(_ l: [String]) -> String { text(l, "Quebra automática de linha", "Word Wrap") }
    static func readme(_ l: [String]) -> String { text(l, "Ajuda do Retro98 (README)", "Retro98 Help (README)") }
    static func about(_ l: [String]) -> String { text(l, "Sobre o Retro98 Notepad", "About Retro98 Notepad") }
    static func hide(_ l: [String]) -> String { text(l, "Ocultar Retro98 Notepad", "Hide Retro98 Notepad") }
    static func hideOthers(_ l: [String]) -> String { text(l, "Ocultar Outros", "Hide Others") }
    static func showAll(_ l: [String]) -> String { text(l, "Mostrar Tudo", "Show All") }
    static func quit(_ l: [String]) -> String { text(l, "Encerrar Retro98 Notepad", "Quit Retro98 Notepad") }
    static func minimize(_ l: [String]) -> String { text(l, "Minimizar", "Minimize") }
    static func zoom(_ l: [String]) -> String { "Zoom" }
    static func bringAllToFront(_ l: [String]) -> String { text(l, "Trazer Tudo para a Frente", "Bring All to Front") }

    static func aboutCredits(_ l: [String]) -> String {
        text(l, "Fonte: PxPlus IBM VGA 8x16, de VileR (int10h.org), CC BY-SA 4.0.",
             "Font: PxPlus IBM VGA 8x16 by VileR (int10h.org), CC BY-SA 4.0.")
    }
}
