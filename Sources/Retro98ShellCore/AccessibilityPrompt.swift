import Foundation
import Retro98Settings

public enum AccessibilityPrompt {
    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
    public static let lastPromptedKey = "lastAccessibilityPromptBuild"
    /// Options for AXIsProcessTrustedWithOptions that make macOS ask too, which also puts the Shell in the
    /// Accessibility list. The key is kAXTrustedCheckOptionPrompt's value, a C global Swift 6 won't read.
    public static let requestOptions = ["AXTrustedCheckOptionPrompt": true]

    /// Ask only when the permission is missing and this installed build hasn't asked yet.
    public static func shouldShow(isTrusted: Bool, lastPromptedBuild: String?, currentBuild: String) -> Bool {
        !isTrusted && lastPromptedBuild != currentBuild
    }

    public static func message(languages: [String]) -> String {
        LocalizedText(
            en: "To show your open windows on the taskbar and keep maximized windows above it, Retro98 Shell needs "
                + "Accessibility permission. I'll open System Settings › Privacy & Security › Accessibility: "
                + "turn on Retro98 Shell there. If it's already on, remove it with − and add it again with + "
                + "(it's in ~/Applications/Retro98). The taskbar keeps working meanwhile.",
            ptBR: "Para mostrar as janelas abertas na barra de tarefas e manter as janelas maximizadas acima dela, "
                + "o Retro98 Shell precisa da permissão de Acessibilidade. Vou abrir Ajustes do Sistema › Privacidade e "
                + "Segurança › Acessibilidade: ative o Retro98 Shell lá. Se ele já aparece ativado, remova-o com − e "
                + "adicione de novo com + (fica em ~/Applications/Retro98). A barra continua funcionando enquanto isso."
        ).resolve(for: languages)
    }
}

public enum TrustTransition: Equatable, Sendable {
    case none, granted, revoked
}

public func trustTransition(was: Bool, now: Bool) -> TrustTransition {
    switch (was, now) {
    case (false, true): .granted
    case (true, false): .revoked
    default: .none
    }
}
