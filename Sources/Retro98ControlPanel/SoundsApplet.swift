import AppKit
import Retro98Settings
import Retro98UI

/// The Sounds dialog: Retro98's sounds on or off, a Play button per sound, and the macOS alert sound.
@MainActor
final class SoundsApplet {
    static let width: CGFloat = 340
    static let rowHeight: CGFloat = 28

    let dialog: AppletDialog
    let soundsBox: RetroCheckBox
    let alertBox: RetroCheckBox
    private(set) var rows: [(kind: RetroSoundKind, title: String, play: RetroButton)] = []
    private let model: ControlPanelModel
    private let services: ControlPanelServices
    private let prompter: ControlPanelPrompter

    init(model: ControlPanelModel, services: ControlPanelServices, prompter: ControlPanelPrompter) {
        self.model = model
        self.services = services
        self.prompter = prompter
        let l = services.languages
        let margin = AppletDialog.margin
        let kinds = RetroSoundKind.allCases
        let height = margin + 22 + CGFloat(kinds.count) * Self.rowHeight + margin + 22 + margin + RetroButton.height
        dialog = AppletDialog(title: Applet.sounds.title(l), contentSize: CGSize(width: Self.width, height: height), languages: l)
        soundsBox = RetroCheckBox(title: ControlPanelText.playSounds(l), isOn: false) { _ in }
        alertBox = RetroCheckBox(title: model.title(of: .alertSound), isOn: false) { _ in }
        let content = dialog.contentView
        soundsBox.frame.origin = CGPoint(x: margin, y: margin)
        content.addSubview(soundsBox)
        var y = margin + 22
        let playTitle = ControlPanelText.play(l)
        let playSize = RetroButton.preferredSize(title: playTitle, icon: nil, bold: false)
        for kind in kinds {
            let title = ControlPanelText.soundName(kind, l)
            let label = RetroLabel(lines: [title])
            label.frame = CGRect(x: margin * 2, y: y + 5, width: Self.width - margin * 4 - playSize.width, height: CGFloat(PixelText.lineHeight))
            content.addSubview(label)
            let play = RetroButton(title: playTitle) { [weak services] in services?.preview(kind) }
            play.frame = CGRect(x: Self.width - margin - playSize.width, y: y, width: playSize.width, height: playSize.height)
            content.addSubview(play)
            rows.append((kind, title, play))
            y += Self.rowHeight
        }
        alertBox.frame.origin = CGPoint(x: margin, y: y + margin / 2)
        content.addSubview(alertBox)
        y += 22 + margin
        let sound = macOSButton(ControlPanelText.macOSSound(l), .sound, services: services)
        sound.frame.origin = CGPoint(x: margin, y: y)
        content.addSubview(sound)
        dialog.onApply = { [weak self] in self?.apply() }
        refresh()
    }

    func refresh() {
        soundsBox.isOn = model.soundsOn()
        alertBox.isOn = ((try? model.managed()) ?? []).contains(.alertSound)
    }

    private func apply() {
        var problems: [Problem] = []
        if soundsBox.isOn != model.soundsOn() { problems += model.setSounds(on: soundsBox.isOn) }
        if alertBox.isOn != ((try? model.managed()) ?? []).contains(.alertSound) { problems += model.setAlertSound(on: alertBox.isOn) }
        presentProblems(problems, model: model, services: services, prompter: prompter)
        refresh()
    }
}
