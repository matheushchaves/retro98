import AppKit
import Retro98Settings
import Retro98UI

/// The Components dialog: the taskbar, Explorer instead of Finder, and the hidden macOS menu bar.
/// A piece that isn't installed shows a disabled box and how to install it.
@MainActor
final class ComponentsApplet {
    static let width: CGFloat = 360
    static let rowHeight: CGFloat = 22
    static let noteHeight: CGFloat = 18

    let dialog: AppletDialog
    let taskbarBox: RetroCheckBox
    let fileViewerBox: RetroCheckBox
    let menuBarBox: RetroCheckBox
    let taskbarNote: RetroLabel
    let fileViewerNote: RetroLabel
    private var state: ComponentsState?
    private let model: ControlPanelModel
    private let services: ControlPanelServices
    private let prompter: ControlPanelPrompter

    init(model: ControlPanelModel, services: ControlPanelServices, prompter: ControlPanelPrompter) {
        self.model = model
        self.services = services
        self.prompter = prompter
        let l = services.languages
        let margin = AppletDialog.margin
        let height = margin + 3 * Self.rowHeight + 2 * Self.noteHeight + margin
        dialog = AppletDialog(title: Applet.components.title(l), contentSize: CGSize(width: Self.width, height: height), languages: l)
        taskbarBox = RetroCheckBox(title: ControlPanelText.taskbar(l), isOn: false) { _ in }
        fileViewerBox = RetroCheckBox(title: model.title(of: .explorerFileViewer), isOn: false) { _ in }
        menuBarBox = RetroCheckBox(title: model.title(of: .hiddenMenuBar), isOn: false) { _ in }
        taskbarNote = RetroLabel(lines: [ControlPanelText.notInstalled(l)])
        fileViewerNote = RetroLabel(lines: [ControlPanelText.notInstalled(l)])
        for view in [taskbarBox, taskbarNote, fileViewerBox, fileViewerNote, menuBarBox] { dialog.contentView.addSubview(view) }
        dialog.onApply = { [weak self] in self?.apply() }
        refresh()
    }

    func refresh() {
        state = try? model.components()
        let state = state ?? ComponentsState(taskbar: .off, fileViewer: .off, hiddenMenuBar: false)
        for (box, note, availability) in [(taskbarBox, taskbarNote, state.taskbar), (fileViewerBox, fileViewerNote, state.fileViewer)] {
            box.isOn = availability == .on
            box.isEnabled = availability != .notInstalled
            note.isHidden = availability != .notInstalled
        }
        menuBarBox.isOn = state.hiddenMenuBar
        layout()
    }

    /// Boxes one under the other; a "not installed" note sits under its box only when shown.
    private func layout() {
        let margin = AppletDialog.margin
        var y = margin
        for (box, note) in [(taskbarBox, Optional(taskbarNote)), (fileViewerBox, fileViewerNote), (menuBarBox, nil)] {
            box.frame.origin = CGPoint(x: margin, y: y)
            y += Self.rowHeight
            guard let note, !note.isHidden else { continue }
            note.frame = CGRect(x: margin + RetroCheckBox.boxSize + RetroCheckBox.labelGap, y: y - 4, width: Self.width - margin * 3,
                                height: CGFloat(PixelText.lineHeight))
            y += Self.noteHeight
        }
    }

    private func apply() {
        guard let state else {
            presentProblems([.backupUnreadable(path: services.paths.backupFile.path)], model: model, services: services, prompter: prompter)
            return
        }
        var problems: [Problem] = []
        if taskbarBox.isEnabled && taskbarBox.isOn != (state.taskbar == .on) { problems += model.setTaskbar(on: taskbarBox.isOn) }
        if fileViewerBox.isEnabled && fileViewerBox.isOn != (state.fileViewer == .on) { problems += model.setFileViewer(on: fileViewerBox.isOn) }
        if menuBarBox.isOn != state.hiddenMenuBar {
            problems += menuBarBox.isOn ? model.setTweaks(on: [.hiddenMenuBar], off: []) : model.setTweaks(on: [], off: [.hiddenMenuBar])
        }
        presentProblems(problems, model: model, services: services, prompter: prompter)
        refresh()
    }
}
