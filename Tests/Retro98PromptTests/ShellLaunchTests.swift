import Foundation
import Testing
@testable import Retro98Prompt

private let ptBR = Locale(identifier: "pt_BR")

private func launch(_ environment: [String: String], accountShell: String? = nil, executables: Set<String> = ["/bin/bash", "/bin/ksh"],
                    locale: Locale = ptBR) -> ShellLaunch {
    ShellLaunch.userShell(environment: environment, accountShell: accountShell, home: "/Users/ana", locale: locale,
                          version: "0.7.0", isExecutable: { executables.contains($0) })
}

private func variables(_ launch: ShellLaunch) -> [String: String] {
    Dictionary(launch.environment.map { line in
        let parts = line.split(separator: "=", maxSplits: 1)
        return (String(parts[0]), parts.count > 1 ? String(parts[1]) : "")
    }, uniquingKeysWith: { _, last in last })
}

@Test func usesTheUserShellAsLogin() {
    let shell = launch(["SHELL": "/bin/bash"])
    #expect(shell.executable == "/bin/bash")
    #expect(shell.execName == "-bash")
    #expect(shell.arguments.isEmpty)
    #expect(shell.directory == "/Users/ana")
}

@Test func fallsBackWhenShellIsBad() {
    for environment in [["SHELL": "zsh"], [:], ["SHELL": "/opt/nada/fish"]] {
        #expect(launch(environment, accountShell: "/bin/ksh").executable == "/bin/ksh")
        #expect(launch(environment, accountShell: "/bin/ksh").execName == "-ksh")
        #expect(launch(environment).executable == "/bin/zsh")
    }
    #expect(launch([:], accountShell: "/opt/nada/fish").executable == "/bin/zsh")
}

@Test func setsTerminalVariables() {
    let values = variables(launch(["SHELL": "/bin/bash", "PATH": "/usr/bin:/bin", "HOME": "/Users/ana", "TERM": "dumb"]))
    #expect(values["TERM"] == "xterm-256color")
    #expect(values["COLORTERM"] == "truecolor")
    #expect(values["TERM_PROGRAM"] == "Retro98_Prompt")
    #expect(values["TERM_PROGRAM_VERSION"] == "0.7.0")
    #expect(values["PATH"] == "/usr/bin:/bin")
    #expect(values["HOME"] == "/Users/ana")
    let keys = launch(["SHELL": "/bin/bash", "PATH": "/usr/bin"]).environment.map { String($0.split(separator: "=")[0]) }
    #expect(keys == keys.sorted())
}

@Test func addsLangOnlyWhenMissing() {
    #expect(variables(launch(["SHELL": "/bin/bash"]))["LANG"] == "pt_BR.UTF-8")
    let withCAll = variables(launch(["SHELL": "/bin/bash", "LC_ALL": "C"]))
    #expect(withCAll["LANG"] == nil)
    #expect(withCAll["LC_ALL"] == "C")
    #expect(variables(launch(["SHELL": "/bin/bash", "LC_CTYPE": "UTF-8"]))["LANG"] == nil)
    #expect(variables(launch(["SHELL": "/bin/bash", "LANG": "en_GB.UTF-8"]))["LANG"] == "en_GB.UTF-8")
    // English with region Brazil has no en_BR locale: the shell would fall back to C and lose accents.
    let englishInBrazil = variables(launch(["SHELL": "/bin/bash"], locale: Locale(identifier: "en_BR")))
    #expect(englishInBrazil["LANG"] == nil)
    #expect(englishInBrazil["LC_CTYPE"] == "UTF-8")
}

@Test func languageForLocales() {
    #expect(ShellLaunch.language(for: ptBR) == "pt_BR.UTF-8")
    #expect(ShellLaunch.language(for: Locale(identifier: "en_BR")) == nil)
    #expect(ShellLaunch.language(for: Locale(identifier: "fr_FR")) == "fr_FR.UTF-8")
}
