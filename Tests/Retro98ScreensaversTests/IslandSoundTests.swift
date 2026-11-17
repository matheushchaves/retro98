import AppKit
import Testing
@testable import Retro98Screensavers

private func peak(_ samples: [Int16]) -> Int { samples.map { abs(Int($0)) }.max() ?? 0 }

private let effects = IslandSoundEffect.allCases.filter { $0 != .surf }

@Test func islandSoundsAreAudibleButNeverLoud() {
    for effect in IslandSoundEffect.allCases {
        let samples = IslandSound.samples(effect)
        #expect(peak(samples) > 0, "\(effect) is silent")
        #expect(peak(samples) <= Int(0.25 * 32767), "\(effect) peak \(peak(samples))")
    }
}

@Test func islandSoundsAreDeterministicAndDistinct() {
    let all = IslandSoundEffect.allCases.map(IslandSound.samples)
    #expect(all == IslandSoundEffect.allCases.map(IslandSound.samples))
    #expect(Set(all).count == all.count)
}

@Test func surfStaysUnderEveryEffect() {
    let surf = peak(IslandSound.samples(.surf))
    for effect in effects {
        #expect(surf * 2 <= peak(IslandSound.samples(effect)), "\(effect)")
    }
}

@Test func surfLoopsEveryEightSecondsWithoutAClick() {
    let surf = IslandSound.samples(.surf)
    #expect(surf.count == 8 * 22050)
    let steps = zip(surf, surf.dropFirst()).map { abs(Int($0) - Int($1)) }
    let seam = abs(Int(surf[0]) - Int(surf[surf.count - 1]))
    #expect(seam <= steps.max()!, "seam \(seam)")
}

@Test func effectsEndInSilence() {
    for effect in effects {
        let samples = IslandSound.samples(effect)
        #expect(abs(Int(samples.last!)) * 50 <= peak(samples), "\(effect) ends at \(samples.last!)")
    }
}

@MainActor @Test func appKitReadsIslandSounds() throws {
    for effect in IslandSoundEffect.allCases {
        let samples = IslandSound.samples(effect)
        let sound = try #require(NSSound(data: IslandSound.aiff(effect)), "\(effect)")
        #expect(abs(sound.duration - Double(samples.count) / 22050) < 0.01, "\(effect) \(sound.duration)")
    }
}
