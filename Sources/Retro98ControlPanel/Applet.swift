import Foundation
import Retro98UI

/// One icon in the Control Panel: a Retro98 applet (opens its dialog) or a shortcut to a macOS settings panel.
enum Applet: CaseIterable {
    case display, appearance, mouse, sounds, components, screensaver, network, printers, keyboard, dateTime, users, systemSettings

    func title(_ l: [String]) -> String {
        switch self {
        case .display: ControlPanelText.text(l, "Vídeo", "Display")
        case .appearance: ControlPanelText.text(l, "Aparência", "Appearance")
        case .mouse: "Mouse"
        case .sounds: ControlPanelText.text(l, "Sons", "Sounds")
        case .components: ControlPanelText.text(l, "Componentes", "Components")
        case .screensaver: ControlPanelText.text(l, "Proteção de Tela", "Screen Saver")
        case .network: ControlPanelText.text(l, "Rede", "Network")
        case .printers: ControlPanelText.text(l, "Impressoras", "Printers")
        case .keyboard: ControlPanelText.text(l, "Teclado", "Keyboard")
        case .dateTime: ControlPanelText.text(l, "Data/Hora", "Date/Time")
        case .users: ControlPanelText.text(l, "Usuários", "Users")
        case .systemSettings: ControlPanelText.text(l, "Ajustes do Sistema", "System Settings")
        }
    }

    /// Shown in the status bar when the icon is selected.
    func description(_ l: [String]) -> String {
        switch self {
        case .display:
            ControlPanelText.text(l, "Muda o papel de parede e a cor da área de trabalho.", "Changes the desktop wallpaper and color.")
        case .appearance:
            ControlPanelText.text(l, "Liga e desliga os ajustes de aparência do Retro98, um a um.",
                                  "Turns Retro98's appearance tweaks on and off, one by one.")
        case .mouse: ControlPanelText.text(l, "Muda o ponteiro do mouse.", "Changes the mouse pointer.")
        case .sounds:
            ControlPanelText.text(l, "Liga e desliga os sons do Retro98 e o som de alerta.",
                                  "Turns Retro98 sounds and the alert sound on and off.")
        case .components:
            ControlPanelText.text(l, "Liga e desliga a barra de tarefas, o Explorer como padrão e a barra de menus escondida.",
                                  "Turns the taskbar, Explorer as default and the hidden menu bar on and off.")
        case .screensaver:
            ControlPanelText.text(l, "Escolhe e configura a proteção de tela do Retro98.",
                                  "Chooses and configures the Retro98 screen saver.")
        case .network: Self.opens(ControlPanelText.text(l, "Rede", "Network"), l)
        case .printers: Self.opens(ControlPanelText.text(l, "Impressoras e Scanners", "Printers & Scanners"), l)
        case .keyboard: Self.opens(ControlPanelText.text(l, "Teclado", "Keyboard"), l)
        case .dateTime: Self.opens(ControlPanelText.text(l, "Data e Hora", "Date & Time"), l)
        case .users: Self.opens(ControlPanelText.text(l, "Usuários e Grupos", "Users & Groups"), l)
        case .systemSettings: ControlPanelText.text(l, "Abre os Ajustes do Sistema do macOS.", "Opens macOS System Settings.")
        }
    }

    private static func opens(_ panel: String, _ l: [String]) -> String {
        ControlPanelText.text(l, "Abre \(panel) nos Ajustes do Sistema do macOS.", "Opens \(panel) in macOS System Settings.")
    }

    var icon: PixelIcon {
        switch self {
        case .display: ControlPanelIcons.icon(.display, size: 32)
        case .appearance: ControlPanelIcons.icon(.appearance, size: 32)
        case .mouse: ControlPanelIcons.icon(.mouse, size: 32)
        case .sounds: ControlPanelIcons.icon(.sounds, size: 32)
        case .components: ControlPanelIcons.icon(.components, size: 32)
        case .screensaver: ControlPanelIcons.icon(.screensaver, size: 32)
        case .network: ControlPanelIcons.icon(.network, size: 32)
        case .printers: ControlPanelIcons.icon(.printers, size: 32)
        case .keyboard: ControlPanelIcons.icon(.keyboard, size: 32)
        case .dateTime: ControlPanelIcons.icon(.dateTime, size: 32)
        case .users: ControlPanelIcons.icon(.users, size: 32)
        case .systemSettings: Self.systemSettingsIcon
        }
    }

    /// The Start menu's 16-pixel System Settings icon, doubled without smoothing to sit among the 32-pixel ones.
    private static let systemSettingsIcon = PixelIcon(width: 32, height: 32) { context in
        PixelIcon.drawUpright(Icons.systemSettings.image(), in: CGRect(x: 0, y: 0, width: 32, height: 32), context: context)
    }

    /// The macOS panel a shortcut opens; nil for Retro98's own applets.
    var settingsURL: URL? {
        switch self {
        case .display, .appearance, .mouse, .sounds, .components, .screensaver: nil
        case .network: MacOSPanel.settings("com.apple.Network-Settings.extension")
        case .printers: MacOSPanel.settings("com.apple.Print-Scan-Settings.extension")
        case .keyboard: MacOSPanel.settings("com.apple.Keyboard-Settings.extension")
        case .dateTime: MacOSPanel.settings("com.apple.Date-Time-Settings.extension")
        case .users: MacOSPanel.settings("com.apple.Users-Groups-Settings.extension")
        case .systemSettings: URL(filePath: "/System/Applications/System Settings.app")
        }
    }
}

/// macOS settings panels the applets' buttons open (ids read from System Settings' extensions on 2026-11-13).
enum MacOSPanel {
    case displays, appearance, mouse, trackpad, sound, fullDiskAccess

    var url: URL {
        switch self {
        case .displays: Self.settings("com.apple.Displays-Settings.extension")
        case .appearance: Self.settings("com.apple.Appearance-Settings.extension")
        case .mouse: Self.settings("com.apple.Mouse-Settings.extension")
        case .trackpad: Self.settings("com.apple.Trackpad-Settings.extension")
        case .sound: Self.settings("com.apple.Sound-Settings.extension")
        case .fullDiskAccess: Self.settings("com.apple.preference.security?Privacy_AllFiles")
        }
    }

    static func settings(_ panel: String) -> URL {
        URL(string: "x-apple.systempreferences:" + panel)!
    }
}
