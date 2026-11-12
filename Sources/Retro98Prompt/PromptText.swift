import Retro98Settings

/// The Prompt's words in Brazilian Portuguese or English, following the system language.
enum PromptText {
    private static func text(_ l: [String], _ ptBR: String, _ en: String) -> String {
        LocalizedText(en: en, ptBR: ptBR).resolve(for: l)
    }

    static let appName = "Retro98 Prompt"

    /// "Prompt", or "Prompt - vim" while a program has set a title.
    static func windowTitle(_ program: String?, _ l: [String]) -> String {
        let name = program?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "Prompt" : "Prompt - \(name)"
    }

    static func processEnded(code: Int32?, _ l: [String]) -> String {
        guard let code else { return text(l, "[Processo concluído]", "[Process completed]") }
        return text(l, "[Processo concluído com código \(code)]", "[Process completed with code \(code)]")
    }

    static func confirmCloseMessage(_ l: [String]) -> String {
        text(l, "Fechar esta janela vai encerrar o programa em execução.", "Closing this window will end the running program.")
    }

    static func confirmQuitMessage(_ l: [String]) -> String {
        text(l, "Há programas em execução no Prompt. Encerrar todos?", "Programs are running in Prompt. End them all?")
    }

    static func end(_ l: [String]) -> String { text(l, "Encerrar", "End") }
    static func cancel(_ l: [String]) -> String { text(l, "Cancelar", "Cancel") }
}
