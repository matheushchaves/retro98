import CoreGraphics
import Testing
@testable import Retro98ShellCore

@Test func taskbarFrameCoversDockReservedArea() {
    let frame = TaskbarGeometry.frame(screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
                                      visibleFrame: CGRect(x: 0, y: 36, width: 1470, height: 887))
    #expect(frame == CGRect(x: 0, y: 0, width: 1470, height: 36))
}

@Test func taskbarFrameUsesMinimumHeight() {
    let frame = TaskbarGeometry.frame(screenFrame: CGRect(x: 0, y: 0, width: 1470, height: 956),
                                      visibleFrame: CGRect(x: 0, y: 0, width: 1470, height: 923))
    #expect(frame == CGRect(x: 0, y: 0, width: 1470, height: 28))
}

@Test func taskbarFrameFollowsScreenOrigin() {
    let frame = TaskbarGeometry.frame(screenFrame: CGRect(x: -1470, y: 100, width: 1470, height: 956),
                                      visibleFrame: CGRect(x: -1470, y: 140, width: 1470, height: 883))
    #expect(frame == CGRect(x: -1470, y: 100, width: 1470, height: 40))
}
