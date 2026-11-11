import CoreFoundation

/// Reads and writes the current user's preferences for any host, like `defaults` does.
/// A write only counts once macOS hands the same value back; otherwise it is reported as denied.
public struct CFPreferenceStore: PreferenceStore {
    public init() {}

    public func value(for key: PreferenceKey) -> PreferenceValue? {
        guard let raw = CFPreferencesCopyValue(
            key.name as CFString, key.domain.cfApplicationID, kCFPreferencesCurrentUser, kCFPreferencesAnyHost
        ) else { return nil }
        return PreferenceValue(propertyList: raw)
    }

    public func write(_ value: PreferenceValue?, for key: PreferenceKey) throws(PreferenceError) {
        let domain = key.domain.cfApplicationID
        CFPreferencesSetValue(
            key.name as CFString, value.map { $0.propertyList as AnyObject },
            domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost
        )
        let synchronized = CFPreferencesSynchronize(domain, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        guard synchronized, self.value(for: key) == value else { throw .writeDenied(key) }
    }
}
