import AppKit
import Testing
@testable import Retro98ControlPanel

/// The Control Panel's window of icons, for the README.
@MainActor @Test(.enabled(if: screenshotFolder != nil), arguments: ["en", "pt-BR"])
func screenshotControlPanel(language: String) throws {
    let controller = ControlPanelWindowController(services: TestServices(languages: [language]), prompter: ScriptedPrompter())
    controller.grid.setSelection(IndexSet(integer: 0))
    try saveScreenshot(of: controller.window, as: "control-panel", language: language)
}
