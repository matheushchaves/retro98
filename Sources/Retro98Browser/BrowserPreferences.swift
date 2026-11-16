import Foundation

/// What the browser remembers between launches, shared by every window.
/// Tests use `.memory`, which never touches the user's defaults.
final class BrowserPreferences: @unchecked Sendable {
    private enum Key {
        static let homePage = "HomePage"
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

    static func memory(homePage: String = AddressInput.homeText) -> BrowserPreferences {
        BrowserPreferences(memory: [Key.homePage: homePage])
    }

    /// What Home and new windows open: "about:home" (the built-in page) until the person picks an address.
    var homePage: String {
        get { lock.withLock { defaults?.object(forKey: Key.homePage) ?? memory[Key.homePage] } as? String ?? AddressInput.homeText }
        set {
            lock.withLock {
                if let defaults { defaults.set(newValue, forKey: Key.homePage) } else { memory[Key.homePage] = newValue }
            }
        }
    }
}
