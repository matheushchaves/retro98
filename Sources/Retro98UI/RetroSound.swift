import AppKit

public enum RetroSoundKind: String, CaseIterable, Sendable {
    case startup, error, warning, emptyTrash, alert
}

/// Retro98's own sounds, synthesized here (no recordings): square-wave chimes, a noise crumple for the
/// Recycle Bin and a sine "ding" for the macOS alert. 16-bit mono AIFF at 22,050 Hz.
public enum RetroSound {
    public static let sampleRate = 22_050
    static let attack: Double = 0.005

    private enum Wave { case square, sine, noise }

    /// One note: frequency 0 is silence.
    private struct Note {
        let frequency: Double
        let length: Double
        let decay: Double
    }

    private struct Recipe {
        let wave: Wave
        let peak: Double
        let notes: [Note]
    }

    private static func recipe(_ kind: RetroSoundKind) -> Recipe {
        switch kind {
        case .startup:
            Recipe(wave: .square, peak: 0.25, notes: [
                Note(frequency: 523.25, length: 0.12, decay: 6), Note(frequency: 659.25, length: 0.12, decay: 6),
                Note(frequency: 783.99, length: 0.12, decay: 6), Note(frequency: 1046.50, length: 0.50, decay: 3),
            ])
        case .error:
            Recipe(wave: .square, peak: 0.30, notes: [
                Note(frequency: 220.00, length: 0.10, decay: 8), Note(frequency: 164.81, length: 0.22, decay: 8),
            ])
        case .warning:
            Recipe(wave: .square, peak: 0.25, notes: [
                Note(frequency: 440, length: 0.07, decay: 10), Note(frequency: 0, length: 0.04, decay: 10),
                Note(frequency: 440, length: 0.11, decay: 10),
            ])
        case .emptyTrash:
            Recipe(wave: .noise, peak: 0.20, notes: [Note(frequency: 1, length: 0.40, decay: 9)])
        case .alert:
            Recipe(wave: .sine, peak: 0.30, notes: [
                Note(frequency: 880, length: 0.05, decay: 12), Note(frequency: 1318.51, length: 0.15, decay: 12),
            ])
        }
    }

    public static func duration(_ kind: RetroSoundKind) -> TimeInterval {
        (recipe(kind).notes.map(\.length).reduce(0, +) * 1000).rounded() / 1000
    }

    public static func samples(_ kind: RetroSoundKind) -> [Int16] {
        let recipe = recipe(kind)
        let rate = Double(sampleRate)
        let total = Int((duration(kind) * rate).rounded())
        var samples: [Int16] = []
        samples.reserveCapacity(total)
        var noise = NoiseSource(seed: 98)
        for note in recipe.notes {
            let count = Int((note.length * rate).rounded())
            for index in 0..<count {
                let t = Double(index) / rate
                let envelope = recipe.peak * min(1, t / attack) * exp(-note.decay * t)
                let value: Double = switch recipe.wave {
                case _ where note.frequency == 0: 0
                case .square: sin(2 * .pi * note.frequency * t) >= 0 ? 1 : -1
                case .sine: sin(2 * .pi * note.frequency * t)
                case .noise: noise.next()
                }
                samples.append(Int16((value * envelope * 32767).rounded()))
            }
        }
        // Rounding each note can leave a frame more or less than the whole: match the total exactly.
        if samples.count > total { samples.removeLast(samples.count - total) }
        while samples.count < total { samples.append(0) }
        return samples
    }

    /// Deterministic white noise, smoothed by averaging the last four values.
    private struct NoiseSource {
        var state: UInt32
        var recent: [Double] = []

        init(seed: UInt32) { state = seed }

        mutating func next() -> Double {
            state = state &* 1_103_515_245 &+ 12345
            recent.append(Double(state >> 16) / 32767.5 - 1)
            if recent.count > 4 { recent.removeFirst() }
            return recent.reduce(0, +) / Double(recent.count)
        }
    }

    // MARK: AIFF

    public static func aiff(_ kind: RetroSoundKind) -> Data {
        let samples = samples(kind)
        var comm = Data()
        comm.append(bigEndian: UInt16(1))
        comm.append(bigEndian: UInt32(samples.count))
        comm.append(bigEndian: UInt16(16))
        comm.append(contentsOf: extended80(Double(sampleRate)))
        var ssnd = Data()
        ssnd.append(bigEndian: UInt32(0))   // offset
        ssnd.append(bigEndian: UInt32(0))   // block size
        for sample in samples { ssnd.append(bigEndian: UInt16(bitPattern: sample)) }
        var body = Data("AIFF".utf8)
        for (id, chunk) in [("COMM", comm), ("SSND", ssnd)] {
            body.append(contentsOf: Data(id.utf8))
            body.append(bigEndian: UInt32(chunk.count))
            body.append(chunk)
        }
        var file = Data("FORM".utf8)
        file.append(bigEndian: UInt32(body.count))
        file.append(body)
        return file
    }

    /// The 80-bit IEEE extended float AIFF uses for its sample rate (positive whole numbers only).
    public static func extended80(_ value: Double) -> [UInt8] {
        guard value >= 1 else { return Array(repeating: 0, count: 10) }
        let whole = UInt64(value)
        let shift = whole.leadingZeroBitCount
        let exponent = UInt16(16383 + 63 - shift)
        let mantissa = whole << shift
        return [UInt8(exponent >> 8), UInt8(exponent & 0xFF)] + (0..<8).map { UInt8((mantissa >> (56 - 8 * $0)) & 0xFF) }
    }

    // MARK: Playing

    /// Whether the sounds are on; each app points this at the person's choice when it starts.
    @MainActor public static var isEnabled: () -> Bool = { false }
    /// Sounds being played, kept alive until they finish.
    @MainActor private static var playing: [NSSound] = []

    @MainActor public static func output(_ data: Data) {
        playing.removeAll { !$0.isPlaying }
        guard let sound = NSSound(data: data) else { return }
        playing.append(sound)
        sound.play()
    }

    @MainActor public static func play(_ kind: RetroSoundKind, isEnabled: () -> Bool = RetroSound.isEnabled,
                                       output: @MainActor (Data) -> Void = RetroSound.output) {
        guard isEnabled() else { return }
        output(aiff(kind))
    }

    /// Plays even when the sounds are off (the Control Panel's "Play" buttons).
    @MainActor public static func preview(_ kind: RetroSoundKind, output: @MainActor (Data) -> Void = RetroSound.output) {
        output(aiff(kind))
    }
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(bigEndian value: T) {
        Swift.withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }
}
