import Foundation
import Retro98FilesCore

/// The quick launch button next to Start: opens the Explorer on the Desktop.
public enum QuickLaunch {
    public static let desktopURL = ExplorerURL.url(for: .desktop)

    /// Shown only while some app (the Explorer) handles `retro98-explorer://`.
    public static func isAvailable(canOpen: (URL) -> Bool) -> Bool {
        canOpen(desktopURL)
    }
}
