import AppKit
import Retro98UI
import Retro98Settings

/// Opens a Prompt window at launch, on ⌘N and when reopened with none; quitting while programs run asks once.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// New windows open this far right of and below the active one.
    static let cascadeOffset: CGFloat = 22

    let languages = Locale.preferredLanguages
    private var controllers: [PromptWindowController] = []
    private let launch: () -> ShellLaunch
    private let prompter: PromptPrompter
    /// Tests open windows without putting them on screen.
    var presentsWindows = true

    var windowControllers: [PromptWindowController] { controllers }

    init(launch: @escaping () -> ShellLaunch = AppDelegate.userShell, prompter: PromptPrompter = RetroPromptPrompter()) {
        self.launch = launch
        self.prompter = prompter
        super.init()
    }

    /// The person's login shell, with what macOS knows about the account and this app's version.
    nonisolated static func userShell() -> ShellLaunch {
        let accountShell = getpwuid(getuid()).flatMap { $0.pointee.pw_shell }.map { String(cString: $0) }
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        return ShellLaunch.userShell(
            environment: ProcessInfo.processInfo.environment, accountShell: accountShell,
            home: FileManager.default.homeDirectoryForCurrentUser.path, locale: .current, version: version,
            isExecutable: FileManager.default.isExecutableFile(atPath:)
        )
    }

    nonisolated static func aboutCredits(_ l: [String]) -> String {
        LocalizedText(
            en: "Font: PxPlus IBM VGA 8x16 by VileR (int10h.org), CC BY-SA 4.0.\nTerminal: SwiftTerm by Miguel de Icaza, MIT license.",
            ptBR: "Fonte: PxPlus IBM VGA 8x16, de VileR (int10h.org), CC BY-SA 4.0.\nTerminal: SwiftTerm, de Miguel de Icaza, licença MIT."
        ).resolve(for: l)
    }

    var active: PromptWindowController? {
        controllers.first { $0.window.isKeyWindow } ?? controllers.first { $0.window.isMainWindow } ?? controllers.last
    }

    // MARK: Application

    /// One window per program, never tabs.
    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        if let font = VGAFont.bundledURL { VGAFont.register(at: font) }
        if controllers.isEmpty { openWindow() }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { openWindow() }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if controllers.contains(where: \.hasRunningProgram),
           !prompter.confirmEnd(title: PromptText.appName, message: PromptText.confirmQuitMessage(languages), languages: languages) {
            return .terminateCancel
        }
        controllers.forEach { $0.endProcess() }
        return .terminateNow
    }

    @discardableResult
    func openWindow() -> PromptWindowController {
        let controller = PromptWindowController(launch: launch(), languages: languages, prompter: prompter)
        if let previous = active?.window.frame {
            controller.window.setFrameTopLeftPoint(CGPoint(x: previous.minX + Self.cascadeOffset, y: previous.maxY - Self.cascadeOffset))
        }
        controller.onClose = { [weak self, weak controller] in
            self?.controllers.removeAll { $0 === controller }
        }
        controllers.append(controller)
        if presentsWindows {
            controller.window.makeKeyAndOrderFront(nil)
            NSApp.activate()
        }
        controller.start()
        return controller
    }

    // MARK: Menu actions (both menu bars send these up the responder chain)

    @objc func newWindow(_ sender: Any?) { openWindow() }
    @objc func closeWindow(_ sender: Any?) { active?.window.performClose(nil) }

    @objc func showAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: PromptText.appName,
            .credits: NSAttributedString(string: Self.aboutCredits(languages)),
        ])
        NSApp.activate()
    }

    @objc func openHelp(_ sender: Any?) { NSWorkspace.shared.open(PromptMenus.helpURL) }
}
