import Retro98FilesCore
import Retro98Settings

/// The open and save dialogs' words in Brazilian Portuguese or English, following the system language.
enum FileDialogText {
    private static func text(_ l: [String], _ ptBR: String, _ en: String) -> String {
        LocalizedText(en: en, ptBR: ptBR).resolve(for: l)
    }

    static func title(_ mode: FileDialogMode, _ l: [String]) -> String {
        mode == .open ? text(l, "Abrir", "Open") : text(l, "Salvar como", "Save As")
    }

    static func lookIn(_ mode: FileDialogMode, _ l: [String]) -> String {
        mode == .open ? text(l, "Examinar:", "Look in:") : text(l, "Salvar em:", "Save in:")
    }

    static func fileName(_ l: [String]) -> String { text(l, "Nome do arquivo:", "File name:") }

    static func filesOfType(_ mode: FileDialogMode, _ l: [String]) -> String {
        mode == .open ? text(l, "Arquivos do tipo:", "Files of type:") : text(l, "Salvar como tipo:", "Save as type:")
    }

    static func confirm(_ mode: FileDialogMode, _ l: [String]) -> String {
        mode == .open ? text(l, "Abrir", "Open") : text(l, "Salvar", "Save")
    }

    static func cancel(_ l: [String]) -> String { text(l, "Cancelar", "Cancel") }
    static func yes(_ l: [String]) -> String { text(l, "Sim", "Yes") }
    static func no(_ l: [String]) -> String { text(l, "Não", "No") }

    static func notFound(_ name: String, _ l: [String]) -> String {
        text(l, "\(name)\nArquivo não encontrado.\nVerifique se o nome do arquivo está correto.",
             "\(name)\nFile not found.\nCheck the file name and try again.")
    }

    static func replace(_ name: String, _ l: [String]) -> String {
        text(l, "\(name) já existe.\nDeseja substituí-lo?", "\(name) already exists.\nDo you want to replace it?")
    }

    static func invalidName(_ name: String, _ l: [String]) -> String {
        text(l, "\(name)\nO nome do arquivo não é válido.", "\(name)\nThe file name is not valid.")
    }

    static func folderNotFound(_ path: String, _ l: [String]) -> String {
        text(l, "\(path)\nO caminho não existe.\nVerifique se o caminho está correto.",
             "\(path)\nThe path does not exist.\nCheck the path and try again.")
    }

    static func cannotOpenFolder(_ name: String, _ l: [String]) -> String {
        text(l, "Não foi possível abrir \(name): o macOS não deu acesso a essa pasta ou ela não existe mais.",
             "Can't open \(name): macOS didn't allow access to it or it no longer exists.")
    }
}
