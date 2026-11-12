import Foundation
import Retro98Settings

/// The "time remaining" line of the progress dialog.
public enum ProgressEstimate {
    static let warmUp: TimeInterval = 2

    /// nil until there is enough to go on (2 s and some progress).
    public static func remaining(completed: Int64, total: Int64, elapsed: TimeInterval) -> TimeInterval? {
        guard elapsed >= warmUp, completed > 0, total >= completed else { return nil }
        return Double(total - completed) * elapsed / Double(completed)
    }

    /// Seconds under a minute, minutes after that, both rounded up.
    public static func text(_ remaining: TimeInterval?, languages: [String]) -> String {
        guard let remaining else {
            return LocalizedText(en: "Calculating the time remaining...", ptBR: "Calculando o tempo restante...").resolve(for: languages)
        }
        if remaining < 60 {
            let seconds = max(1, Int(remaining.rounded(.up)))
            return seconds == 1
                ? LocalizedText(en: "1 second remaining", ptBR: "1 segundo restante").resolve(for: languages)
                : LocalizedText(en: "\(seconds) seconds remaining", ptBR: "\(seconds) segundos restantes").resolve(for: languages)
        }
        let minutes = Int((remaining / 60).rounded(.up))
        return LocalizedText(en: "\(minutes) minutes remaining", ptBR: "\(minutes) minutos restantes").resolve(for: languages)
    }
}

public enum PromptIcon: Equatable, Sendable {
    case question, warning, error
}

/// A question or message box: the index of the chosen button is the answer (Esc picks the last one).
public struct Prompt: Equatable, Sendable {
    public let title: String
    public let message: String
    public let icon: PromptIcon
    public let buttons: [String]

    public init(title: String, message: String, icon: PromptIcon, buttons: [String]) {
        self.title = title
        self.message = message
        self.icon = icon
        self.buttons = buttons
    }

    public func appending(_ text: String) -> Prompt {
        Prompt(title: title, message: message + "\n\n" + text, icon: icon, buttons: buttons)
    }
}

/// The Explorer's dialogs, in Brazilian Portuguese and English.
public enum Prompts {
    private static func text(_ en: String, _ ptBR: String, _ l: [String]) -> String {
        LocalizedText(en: en, ptBR: ptBR).resolve(for: l)
    }

    private static func yesNo(_ l: [String]) -> [String] { [text("Yes", "Sim", l), text("No", "Não", l)] }
    private static func confirmDelete(_ l: [String]) -> String { text("Confirm Delete", "Confirmar exclusão", l) }

    /// Answers: 0 replace, 1 replaceAll, 2 skip, 3 cancel; with no items left, 0 replace and 1 skip.
    public static func replace(_ conflict: FileConflict, existing: (size: Int64?, modified: Date?),
                               incoming: (size: Int64?, modified: Date?), languages l: [String],
                               locale: Locale, timeZone: TimeZone) -> Prompt {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        func details(_ item: (size: Int64?, modified: Date?)) -> String {
            [item.size.map { StatusText.bytes($0, locale: locale) },
             item.modified.map { text("modified ", "modificado em ", l) + formatter.string(from: $0) }]
                .compactMap { $0 }.joined(separator: ", ")
        }
        let name = conflict.existing.lastPathComponent
        let message = text("This folder already contains an item named '\(name)'.\n\nWould you like to replace the existing item\n",
                           "Esta pasta já contém um item chamado '\(name)'.\n\nDeseja substituir o item existente\n", l)
            + details(existing) + text("\n\nwith this one?\n", "\n\npor este?\n", l) + details(incoming)
        let buttons = conflict.remaining > 0
            ? [text("Yes", "Sim", l), text("Yes to All", "Sim para todos", l), text("No", "Não", l), text("Cancel", "Cancelar", l)]
            : yesNo(l)
        return Prompt(title: text("Replace File", "Substituir arquivo", l), message: message, icon: .question, buttons: buttons)
    }

    public static func conflictChoice(answer: Int, remaining: Int) -> ConflictChoice {
        if remaining == 0 { return answer == 0 ? .replace : .skip }
        return [.replace, .replaceAll, .skip, .cancel][min(max(answer, 0), 3)]
    }

    public static func trash(names: [String], languages l: [String]) -> Prompt {
        let message = names.count == 1
            ? text("Are you sure you want to send '\(names[0])' to the Recycle Bin?",
                   "Tem certeza de que deseja enviar '\(names[0])' para a Lixeira?", l)
            : text("Are you sure you want to send these \(names.count) items to the Recycle Bin?",
                   "Tem certeza de que deseja enviar estes \(names.count) itens para a Lixeira?", l)
        return Prompt(title: confirmDelete(l), message: message, icon: .question, buttons: yesNo(l))
    }

    public static func deletePermanently(names: [String], languages l: [String]) -> Prompt {
        let message = names.count == 1
            ? text("Are you sure you want to permanently delete '\(names[0])'? This can't be undone.",
                   "Tem certeza de que deseja excluir '\(names[0])' permanentemente? Isso não pode ser desfeito.", l)
            : text("Are you sure you want to permanently delete these \(names.count) items? This can't be undone.",
                   "Tem certeza de que deseja excluir estes \(names.count) itens permanentemente? Isso não pode ser desfeito.", l)
        return Prompt(title: confirmDelete(l), message: message, icon: .warning, buttons: yesNo(l))
    }

