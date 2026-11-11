/// Where the taskbar's windows come from (Accessibility in the app, fakes in tests).
public protocol WindowSource<ID> {
    associatedtype ID: Hashable & Sendable
    func snapshot() -> [WindowSnapshot<ID>]
}

/// What the taskbar can do to a window. Each returns false when the window is gone or refused.
public protocol WindowCommands<ID> {
    associatedtype ID: Hashable & Sendable
    func activate(_ id: ID) -> Bool
    func minimize(_ id: ID) -> Bool
    func close(_ id: ID) -> Bool
}

public enum WindowCollector {
    /// Gathers every app's windows; an app whose read fails is skipped and the others still count.
    public static func collect<ID>(apps: [() throws -> [WindowSnapshot<ID>]]) -> [WindowSnapshot<ID>] {
        apps.flatMap { read in (try? read()) ?? [] }
    }
}
