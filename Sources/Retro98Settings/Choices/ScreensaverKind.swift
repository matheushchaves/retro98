/// Which built-in screensaver to show after the idle timeout.
public enum ScreensaverKind: String, CaseIterable, Sendable {
    case none
    case pipes
    case text3d
    case island

    public static let standard: ScreensaverKind = .pipes

    /// The kind a saved choices file names, including the island's old name from before 0.12.1.
    init?(saved value: String) {
        self.init(rawValue: value == "johnny" ? Self.island.rawValue : value)
    }
}
