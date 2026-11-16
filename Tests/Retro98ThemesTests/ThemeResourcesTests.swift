import Foundation
import Retro98UI
import Testing
@testable import Retro98Themes

private let themes = repoRoot.appending(path: "Resources/Themes")

private func json(_ path: String) throws -> [String: Any] {
    let data = try Data(contentsOf: themes.appending(path: path))
    return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

/// Every "#RRGGBB" in a JSON value, however deep.
private func hexColors(in value: Any) -> [String] {
    switch value {
    case let text as String where text.hasPrefix("#") && text.count == 7: [String(text.dropFirst())]
    case let dictionary as [String: Any]: dictionary.values.flatMap(hexColors(in:))
    case let array as [Any]: array.flatMap(hexColors(in:))
    default: []
    }
}

@Test func chromeManifestIsAThemeWithTheClassicColors() throws {
    let manifest = try json("Chrome/manifest.json")
    #expect(manifest["manifest_version"] as? Int == 3)
    #expect(manifest["name"] as? String == "Retro98" && manifest["version"] as? String == "1.0")
    let theme = try #require(manifest["theme"] as? [String: Any])
    let colors = try #require(theme["colors"] as? [String: [Int]])
    #expect(colors["frame"] == [0, 0, 128] && colors["frame_inactive"] == [128, 128, 128])
    #expect(colors["toolbar"] == [192, 192, 192] && colors["ntp_background"] == [0, 128, 128])
    #expect(colors["tab_text"] == [0, 0, 0] && colors["tab_background_text"] == [255, 255, 255])
    #expect(colors["omnibox_background"] == [255, 255, 255] && colors["omnibox_text"] == [0, 0, 0])
    #expect(colors.count == 18)
    for (name, color) in colors {
        #expect(color.count == 3 && color.allSatisfy { (0...255).contains($0) }, "\(name)")
    }
    #expect((theme["properties"] as? [String: Int])?["ntp_logo_alternate"] == 1)
}

@Test func chromeManifestOnlyNamesImagesTheToolWrites() throws {
    let theme = try #require(try json("Chrome/manifest.json")["theme"] as? [String: Any])
    let images = try #require(theme["images"] as? [String: String])
    #expect(images == ["theme_frame": "images/theme_frame.png", "theme_frame_inactive": "images/theme_frame_inactive.png"])
    #expect(Set(images.values) == Set(ThemeFiles.chromeImagePaths))
}

@Test func sublimeThemeOnlyOverridesVariables() throws {
    let theme = try json("Sublime Text/Retro98.sublime-theme")
    #expect(Set(theme.keys) == ["extends", "variables"])
    #expect(theme["extends"] as? String == "Default.sublime-theme")
    let variables = try #require(theme["variables"] as? [String: String])
    #expect(variables["ui_bg"] == "#C0C0C0" && variables["font_face"] == "Tahoma")
    #expect(variables["sidebar_row_selected"] == "#000080" && variables["sidebar_label_selected"] == "#FFFFFF")
    #expect(variables["quick_panel_selected_row_bg"] == "#000080" && variables["tool_tip_bg"] == "#FFFFE1")
    // Every label on the navy selected row is white, the matched letters of the path included.
    for name in ["label", "path_label", "matched_label", "matched_path_label"] {
        #expect(variables["quick_panel_selected_\(name)_color"] == "#FFFFFF", "\(name)")
    }
    #expect(variables.count == 30)
}

@Test func sublimeColorSchemeIsBlackOnWhiteWithNavySelection() throws {
    let scheme = try json("Sublime Text/Retro98.sublime-color-scheme")
    #expect(scheme["name"] as? String == "Retro98")
    let globals = try #require(scheme["globals"] as? [String: String])
    #expect(globals["background"] == "#FFFFFF" && globals["foreground"] == "#000000")
    #expect(globals["selection"] == "#000080" && globals["selection_foreground"] == "#FFFFFF")
    let rules = try #require(scheme["rules"] as? [[String: String]])
    func color(ofScopeStarting prefix: String) -> String? {
        rules.first { $0["scope"]?.hasPrefix(prefix) == true }?["foreground"]
    }
    #expect(color(ofScopeStarting: "comment") == "#008000")
    #expect(color(ofScopeStarting: "string") == "#800000")
    #expect(color(ofScopeStarting: "keyword") == "#0000FF")
    #expect(rules.count == 15 && rules.allSatisfy { $0["scope"] != nil && $0["name"] != nil })
}

@Test func sublimeColorsComeFromTheClassicPalette() throws {
    let used = Set(hexColors(in: try json("Sublime Text/Retro98.sublime-color-scheme")))
    #expect(!used.isEmpty && used.isSubset(of: Set(ConsolePalette.ansiHex)))
}
