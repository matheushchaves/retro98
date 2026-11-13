@preconcurrency import ApplicationServices
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

@Test func messageExplainsASwitchThatIsAlreadyOn() {
    #expect(AccessibilityPrompt.message(languages: ["pt-BR"])
        .contains("Se ele já aparece ativado, remova-o com − e adicione de novo com + (fica em ~/Applications/Retro98)."))
    #expect(AccessibilityPrompt.message(languages: ["en"])
        .contains("If it's already on, remove it with − and add it again with + (it's in ~/Applications/Retro98)."))
}

@Test func requestAsksMacOSToListTheShell() {
    let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
    #expect(AccessibilityPrompt.requestOptions == [promptKey: true])
}
