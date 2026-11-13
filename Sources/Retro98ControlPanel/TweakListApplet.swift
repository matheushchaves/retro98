import AppKit
import Retro98Settings
import Retro98UI

/// A dialog with one check box per tweak (Appearance and Mouse). A box is on when Retro98 manages the tweak.
@MainActor
final class TweakListApplet {
    static let width: CGFloat = 360
    static let rowHeight: CGFloat = 22

    let dialog: AppletDialog
    private(set) var boxes: [(id: TweakID, box: RetroCheckBox)] = []
    private let model: ControlPanelModel
    private let services: ControlPanelServices
    private let prompter: ControlPanelPrompter

    static func appearance(model: ControlPanelModel, services: ControlPanelServices, prompter: ControlPanelPrompter) -> TweakListApplet {
        let l = services.languages
        return TweakListApplet(
            title: Applet.appearance.title(l),
            ids: [.lightAppearance, .colors, .contrast, .scrollBars, .windowAnimations, .titleBarDoubleClick, .finderExplorer],
            note: ControlPanelText.appearanceNote(l), panels: [(ControlPanelText.macOSAppearance(l), .appearance)],
            model: model, services: services, prompter: prompter
        )
    }

    static func mouse(model: ControlPanelModel, services: ControlPanelServices, prompter: ControlPanelPrompter) -> TweakListApplet {
        let l = services.languages
        return TweakListApplet(
            title: Applet.mouse.title(l), ids: [.pointer], note: nil,
            panels: [(ControlPanelText.macOSMouse(l), .mouse), (ControlPanelText.macOSTrackpad(l), .trackpad)],
            model: model, services: services, prompter: prompter
        )
    }

    init(title: String, ids: [TweakID], note: String?, panels: [(String, MacOSPanel)], model: ControlPanelModel,
         services: ControlPanelServices, prompter: ControlPanelPrompter) {
        self.model = model
        self.services = services
        self.prompter = prompter
        let margin = AppletDialog.margin
        let noteLines = note.map { RetroText.wrap($0, maxWidth: Int(Self.width - margin * 2)) } ?? []
        let height = margin + CGFloat(ids.count) * Self.rowHeight + CGFloat(noteLines.count * PixelText.lineHeight)
            + (noteLines.isEmpty ? 0 : margin) + margin + RetroButton.height
        dialog = AppletDialog(title: title, contentSize: CGSize(width: Self.width, height: height), languages: services.languages)
        var y = margin
        for id in ids {
            let box = RetroCheckBox(title: model.title(of: id), isOn: false) { _ in }
            box.frame.origin = CGPoint(x: margin, y: y)
            dialog.contentView.addSubview(box)
            boxes.append((id, box))
            y += Self.rowHeight
        }
        if !noteLines.isEmpty {
            let label = RetroLabel(lines: noteLines)
            label.frame = CGRect(x: margin, y: y, width: Self.width - margin * 2, height: CGFloat(noteLines.count * PixelText.lineHeight))
            dialog.contentView.addSubview(label)
            y += label.frame.height + margin
        }
        var x = margin
        for (title, panel) in panels {
            let button = macOSButton(title, panel, services: services)
            button.frame.origin = CGPoint(x: x, y: y + margin)
            dialog.contentView.addSubview(button)
            x += button.frame.width + AppletDialog.buttonGap
        }
        dialog.onApply = { [weak self] in self?.apply() }
        refresh()
    }

    func box(_ id: TweakID) -> RetroCheckBox? {
        boxes.first { $0.id == id }?.box
    }

    /// Re-reads which tweaks are on. An unreadable backup shows them all off; applying then says why.
    func refresh() {
        let managed = (try? model.managed()) ?? []
        for (id, box) in boxes { box.isOn = managed.contains(id) }
    }

    private func apply() {
        let managed = (try? model.managed()) ?? []
        let on = Set(boxes.filter { $0.box.isOn && !managed.contains($0.id) }.map(\.id))
        let off = Set(boxes.filter { !$0.box.isOn && managed.contains($0.id) }.map(\.id))
        guard !on.isEmpty || !off.isEmpty else { return }
        presentProblems(model.setTweaks(on: on, off: off), model: model, services: services, prompter: prompter)
        refresh()
    }
}
