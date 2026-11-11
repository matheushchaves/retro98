import CoreGraphics
import Testing
@testable import Retro98ShellCore

private let screen = CGRect(x: 0, y: 0, width: 1470, height: 956)

@Test func maximizedWindowStopsAtTheTaskbar() {
    #expect(WorkAreaGuard.adjustedSize(window: CGRect(x: 0, y: 34, width: 1470, height: 922), screen: screen, taskbarHeight: 28)
            == CGSize(width: 1470, height: 894))
}

@Test func windowsPastTheBottomAreClampedToo() {
    #expect(WorkAreaGuard.adjustedSize(window: CGRect(x: 100, y: 500, width: 600, height: 500), screen: screen, taskbarHeight: 28)
            == CGSize(width: 600, height: 428))
}

@Test func leavesWindowsAwayFromTheBottomAlone() {
    #expect(WorkAreaGuard.adjustedSize(window: CGRect(x: 100, y: 100, width: 600, height: 400), screen: screen, taskbarHeight: 28) == nil)
}

@Test func doesNotTouchWindowsAlreadyAboveTheTaskbar() {
    #expect(WorkAreaGuard.adjustedSize(window: CGRect(x: 0, y: 34, width: 1470, height: 894), screen: screen, taskbarHeight: 28) == nil)
}

@Test func ignoresOtherScreens() {
    #expect(WorkAreaGuard.adjustedSize(window: CGRect(x: 1470, y: 0, width: 800, height: 956), screen: screen, taskbarHeight: 28) == nil)
}

@Test func windowEntirelyBehindTheTaskbarIsLeftAlone() {
    #expect(WorkAreaGuard.adjustedSize(window: CGRect(x: 0, y: 940, width: 300, height: 16), screen: screen, taskbarHeight: 28) == nil)
}

@Test func fullScreenWindowsAreLeftAlone() {
    #expect(WorkAreaGuard.adjustedSize(window: CGRect(x: 0, y: 0, width: 1470, height: 956), screen: screen,
                                       taskbarHeight: 28, isFullScreen: true) == nil)
}

@Test func onlyCreatedAndResizedWindowsAreChecked() {
    #expect(WorkAreaGuard.shouldCheck(notification: "AXWindowCreated"))
    #expect(WorkAreaGuard.shouldCheck(notification: "AXWindowResized"))
    #expect(!WorkAreaGuard.shouldCheck(notification: "AXWindowMoved"))   // never fight a drag
    #expect(!WorkAreaGuard.shouldCheck(notification: "AXTitleChanged"))
}
