import AppKit

/// The classic VGA text-mode font (PxPlus IBM VGA 8x16 by VileR, CC BY-SA 4.0), shipped in the app's Resources.
/// At 16 pt every cell is exactly 8×16, so each font pixel lands on whole screen pixels.
enum PromptFont {
    static let fileName = "PxPlus_IBM_VGA_8x16.ttf"
    static let postScriptName = "PxPlus_IBM_VGA_8x16"
    static let size: CGFloat = 16

    /// Registers the font for this process; registering it again counts as success.
    @discardableResult static func register(at url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        var error: Unmanaged<CFError>?
        if CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) { return true }
        let code = error.map { CFErrorGetCode($0.takeRetainedValue()) }
        return code == CTFontManagerError.alreadyRegistered.rawValue
    }

    /// The copy inside the app bundle (Contents/Resources), when there is one.
    static var bundledURL: URL? {
        Bundle.main.url(forResource: (fileName as NSString).deletingPathExtension, withExtension: "ttf")
    }

    /// The VGA font at 16 pt once registered; the system's monospaced font otherwise (e.g. `swift run`).
    static func make() -> NSFont {
        NSFont(name: postScriptName, size: size) ?? .monospacedSystemFont(ofSize: size, weight: .regular)
    }
}
