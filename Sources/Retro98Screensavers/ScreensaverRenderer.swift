import AppKit
import Retro98Settings

/// A screensaver that can render into an NSView.
@MainActor
public protocol ScreensaverRenderer: AnyObject {
    func start(in view: NSView)
    func stop()
}

public enum ScreensaverRendererFactory {
    /// Returns the renderer for `kind`, or nil when kind is `.none`.
    @MainActor
    public static func make(_ kind: ScreensaverKind) -> (any ScreensaverRenderer)? {
        switch kind {
        case .none: nil
        case .pipes: PipesRenderer()
        case .text3d: TextRenderer()
        case .johnny: JohnnyRenderer()
        }
    }
}
