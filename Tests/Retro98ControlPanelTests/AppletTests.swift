import Foundation
import Testing
@testable import Retro98ControlPanel

@Test func appletsInOrderWithTitlesAndLinks() {
    #expect(Applet.allCases == [.display, .appearance, .mouse, .sounds, .components, .screensaver, .network, .printers,
                                .keyboard, .dateTime, .users, .systemSettings])
    #expect(Applet.allCases.map { $0.title(["pt-BR"]) } == [
        "Vídeo", "Aparência", "Mouse", "Sons", "Componentes", "Proteção de Tela", "Rede", "Impressoras", "Teclado", "Data/Hora",
        "Usuários", "Ajustes do Sistema",
    ])
    #expect(Applet.allCases.map { $0.title(["en"]) } == [
        "Display", "Appearance", "Mouse", "Sounds", "Components", "Screen Saver", "Network", "Printers", "Keyboard", "Date/Time",
        "Users", "System Settings",
    ])
    let prefix = "x-apple.systempreferences:"
    #expect(Applet.network.settingsURL?.absoluteString == prefix + "com.apple.Network-Settings.extension")
    #expect(Applet.printers.settingsURL?.absoluteString == prefix + "com.apple.Print-Scan-Settings.extension")
    #expect(Applet.keyboard.settingsURL?.absoluteString == prefix + "com.apple.Keyboard-Settings.extension")
    #expect(Applet.dateTime.settingsURL?.absoluteString == prefix + "com.apple.Date-Time-Settings.extension")
    #expect(Applet.users.settingsURL?.absoluteString == prefix + "com.apple.Users-Groups-Settings.extension")
    #expect(Applet.systemSettings.settingsURL == URL(filePath: "/System/Applications/System Settings.app"))
    #expect([Applet.display, .appearance, .mouse, .sounds, .components, .screensaver].allSatisfy { $0.settingsURL == nil })
    for applet in Applet.allCases {
        for languages in [["pt-BR"], ["en"]] { #expect(!applet.description(languages).isEmpty, "\(applet) \(languages)") }
    }
    #expect(Applet.keyboard.description(["pt-BR"]) == "Abre Teclado nos Ajustes do Sistema do macOS.")
    #expect(MacOSPanel.fullDiskAccess.url.absoluteString == prefix + "com.apple.preference.security?Privacy_AllFiles")
    #expect(MacOSPanel.displays.url.absoluteString == prefix + "com.apple.Displays-Settings.extension")
}
