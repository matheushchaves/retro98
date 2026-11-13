import Foundation

/// What the Notepad remembers between launches, shared by every window.
/// Tests use `.memory`, which never touches the user's defaults.
final class NotepadPreferences: @unchecked Sendable {
    private enum Key {
        static let wordWrap = "WordWrap"
    }

    private let lock = NSLock()
    private let defaults: UserDefaults?
    private var memory: [String: Any] = [:]

    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    private init(memory: [String: Any]) {
        defaults = nil
        self.memory = memory
    }

    static func memory(wordWrap: Bool = false) -> NotepadPreferences {
        NotepadPreferences(memory: [Key.wordWrap: wordWrap])
    }

    /// Format › Word Wrap; off until the person turns it on.
    var wordWrap: Bool {
        get { lock.withLock { defaults?.object(forKey: Key.wordWrap) ?? memory[Key.wordWrap] } as? Bool ?? false }
        set {
            lock.withLock {
                if let defaults { defaults.set(newValue, forKey: Key.wordWrap) } else { memory[Key.wordWrap] = newValue }
            }
        }
    }
}
