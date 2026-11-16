import AppKit
import Retro98Screensavers
import Retro98Settings
import Retro98UI

/// The Screen Saver dialog: pick a screensaver and set the idle timeout.
@MainActor
final class ScreensaverApplet {
    static let width: CGFloat = 300
    static let height: CGFloat = 130

    let dialog: AppletDialog
    private let kindDrop: RetroDropDown
    private let timeoutDrop: RetroDropDown
    private let model: ControlPanelModel
    private let services: ControlPanelServices

    // Test seams
    private(set) var selectedKind: ScreensaverKind
    private(set) var selectedTimeout: Int

    private static let timeouts = [1, 2, 5, 10, 15, 20, 30]

    init(model: ControlPanelModel, services: ControlPanelServices, prompter: ControlPanelPrompter) {
        self.model = model
        self.services = services
        let l = services.languages
        let choices = services.choices.load()
        selectedKind = choices.screensaver
        selectedTimeout = choices.screensaverTimeout

        dialog = AppletDialog(title: Applet.screensaver.title(l),
                              contentSize: CGSize(width: Self.width, height: Self.height),
                              languages: l)
        let margin = AppletDialog.margin
        let content = dialog.contentView

        // Screensaver row
        let kindLabel = RetroLabel(lines: [ControlPanelText.screensaverKindLabel(l)])
        kindLabel.frame = CGRect(x: margin, y: Self.height - margin - CGFloat(PixelText.lineHeight),
                                 width: 100, height: CGFloat(PixelText.lineHeight))
        content.addSubview(kindLabel)

        kindDrop = RetroDropDown(items: { [] })
        kindDrop.frame = CGRect(x: margin + 100, y: Self.height - margin - RetroDropDown.height,
                                width: Self.width - margin * 2 - 100, height: RetroDropDown.height)
        content.addSubview(kindDrop)

        // Timeout row
        let timeoutLabel = RetroLabel(lines: [ControlPanelText.screensaverTimeoutLabel(l)])
        timeoutLabel.frame = CGRect(x: margin, y: kindDrop.frame.minY - margin / 2 - CGFloat(PixelText.lineHeight),
                                    width: 100, height: CGFloat(PixelText.lineHeight))
        content.addSubview(timeoutLabel)

        timeoutDrop = RetroDropDown(items: { [] })
        timeoutDrop.frame = CGRect(x: margin + 100,
                                   y: kindDrop.frame.minY - margin / 2 - RetroDropDown.height,
                                   width: 100, height: RetroDropDown.height)
        content.addSubview(timeoutDrop)

        // Wire items now that self is fully initialized
        rebuildKindItems(l)
        rebuildTimeoutItems(l)
        refresh(l)

        dialog.onApply = { [weak self] in self?.apply() }
    }

    func select(_ kind: ScreensaverKind) {
        selectedKind = kind
        rebuildKindItems(services.languages)
        refresh(services.languages)
    }

    func selectTimeout(_ minutes: Int) {
        selectedTimeout = minutes
        rebuildTimeoutItems(services.languages)
        refresh(services.languages)
    }

    func applyForTesting() { apply() }

    // MARK: - Private

    private func rebuildKindItems(_ l: [String]) {
        let items: [RetroMenuItem] = ScreensaverKind.allCases.map { kind in
            let isCurrent = kind == selectedKind
            return RetroMenuItem(title: ControlPanelText.screensaverKindName(kind, l),
                                 kind: .action { [weak self] in self?.select(kind) },
                                 mark: isCurrent ? .bullet : .none)
        }
        kindDrop.items = { items }
    }

    private func rebuildTimeoutItems(_ l: [String]) {
        let items: [RetroMenuItem] = Self.timeouts.map { mins in
            let isCurrent = mins == selectedTimeout
            return RetroMenuItem(title: ControlPanelText.screensaverTimeoutName(mins, l),
                                 kind: .action { [weak self] in self?.selectTimeout(mins) },
                                 mark: isCurrent ? .bullet : .none)
        }
        timeoutDrop.items = { items }
    }

    private func refresh(_ l: [String]) {
        kindDrop.set(text: ControlPanelText.screensaverKindName(selectedKind, l), icon: nil)
        timeoutDrop.set(text: ControlPanelText.screensaverTimeoutName(selectedTimeout, l), icon: nil)
    }

    private func apply() {
        let updated = services.choices.load()
            .with(screensaver: selectedKind)
            .with(screensaverTimeout: selectedTimeout)
        try? services.choices.save(updated)
    }
}
