import AppKit
import Retro98Screensavers
import Retro98Settings
import Retro98UI

/// The Screen Saver dialog: pick a screensaver, set the idle timeout and whether it plays its own sounds.
@MainActor
final class ScreensaverApplet {
    static let width: CGFloat = 300
    private static let rowGap: CGFloat = AppletDialog.margin / 2
    static let height: CGFloat = AppletDialog.margin + RetroDropDown.height + rowGap + RetroDropDown.height
        + rowGap + 16 + AppletDialog.margin

    let dialog: AppletDialog
    private let kindDrop: RetroDropDown
    private let timeoutDrop: RetroDropDown
    private var previewBtn: RetroButton!
    private var soundBox: RetroCheckBox!
    private let model: ControlPanelModel
    private let services: ControlPanelServices
    private var previewWin: ScreensaverWindow?

    // Test seams
    private(set) var selectedKind: ScreensaverKind
    private(set) var selectedTimeout: Int
    private(set) var selectedSound: Bool

    private static let timeouts = [1, 2, 5, 10, 15, 20, 30]

    init(model: ControlPanelModel, services: ControlPanelServices, prompter: ControlPanelPrompter) {
        self.model = model
        self.services = services
        let l = services.languages
        let choices = services.choices.load()
        selectedKind = choices.screensaver
        selectedTimeout = choices.screensaverTimeout
        selectedSound = choices.screensaverSound

        dialog = AppletDialog(title: Applet.screensaver.title(l),
                              contentSize: CGSize(width: Self.width, height: Self.height),
                              languages: l)
        let margin = AppletDialog.margin
        let content = dialog.contentView

        // Screensaver row (the content view is flipped: rows go down from the top)
        let lineHeight = CGFloat(PixelText.lineHeight)
        let labelInset = ((RetroDropDown.height - lineHeight) / 2).rounded(.down)
        let kindLabel = RetroLabel(lines: [ControlPanelText.screensaverKindLabel(l)])
        kindLabel.frame = CGRect(x: margin, y: margin + labelInset, width: 100, height: lineHeight)
        content.addSubview(kindLabel)

        kindDrop = RetroDropDown(items: { [] })
        kindDrop.frame = CGRect(x: margin + 100, y: margin,
                                width: Self.width - margin * 2 - 100, height: RetroDropDown.height)
        content.addSubview(kindDrop)

        // Timeout row, with the Preview button
        let timeoutY = kindDrop.frame.maxY + Self.rowGap
        let timeoutLabel = RetroLabel(lines: [ControlPanelText.screensaverTimeoutLabel(l)])
        timeoutLabel.frame = CGRect(x: margin, y: timeoutY + labelInset, width: 100, height: lineHeight)
        content.addSubview(timeoutLabel)

        timeoutDrop = RetroDropDown(items: { [] })
        timeoutDrop.frame = CGRect(x: margin + 100, y: timeoutY, width: 100, height: RetroDropDown.height)
        content.addSubview(timeoutDrop)

        let previewX = timeoutDrop.frame.maxX + 4
        previewBtn = RetroButton(title: ControlPanelText.screensaverPreview(l),
                                 action: { [weak self] in self?.showPreview() })
        previewBtn.frame = CGRect(x: previewX, y: timeoutY,
                                  width: Self.width - margin - previewX, height: RetroButton.height)
        content.addSubview(previewBtn)

        // Sound row
        soundBox = RetroCheckBox(title: ControlPanelText.screensaverSound(l), isOn: selectedSound) { [weak self] isOn in
            self?.selectedSound = isOn
        }
        soundBox.frame.origin = CGPoint(x: margin + 100, y: timeoutDrop.frame.maxY + Self.rowGap)
        content.addSubview(soundBox)

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

    func setSound(_ isOn: Bool) {
        selectedSound = isOn
        soundBox.isOn = isOn
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
        previewBtn.isEnabled = selectedKind != .none
    }

    private func showPreview() {
        guard selectedKind != .none,
              let renderer = ScreensaverRendererFactory.make(selectedKind, sound: selectedSound) else { return }
        let win = ScreensaverWindow()
        previewWin = win
        win.onDismiss = { [weak self] in self?.previewWin = nil }
        win.present(renderer: renderer)
    }

    private func apply() {
        let updated = services.choices.load()
            .with(screensaver: selectedKind)
            .with(screensaverTimeout: selectedTimeout)
            .with(screensaverSound: selectedSound)
        try? services.choices.save(updated)
    }
}
