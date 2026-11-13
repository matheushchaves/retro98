import Retro98UI

/// Message boxes; tests answer them from a script.
@MainActor
protocol ControlPanelPrompter {
    func show(title: String, message: String, icon: MessageBoxIcon, buttons: [String]) -> Int
}

struct RetroControlPanelPrompter: ControlPanelPrompter {
    func show(title: String, message: String, icon: MessageBoxIcon, buttons: [String]) -> Int {
        RetroMessageBox.run(title: title, message: message, icon: icon, buttons: buttons)
    }
}
