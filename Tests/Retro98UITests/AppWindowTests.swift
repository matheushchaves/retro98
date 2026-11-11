import AppKit
import Testing
@testable import Retro98UI

@Test func maximizedFrameLeavesTheTaskbar() {
    #expect(WindowGeometry.maximizedFrame(visibleFrame: CGRect(x: 0, y: 0, width: 1470, height: 922), taskbarHeight: 28)
            == CGRect(x: 0, y: 28, width: 1470, height: 894))
}

@Test func edgesAndCorners() {
    let size = CGSize(width: 680, height: 480)
    #expect(WindowGeometry.edge(at: CGPoint(x: 1, y: 200), windowSize: size) == .left)
    #expect(WindowGeometry.edge(at: CGPoint(x: 678, y: 478), windowSize: size) == [.right, .bottom])
    #expect(WindowGeometry.edge(at: CGPoint(x: 300, y: 10), windowSize: size) == nil)
    #expect(WindowGeometry.edge(at: CGPoint(x: 2, y: 8), windowSize: size) == [.left, .top])
    #expect(WindowGeometry.edge(at: CGPoint(x: 300, y: 1), windowSize: size) == .top)
}

@Test func resizeFromLeftMovesOriginAndKeepsMinimum() {
    let frame = WindowGeometry.resized(CGRect(x: 100, y: 100, width: 400, height: 300), edge: .left,
                                       delta: CGVector(dx: 200, dy: 0), minimumSize: WindowGeometry.minimumSize)
    #expect(frame == CGRect(x: 180, y: 100, width: 320, height: 300))
}

@Test func resizeFromTopGrowsUp() {
    let frame = WindowGeometry.resized(CGRect(x: 100, y: 100, width: 400, height: 300), edge: .top,
                                       delta: CGVector(dx: 0, dy: 50), minimumSize: WindowGeometry.minimumSize)
    #expect(frame == CGRect(x: 100, y: 100, width: 400, height: 350))
}

@Test func resizeFromBottomRightCorner() {
    let frame = WindowGeometry.resized(CGRect(x: 100, y: 100, width: 400, height: 300), edge: [.right, .bottom],
                                       delta: CGVector(dx: 30, dy: -20), minimumSize: WindowGeometry.minimumSize)
    #expect(frame == CGRect(x: 100, y: 80, width: 430, height: 320))
}

@MainActor @Test func maximizeAndRestoreRoundTrip() {
    let window = RetroAppWindow(title: "Teste", icon: Icons.folder, contentSize: CGSize(width: 400, height: 300))
    window.setFrame(CGRect(x: 50, y: 60, width: 500, height: 400), display: false)
    window.taskbarHeight = { 28 }
    window.toggleMaximize()
    #expect(window.isMaximized)
    window.toggleMaximize()
    #expect(!window.isMaximized)
    #expect(window.frame == CGRect(x: 50, y: 60, width: 500, height: 400))
}

@MainActor @Test func contentSitsInsideFrameAndBelowTitle() {
    let window = RetroAppWindow(title: "Teste", icon: Icons.folder, contentSize: CGSize(width: 400, height: 300))
    #expect(window.contentContainer.frame.minY == WindowGeometry.border + WindowGeometry.titleHeight + 1)
    #expect(window.contentContainer.frame.width == 400)
}
