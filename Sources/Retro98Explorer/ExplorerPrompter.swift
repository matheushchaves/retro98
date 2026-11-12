import AppKit
import Retro98FilesCore
import Retro98UI

/// Asks a question and returns the index of the chosen button (tests answer from a script).
@MainActor
protocol ExplorerPrompter: AnyObject {
    func ask(_ prompt: Prompt) -> Int
}

/// The live prompter: a modal 98-style message box.
@MainActor
final class RetroPrompter: ExplorerPrompter {
    func ask(_ prompt: Prompt) -> Int {
        let icon: MessageBoxIcon = switch prompt.icon {
        case .question: .question
        case .warning: .warning
        case .error: .error
        }
        return RetroMessageBox.run(title: prompt.title, message: prompt.message, icon: icon, buttons: prompt.buttons)
    }
}
