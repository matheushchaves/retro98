import AppKit
import Retro98UI

/// Asks whether to end running programs (tests answer from a script).
@MainActor
protocol PromptPrompter: AnyObject {
    /// True when the person chose End.
    func confirmEnd(title: String, message: String, languages: [String]) -> Bool
}

/// The live prompter: a modal 98-style question with End and Cancel.
@MainActor
final class RetroPromptPrompter: PromptPrompter {
    func confirmEnd(title: String, message: String, languages: [String]) -> Bool {
        RetroMessageBox.run(title: title, message: message, icon: .question,
                            buttons: [PromptText.end(languages), PromptText.cancel(languages)]) == 0
    }
}
