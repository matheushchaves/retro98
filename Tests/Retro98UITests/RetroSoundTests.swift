import AppKit
import Testing
@testable import Retro98UI

private let durations: [RetroSoundKind: TimeInterval] = [
    .startup: 0.86, .error: 0.32, .warning: 0.22, .emptyTrash: 0.40, .alert: 0.20,
]

private func bigEndian(_ data: Data, _ offset: Int, _ count: Int) -> Int {
    data[data.startIndex + offset ..< data.startIndex + offset + count].reduce(0) { $0 << 8 | Int($1) }
}

private func chunk(_ id: String, in data: Data) -> Int? {
    var offset = 12
    while offset + 8 <= data.count {
        if String(decoding: data[data.startIndex + offset ..< data.startIndex + offset + 4], as: UTF8.self) == id { return offset }
        offset += 8 + bigEndian(data, offset + 4, 4)
    }
    return nil
}

@Test func soundsHaveExactLengthAndStayQuiet() {
    for kind in RetroSoundKind.allCases {
        let samples = RetroSound.samples(kind)
        #expect(RetroSound.duration(kind) == durations[kind])
        #expect(samples.count == Int((durations[kind]! * 22050).rounded()), "\(kind)")
        let peak = samples.map { abs(Int($0)) }.max() ?? 0
        #expect(peak <= Int(0.31 * 32767), "\(kind) peak \(peak)")
        #expect(peak > 0, "\(kind) is silent")
    }
}

@Test func soundsAreDeterministicAndDistinct() {
    let all = RetroSoundKind.allCases.map(RetroSound.samples)
    #expect(all == RetroSoundKind.allCases.map(RetroSound.samples))
    for i in all.indices { for j in all.indices where j > i { #expect(all[i] != all[j]) } }
}

@Test func aiffHeaderIsValid() throws {
    #expect(RetroSound.extended80(22050) == [0x40, 0x0D, 0xAC, 0x44, 0, 0, 0, 0, 0, 0])
    #expect(RetroSound.extended80(44100) == [0x40, 0x0E, 0xAC, 0x44, 0, 0, 0, 0, 0, 0])
    let data = RetroSound.aiff(.alert)
    let frames = RetroSound.samples(.alert).count
    #expect(String(decoding: data.prefix(4), as: UTF8.self) == "FORM")
    #expect(bigEndian(data, 4, 4) == data.count - 8)
    #expect(String(decoding: data[8..<12], as: UTF8.self) == "AIFF")
    let comm = try #require(chunk("COMM", in: data))
    #expect(bigEndian(data, comm + 8, 2) == 1)
    #expect(bigEndian(data, comm + 10, 4) == frames)
    #expect(bigEndian(data, comm + 14, 2) == 16)
    #expect(Array(data[comm + 16 ..< comm + 26]) == RetroSound.extended80(22050))
    let ssnd = try #require(chunk("SSND", in: data))
    #expect(bigEndian(data, ssnd + 4, 4) == 8 + 2 * frames)
    let first = RetroSound.samples(.alert)[1]
    #expect(Int16(bitPattern: UInt16(bigEndian(data, ssnd + 16 + 2, 2))) == first)
}

@MainActor @Test func appKitReadsTheSound() throws {
    for kind in RetroSoundKind.allCases {
        let sound = try #require(NSSound(data: RetroSound.aiff(kind)), "\(kind)")
        #expect(abs(sound.duration - durations[kind]!) < 0.01, "\(kind) \(sound.duration)")
    }
}

@MainActor @Test func playRespectsSwitchButPreviewDoesNot() {
    var played: [Data] = []
    RetroSound.play(.error, isEnabled: { false }, output: { played.append($0) })
    #expect(played.isEmpty)
    RetroSound.play(.error, isEnabled: { true }, output: { played.append($0) })
    #expect(played == [RetroSound.aiff(.error)])
    RetroSound.preview(.warning, output: { played.append($0) })
    #expect(played.count == 2)
    #expect(!RetroSound.isEnabled())
}

@Test func messageBoxSounds() {
    #expect(MessageBoxIcon.error.sound == .error)
    #expect(MessageBoxIcon.warning.sound == .warning)
    #expect(MessageBoxIcon.info.sound == nil)
    #expect(MessageBoxIcon.question.sound == nil)
}

@Test func aiffFromSamplesIsTheSameFile() {
    for kind in RetroSoundKind.allCases {
        #expect(RetroSound.aiff(samples: RetroSound.samples(kind)) == RetroSound.aiff(kind), "\(kind)")
    }
}
