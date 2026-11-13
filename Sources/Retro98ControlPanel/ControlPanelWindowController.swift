import AppKit
import Retro98Settings
import Retro98UI

/// The Control Panel window: one icon per applet, a "Back to macOS normal…" button and a status bar
/// that describes the selected icon.
@MainActor
final class ControlPanelWindowController: NSObject, NSWindowDelegate, RetroIconGridDataSource {
    static let shellBundleID = ShellAgent.label
    static let contentSize = CGSize(width: 480, height: 360)
    static let menuHeight: CGFloat = 22
    static let footerHeight: CGFloat = 32
    static let statusHeight: CGFloat = 20

    let window: RetroAppWindow
    let grid = RetroIconGrid()
    let statusBar = RetroStatusBar()
    let services: ControlPanelServices
    let prompter: ControlPanelPrompter
    private(set) var backToNormalButton: RetroButton!
    /// A Retro98 applet was opened; by default its dialog shows (one per applet).
    var onOpenApplet: ((Applet) -> Void)?
    var onClose: (() -> Void)?
    let model: ControlPanelModel
    /// Open applet dialogs, each kept until it closes.
    private(set) var dialogs: [Applet: AppletDialog] = [:]
    /// Tests build dialogs without putting them on screen.
    var presentsDialogs = true

    private var languages: [String] { services.languages }
    private let applets = Applet.allCases

    init(services: ControlPanelServices, prompter: ControlPanelPrompter) {
        self.services = services
        self.prompter = prompter
        model = ControlPanelModel(services: services)
        window = RetroAppWindow(title: ControlPanelText.windowTitle(services.languages), icon: ControlPanelIcons.appSmall,
                                contentSize: Self.contentSize)
        super.init()
        window.delegate = self
        window.tabbingMode = .disallowed
        window.taskbarHeight = {
            NSRunningApplication.runningApplications(withBundleIdentifier: Self.shellBundleID).isEmpty ? 0 : 28
        }
        build()
        updateStatus()
        onOpenApplet = { [weak self] applet in self?.openDialog(applet) }
    }

    // MARK: Layout

    private func build() {
        let content = window.contentContainer
        let width = content.bounds.width, height = content.bounds.height
        let menuBar = RetroMenuBar(menus: retroMenus())
        menuBar.frame = CGRect(x: 0, y: 0, width: width, height: Self.menuHeight)
        menuBar.autoresizingMask = [.width]
        content.addSubview(menuBar)
        let line = EtchedLine()
        line.frame = CGRect(x: 0, y: Self.menuHeight, width: width, height: 2)
        line.autoresizingMask = [.width]
        content.addSubview(line)

        let top = Self.menuHeight + 2
        let scroll = RetroScroller.makeScrollView(document: grid)
        scroll.hasHorizontalScroller = false
        scroll.frame = CGRect(x: 0, y: top, width: width, height: height - top - Self.footerHeight - Self.statusHeight)
        let frame = FieldFrame(wrapping: scroll)
        frame.autoresizingMask = [.width, .height]
        content.addSubview(frame)
        grid.dataSource = self
        grid.onOpen = { [weak self] index in self?.openItem(at: index) }
        grid.onSelectionChange = { [weak self] _ in self?.updateStatus() }
        grid.reloadData()

        let title = ControlPanelText.backToNormal(languages)
        let button = RetroButton(title: title) { [weak self] in self?.backToNormal(nil) }
        let size = RetroButton.preferredSize(title: title, icon: nil, bold: false)
        button.frame = CGRect(x: 8, y: height - Self.statusHeight - Self.footerHeight + ((Self.footerHeight - size.height) / 2).rounded(.down),
                              width: size.width, height: size.height)
        button.autoresizingMask = [.maxXMargin, .minYMargin]
        content.addSubview(button)
        backToNormalButton = button

        statusBar.frame = CGRect(x: 0, y: height - Self.statusHeight, width: width, height: Self.statusHeight)
        statusBar.autoresizingMask = [.width, .minYMargin]
        content.addSubview(statusBar)
    }

