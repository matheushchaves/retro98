import Foundation

/// How a Prompt window starts its program: normally the person's own shell as a login shell, in the home
/// folder, with the terminal variables programs look for.
struct ShellLaunch: Equatable {
    let executable: String
    /// Empty for the person's shell.
    let arguments: [String]
    /// argv[0]; a leading "-" makes it a login shell, as Terminal does.
    let execName: String
    /// "KEY=value", sorted by key.
    let environment: [String]
    let directory: String

    static let fallbackShell = "/bin/zsh"

    /// `$SHELL` when it is an absolute path to an executable, then the account's shell, then zsh. Apps opened
    /// from Finder or launchd may have no `$SHELL` and no `LANG`, so both are filled in.
    static func userShell(environment: [String: String], accountShell: String?, home: String, locale: Locale,
                          version: String, isExecutable: (String) -> Bool) -> ShellLaunch {
        func usable(_ path: String?) -> String? {
            guard let path, path.hasPrefix("/"), isExecutable(path) else { return nil }
            return path
        }
        let shell = usable(environment["SHELL"]) ?? usable(accountShell) ?? fallbackShell
        var variables = environment
        variables["SHELL"] = shell
        variables["TERM"] = "xterm-256color"
        variables["COLORTERM"] = "truecolor"
        variables["TERM_PROGRAM"] = "Retro98_Prompt"
        variables["TERM_PROGRAM_VERSION"] = version
        if ["LANG", "LC_ALL", "LC_CTYPE"].allSatisfy({ variables[$0] == nil }) {
            // Without a real locale for this language and region, UTF-8 text still works, as in Terminal.
            if let name = language(for: locale) { variables["LANG"] = name } else { variables["LC_CTYPE"] = "UTF-8" }
        }
        return ShellLaunch(
            executable: shell, arguments: [], execName: "-" + (shell as NSString).lastPathComponent,
            environment: variables.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }, directory: home
        )
    }

    /// "pt_BR.UTF-8" for Brazilian Portuguese; nil when macOS has no locale for the pair (English with region
    /// Brazil has no en_BR) or the locale lacks a language or region.
    static func language(for locale: Locale) -> String? {
        guard let language = locale.language.languageCode?.identifier, let region = locale.region?.identifier else { return nil }
        let name = "\(language)_\(region).UTF-8"
        guard let handle = newlocale(LC_CTYPE_MASK, name, nil) else { return nil }
        freelocale(handle)
        return name
    }
}
