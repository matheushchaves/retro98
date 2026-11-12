import Foundation

public enum StartMenuAction: Equatable, Sendable {
    case open(URL)
    case run
    case shutDown
}

/// Built-in icon a node asks for; nodes without one use the icon of `iconURL`.
public enum StartMenuSymbol: Equatable, Sendable {
    case programs, documents, settings, find, help, run, shutDown, folder, systemSettings
}

/// One Start menu entry. A node with neither action nor children is shown disabled.
public struct StartMenuNode: Equatable, Sendable {
    public let title: String
    public let iconURL: URL?
    public let action: StartMenuAction?
    public let children: [StartMenuNode]?
    public let symbol: StartMenuSymbol?

    public init(
        title: String, iconURL: URL?, action: StartMenuAction?, children: [StartMenuNode]?,
        symbol: StartMenuSymbol? = nil
    ) {
        self.title = title
        self.iconURL = iconURL
        self.action = action
        self.children = children
        self.symbol = symbol
    }
}

public enum StartMenuItems {
    /// Top-level Start menu in `StartMenuModel.topLevel` order; nil marks a separator.
    /// "Find…" opens `findURL` (the Explorer's search) and is left out without it.
    public static func build(programs: [ProgramNode], documents: [RecentDocument], languages: [String],
                             findURL: URL? = nil) -> [StartMenuNode?] {
        StartMenuModel.topLevel.compactMap { entry -> StartMenuNode?? in
            let title = StartMenuModel.title(entry, languages: languages)
            switch entry {
            case .find:
                guard let findURL else { return .none }
                return StartMenuNode(title: title, iconURL: nil, action: .open(findURL), children: nil, symbol: .find)
            case .programs:
                return StartMenuNode(title: title, iconURL: nil, action: nil,
                                     children: programs.map(node(for:)), symbol: .programs)
            case .documents:
                let children: [StartMenuNode] = documents.isEmpty
                    ? [StartMenuNode(title: StartMenuModel.emptyTitle(languages: languages), iconURL: nil, action: nil, children: nil)]
                    : documents.map { StartMenuNode(title: $0.name, iconURL: $0.url, action: .open($0.url), children: nil) }
                return StartMenuNode(title: title, iconURL: nil, action: nil, children: children, symbol: .documents)
            case .settings:
                let systemSettings = StartMenuNode(
                    title: StartMenuModel.systemSettingsTitle(languages: languages), iconURL: nil,
                    action: .open(StartMenuModel.systemSettingsURL), children: nil, symbol: .systemSettings
                )
                return StartMenuNode(title: title, iconURL: nil, action: nil, children: [systemSettings], symbol: .settings)
            case .help:
                return StartMenuNode(title: title, iconURL: nil, action: .open(StartMenuModel.helpURL), children: nil, symbol: .help)
            case .run:
                return StartMenuNode(title: title, iconURL: nil, action: .run, children: nil, symbol: .run)
            case .shutDown:
                return StartMenuNode(title: title, iconURL: nil, action: .shutDown, children: nil, symbol: .shutDown)
            case .separator:
                return .some(nil)
            }
        }
    }

    private static func node(for program: ProgramNode) -> StartMenuNode {
        switch program {
        case .folder(let name, let children):
            StartMenuNode(title: name, iconURL: nil, action: nil, children: children.map(node(for:)), symbol: .folder)
        case .app(let name, let url):
            StartMenuNode(title: name, iconURL: url, action: .open(url), children: nil)
        }
    }
}
