public enum TweakID: String, Codable, CaseIterable, Sendable {
    case wallpaper, lightAppearance, colors, contrast, pointer, scrollBars, windowAnimations, titleBarDoubleClick, finderExplorer
    case dockUnderTaskbar
    case explorerFileViewer
}

/// Which installable piece a tweak belongs to: the base tweaks, the Shell (taskbar), or the optional
/// Explorer-as-file-viewer.
public enum TweakGroup: String, Codable, Sendable {
    case base, shell, fileViewer
}

/// Side effects needed after preferences change so running apps pick them up.
public enum RefreshEffect: Hashable, Sendable {
    case restartFinder, notifyColorChange, notifyScrollBarChange, syncAppearance, restartDock
}

/// Work that is not a plain preference write.
public enum SpecialAction: Equatable, Sendable {
    case solidWallpaper(hex: String)
}

public struct LocalizedText: Equatable, Sendable {
    public let en: String
    public let ptBR: String

    public init(en: String, ptBR: String) {
        self.en = en
        self.ptBR = ptBR
    }

    /// Portuguese when the first preferred language is Portuguese, English otherwise.
    public func resolve(for languages: [String]) -> String {
        languages.first?.hasPrefix("pt") == true ? ptBR : en
    }
}

public struct Tweak: Equatable, Sendable {
    public let id: TweakID
    public let title: LocalizedText
    public let changes: [PreferenceChange]
    public let special: SpecialAction?
    public let effects: Set<RefreshEffect>
    public let group: TweakGroup

    public init(
        id: TweakID, title: LocalizedText, changes: [PreferenceChange],
        special: SpecialAction? = nil, effects: Set<RefreshEffect> = [], group: TweakGroup = .base
    ) {
        self.id = id
        self.title = title
        self.changes = changes
        self.special = special
        self.effects = effects
        self.group = group
    }
}
