import Foundation

/// The native, reversible macOS settings that make up Phase 1 (spec section 6, "Fase 1").
public enum TweakCatalog {
    static let teal = "#008080"
    static let navyHighlight = "0.000000 0.000000 0.501961 Other"
    static let graphiteAccent = -1
    static let graphiteAquaVariant = 6
    static let fillDoubleClickMinimumMacOS = 15
    static let smallestDockTileSize = 16
    static let dockRevealDelaySeconds = 1000.0

    public static func phase1(osMajorVersion: Int, homeDirectory: URL) -> [Tweak] {
        let universalAccess = PreferenceDomain.app("com.apple.universalaccess")
        let finder = PreferenceDomain.app("com.apple.finder")
        let homePath = homeDirectory.absoluteString.hasSuffix("/")
            ? homeDirectory.absoluteString
            : homeDirectory.absoluteString + "/"

        return [
            Tweak(
                id: .wallpaper,
                title: LocalizedText(en: "Solid teal desktop", ptBR: "Fundo verde-água sólido"),
                changes: [],
                special: .solidWallpaper(hex: teal)
            ),
            Tweak(
                id: .lightAppearance,
                title: LocalizedText(en: "Light mode", ptBR: "Modo claro"),
                changes: [
                    change(.global, "AppleInterfaceStyle", nil),
                    change(.global, "AppleInterfaceStyleSwitchesAutomatically", .bool(false)),
                ],
                effects: [.syncAppearance]
            ),
            Tweak(
                id: .colors,
                title: LocalizedText(en: "Graphite accent and navy selection", ptBR: "Destaque grafite e seleção azul-marinho"),
                changes: [
                    change(.global, "AppleAccentColor", .int(graphiteAccent)),
                    change(.global, "AppleAquaColorVariant", .int(graphiteAquaVariant)),
                    change(.global, "AppleHighlightColor", .string(navyHighlight)),
                ],
                effects: [.notifyColorChange]
            ),
            Tweak(
                id: .contrast,
                title: LocalizedText(
                    en: "Reduced transparency and increased contrast", ptBR: "Menos transparência e mais contraste"
                ),
                changes: [
                    change(universalAccess, "reduceTransparency", .bool(true)),
                    change(universalAccess, "increaseContrast", .bool(true)),
                ]
            ),
            Tweak(
                id: .pointer,
                title: LocalizedText(en: "White pointer with black outline", ptBR: "Ponteiro branco com contorno preto"),
                changes: [
                    change(universalAccess, "cursorIsCustomized", .bool(true)),
                    change(universalAccess, "cursorFill", rgba(red: 1, green: 1, blue: 1)),
                    change(universalAccess, "cursorOutline", rgba(red: 0, green: 0, blue: 0)),
                ]
            ),
            Tweak(
                id: .scrollBars,
                title: LocalizedText(en: "Always-visible scroll bars", ptBR: "Barras de rolagem sempre visíveis"),
                changes: [change(.global, "AppleShowScrollBars", .string("Always"))],
                effects: [.notifyScrollBarChange]
            ),
            Tweak(
                id: .windowAnimations,
                title: LocalizedText(en: "No window animations", ptBR: "Sem animações de janela"),
                changes: [change(.global, "NSAutomaticWindowAnimationsEnabled", .bool(false))]
            ),
            Tweak(
                id: .titleBarDoubleClick,
                title: LocalizedText(
                    en: "Double-click title bar to maximize", ptBR: "Duplo clique na barra de título maximiza"
                ),
                changes: [
                    change(
                        .global, "AppleActionOnDoubleClick",
                        .string(osMajorVersion >= fillDoubleClickMinimumMacOS ? "Fill" : "Maximize")
                    ),
                ]
            ),
            Tweak(
                id: .finderExplorer,
                title: LocalizedText(en: "Explorer-like Finder", ptBR: "Finder no jeito do Explorer"),
                changes: [
                    change(.global, "AppleShowAllExtensions", .bool(true)),
                    change(finder, "ShowStatusBar", .bool(true)),
                    change(finder, "ShowPathbar", .bool(true)),
                    change(finder, "_FXSortFoldersFirst", .bool(true)),
                    change(finder, "FXPreferredViewStyle", .string("Nlsv")),
                    change(finder, "NewWindowTarget", .string("PfHm")),
                    change(finder, "NewWindowTargetPath", .string(homePath)),
                ],
                effects: [.restartFinder]
            ),
        ]
    }

    /// Tweaks that only make sense while the Retro98 Shell taskbar runs. The Dock is hidden for good
    /// (autohide with a huge delay) so it never shows labels over the taskbar or pops up at the edge.
    public static func shell() -> [Tweak] {
        let dock = PreferenceDomain.app("com.apple.dock")
        return [
            Tweak(
                id: .dockUnderTaskbar,
                title: LocalizedText(en: "Dock hidden under the taskbar", ptBR: "Dock escondido sob a barra de tarefas"),
                changes: [
                    change(dock, "tilesize", .int(smallestDockTileSize)),
                    change(dock, "magnification", .bool(false)),
                    change(dock, "autohide", .bool(true)),
                    change(dock, "autohide-delay", .double(dockRevealDelaySeconds)),
                    change(dock, "autohide-time-modifier", .double(0)),
                    change(dock, "orientation", .string("bottom")),
                ],
                effects: [.restartDock],
                group: .shell
            ),
        ]
    }

    /// Optional: other apps' "Show in Finder" opens Retro98 Explorer (the global NSFileViewer preference).
    public static func fileViewer() -> [Tweak] {
        [
            Tweak(
                id: .explorerFileViewer,
                title: LocalizedText(en: "Explorer instead of Finder for \"Show in Finder\"",
                                     ptBR: "Explorer no lugar do Finder em \"Mostrar no Finder\""),
                changes: [change(.global, "NSFileViewer", .string(explorerBundleID))],
                group: .fileViewer
            ),
        ]
    }

    static let explorerBundleID = "io.github.matheushchaves.retro98.explorer"

    public static func all(osMajorVersion: Int, homeDirectory: URL) -> [Tweak] {
        phase1(osMajorVersion: osMajorVersion, homeDirectory: homeDirectory) + shell() + fileViewer()
    }

    private static func change(_ domain: PreferenceDomain, _ name: String, _ target: PreferenceValue?) -> PreferenceChange {
        PreferenceChange(key: PreferenceKey(domain: domain, name: name), target: target)
    }

    private static func rgba(red: Double, green: Double, blue: Double) -> PreferenceValue {
        .dictionary(["alpha": .double(1), "red": .double(red), "green": .double(green), "blue": .double(blue)])
    }
}
