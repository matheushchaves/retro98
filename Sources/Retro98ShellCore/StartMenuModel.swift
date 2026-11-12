import Foundation
import Retro98Settings

public enum StartMenuEntry: Equatable, Sendable {
    case programs, documents, settings, find, help, run, shutDown, separator
}

public enum StartMenuModel {
    public static let topLevel: [StartMenuEntry] = [.programs, .documents, .settings, .find, .help, .run, .separator, .shutDown]
    public static let helpURL = URL(string: "https://github.com/matheushchaves/retro98#readme")!
    public static let systemSettingsURL = URL(filePath: "/System/Applications/System Settings.app")
    public static let recentDocumentsLimit = 15

    public static func title(_ entry: StartMenuEntry, languages: [String]) -> String {
        let text: LocalizedText
        switch entry {
        case .programs: text = LocalizedText(en: "Programs", ptBR: "Programas")
        case .documents: text = LocalizedText(en: "Documents", ptBR: "Documentos")
        case .settings: text = LocalizedText(en: "Settings", ptBR: "Configurações")
        case .find: text = LocalizedText(en: "Find…", ptBR: "Localizar…")
        case .help: text = LocalizedText(en: "Help", ptBR: "Ajuda")
        case .run: text = LocalizedText(en: "Run…", ptBR: "Executar…")
        case .shutDown: text = LocalizedText(en: "Shut Down…", ptBR: "Desligar…")
        case .separator: return ""
        }
        return text.resolve(for: languages)
    }

    public static func systemSettingsTitle(languages: [String]) -> String {
        LocalizedText(en: "System Settings", ptBR: "Ajustes do Sistema").resolve(for: languages)
    }

    public static func emptyTitle(languages: [String]) -> String {
        LocalizedText(en: "(Empty)", ptBR: "(Vazio)").resolve(for: languages)
    }
}
