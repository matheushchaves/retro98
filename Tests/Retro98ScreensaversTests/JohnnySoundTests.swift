import AppKit
import Testing
@testable import Retro98Screensavers

private func peak(_ samples: [Int16]) -> Int { samples.map { abs(Int($0)) }.max() ?? 0 }

private let effects = JohnnySoundEffect.allCases.filter { $0 != .surf }

@Test func johnnySoundsAreAudibleButNeverLoud() {
    for effect in JohnnySoundEffect.allCases {
        let samples = JohnnySound.samples(effect)
        #expect(peak(samples) > 0, "\(effect) is silent")
        #expect(peak(samples) <= Int(0.25 * 32767), "\(effect) peak \(peak(samples))")
    }
}

@Test func johnnySoundsAreDeterministicAndDistinct() {
    let all = JohnnySoundEffect.allCases.map(JohnnySound.samples)
    #expect(all == JohnnySoundEffect.allCases.map(JohnnySound.samples))
    #expect(Set(all).count == all.count)
}

@Test func surfStaysUnderEveryEffect() {
    let surf = peak(JohnnySound.samples(.surf))
    for effect in effects {
        #expect(surf * 2 <= peak(JohnnySound.samples(effect)), "\(effect)")
    }
}

@Test func surfLoopsEveryEightSecondsWithoutAClick() {
    let surf = JohnnySound.samples(.surf)
    #expect(surf.count == 8 * 22050)
    let steps = zip(surf, surf.dropFirst()).map { abs(Int($0) - Int($1)) }
    let seam = abs(Int(surf[0]) - Int(surf[surf.count - 1]))
    #expect(seam <= steps.max()!, "seam \(seam)")
}

@Test func effectsEndInSilence() {
    for effect in effects {
        let samples = JohnnySound.samples(effect)
        #expect(abs(Int(samples.last!)) * 50 <= peak(samples), "\(effect) ends at \(samples.last!)")
    }
}

@MainActor @Test func appKitReadsJohnnySounds() throws {
    for effect in JohnnySoundEffect.allCases {
        let samples = JohnnySound.samples(effect)
        let sound = try #require(NSSound(data: JohnnySound.aiff(effect)), "\(effect)")
        #expect(abs(sound.duration - Double(samples.count) / 22050) < 0.01, "\(effect) \(sound.duration)")
    }
}
