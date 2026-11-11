import Testing
@testable import Retro98ShellCore

@Test func promptsOncePerBuild() {
    #expect(AccessibilityPrompt.shouldShow(isTrusted: false, lastPromptedBuild: nil, currentBuild: "3"))
    #expect(!AccessibilityPrompt.shouldShow(isTrusted: false, lastPromptedBuild: "3", currentBuild: "3"))
    #expect(AccessibilityPrompt.shouldShow(isTrusted: false, lastPromptedBuild: "2", currentBuild: "3"))
    #expect(!AccessibilityPrompt.shouldShow(isTrusted: true, lastPromptedBuild: nil, currentBuild: "3"))
}

@Test func buttonsFollowTrust() {
    #expect(trustTransition(was: false, now: true) == .granted)
    #expect(trustTransition(was: true, now: false) == .revoked)
    #expect(trustTransition(was: true, now: true) == .none)
    #expect(trustTransition(was: false, now: false) == .none)
}

@Test func messageMentionsTheSettingsPath() {
    #expect(AccessibilityPrompt.message(languages: ["pt-BR"]).contains("Privacidade e Segurança › Acessibilidade"))
    #expect(AccessibilityPrompt.message(languages: ["en"]).contains("Privacy & Security › Accessibility"))
    #expect(AccessibilityPrompt.settingsURL.absoluteString
            == "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
}
