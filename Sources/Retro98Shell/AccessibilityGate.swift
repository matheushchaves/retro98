import AppKit
import ApplicationServices
import Retro98ShellCore
import Retro98UI

/// Watches the Accessibility permission: asks once per installed build, then turns the
/// features that need it on and off as the permission comes and goes (checked every 3 s).
@MainActor
final class AccessibilityGate {
    static let checkInterval: TimeInterval = 3

    private let languages: [String]
    private let onChange: (Bool) -> Void
    private var isTrusted = false
    private var timer: Timer?

    init(languages: [String], onChange: @escaping (Bool) -> Void) {
        self.languages = languages
        self.onChange = onChange
    }

    func start() {
        isTrusted = Self.currentlyTrusted()
        onChange(isTrusted)
        askIfNeeded()
        let timer = Timer(timeInterval: Self.checkInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func check() {
        let now = Self.currentlyTrusted()
        if trustTransition(was: isTrusted, now: now) != .none { onChange(now) }
        isTrusted = now
    }

    private func askIfNeeded() {
        let defaults = UserDefaults.standard
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "dev"
        guard AccessibilityPrompt.shouldShow(isTrusted: isTrusted,
                                             lastPromptedBuild: defaults.string(forKey: AccessibilityPrompt.lastPromptedKey),
                                             currentBuild: build) else { return }
        defaults.set(build, forKey: AccessibilityPrompt.lastPromptedKey)
        _ = RetroMessageBox.run(title: "Retro98 Shell", message: AccessibilityPrompt.message(languages: languages),
                                icon: .info, buttons: ["OK"])
        // macOS's own request lists the Shell, so after an uninstall the person only flips its switch.
        _ = AXIsProcessTrustedWithOptions(AccessibilityPrompt.requestOptions as CFDictionary)
        NSWorkspace.shared.open(AccessibilityPrompt.settingsURL)
    }

    /// Checks without triggering the system's own prompt; our message box explains instead.
    private static func currentlyTrusted() -> Bool {
        AXIsProcessTrusted()
    }
}
