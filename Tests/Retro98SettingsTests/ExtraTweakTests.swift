import Foundation
import Testing
@testable import Retro98Settings

private let extra = TweakCatalog.extra(alertSoundPath: "/Users/ana/Library/Sounds/Retro98.aiff")

@Test func hiddenMenuBarPinsBothKeys() {
    let tweak = extra.first { $0.id == .hiddenMenuBar }
    #expect(tweak?.changes == [
        PreferenceChange(key: PreferenceKey(domain: .global, name: "_HIHideMenuBar"), target: .bool(true)),
        PreferenceChange(key: PreferenceKey(domain: .global, name: "AppleMenuBarVisibleInFullscreen"), target: .bool(false)),
    ])
    #expect(tweak?.effects == [.notifyMenuBarChange])
    #expect(tweak?.group == .extra)
    #expect(tweak?.title == LocalizedText(en: "macOS menu bar hidden", ptBR: "Barra de menus do macOS escondida"))
}

@Test func alertSoundPointsAtRetro98File() {
    let tweak = extra.first { $0.id == .alertSound }
    #expect(tweak?.changes == [
        PreferenceChange(key: PreferenceKey(domain: .global, name: "com.apple.sound.beep.sound"),
                         target: .string("/Users/ana/Library/Sounds/Retro98.aiff")),
    ])
    #expect(tweak?.group == .extra)
    #expect(tweak?.special == nil)
    #expect(tweak?.title == LocalizedText(en: "Retro98 alert sound for macOS", ptBR: "Som de alerta do Retro98 no macOS"))
}

@Test func extraTweaksAreNeverAppliedByDefault() {
    let all = TweakCatalog.all(osMajorVersion: 27, homeDirectory: URL(filePath: "/Users/ana"))
    #expect(all.suffix(2).map(\.id) == [.hiddenMenuBar, .alertSound])
    #expect(all.first { $0.id == .alertSound }?.changes.first?.target == .string("/Users/ana/Library/Sounds/Retro98.aiff"))
    let selected = TweakSelection.defaultApply(catalog: all, choices: .standard)
    #expect(!selected.contains(.hiddenMenuBar))
    #expect(!selected.contains(.alertSound))
}

@Test func soundsDirectoryFollowsOverride() {
    let home = URL(filePath: "/Users/ana")
    #expect(Retro98Paths.standard(home: home, environment: [:]).alertSoundFile.path == "/Users/ana/Library/Sounds/Retro98.aiff")
    #expect(Retro98Paths.standard(home: home, environment: ["RETRO98_SOUNDS_DIR": "/tmp/s"]).alertSoundFile.path == "/tmp/s/Retro98.aiff")
}
