import Retro98Settings
import Retro98UI

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

// MARK: Dialogs and problems

extension ControlPanelText {
    static func ok(_ l: [String]) -> String { "OK" }
    static func cancel(_ l: [String]) -> String { text(l, "Cancelar", "Cancel") }
    static func apply(_ l: [String]) -> String { text(l, "Aplicar", "Apply") }
    static func openSettings(_ l: [String]) -> String { text(l, "Abrir Ajustes", "Open Settings") }

    static func appearanceNote(_ l: [String]) -> String {
        text(l, "O papel de parede fica em Vídeo e o ponteiro em Mouse.", "The wallpaper is in Display and the pointer in Mouse.")
    }
    static func macOSAppearance(_ l: [String]) -> String { text(l, "Aparência do macOS…", "macOS Appearance…") }
    static func macOSMouse(_ l: [String]) -> String { text(l, "Mouse do macOS…", "macOS Mouse…") }
    static func macOSTrackpad(_ l: [String]) -> String { text(l, "Trackpad do macOS…", "macOS Trackpad…") }
    static func macOSDisplays(_ l: [String]) -> String { text(l, "Monitores do macOS…", "macOS Displays…") }
    static func macOSWallpaper(_ l: [String]) -> String { text(l, "Papel de parede do macOS", "macOS wallpaper") }
    static func solidColor(_ l: [String]) -> String { text(l, "Cor sólida", "Solid color") }
    static func picture(_ l: [String]) -> String { text(l, "Imagem", "Picture") }
    static func browse(_ l: [String]) -> String { text(l, "Procurar…", "Browse…") }
    static func noPicture(_ l: [String]) -> String { text(l, "(nenhuma imagem)", "(no picture)") }

    /// The message for what went wrong: nil when nothing did. Offers Full Disk Access when macOS refused an
    /// accessibility preference (the Control Panel needs it to write them).
    @MainActor static func problems(_ problems: [Problem], model: ControlPanelModel, languages l: [String])
        -> (message: String, icon: MessageBoxIcon, offersFullDiskAccess: Bool)? {
        guard !problems.isEmpty else { return nil }
        var parts: [String] = []
        let failures = problems.compactMap { problem -> TweakFailure? in
            if case .failed(let failure) = problem { return failure }
            return nil
        }
        if !failures.isEmpty {
            let titles = failures.map { model.title(of: $0.id) }.joined(separator: ", ")
            parts.append(text(l, "Não foi possível mudar: \(titles).", "Couldn't change: \(titles)."))
        }
        let deniedAccessibility = failures.contains { failure in
            guard case .writeDenied(let keys) = failure.reason else { return false }
            return keys.contains { $0.domain == .app("com.apple.universalaccess") }
        }
        if deniedAccessibility {
            parts.append(text(l,
                "O macOS não deixou mudar os ajustes de acessibilidade. Dê Acesso Total ao Disco ao Retro98 Control Panel em "
                    + "Ajustes do Sistema › Privacidade e Segurança › Acesso Total ao Disco (use o botão + e escolha Retro98 Control Panel "
                    + "em ~/Applications/Retro98) e tente de novo.",
                "macOS didn't allow changing the accessibility settings. Give Retro98 Control Panel Full Disk Access in "
                    + "System Settings › Privacy & Security › Full Disk Access (use the + button and pick Retro98 Control Panel in "
                    + "~/Applications/Retro98) and try again."))
        }
        for problem in problems {
            switch problem {
            case .failed: continue
            case .backupUnreadable(let path):
                parts.append(text(l, "O backup dos ajustes está ilegível (\(path)). Nada foi mudado.",
                                  "The settings backup can't be read (\(path)). Nothing was changed."))
            case .notAnImage(let name):
                parts.append(text(l, "\"\(name)\" não é uma imagem que o macOS consiga abrir.", "\"\(name)\" isn't an image macOS can open."))
            case .shellNotInstalled:
                parts.append(text(l, "A barra de tarefas não está instalada. Rode ./install.sh para instalar.",
                                  "The taskbar isn't installed. Run ./install.sh to install it."))
            case .shellFailed(let detail):
                parts.append(text(l, "Não foi possível ligar a barra de tarefas (\(detail)).", "Couldn't turn on the taskbar (\(detail))."))
            case .fileFailed(let detail):
                parts.append(text(l, "Não foi possível gravar um arquivo do Retro98 (\(detail)).", "Couldn't write a Retro98 file (\(detail))."))
            case .warning(.appearanceNeedsLogout):
                parts.append(text(l, "Para o modo claro aparecer em tudo, saia e entre de novo na sua conta.",
                                  "Log out and back in for light mode to show everywhere."))
            case .warning(.wallpaperResetToSystemDefault):
                parts.append(text(l,
                    "O papel de parede de antes do Retro98 não estava no backup, então voltou o padrão do macOS. "
                        + "Para usar outro, escolha em Ajustes do Sistema › Papel de Parede.",
                    "Your wallpaper from before Retro98 wasn't in the backup, so the macOS default is back. "
                        + "To use another one, pick it in System Settings › Wallpaper."))
            }
        }
        let icon: MessageBoxIcon = problems.contains(where: ControlPanelModel.isFailure) ? .error : .info
        return (parts.joined(separator: " "), icon, deniedAccessibility)
    }
}

