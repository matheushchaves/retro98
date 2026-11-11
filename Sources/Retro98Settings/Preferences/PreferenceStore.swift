public enum PreferenceError: Error, Equatable {
    /// macOS did not keep the written value (read-back mismatch).
    case writeDenied(PreferenceKey)
}

public protocol PreferenceStore {
    func value(for key: PreferenceKey) -> PreferenceValue?
    /// Writes `value`, or removes the key when `value` is nil.
    func write(_ value: PreferenceValue?, for key: PreferenceKey) throws(PreferenceError)
}

/// In-memory store for tests and previews. Keys in `deniedKeys` reject writes.
public final class InMemoryPreferenceStore: PreferenceStore {
    private var storage: [PreferenceKey: PreferenceValue]
    public var deniedKeys: Set<PreferenceKey>

    public init(_ initial: [PreferenceKey: PreferenceValue] = [:], deniedKeys: Set<PreferenceKey> = []) {
        self.storage = initial
        self.deniedKeys = deniedKeys
    }

    public var snapshot: [PreferenceKey: PreferenceValue] { storage }

    public func value(for key: PreferenceKey) -> PreferenceValue? { storage[key] }

    public func write(_ value: PreferenceValue?, for key: PreferenceKey) throws(PreferenceError) {
        guard !deniedKeys.contains(key) else { throw .writeDenied(key) }
        storage[key] = value
    }
}
