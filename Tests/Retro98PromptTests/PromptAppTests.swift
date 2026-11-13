import AppKit
import Retro98UI
import Testing
@testable import Retro98Prompt

private let pt = ["pt-BR"]

@MainActor private func makeApp(_ prompter: ScriptedPrompter = ScriptedPrompter()) -> AppDelegate {
    VGAFont.register(at: vgaFontURL)
    let home = FileManager.default.temporaryDirectory.appending(path: "retro98-prompt-\(UUID().uuidString)")
    try? FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    let app = AppDelegate(launch: { sh(["-i"], home: home) }, prompter: prompter)
    app.presentsWindows = false
    return app
}

@MainActor private func closeAll(_ app: AppDelegate) {
    for controller in app.windowControllers {
        controller.endProcess()
        controller.window.close()
    }
}

@MainActor @Test func menusHaveTheShortcuts() {
    let main = PromptMenus.mainMenu(languages: pt)
    let items = main.items.flatMap { $0.submenu?.items ?? [] }
    func has(_ key: String, _ modifiers: NSEvent.ModifierFlags, _ action: String) -> Bool {
        items.contains { $0.keyEquivalent == key && $0.keyEquivalentModifierMask == modifiers && $0.action.map(NSStringFromSelector) == action }
    }
    #expect(has("n", .command, "newWindow:"))
    #expect(has("w", .command, "closeWindow:"))
    #expect(has("c", .command, "copy:"))
    #expect(has("v", .command, "paste:"))
    #expect(has("a", .command, "selectAll:"))
    #expect(has("q", .command, "terminate:"))
    #expect(has("m", .command, "miniaturize:"))
    #expect(items.contains { $0.action.map(NSStringFromSelector) == "showAbout:" })
    let tabActions: Set<String> = ["toggleTabBar:", "toggleTabOverview:", "mergeAllWindows:", "moveTabToNewWindow:", "selectNextTab:"]
    #expect(!items.contains { $0.action.map(NSStringFromSelector).map(tabActions.contains) == true })
    #expect(PromptMenus.windowMenu(in: main, languages: pt)?.title == "Janela")
}

@MainActor @Test func retroMenusMirrorTheGroups() {
    let groups = PromptMenus.groups(pt)
    let menus = PromptMenus.retroMenus(languages: pt)
    #expect(menus.map(\.title) == groups.map(\.title))
    #expect(groups.map(\.title) == ["Arquivo", "Editar", "Ajuda"])
    for (menu, group) in zip(menus, groups) {
        #expect(menu.items().map(\.title) == group.commands.map { $0?.title ?? "" })
    }
}

@MainActor @Test func newWindowOpensAnother() async {
    let app = makeApp()
    defer { closeAll(app) }
    app.newWindow(nil)
    app.newWindow(nil)
    #expect(app.windowControllers.count == 2)
    let (first, second) = (app.windowControllers[0].window.frame, app.windowControllers[1].window.frame)
    #expect(second.minX == first.minX + 22 && second.maxY == first.maxY - 22)
    #expect(app.windowControllers[1].menuBar.menus.map(\.title) == ["Arquivo", "Editar", "Ajuda"])
    let closing = app.windowControllers[0]
    #expect(await waitUntil { closing.terminal.process.running })
    closing.window.performClose(nil)
    #expect(app.windowControllers.count == 1)
}

@MainActor @Test func quittingAsksOnceWhenSomethingRuns() async {
    let prompter = ScriptedPrompter()
    let app = makeApp(prompter)
    defer { closeAll(app) }
    #expect(app.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
    #expect(prompter.asked.isEmpty)

    app.newWindow(nil)
    app.newWindow(nil)
    let busy = app.windowControllers[1]
    #expect(await waitUntil { app.windowControllers.allSatisfy { $0.terminal.process.running } })
    try? await Task.sleep(for: .milliseconds(300))
    busy.terminal.send(txt: "sleep 30\n")
    #expect(await waitUntil { busy.hasRunningProgram })

    prompter.answers = [false]
    #expect(app.applicationShouldTerminate(NSApplication.shared) == .terminateCancel)
    #expect(prompter.asked == ["Há programas em execução no Prompt. Encerrar todos?"])
    #expect(app.windowControllers.allSatisfy { $0.terminal.process.running })

    prompter.answers = [true]
    #expect(app.applicationShouldTerminate(NSApplication.shared) == .terminateNow)
    #expect(prompter.asked.count == 2)
    #expect(app.windowControllers.allSatisfy { !$0.terminal.process.running })
}

@MainActor @Test func windowTabsAreOff() {
    let app = makeApp()
    defer { closeAll(app) }
    app.applicationWillFinishLaunching(Notification(name: NSApplication.willFinishLaunchingNotification))
    #expect(!NSWindow.allowsAutomaticWindowTabbing)
    app.newWindow(nil)
    #expect(app.windowControllers.allSatisfy { $0.window.tabbingMode == .disallowed })
}

@Test func aboutCreditsTheFontAndTerminal() {
    for languages in [pt, ["en"]] {
        let credits = AppDelegate.aboutCredits(languages)
        #expect(credits.contains("PxPlus IBM VGA 8x16") && credits.contains("VileR") && credits.contains("CC BY-SA 4.0")
            && credits.contains("SwiftTerm"))
    }
}
