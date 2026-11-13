import Retro98Settings

/// The Control Panel's words in Brazilian Portuguese or English, following the system language.
enum ControlPanelText {
    static func text(_ l: [String], _ ptBR: String, _ en: String) -> String {
        LocalizedText(en: en, ptBR: ptBR).resolve(for: l)
    }

    static let appName = "Retro98 Control Panel"

    static func windowTitle(_ l: [String]) -> String { text(l, "Painel de Controle", "Control Panel") }
    static func objects(_ count: Int, _ l: [String]) -> String { text(l, "\(count) objeto(s)", "\(count) object(s)") }
    static func backToNormal(_ l: [String]) -> String { text(l, "Voltar ao macOS normal…", "Back to macOS normal…") }

    // MARK: Menus

    static func menuFile(_ l: [String]) -> String { text(l, "Arquivo", "File") }
    static func menuWindow(_ l: [String]) -> String { text(l, "Janela", "Window") }
    static func menuHelp(_ l: [String]) -> String { text(l, "Ajuda", "Help") }
    static func open(_ l: [String]) -> String { text(l, "Abrir", "Open") }
    static func close(_ l: [String]) -> String { text(l, "Fechar", "Close") }
    static func readme(_ l: [String]) -> String { text(l, "Ajuda do Retro98 (README)", "Retro98 Help (README)") }
    static func about(_ l: [String]) -> String { text(l, "Sobre o Retro98 Control Panel", "About Retro98 Control Panel") }
    static func settings(_ l: [String]) -> String { text(l, "Ajustes…", "Settings…") }
    static func hide(_ l: [String]) -> String { text(l, "Ocultar Retro98 Control Panel", "Hide Retro98 Control Panel") }
    static func hideOthers(_ l: [String]) -> String { text(l, "Ocultar Outros", "Hide Others") }
    static func showAll(_ l: [String]) -> String { text(l, "Mostrar Tudo", "Show All") }
    static func quit(_ l: [String]) -> String { text(l, "Encerrar Retro98 Control Panel", "Quit Retro98 Control Panel") }
    static func minimize(_ l: [String]) -> String { text(l, "Minimizar", "Minimize") }
    static func zoom(_ l: [String]) -> String { "Zoom" }
    static func bringAllToFront(_ l: [String]) -> String { text(l, "Trazer Tudo para a Frente", "Bring All to Front") }
}
