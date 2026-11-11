import AppKit
import Retro98Settings
import Retro98ShellCore
import Retro98UI

/// The Shut Down… dialog. The dialog itself is the confirmation; OK carries out the choice.
@MainActor
enum ShutdownDialog {
    static let contentSize = CGSize(width: 312, height: 150)
    static let margin: CGFloat = 12
    static let radioSpacing: CGFloat = 20
    private static var window: RetroWindow?

    static func show(languages: [String]) {
        if let window {
            window.showCentered()
            return
        }
        let window = RetroWindow(title: ShutDownDialogText.title(languages: languages), contentSize: contentSize)
        let content = window.contentContainer
        let textX = margin * 2 + 32

        let icon = RetroIconView(icon: Icons.shutDown)
        icon.frame.origin = CGPoint(x: margin, y: margin)
        content.addSubview(icon)

        let question = RetroLabel(lines: [ShutDownDialogText.question(languages: languages)])
        question.frame = CGRect(x: textX, y: margin, width: contentSize.width - textX - margin, height: CGFloat(PixelText.lineHeight))
        content.addSubview(question)

        var selected = PowerAction.shutDown
        var radios: [RetroRadioButton] = []
        for (index, action) in PowerAction.allCases.enumerated() {
            let radio = RetroRadioButton(title: action.title(languages: languages), isSelected: action == selected) {
                selected = action
                radios.forEach { $0.isSelected = $0.title == action.title(languages: languages) }
            }
            radio.frame.origin = CGPoint(x: textX, y: margin + 22 + CGFloat(index) * radioSpacing)
            radios.append(radio)
            content.addSubview(radio)
        }

        let cancel = RetroButton(title: RunDialog.cancelText(languages)) { close() }
        let ok = RetroButton(title: "OK", isDefault: true) {
            close()
            if !selected.perform(runner: ProcessCommandRunner()) {
                _ = RetroMessageBox.run(title: ShutDownDialogText.title(languages: languages),
                                        message: ShutDownDialogText.failure(languages: languages),
                                        icon: .warning, buttons: ["OK"])
            }
        }
        cancel.frame.origin = CGPoint(x: contentSize.width - margin - cancel.frame.width, y: contentSize.height - margin - 23)
        ok.frame.origin = CGPoint(x: cancel.frame.minX - 6 - ok.frame.width, y: cancel.frame.minY)
        content.addSubview(ok)
        content.addSubview(cancel)

        window.defaultButton = ok
        window.onCancel = { close() }
        self.window = window
        window.showCentered()
        window.makeFirstResponder(ok)
    }

    private static func close() {
        window?.orderOut(nil)
        window = nil
    }
}
