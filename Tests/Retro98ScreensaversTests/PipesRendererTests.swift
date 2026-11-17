import AppKit
import SceneKit
import Testing
@testable import Retro98Screensavers

@MainActor
@Test func pipesGrowSideBySide() {
    let pipes = PipesRenderer()
    pipes.startForTesting()
    let count = pipes.pipesForTesting.count
    pipes.tickForTesting()
    #expect(count >= 3)
    // Every pipe grew a step in that one tick.
    #expect(pipes.segmentCount == count)
}

@MainActor
@Test func pipesGrowingTogetherHaveDifferentColors() {
    let pipes = PipesRenderer()
    pipes.startForTesting()
    for _ in 0..<300 { pipes.tickForTesting() }
    let colors = pipes.pipesForTesting.map(\.color)
    #expect(colors.count >= 3)
    #expect(Set(colors).count == colors.count)
}

@MainActor
@Test func pipesTurnWithoutBeingBlocked() {
    let pipes = PipesRenderer()
    pipes.startForTesting()
    var freeTurns = 0, straightSteps = 0
    for _ in 0..<100 {
        let before = pipes.pipesForTesting
        let occupied = pipes.occupiedForTesting
        pipes.tickForTesting()
        for (old, new) in zip(before, pipes.pipesForTesting) where new.position == old.position.moved(by: new.direction) {
            let ahead = old.position.moved(by: old.direction)
            if new.direction == old.direction {
                straightSteps += 1
            } else if ahead.isValid && !occupied.contains(ahead) {
                freeTurns += 1
            }
        }
    }
    #expect(freeTurns > 0)
    // Still mostly straight runs, not a pipe that wiggles every step.
    #expect(straightSteps > freeTurns)
}

@MainActor
@Test func corneredPipeGivesWayToANewOne() {
    let pipes = PipesRenderer()
    pipes.startForTesting()
    pipes.blockPipeForTesting(at: 0)
    let cornered = pipes.pipesForTesting[0]
    pipes.tickForTesting()
    let replacement = pipes.pipesForTesting[0]
    #expect(replacement.position != cornered.position)
    #expect(!pipes.pipesForTesting.dropFirst().map(\.color).contains(replacement.color))
}

@MainActor
@Test func pipesStartOverWhenTheGridIsFull() throws {
    let pipes = PipesRenderer()
    pipes.startForTesting()
    for _ in 0..<5 { pipes.tickForTesting() }
    pipes.fillGridTo(fraction: 0.8)
    pipes.tickForTesting()
    let scene = try #require(pipes.sceneForTesting)
    #expect(pipes.segmentCount == 0)
    #expect(pipes.occupiedForTesting.count == pipes.pipesForTesting.count)
    #expect(scene.rootNode.childNodes.allSatisfy { $0.camera != nil || $0.light != nil })
}

@MainActor
@Test func pipeSegmentsRunFromGridPointToGridPoint() throws {
    let pipes = PipesRenderer()
    pipes.startForTesting()
    for _ in 0..<60 { pipes.tickForTesting() }
    let scene = try #require(pipes.sceneForTesting)
    let segments = scene.rootNode.childNodes.filter { $0.geometry is SCNCylinder }
    #expect(!segments.isEmpty)
    for node in segments {
        let half = try #require(node.geometry as? SCNCylinder).height / 2
        let axis = node.convertVector(SCNVector3(0, half, 0), to: nil)
        for end in [node.position + axis, node.position - axis] {
            #expect(isGridPoint(end), "segment end \(end) is off the grid")
        }
    }
}

private func + (a: SCNVector3, b: SCNVector3) -> SCNVector3 { SCNVector3(a.x + b.x, a.y + b.y, a.z + b.z) }
private func - (a: SCNVector3, b: SCNVector3) -> SCNVector3 { SCNVector3(a.x - b.x, a.y - b.y, a.z - b.z) }

private func isGridPoint(_ v: SCNVector3) -> Bool {
    [v.x, v.y, v.z].allSatisfy { abs($0 - $0.rounded()) < 0.001 }
}
