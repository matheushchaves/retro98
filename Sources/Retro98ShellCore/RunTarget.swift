import Foundation
import Retro98Settings

/// What the Run… dialog should open for a typed line.
public enum RunTarget: Equatable, Sendable {
    case url(URL)
    case path(URL)
    case app(URL)
    case notFound(String)

    static let maxSearchDepth = 5

    /// Resolves, in order: URL, web address, path (with ~), app name. Nil for blank input.
    public static func resolve(_ input: String, appRoots: [URL], home: URL, fileManager: FileManager = .default) -> RunTarget? {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let lowered = text.lowercased()

        if text.contains("://") || lowered.hasPrefix("mailto:"), let url = URL(string: text) {
            return .url(url)
        }
        if lowered.hasPrefix("www."), let url = URL(string: "https://" + text) {
            return .url(url)
        }
        if text.hasPrefix("/") || text.hasPrefix("~") {
            let path = text.hasPrefix("~") ? home.path + text.dropFirst() : text
            return fileManager.fileExists(atPath: path) ? .path(URL(filePath: path)) : .notFound(text)
        }

        let wanted = lowered.hasSuffix(".app") ? String(text.dropLast(4)) : text
        for root in appRoots {
            if let url = findApp(named: wanted, in: root, depth: 0, fileManager: fileManager) { return .app(url) }
        }
        return .notFound(text)
    }

    /// Apps in a folder are checked before its subfolders; app bundles are never entered.
    private static func findApp(named wanted: String, in folder: URL, depth: Int, fileManager: FileManager) -> URL? {
        guard depth < maxSearchDepth, let names = try? fileManager.contentsOfDirectory(atPath: folder.path) else { return nil }
        let visible = names.filter { !$0.hasPrefix(".") }.sorted()
        for name in visible where name.lowercased().hasSuffix(".app") {
            let url = folder.appending(path: name, directoryHint: .notDirectory)
            let candidates = [String(name.dropLast(4)), stripApp(fileManager.displayName(atPath: url.path))]
            if candidates.contains(where: { matches($0, wanted) }) { return url }
        }
        for name in visible where !name.lowercased().hasSuffix(".app") {
            let url = folder.appending(path: name, directoryHint: .notDirectory)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else { continue }
            if let found = findApp(named: wanted, in: url, depth: depth + 1, fileManager: fileManager) { return found }
        }
        return nil
    }

    private static func matches(_ candidate: String, _ wanted: String) -> Bool {
        candidate.compare(wanted, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    private static func stripApp(_ name: String) -> String {
        name.lowercased().hasSuffix(".app") ? String(name.dropLast(4)) : name
    }
}

public enum RunDialogText {
    public static func prompt(languages: [String]) -> String {
        LocalizedText(
            en: "Type the name of a program, folder, document, or Internet address, and Retro98 will open it for you.",
            ptBR: "Digite o nome de um programa, pasta, documento ou endereço da Internet, e o Retro98 o abrirá para você."
        ).resolve(for: languages)
    }

    public static func openLabel(languages: [String]) -> String {
        LocalizedText(en: "Open:", ptBR: "Abrir:").resolve(for: languages)
    }

    public static func notFound(_ input: String, languages: [String]) -> String {
        LocalizedText(
            en: "Cannot find '\(input)'. Make sure you typed the name correctly, and then try again.",
            ptBR: "Não foi possível encontrar '\(input)'. Verifique se o nome está correto e tente de novo."
        ).resolve(for: languages)
    }
}
