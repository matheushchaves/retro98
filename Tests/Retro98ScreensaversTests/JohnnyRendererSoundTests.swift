import AppKit
import Testing
@testable import Retro98Screensavers

/// Records what Johnny would play, so the tests never touch the speakers.
@MainActor
private final class SoundRecorder: JohnnySoundOutput {
    private(set) var played: [JohnnySoundEffect] = []
    private(set) var looped: [JohnnySoundEffect] = []
    private(set) var stops = 0

    func play(_ effect: JohnnySoundEffect, loops: Bool) {
        played.append(effect)
        if loops { looped.append(effect) }
    }

    func stopAll() { stops += 1 }
}

/// What the renderer plays while `action` runs.
@MainActor
private func sounds(of recorder: SoundRecorder, during action: () -> Void) -> [JohnnySoundEffect] {
    let before = recorder.played.count
    action()
    return Array(recorder.played.dropFirst(before))
}

@MainActor @Test func johnnyStartsTheSurfOnALoopAndStopsEverything() {
    let recorder = SoundRecorder()
    let renderer = JohnnyRenderer(output: recorder)
    renderer.start(in: NSView(frame: CGRect(x: 0, y: 0, width: 320, height: 180)))
    #expect(recorder.played == [.surf])
    #expect(recorder.looped == [.surf])
    renderer.stop()
    #expect(recorder.stops == 1)
}

@MainActor @Test func eachJohnnySceneMakesItsOwnSoundAsItBegins() {
    let recorder = SoundRecorder()
    let renderer = JohnnyRenderer(output: recorder)
    renderer.startSceneForTesting()
    var heard: [JohnnySceneKind: [JohnnySoundEffect]] = [:]
    for _ in 0..<6 {
        let effects = sounds(of: recorder) { renderer.advanceSceneForTesting() }
        heard[renderer.currentSceneKind, default: []] += effects
    }
    #expect(heard == [.sleeping: [.snore], .fishing: [], .shark: [.shark], .idle: [], .bird: [.gull],
                      .stretching: [.yawn]])
    #expect(recorder.looped.isEmpty)
}

@MainActor @Test func johnnySnoresOncePerRiseOfTheZs() {
    let recorder = SoundRecorder()
    let renderer = JohnnyRenderer(output: recorder)
    renderer.startSceneForTesting()
    renderer.advanceSceneForTesting()
    #expect(renderer.currentSceneKind == .sleeping)
    #expect(sounds(of: recorder) { for _ in 0..<23 { renderer.tickFrameForTesting() } }.isEmpty)
    #expect(sounds(of: recorder) { renderer.tickFrameForTesting() } == [.snore])
    #expect(sounds(of: recorder) { for _ in 0..<24 { renderer.tickFrameForTesting() } } == [.snore])
}

@MainActor @Test func theFloatPlopsWhenTheFishBites() {
    let recorder = SoundRecorder()
    let renderer = JohnnyRenderer(output: recorder)
    renderer.startSceneForTesting()
    renderer.advanceSceneForTesting()
    renderer.advanceSceneForTesting()
    #expect(renderer.currentSceneKind == .fishing)
    var bites: [[JohnnySoundEffect]] = []
    for _ in 0..<99 {
        let before = renderer.currentFrame
        let effects = sounds(of: recorder) { renderer.tickFrameForTesting() }
        if renderer.currentFrame != before, renderer.currentFrame == 1 { bites.append(effects) }
        else { #expect(effects.isEmpty, "frame \(renderer.currentFrame)") }
    }
    #expect(bites == [[.plop], [.plop]])
}

@MainActor @Test func theSoundChoiceDecidesWhetherJohnnyHasSpeakers() {
    #expect(!JohnnyRenderer().hasSoundForTesting)
    #expect(!JohnnyRenderer(sound: false).hasSoundForTesting)
    #expect(JohnnyRenderer(sound: true).hasSoundForTesting)
}
