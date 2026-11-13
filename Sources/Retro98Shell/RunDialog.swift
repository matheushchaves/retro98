import AppKit
import Retro98Settings
import Retro98ShellCore
import Retro98UI

/// The Run… dialog: opens an app, folder, document or Internet address.
@MainActor
enum RunDialog {
    static let contentWidth: CGFloat = 347
    static let margin: CGFloat = 12
    private static var window: RetroWindow?
    private static var lastEntry = ""

    static func show(languages: [String]) {
        if let window {
            window.showCentered()
            return
        }
        let textX = margin * 2 + 32
        let textWidth = contentWidth - textX - margin
        let prompt = RetroText.wrap(RunDialogText.prompt(languages: languages), maxWidth: Int(textWidth))
        let promptHeight = CGFloat(prompt.count * PixelText.lineHeight)
        let fieldY = max(margin + 32, margin + promptHeight) + 10
        let fieldHeight: CGFloat = 23
        let contentSize = CGSize(width: contentWidth, height: fieldY + fieldHeight + 14 + RetroButton.height + margin)
        let window = RetroWindow(title: titleText(languages), contentSize: contentSize)
        let content = window.contentContainer

        let icon = RetroIconView(icon: Icons.run)
        icon.frame.origin = CGPoint(x: margin, y: margin)
        content.addSubview(icon)

        let promptView = RetroLabel(lines: prompt)
        promptView.frame = CGRect(x: textX, y: margin, width: textWidth, height: promptHeight)
        content.addSubview(promptView)

        let label = RetroLabel(lines: [RunDialogText.openLabel(languages: languages)])
        label.frame = CGRect(x: margin, y: fieldY + ((fieldHeight - CGFloat(PixelText.lineHeight)) / 2).rounded(.down),
                             width: textX - margin, height: CGFloat(PixelText.lineHeight))
        content.addSubview(label)

        let field = RetroTextField(frame: CGRect(x: textX, y: fieldY, width: textWidth, height: fieldHeight))
        field.text = lastEntry
        content.addSubview(field)

        let cancel = RetroButton(title: cancelText(languages)) { close() }
        let ok = RetroButton(title: "OK", isDefault: true) { submit(field.text, languages: languages) }
        cancel.frame.origin = CGPoint(x: contentSize.width - margin - cancel.frame.width, y: contentSize.height - margin - 23)
        ok.frame.origin = CGPoint(x: cancel.frame.minX - 6 - ok.frame.width, y: cancel.frame.minY)
        content.addSubview(ok)
        content.addSubview(cancel)

        window.defaultButton = ok
        window.onCancel = { close() }
        field.onSubmit = { submit(field.text, languages: languages) }
        self.window = window
        window.showCentered()
        field.focus(in: window)
    }

    private static func submit(_ input: String, languages: [String]) {
        guard let target = RunTarget.resolve(input, appRoots: StartMenuController.appRoots,
                                             home: FileManager.default.homeDirectoryForCurrentUser) else { return }
        lastEntry = input
        switch target {
        case .url(let url), .path(let url), .app(let url):
            close()
            NSWorkspace.shared.open(url)
        case .notFound(let text):
            _ = RetroMessageBox.run(title: titleText(languages), message: RunDialogText.notFound(text, languages: languages),
                                    icon: .error, buttons: ["OK"])
        }
    }

    private static func close() {
        window?.orderOut(nil)
        window = nil
    }

    private static func titleText(_ languages: [String]) -> String {
        LocalizedText(en: "Run", ptBR: "Executar").resolve(for: languages)
    }

    static func cancelText(_ languages: [String]) -> String {
        LocalizedText(en: "Cancel", ptBR: "Cancelar").resolve(for: languages)
    }
}
