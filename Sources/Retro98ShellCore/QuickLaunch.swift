import Foundation
import Retro98FilesCore

/// The quick launch button next to Start: opens the Explorer on the Desktop.
public enum QuickLaunch {
    public static let desktopURL = ExplorerURL.url(for: .desktop)
    /// Start › Find…: the Explorer's search in the home folder.
    public static let findURL = ExplorerURL.searchURL(in: nil)

    /// Shown only while some app (the Explorer) handles `retro98-explorer://`.
    public static func isAvailable(canOpen: (URL) -> Bool) -> Bool {
        canOpen(desktopURL)
    }
}
