public enum TweakID: String, Codable, CaseIterable, Sendable {
    case wallpaper, lightAppearance, colors, contrast, pointer, scrollBars, windowAnimations, titleBarDoubleClick, finderExplorer
}

/// Side effects needed after preferences change so running apps pick them up.
public enum RefreshEffect: Hashable, Sendable {
    case restartFinder, notifyColorChange, notifyScrollBarChange, syncAppearance, restartWallpaperAgent
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

    public init(
        id: TweakID, title: LocalizedText, changes: [PreferenceChange],
        special: SpecialAction? = nil, effects: Set<RefreshEffect> = []
    ) {
        self.id = id
        self.title = title
        self.changes = changes
        self.special = special
        self.effects = effects
    }
}
