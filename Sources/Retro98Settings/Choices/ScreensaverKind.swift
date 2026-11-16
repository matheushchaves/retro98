/// Which built-in screensaver to show after the idle timeout.
public enum ScreensaverKind: String, CaseIterable, Sendable {
    case none
    case pipes
    case text3d
    case johnny

    public static let standard: ScreensaverKind = .pipes
}