    private func retroMenus() -> [RetroMenuBarMenu] {
        let l = languages
        return [
            RetroMenuBarMenu(title: ControlPanelText.menuFile(l)) { [weak self] in
                [
                    RetroMenuItem(title: ControlPanelText.open(l), kind: .action({ self?.openSelected(nil) }),
                                  isEnabled: self?.grid.selection.isEmpty == false),
                    .separator,
                    RetroMenuItem(title: ControlPanelText.backToNormal(l), kind: .action({ self?.backToNormal(nil) })),
                    .separator,
                    RetroMenuItem(title: ControlPanelText.close(l), kind: .action({ self?.window.performClose(nil) })),
                ]
            },
            RetroMenuBarMenu(title: ControlPanelText.menuHelp(l)) {
                [
                    RetroMenuItem(title: ControlPanelText.readme(l), kind: .action({ NSWorkspace.shared.open(ControlPanelMenus.helpURL) })),
                    .separator,
                    RetroMenuItem(title: ControlPanelText.about(l), kind: .action({
                        NSApplication.shared.sendAction(#selector(AppDelegate.showAbout(_:)), to: nil, from: nil)
                    })),
                ]
            },
        ]
    }

    func show() {
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
        window.makeFirstResponder(grid)
    }

    // MARK: Status

    private func updateStatus() {
        let text = grid.selection.first.map { applets[$0].description(languages) } ?? ControlPanelText.objects(applets.count, languages)
        statusBar.fields = [(text, nil)]
    }

    // MARK: Opening

    /// A macOS shortcut opens its System Settings panel; a Retro98 applet opens its dialog.
    func open(_ applet: Applet) {
        if let url = applet.settingsURL {
            services.open(url)
        } else {
            onOpenApplet?(applet)
        }
    }

    /// Shows the applet's dialog, or brings the open one to the front.
    func openDialog(_ applet: Applet) {
        if let open = dialogs[applet] {
            if presentsDialogs { open.window.makeKeyAndOrderFront(nil) }
            return
        }
        guard let dialog = makeDialog(applet) else { return }
        dialog.onClose = { [weak self] in
            self?.dialogs[applet] = nil
            self?.appletObjects[applet] = nil
        }
        dialogs[applet] = dialog
        if presentsDialogs { dialog.show() }
    }

    /// The objects behind each dialog stay alive with it.
    private var appletObjects: [Applet: AnyObject] = [:]

    private func makeDialog(_ applet: Applet) -> AppletDialog? {
        let object: AnyObject
        let dialog: AppletDialog
        switch applet {
        case .display:
            let display = DisplayApplet(model: model, services: services, prompter: prompter)
            (object, dialog) = (display, display.dialog)
        case .appearance:
            let list = TweakListApplet.appearance(model: model, services: services, prompter: prompter)
            (object, dialog) = (list, list.dialog)
        case .mouse:
            let list = TweakListApplet.mouse(model: model, services: services, prompter: prompter)
            (object, dialog) = (list, list.dialog)
        case .sounds:
            let sounds = SoundsApplet(model: model, services: services, prompter: prompter)
            (object, dialog) = (sounds, sounds.dialog)
        case .components:
            let components = ComponentsApplet(model: model, services: services, prompter: prompter)
            (object, dialog) = (components, components.dialog)
        case .network, .printers, .keyboard, .dateTime, .users, .systemSettings:
            return nil
        }
        appletObjects[applet] = object
        return dialog
    }

    private func openItem(at index: Int) {
        guard applets.indices.contains(index) else { return }
        open(applets[index])
    }

    @objc func openSelected(_ sender: Any?) {
        grid.selection.first.map(openItem(at:))
    }

    /// Asks first; then turns everything off, closes the open dialogs and says how to remove the apps.
    @objc func backToNormal(_ sender: Any?) {
        let l = languages
        let title = ControlPanelText.windowTitle(l)
        let answer = prompter.show(title: title, message: ControlPanelText.backToNormalQuestion(l), icon: .question,
                                   buttons: [ControlPanelText.backToNormalConfirm(l), ControlPanelText.cancel(l)])
        guard answer == 0 else { return }
        let problems = model.backToNormal()
        dialogs.values.forEach { $0.close() }
        if problems.isEmpty {
            _ = prompter.show(title: title, message: ControlPanelText.backToNormalDone(l), icon: .info, buttons: ["OK"])
        } else {
            presentProblems(problems, model: model, services: services, prompter: prompter)
        }
    }

    // MARK: RetroIconGridDataSource

    func numberOfItems(in grid: RetroIconGrid) -> Int { applets.count }
    func grid(_ grid: RetroIconGrid, titleAt index: Int) -> String { applets[index].title(languages) }
    func grid(_ grid: RetroIconGrid, iconAt index: Int) -> PixelIcon { applets[index].icon }

    // MARK: NSWindowDelegate

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }
}
