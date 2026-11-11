import Retro98Settings

/// The choices of the Shut Down… dialog, carried out by System Events.
public enum PowerAction: String, CaseIterable, Sendable {
    case shutDown, restart, logOut, sleep

    public func title(languages: [String]) -> String {
        let text: LocalizedText
        switch self {
        case .shutDown: text = LocalizedText(en: "Shut down", ptBR: "Desligar")
        case .restart: text = LocalizedText(en: "Restart", ptBR: "Reiniciar")
        case .logOut: text = LocalizedText(en: "Log out", ptBR: "Encerrar sessão")
        case .sleep: text = LocalizedText(en: "Sleep", ptBR: "Repouso")
        }
        return text.resolve(for: languages)
    }

    public var appleScriptCommand: String {
        switch self {
        case .shutDown: "shut down"
        case .restart: "restart"
        case .logOut: "log out"
        case .sleep: "sleep"
        }
    }

    /// Returns false when macOS refused (e.g. Automation permission denied).
    public func perform(runner: CommandRunner) -> Bool {
        runner.run("/usr/bin/osascript", ["-e", "tell application \"System Events\" to \(appleScriptCommand)"]) == 0
    }
}

public enum ShutDownDialogText {
    public static func title(languages: [String]) -> String {
        LocalizedText(en: "Shut Down Computer", ptBR: "Desligar o computador").resolve(for: languages)
    }

    public static func question(languages: [String]) -> String {
        LocalizedText(en: "What do you want the computer to do?", ptBR: "O que você deseja que o computador faça?")
            .resolve(for: languages)
    }

    public static func failure(languages: [String]) -> String {
        LocalizedText(
            en: "macOS did not allow this. In System Settings › Privacy & Security › Automation, "
                + "allow Retro98 Shell to control System Events.",
            ptBR: "O macOS não permitiu esta ação. Em Ajustes do Sistema › Privacidade e Segurança › Automação, "
                + "permita que o Retro98 Shell controle o System Events."
        ).resolve(for: languages)
    }
}
