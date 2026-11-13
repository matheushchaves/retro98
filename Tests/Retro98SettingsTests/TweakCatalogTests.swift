import Foundation
import Testing
@testable import Retro98Settings

private let catalog = TweakCatalog.phase1(osMajorVersion: 27, homeDirectory: URL(filePath: "/Users/test"))
private let universalAccess = PreferenceDomain.app("com.apple.universalaccess")
private let finder = PreferenceDomain.app("com.apple.finder")

private func target(_ id: TweakID, _ domain: PreferenceDomain, _ name: String) -> PreferenceChange? {
    catalog.first { $0.id == id }?.changes.first { $0.key == PreferenceKey(domain: domain, name: name) }
}

@Test func listsEveryTweakOnceInOrder() {
    let notPhase1: Set<TweakID> = [.dockUnderTaskbar, .explorerFileViewer, .hiddenMenuBar, .alertSound]
    #expect(catalog.map(\.id) == TweakID.allCases.filter { !notPhase1.contains($0) })
    #expect(catalog.allSatisfy { $0.group == .base })
}

@Test func shellCatalogPinsDockValues() {
    let dock = TweakCatalog.shell().first { $0.id == .dockUnderTaskbar }
    let dockDomain = PreferenceDomain.app("com.apple.dock")
    #expect(dock?.group == .shell)
    #expect(dock?.effects == [.restartDock])
    #expect(dock?.changes == [
        PreferenceChange(key: PreferenceKey(domain: dockDomain, name: "tilesize"), target: .int(16)),
        PreferenceChange(key: PreferenceKey(domain: dockDomain, name: "magnification"), target: .bool(false)),
        PreferenceChange(key: PreferenceKey(domain: dockDomain, name: "autohide"), target: .bool(true)),
        PreferenceChange(key: PreferenceKey(domain: dockDomain, name: "autohide-delay"), target: .double(1000)),
        PreferenceChange(key: PreferenceKey(domain: dockDomain, name: "autohide-time-modifier"), target: .double(0)),
        PreferenceChange(key: PreferenceKey(domain: dockDomain, name: "orientation"), target: .string("bottom")),
    ])
    #expect(dock?.title == LocalizedText(en: "Dock hidden under the taskbar", ptBR: "Dock escondido sob a barra de tarefas"))
}

@Test func allCatalogIsPhase1PlusShell() {
    let all = TweakCatalog.all(osMajorVersion: 27, homeDirectory: URL(filePath: "/Users/test"))
    #expect(all.map(\.id) == TweakID.allCases)
    #expect(all.filter { $0.group == .base }.count == 9)
}

@Test func pinsColorsAndAppearance() {
    #expect(target(.colors, .global, "AppleHighlightColor")?.target == .string("0.000000 0.000000 0.501961 Other"))
    #expect(target(.colors, .global, "AppleAccentColor")?.target == .int(-1))
    #expect(target(.colors, .global, "AppleAquaColorVariant")?.target == .int(6))
    #expect(target(.lightAppearance, .global, "AppleInterfaceStyle") != nil)
    #expect(target(.lightAppearance, .global, "AppleInterfaceStyle")?.target == nil)
    #expect(target(.lightAppearance, .global, "AppleInterfaceStyleSwitchesAutomatically")?.target == .bool(false))
    #expect(catalog.first { $0.id == .lightAppearance }?.effects == [.syncAppearance])
    #expect(catalog.first { $0.id == .colors }?.effects == [.notifyColorChange])
}

@Test func pinsAccessibilityAndWindowBehaviour() {
    #expect(target(.contrast, universalAccess, "reduceTransparency")?.target == .bool(true))
    #expect(target(.contrast, universalAccess, "increaseContrast")?.target == .bool(true))
    #expect(target(.scrollBars, .global, "AppleShowScrollBars")?.target == .string("Always"))
    #expect(catalog.first { $0.id == .scrollBars }?.effects == [.notifyScrollBarChange])
    #expect(target(.windowAnimations, .global, "NSAutomaticWindowAnimationsEnabled")?.target == .bool(false))
}

@Test func pinsWallpaperPointerAndFinder() {
    #expect(catalog.first { $0.id == .wallpaper }?.special == .solidWallpaper(hex: "#008080"))
    #expect(target(.pointer, universalAccess, "cursorIsCustomized")?.target == .bool(true))
    #expect(target(.pointer, universalAccess, "cursorFill")?.target
            == .dictionary(["alpha": .double(1), "red": .double(1), "green": .double(1), "blue": .double(1)]))
    #expect(target(.pointer, universalAccess, "cursorOutline")?.target
            == .dictionary(["alpha": .double(1), "red": .double(0), "green": .double(0), "blue": .double(0)]))
    #expect(target(.finderExplorer, .global, "AppleShowAllExtensions")?.target == .bool(true))
    #expect(target(.finderExplorer, finder, "ShowStatusBar")?.target == .bool(true))
    #expect(target(.finderExplorer, finder, "ShowPathbar")?.target == .bool(true))
    #expect(target(.finderExplorer, finder, "_FXSortFoldersFirst")?.target == .bool(true))
    #expect(target(.finderExplorer, finder, "FXPreferredViewStyle")?.target == .string("Nlsv"))
    #expect(target(.finderExplorer, finder, "NewWindowTarget")?.target == .string("PfHm"))
    #expect(target(.finderExplorer, finder, "NewWindowTargetPath")?.target == .string("file:///Users/test/"))
    #expect(catalog.first { $0.id == .finderExplorer }?.effects == [.restartFinder])
}

@Test func doubleClickValueDependsOnMacOSVersion() {
    let sonoma = TweakCatalog.phase1(osMajorVersion: 14, homeDirectory: URL(filePath: "/Users/test"))
    #expect(sonoma.first { $0.id == .titleBarDoubleClick }?.changes.first?.target == .string("Maximize"))
    #expect(target(.titleBarDoubleClick, .global, "AppleActionOnDoubleClick")?.target == .string("Fill"))
}

@Test func resolvesLanguage() {
    let text = LocalizedText(en: "Light mode", ptBR: "Modo claro")
    #expect(text.resolve(for: ["pt-BR"]) == "Modo claro")
    #expect(text.resolve(for: ["fr-FR", "pt-BR"]) == "Light mode")
    #expect(text.resolve(for: []) == "Light mode")
}
