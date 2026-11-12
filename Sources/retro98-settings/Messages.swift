import Retro98Settings

/// User-facing CLI text in Brazilian Portuguese or English, following the system language.
struct Messages {
    let languages: [String]

    private func text(en: String, ptBR: String) -> String {
        LocalizedText(en: en, ptBR: ptBR).resolve(for: languages)
    }

    var usage: String {
        let ids = TweakID.allCases.map(\.rawValue).joined(separator: ", ")
        return text(
            en: "Usage: retro98-settings <status | apply | restore> [--only id1,id2]\nTweaks: \(ids)",
            ptBR: "Uso: retro98-settings <status | apply | restore> [--only id1,id2]\nAjustes: \(ids)"
        )
    }

    func unknownTweak(_ name: String) -> String {
        text(en: "Unknown tweak: \(name)", ptBR: "Ajuste desconhecido: \(name)")
    }

    var ok: String { "OK" }
    var failed: String { text(en: "FAILED", ptBR: "FALHOU") }
    var nothingToRestore: String { text(en: "Nothing to restore.", ptBR: "Nada para restaurar.") }

    /// Writes to com.apple.universalaccess need Full Disk Access for the terminal app running the tool.
    var accessibilityDenied: String {
        text(
            en: "macOS did not allow this change. I opened System Settings › Privacy & Security › Full Disk Access: "
                + "turn on your terminal app there and run the same command again. "
                + "After turning it on, quit and reopen the terminal app.",
            ptBR: "O macOS não deixou mudar este ajuste. Abri Ajustes do Sistema › Privacidade e Segurança › "
                + "Acesso Total ao Disco: ative lá o seu app de terminal e rode o mesmo comando de novo. "
                + "Depois de ativar, feche e abra de novo o app de terminal."
        )
    }

    var appearanceNeedsLogout: String {
        text(
            en: "Log out and back in for light mode to show everywhere.",
            ptBR: "Para o modo claro aparecer em tudo, saia e entre de novo na sua conta."
        )
    }

    /// The saved wallpaper was Retro98's own color (left by an earlier uninstall), so macOS's picture came back instead.
    var wallpaperResetToSystemDefault: String {
        text(
            en: "Your wallpaper from before Retro98 wasn't in the backup, so the macOS default is back. "
                + "To use another one, pick it in System Settings › Wallpaper.",
            ptBR: "O papel de parede de antes do Retro98 não estava no backup, então voltou o padrão do macOS. "
                + "Para usar outro, escolha em Ajustes do Sistema › Papel de Parede."
        )
    }

    func unreadableBackup(_ path: String) -> String {
        text(
            en: "The backup at \(path) is unreadable. Nothing was changed. Don't delete that file; please open a GitHub issue.",
            ptBR: "O backup em \(path) está ilegível. Nada foi alterado. Não apague esse arquivo; abra uma issue no GitHub."
        )
    }

    func unexpected(_ error: Error) -> String {
        text(en: "Error: \(error)", ptBR: "Erro: \(error)")
    }
}
