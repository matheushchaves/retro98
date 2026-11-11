import Foundation
import Testing
@testable import Retro98ShellCore

@Test func quickLaunchOpensTheDesktop() {
    #expect(QuickLaunch.desktopURL.absoluteString == "retro98-explorer://desktop")
    #expect(QuickLaunch.isAvailable(canOpen: { $0 == QuickLaunch.desktopURL }))
    #expect(!QuickLaunch.isAvailable(canOpen: { _ in false }))
}