    public static func cannotTrash(names: [String], languages l: [String]) -> Prompt {
        let message = names.count == 1
            ? text("'\(names[0])' can't go to the Recycle Bin. Do you want to delete it permanently?",
                   "'\(names[0])' não pode ir para a Lixeira. Deseja excluí-lo permanentemente?", l)
            : text("These \(names.count) items can't go to the Recycle Bin. Do you want to delete them permanently?",
                   "Estes \(names.count) itens não podem ir para a Lixeira. Deseja excluí-los permanentemente?", l)
        return Prompt(title: confirmDelete(l), message: message, icon: .warning, buttons: yesNo(l))
    }

    public static func emptyTrash(count: Int, languages l: [String]) -> Prompt {
        let message = count == 1
            ? text("Are you sure you want to permanently delete the item in the Recycle Bin?",
                   "Tem certeza de que deseja excluir permanentemente o item da Lixeira?", l)
            : text("Are you sure you want to permanently delete the \(count) items in the Recycle Bin?",
                   "Tem certeza de que deseja excluir permanentemente os \(count) itens da Lixeira?", l)
        return Prompt(title: confirmDelete(l), message: message, icon: .warning, buttons: yesNo(l))
    }

    public static func extensionChange(from: String, to: String, languages l: [String]) -> Prompt {
        Prompt(title: ExplorerText.rename(l),
               message: text("If you change the extension from '\(from)' to '\(to)', the file may open in another app or stop opening. Change it?",
                             "Se você mudar a extensão de '\(from)' para '\(to)', o arquivo pode abrir em outro app ou deixar de abrir. Deseja mudar?", l),
               icon: .warning, buttons: yesNo(l))
    }

    public static func hiddenName(languages l: [String]) -> Prompt {
        Prompt(title: ExplorerText.rename(l),
               message: text("Names that begin with '.' are hidden. Use this name anyway?",
                             "Nomes que começam com '.' ficam ocultos. Deseja usar este nome?", l),
               icon: .warning, buttons: yesNo(l))
    }

    public static func invalidName(_ message: String, languages l: [String]) -> Prompt {
        Prompt(title: errorTitle(.rename, isUndo: false, l), message: message, icon: .error, buttons: ["OK"])
    }

    /// nil for a cancel (nothing to say) and for items the Trash refused (the caller offers to delete them).
    public static func failure(_ failure: OperationFailure, action: FileActionName, isUndo: Bool, languages l: [String]) -> Prompt? {
        let message: String
        switch failure {
        case .cancelled, .cannotTrash:
            return nil
        case .intoItself(let item):
            message = action == .copy
                ? text("Can't copy '\(item.lastPathComponent)': the destination folder is inside it.",
                       "Não é possível copiar '\(item.lastPathComponent)': a pasta de destino está dentro dela.", l)
                : text("Can't move '\(item.lastPathComponent)': the destination folder is inside it.",
                       "Não é possível mover '\(item.lastPathComponent)': a pasta de destino está dentro dela.", l)
        case .replacesItsOwnSource(let item):
            message = action == .copy
                ? text("Can't replace '\(item.lastPathComponent)': it contains the item being copied.",
                       "Não é possível substituir '\(item.lastPathComponent)': ela contém o item que está sendo copiado.", l)
                : text("Can't replace '\(item.lastPathComponent)': it contains the item being moved.",
                       "Não é possível substituir '\(item.lastPathComponent)': ela contém o item que está sendo movido.", l)
        case .alreadyExists(let item):
            message = text("There is already an item named '\(item.lastPathComponent)'. Choose another name.",
                           "Já existe um item chamado '\(item.lastPathComponent)'. Escolha outro nome.", l)
        case .failed(let item, let reason):
            message = isUndo
                ? text("Couldn't undo. '\(item.lastPathComponent)': \(reason)", "Não foi possível desfazer. '\(item.lastPathComponent)': \(reason)", l)
                : text("Couldn't \(verb(action, en: true)) '\(item.lastPathComponent)': \(reason)",
                       "Não foi possível \(verb(action, en: false)) '\(item.lastPathComponent)': \(reason)", l)
        }
        return Prompt(title: errorTitle(action, isUndo: isUndo, l), message: message, icon: .error, buttons: ["OK"])
    }

    private static func errorTitle(_ action: FileActionName, isUndo: Bool, _ l: [String]) -> String {
        if isUndo { return text("Error Undoing", "Erro ao desfazer", l) }
        switch action {
        case .copy: return text("Error Copying", "Erro ao copiar", l)
        case .move: return text("Error Moving", "Erro ao mover", l)
        case .rename: return text("Error Renaming", "Erro ao renomear", l)
        case .newFolder: return text("Error Creating Folder", "Erro ao criar pasta", l)
        case .delete: return text("Error Deleting", "Erro ao excluir", l)
        case .restore: return text("Error Restoring", "Erro ao restaurar", l)
        }
    }

    private static func verb(_ action: FileActionName, en: Bool) -> String {
        switch action {
        case .copy: en ? "copy" : "copiar"
        case .move: en ? "move" : "mover"
        case .rename: en ? "rename" : "renomear"
        case .newFolder: en ? "create" : "criar"
        case .delete: en ? "delete" : "excluir"
        case .restore: en ? "restore" : "restaurar"
        }
    }
}
