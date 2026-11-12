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

    // MARK: Menus (the Explorer's wording)

    static func menuFile(_ l: [String]) -> String { text(l, "Arquivo", "File") }
    static func menuEdit(_ l: [String]) -> String { text(l, "Editar", "Edit") }
    static func menuWindow(_ l: [String]) -> String { text(l, "Janela", "Window") }
    static func menuHelp(_ l: [String]) -> String { text(l, "Ajuda", "Help") }
    static func newWindow(_ l: [String]) -> String { text(l, "Nova janela", "New Window") }
    static func close(_ l: [String]) -> String { text(l, "Fechar", "Close") }
    static func copy(_ l: [String]) -> String { text(l, "Copiar", "Copy") }
    static func paste(_ l: [String]) -> String { text(l, "Colar", "Paste") }
    static func selectAll(_ l: [String]) -> String { text(l, "Selecionar tudo", "Select All") }
    static func readme(_ l: [String]) -> String { text(l, "Ajuda do Retro98 (README)", "Retro98 Help (README)") }
    static func about(_ l: [String]) -> String { text(l, "Sobre o Retro98 Prompt", "About Retro98 Prompt") }
    static func hide(_ l: [String]) -> String { text(l, "Ocultar Retro98 Prompt", "Hide Retro98 Prompt") }
    static func hideOthers(_ l: [String]) -> String { text(l, "Ocultar Outros", "Hide Others") }
    static func showAll(_ l: [String]) -> String { text(l, "Mostrar Tudo", "Show All") }
    static func quit(_ l: [String]) -> String { text(l, "Encerrar Retro98 Prompt", "Quit Retro98 Prompt") }
    static func minimize(_ l: [String]) -> String { text(l, "Minimizar", "Minimize") }
    static func zoom(_ l: [String]) -> String { "Zoom" }
    static func bringAllToFront(_ l: [String]) -> String { text(l, "Trazer Tudo para a Frente", "Bring All to Front") }
}
