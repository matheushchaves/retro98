import AppKit
import Retro98UI

/// A 98-style property dialog: the applet's controls above OK, Cancel and Apply. OK applies and closes,
/// Apply applies and stays, Cancel (or Esc, or ×) closes without applying.
@MainActor
final class AppletDialog {
    static let margin: CGFloat = 12
    static let buttonGap: CGFloat = 6
    static let minimumButtonWidth: CGFloat = 75

    let window: RetroWindow
    /// Where the applet puts its controls (flipped, `contentSize` big).
    let contentView: NSView
    var onApply: () -> Void = {}
    var onClose: (() -> Void)?
    private(set) var buttonTitles: [String] = []

    init(title: String, contentSize: CGSize, languages: [String]) {
        let buttonsHeight = Self.margin + RetroButton.height + Self.margin
        window = RetroWindow(title: title, contentSize: CGSize(width: contentSize.width, height: contentSize.height + buttonsHeight))
        window.level = .normal
        contentView = FlippedContent(frame: CGRect(origin: .zero, size: contentSize))
        window.contentContainer.addSubview(contentView)
        window.onCancel = { [weak self] in self?.performCancel() }
        addButtons(languages: languages, top: contentSize.height + Self.margin, width: contentSize.width)
    }

    private func addButtons(languages: [String], top: CGFloat, width: CGFloat) {
        let buttons: [(String, () -> Void)] = [
            (ControlPanelText.ok(languages), { [weak self] in self?.performOK() }),
            (ControlPanelText.cancel(languages), { [weak self] in self?.performCancel() }),
            (ControlPanelText.apply(languages), { [weak self] in self?.performApply() }),
        ]
        buttonTitles = buttons.map(\.0)
        let widths = buttons.map { max(Self.minimumButtonWidth, RetroButton.preferredSize(title: $0.0, icon: nil, bold: false).width) }
        var x = width - Self.margin - widths.reduce(0, +) - Self.buttonGap * CGFloat(buttons.count - 1)
        for (index, (title, action)) in buttons.enumerated() {
            let button = RetroButton(title: title, isDefault: index == 0, action: action)
            button.frame = CGRect(x: x, y: top, width: widths[index], height: RetroButton.height)
            window.contentContainer.addSubview(button)
            if index == 0 { window.defaultButton = button }
            x += widths[index] + Self.buttonGap
        }
    }

    func show() {
        window.showCentered()
    }

    func performOK() {
        onApply()
        close()
    }

    func performApply() {
        onApply()
    }

    func performCancel() {
        close()
    }

    func close() {
        window.orderOut(nil)
        onClose?()
    }

    private final class FlippedContent: NSView {
        override var isFlipped: Bool { true }
    }
}

/// Shows what went wrong after a change, offering to open Full Disk Access when macOS needs it.
@MainActor
func presentProblems(_ problems: [Problem], model: ControlPanelModel, services: ControlPanelServices, prompter: ControlPanelPrompter) {
    let languages = services.languages
    guard let report = ControlPanelText.problems(problems, model: model, languages: languages) else { return }
    let buttons = report.offersFullDiskAccess ? [ControlPanelText.openSettings(languages), "OK"] : ["OK"]
    let answer = prompter.show(title: ControlPanelText.windowTitle(languages), message: report.message, icon: report.icon, buttons: buttons)
    if report.offersFullDiskAccess && answer == 0 { services.open(MacOSPanel.fullDiskAccess.url) }
}

/// A button that opens a macOS settings panel, placed by the applets.
@MainActor
func macOSButton(_ title: String, _ panel: MacOSPanel, services: ControlPanelServices) -> RetroButton {
    let button = RetroButton(title: title) { [weak services] in services?.open(panel.url) }
    button.frame.size = RetroButton.preferredSize(title: title, icon: nil, bold: false)
    return button
}
