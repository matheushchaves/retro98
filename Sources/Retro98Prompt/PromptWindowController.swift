import AppKit
import Retro98UI
import SwiftTerm

/// A local-process terminal that tells its window whenever the visible part of the history may have moved.
final class PromptTerminalView: LocalProcessTerminalView {
    var onViewportChange: (() -> Void)?

    override func scrolled(source: TerminalView, position: Double) {
        super.scrolled(source: source, position: position)
        onViewportChange?()
    }

    override func dataReceived(slice: ArraySlice<UInt8>) {
        super.dataReceived(slice: slice)
        onViewportChange?()
    }
}

/// One Prompt window: the retro menu bar, then the terminal with a retro scroll bar on its right.
/// Closing it while a program runs asks first; a shell that exits cleanly closes it.
@MainActor
final class PromptWindowController: NSObject, NSWindowDelegate {
    static let menuHeight: CGFloat = 22
    /// 80×25 cells of 8×16, the scroll bar, and the menu bar over an etched line.
    static let contentSize = CGSize(width: 656, height: 424)
    static let terminalTop = menuHeight + 2

    let window: RetroAppWindow
    let terminal = PromptTerminalView(frame: .zero)
    let scroller = RetroScroller(frame: .zero)
    let menuBar = RetroMenuBar(menus: [])
    var onClose: (() -> Void)?
    private let launch: ShellLaunch
    private let languages: [String]
    private let prompter: PromptPrompter
    private var isClosed = false

    init(launch: ShellLaunch, languages: [String], prompter: PromptPrompter) {
        self.launch = launch
        self.languages = languages
        self.prompter = prompter
        window = RetroAppWindow(title: PromptText.windowTitle(nil, languages), icon: FileIcons.promptAppSmall,
                                contentSize: Self.contentSize)
        super.init()
        window.delegate = self
        window.tabbingMode = .disallowed
        build()
    }

    private func build() {
        let content = window.contentContainer
        let width = content.bounds.width, height = content.bounds.height
        let barWidth = RetroScroller.thickness
        menuBar.frame = CGRect(x: 0, y: 0, width: width, height: Self.menuHeight)
        menuBar.autoresizingMask = [.width]
        let line = EtchedLine(frame: CGRect(x: 0, y: Self.menuHeight, width: width, height: 2))
        line.autoresizingMask = [.width]
        terminal.frame = CGRect(x: 0, y: Self.terminalTop, width: width - barWidth, height: height - Self.terminalTop)
        terminal.autoresizingMask = [.width, .height]
        scroller.frame = CGRect(x: width - barWidth, y: Self.terminalTop, width: barWidth, height: height - Self.terminalTop)
        scroller.autoresizingMask = [.minXMargin, .height]
        for view in [menuBar, line, terminal, scroller] { content.addSubview(view) }

        PromptStyle.apply(to: terminal)
        terminal.processDelegate = self
        terminal.onViewportChange = { [weak self] in self?.syncScroller() }
        scroller.onScroll = { [weak self] request in self?.scroll(request) }
        syncScroller()
        window.initialFirstResponder = terminal
    }

    /// Starts the program; the app calls this once the window is on screen.
    func start() {
        terminal.startProcess(executable: launch.executable, args: launch.arguments, environment: launch.environment,
                              execName: launch.execName, currentDirectory: launch.directory)
    }

    /// A program other than the shell holds the terminal (vim, ssh, a build).
    var hasRunningProgram: Bool {
        guard let process = terminal.process, process.running, process.childfd >= 0 else { return false }
        let group = tcgetpgrp(process.childfd)
        return group > 0 && group != process.shellPid
    }

    /// Hangs up on the program and the shell, as closing a terminal does, and reaps the shell so it never lingers.
    func endProcess() {
        guard let process = terminal.process, process.running else { return }
        let shell = process.shellPid
        let group = process.childfd >= 0 ? tcgetpgrp(process.childfd) : -1
        if group > 0, group != shell { killpg(group, SIGHUP) }
        kill(shell, SIGHUP)
        terminal.terminate()
        // SwiftTerm stops watching the child on terminate, so nothing else would collect its exit.
        DispatchQueue.global(qos: .utility).async {
            var status: Int32 = 0
            _ = waitpid(shell, &status, 0)
        }
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        guard hasRunningProgram else { return true }
        return prompter.confirmEnd(title: PromptText.windowTitle(nil, languages), message: PromptText.confirmCloseMessage(languages),
                                   languages: languages)
    }

    func windowWillClose(_ notification: Notification) {
        guard !isClosed else { return }
        isClosed = true
        endProcess()
        onClose?()
    }

    /// SwiftTerm passes waitpid's raw status: the exit code sits in its second byte unless a signal ended the program
    /// (reported as 128 + signal, as shells do).
    static func exitCode(fromWaitStatus status: Int32?) -> Int32? {
        guard let status else { return nil }
        let signal = status & 0x7F
        return signal == 0 ? (status >> 8) & 0xFF : 128 + signal
    }

    // MARK: Scroll bar

    private func scroll(_ request: RetroScroller.Request) {
        switch request {
        case .lineUp: terminal.scrollUp(lines: 1)
        case .lineDown: terminal.scrollDown(lines: 1)
        case .pageUp: terminal.pageUp()
        case .pageDown: terminal.pageDown()
        case .position(let value): terminal.scroll(toPosition: value)
        }
        syncScroller()
    }

    func syncScroller() {
        scroller.isEnabled = terminal.canScroll
        scroller.doubleValue = terminal.scrollPosition
        scroller.knobProportion = terminal.scrollThumbsize
        scroller.needsDisplay = true
    }
}

extension PromptWindowController: @preconcurrency LocalProcessTerminalViewDelegate {
    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {
        syncScroller()
    }

    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {
        window.setTitle(PromptText.windowTitle(title, languages), icon: FileIcons.promptAppSmall)
    }

    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        guard !isClosed else { return }
        let code = Self.exitCode(fromWaitStatus: exitCode)
        if code == 0 {
            window.close()
            return
        }
        terminal.feed(text: "\r\n" + PromptText.processEnded(code: code, languages) + "\r\n")
    }
}