// MARK: Sounds, Components and back to normal

extension ControlPanelText {
    static func playSounds(_ l: [String]) -> String { text(l, "Tocar os sons do Retro98", "Play Retro98 sounds") }
    static func play(_ l: [String]) -> String { text(l, "Tocar", "Play") }
    static func macOSSound(_ l: [String]) -> String { text(l, "Som do macOS…", "macOS Sound…") }

    static func soundName(_ kind: RetroSoundKind, _ l: [String]) -> String {
        switch kind {
        case .startup: text(l, "Início do Retro98", "Retro98 startup")
        case .error: text(l, "Erro", "Error")
        case .warning: text(l, "Aviso", "Warning")
        case .emptyTrash: text(l, "Esvaziar a Lixeira", "Empty Recycle Bin")
        case .alert: text(l, "Alerta", "Alert")
        }
    }

    static func screensaverKindLabel(_ l: [String]) -> String { text(l, "Proteção:", "Screen saver:") }
    static func screensaverTimeoutLabel(_ l: [String]) -> String { text(l, "Aguardar:", "Wait:") }

    static func screensaverKindName(_ kind: Retro98Settings.ScreensaverKind, _ l: [String]) -> String {
        switch kind {
        case .none: text(l, "(nenhuma)", "(None)")
        case .pipes: text(l, "Tubulações 3D", "3D Pipes")
        case .text3d: text(l, "Texto 3D", "3D Text")
        case .johnny: "Johnny Castaway"
        }
    }

    static func screensaverTimeoutName(_ minutes: Int, _ l: [String]) -> String {
        text(l, "\(minutes) min", "\(minutes) min")
    }

    static func taskbar(_ l: [String]) -> String { text(l, "Barra de tarefas e menu Iniciar", "Taskbar and Start menu") }
    static func notInstalled(_ l: [String]) -> String {
        text(l, "Não instalado: rode ./install.sh para instalar.", "Not installed: run ./install.sh to install it.")
    }

    static func backToNormalQuestion(_ l: [String]) -> String {
        text(l,
             "Isto desliga a barra de tarefas, devolve o Dock e restaura todos os ajustes que o Retro98 mudou. "
                + "Os apps do Retro98 continuam instalados.",
             "This turns off the taskbar, gives back the Dock and restores every setting Retro98 changed. "
                + "Retro98's apps stay installed.")
    }
    static func backToNormalConfirm(_ l: [String]) -> String { text(l, "Voltar ao normal", "Back to normal") }
    static func backToNormalDone(_ l: [String]) -> String {
        text(l, "Pronto: o macOS voltou ao normal. Para remover os apps do Retro98, rode ./uninstall.sh.",
             "Done: macOS is back to normal. To remove Retro98's apps, run ./uninstall.sh.")
    }
}
