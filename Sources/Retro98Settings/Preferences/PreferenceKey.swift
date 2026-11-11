import CoreFoundation

/// Where a preference lives: the global domain (`defaults -g`) or an app domain.
public enum PreferenceDomain: Codable, Hashable, Sendable {
    case global
    case app(String)

    var cfApplicationID: CFString {
        switch self {
        case .global: return kCFPreferencesAnyApplication
        case .app(let identifier): return identifier as CFString
        }
    }
}

public struct PreferenceKey: Codable, Hashable, Sendable {
    public let domain: PreferenceDomain
    public let name: String

    public init(domain: PreferenceDomain, name: String) {
        self.domain = domain
        self.name = name
    }
}

/// A desired value for a key; a nil `target` means the key must be absent.
public struct PreferenceChange: Equatable, Sendable {
    public let key: PreferenceKey
    public let target: PreferenceValue?

    public init(key: PreferenceKey, target: PreferenceValue?) {
        self.key = key
        self.target = target
    }
}
