import AppKit
import Retro98UI
import SwiftTerm
import Testing
@testable import Retro98Prompt

private let pt = ["pt-BR"]

/// Answers confirmations from a list (true = End) and remembers what was asked.
@MainActor final class ScriptedPrompter: PromptPrompter {
    var answers: [Bool] = []
    private(set) var asked: [String] = []

    func confirmEnd(title: String, message: String, languages: [String]) -> Bool {
        asked.append(message)
        return answers.isEmpty ? false : answers.removeFirst()
    }
}

/// A window running `/bin/sh` with the given arguments; closed (and its process ended) by `finish`.
@MainActor private func promptWindow(_ arguments: [String], prompter: ScriptedPrompter = ScriptedPrompter())
    -> (controller: PromptWindowController, closed: () -> Bool) {
    PromptFont.register(at: vgaFontURL)
    let home = FileManager.default.temporaryDirectory.appending(path: "retro98-prompt-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    let controller = PromptWindowController(launch: sh(arguments, home: home), languages: pt, prompter: prompter)
    var closed = false
    controller.onClose = { closed = true }
    controller.start()
    return (controller, { closed })
}

@MainActor private func finish(_ controller: PromptWindowController) {
    controller.endProcess()
    controller.window.close()
}

@MainActor @Test func opensEightyByTwentyFive() {
    let (controller, _) = promptWindow(["-c", "sleep 5"])
    defer { finish(controller) }
    #expect(controller.window.contentContainer.bounds.size == PromptWindowController.contentSize)
    #expect(controller.terminal.getTerminal().cols == 80)
    #expect(controller.terminal.getTerminal().rows == 25)
    #expect(controller.scroller.frame == CGRect(x: 640, y: 24, width: 16, height: 400))
    #expect(controller.menuBar.frame == CGRect(x: 0, y: 0, width: 656, height: 22))
    #expect(controller.window.tabbingMode == .disallowed)
}

@MainActor @Test func shellOutputAppears() async {
    let (controller, _) = promptWindow(["-c", "printf 'ol\\303\\241 a\\303\\247\\303\\243o\\n'; sleep 5"])
    defer { finish(controller) }
    #expect(await waitUntil { screenText(controller.terminal).contains("olá ação") })
}

@MainActor @Test func cleanExitClosesTheWindow() async {
    let (controller, closed) = promptWindow(["-c", "exit 0"])
    #expect(await waitUntil { closed() })
    #expect(!controller.window.isVisible)
}

@MainActor @Test func failedExitKeepsTheWindow() async {
    let (controller, closed) = promptWindow(["-c", "exit 3"])
    defer { finish(controller) }
    #expect(await waitUntil { screenText(controller.terminal).contains("[Processo concluído com código 3]") })
    #expect(!closed())
}

@MainActor @Test func titleFollowsTheProgram() async {
    let (controller, _) = promptWindow(["-c", "printf '\\033]0;vim\\007'; sleep 5"])
    defer { finish(controller) }
    #expect(await waitUntil { controller.window.title == "Prompt - vim" })
}

@MainActor @Test func scrollBarFollowsTheOutput() async {
    let (controller, _) = promptWindow(["-c", "seq 1 200; sleep 5"])
    defer { finish(controller) }
    let scroller = controller.scroller
    #expect(await waitUntil { screenText(controller.terminal).contains("200") })
    #expect(scroller.isEnabled)
    #expect(scroller.knobProportion < 1)
    #expect(scroller.doubleValue == 1)
    scroller.onScroll?(.lineUp)
    #expect(controller.terminal.scrollPosition < 1)
    #expect(scroller.doubleValue < 1)
    scroller.onScroll?(.position(0))
    #expect(controller.terminal.scrollPosition == 0)
}

@MainActor @Test func resizingChangesColumnsAndRows() {
    let (controller, _) = promptWindow(["-c", "sleep 5"])
    defer { finish(controller) }
    let window = controller.window
    let chrome = CGSize(width: window.frame.width - window.contentContainer.bounds.width,
                        height: window.frame.height - window.contentContainer.bounds.height)
    window.setFrame(CGRect(origin: window.frame.origin, size: CGSize(width: 816 + chrome.width, height: 520 + chrome.height)), display: false)
    #expect(controller.terminal.getTerminal().cols == 100)
    #expect(controller.terminal.getTerminal().rows == 31)
}

@MainActor @Test func closingAnIdleShellDoesNotAsk() async {
    let prompter = ScriptedPrompter()
    let (controller, _) = promptWindow(["-i"], prompter: prompter)
    defer { finish(controller) }
    #expect(await waitUntil { controller.terminal.process.running })
    try? await Task.sleep(for: .milliseconds(300))   // the shell takes its terminal before the check
    #expect(controller.windowShouldClose(controller.window))
    #expect(prompter.asked.isEmpty)
}

@MainActor @Test func closingWithARunningProgramAsks() async {
    let prompter = ScriptedPrompter()
    let (controller, closed) = promptWindow(["-i"], prompter: prompter)
    defer { finish(controller) }
    #expect(await waitUntil { controller.terminal.process.running })
    try? await Task.sleep(for: .milliseconds(300))
    controller.terminal.send(txt: "sleep 30\n")
    #expect(await waitUntil { controller.hasRunningProgram })
    let program = tcgetpgrp(controller.terminal.process.childfd)

    prompter.answers = [false]
    controller.window.performClose(nil)
    #expect(prompter.asked == ["Fechar esta janela vai encerrar o programa em execução."])
    #expect(!closed())
    #expect(controller.terminal.process.running)

    prompter.answers = [true]
    controller.window.performClose(nil)
    #expect(closed())
    #expect(!controller.terminal.process.running)
    #expect(await waitUntil { kill(program, 0) != 0 })   // the program got the hangup too
}
