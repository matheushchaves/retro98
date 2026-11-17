import AppKit
import Retro98UI

/// The desert island's sounds: one effect per scene and the surf behind them.
enum IslandSoundEffect: CaseIterable, Sendable {
    case plop, snore, shark, gull, yawn, surf
}

/// The island's sounds, synthesized here like `RetroSound` (no recordings, no known tunes): 16-bit mono at 22,050 Hz.
enum IslandSound {
    static let rate = Double(RetroSound.sampleRate)
    /// The surf loops for as long as the screensaver runs; one pass lasts this long.
    static let surfSeconds = 8

    static func aiff(_ effect: IslandSoundEffect) -> Data { RetroSound.aiff(samples: samples(effect)) }

    static func samples(_ effect: IslandSoundEffect) -> [Int16] {
        let wave: [Double] = switch effect {
        case .plop: plop()
        case .snore: snore()
        case .shark: shark()
        case .gull: gull()
        case .yawn: yawn()
        case .surf: surf()
        }
        // The effects fade out so they never end on a click; the surf loops instead.
        return quantized(effect == .surf ? wave : fadedOut(wave), peak: peak(effect))
    }

    /// Loudest sample of each sound, as a fraction of full scale: the surf stays well under the effects.
    private static func peak(_ effect: IslandSoundEffect) -> Double {
        switch effect {
        case .plop, .shark: 0.20
        case .yawn: 0.18
        case .snore, .gull: 0.16
        case .surf: 0.05
        }
    }

    // MARK: Effects

    /// The float bobbing under: a sine that drops from 900 to 260 Hz, with a splash of noise at the start.
    private static func plop() -> [Double] {
        var osc = Oscillator()
        var noise = Noise(state: 7)
        return render(0.18) { t in
            let body = sin(osc.next(260 + 640 * exp(-t / 0.025))) * attack(t, 0.002) * exp(-t / 0.05)
            return body + 0.3 * noise.next() * exp(-t / 0.008)
        }
    }

    /// A slow inhale through the nose: a low buzz that flutters 28 times a second, over breathy noise.
    private static func snore() -> [Double] {
        var osc = Oscillator()
        var noise = Noise(state: 11)
        var breath = LowPass(amount: 0.08)
        let length = 1.4
        return render(length) { t in
            let swell = pow(sin(.pi * t / length), 1.5)
            let flutter = 0.55 + 0.45 * abs(sin(.pi * 28 * t))
            let buzz = voice(osc.next(85 + 10 * t / length), [1, 0.7, 0.5, 0.3, 0.2])
            return swell * (buzz * flutter + 4 * breath.next(noise.next()))
        }
    }

    /// Suspense under the water: three low notes (E, G, then a long D) in round voices.
    private static func shark() -> [Double] {
        let notes: [(frequency: Double, start: Double, length: Double)] = [
            (82.41, 0, 0.4), (98.00, 0.45, 0.4), (73.42, 0.9, 0.7),
        ]
        return render(1.6) { t in
            notes.reduce(0) { sum, note in
                let local = t - note.start
                guard local >= 0, local < note.length else { return sum }
                let envelope = attack(local, 0.02) * exp(-local * 2.5) * attack(note.length - local, 0.04)
                return sum + envelope * voice(2 * .pi * note.frequency * local, [1, 0.6, 0.4, 0.25])
            }
        }
    }

    /// Two quick, nasal cries: each leaps to 1,700 Hz and slides down to 1,050 Hz, with a little rasp.
    private static func gull() -> [Double] {
        var osc = Oscillator()
        var noise = Noise(state: 23)
        let calls: [(start: Double, length: Double)] = [(0, 0.2), (0.28, 0.25)]
        return render(0.55) { t in
            let rasp = noise.next()
            guard let call = calls.first(where: { t >= $0.start && t < $0.start + $0.length }) else { return 0 }
            let x = (t - call.start) / call.length
            let frequency = x < 0.2 ? 1300 + 400 * x / 0.2 : 1700 - 650 * (x - 0.2) / 0.8
            let envelope = attack(x, 0.05) * attack(1 - x, 0.15)
            return envelope * (voice(osc.next(frequency), [1, 0.5, 0.3]) + 0.25 * rasp)
        }
    }

    /// A big yawn: a breathy voice glides up from 180 to 330 Hz, then sighs down to 120 Hz, wobbling at the end.
    private static func yawn() -> [Double] {
        var osc = Oscillator()
        var noise = Noise(state: 31)
        var breath = LowPass(amount: 0.2)
        let length = 1.5
        return render(length) { t in
            let x = t / length
            let glide = x < 0.4 ? 180 + 150 * x / 0.4 : 330 - 210 * (x - 0.4) / 0.6
            let wobble = x > 0.5 ? 1 + 0.025 * sin(2 * .pi * 5 * t) : 1
            let swell = pow(sin(.pi * x), 0.8)
            return swell * (voice(osc.next(glide * wobble), [1, 0.6, 0.35, 0.2]) + 1.2 * breath.next(noise.next()))
        }
    }

    /// Waves on the beach: rumbling noise that swells twice a pass. The pass's tail is blended into its head,
    /// so the loop never clicks.
    private static func surf() -> [Double] {
        let count = surfSeconds * Int(rate)
        let blend = Int(rate / 2)
        var noise = Noise(state: 98)
        var rumble = LowPass(amount: 0.03)
        var wash = LowPass(amount: 0.25)
        let raw: [Double] = (0..<(count + blend)).map { index in
            let white = noise.next()
            let swell = 0.35 + 0.65 * pow(sin(.pi * Double(index) / rate / 4), 2)
            return swell * (3 * rumble.next(white) + 0.4 * swell * wash.next(white))
        }
        return (0..<count).map { index in
            guard index < blend else { return raw[index] }
            let mix = Double(index) / Double(blend)
            return raw[index] * mix + raw[count + index] * (1 - mix)
        }
    }

    // MARK: Building blocks

    /// `seconds` of samples, each `value(t)` at its time.
    private static func render(_ seconds: Double, _ value: (Double) -> Double) -> [Double] {
        (0..<Int((seconds * rate).rounded())).map { value(Double($0) / rate) }
    }

    /// Ramps from 0 to 1 over `length`, then holds.
    private static func attack(_ t: Double, _ length: Double) -> Double { min(1, max(0, t / length)) }

    /// A voice from its harmonics' loudness: the first is the fundamental.
    private static func voice(_ phase: Double, _ harmonics: [Double]) -> Double {
        harmonics.enumerated().reduce(0) { $0 + $1.element * sin(Double($1.offset + 1) * phase) }
    }

    /// Ramps the last 30 ms down to silence.
    private static func fadedOut(_ wave: [Double]) -> [Double] {
        let tail = rate * 0.03
        return wave.enumerated().map { index, value in value * min(1, Double(wave.count - 1 - index) / tail) }
    }

    /// Scales `wave` so its loudest sample sits at `peak` of full scale.
    private static func quantized(_ wave: [Double], peak: Double) -> [Int16] {
        let loudest = wave.map(abs).max() ?? 0
        guard loudest > 0 else { return wave.map { _ in 0 } }
        return wave.map { Int16(($0 / loudest * peak * 32767).rounded()) }
    }

    /// A phase advanced by each sample's frequency, so glides stay smooth.
    private struct Oscillator {
        var phase = 0.0

        mutating func next(_ frequency: Double) -> Double {
            defer { phase = (phase + 2 * .pi * frequency / IslandSound.rate).truncatingRemainder(dividingBy: 2 * .pi) }
            return phase
        }
    }

    /// Deterministic white noise in -1..<1, with its own generator so the island never shifts Retro98's sounds.
    private struct Noise {
        var state: UInt32

        mutating func next() -> Double {
            state = state &* 1_664_525 &+ 1_013_904_223
            return Double(state >> 8) / Double(1 << 23) - 1
        }
    }

    /// One-pole low-pass filter: smaller amounts keep only the lower rumble.
    private struct LowPass {
        let amount: Double
        var value = 0.0

        mutating func next(_ input: Double) -> Double {
            value += amount * (input - value)
            return value
        }
    }
}

// MARK: - Output

/// Where the island's sounds go: the speakers, or a recorder in the tests.
@MainActor
protocol IslandSoundOutput: AnyObject {
    func play(_ effect: IslandSoundEffect, loops: Bool)
    func stopAll()
}

/// Plays through the Mac's speakers, keeping each sound alive until it ends or is stopped.
@MainActor
final class IslandSpeaker: IslandSoundOutput {
    private var files: [IslandSoundEffect: Data] = [:]
    private var playing: [NSSound] = []

    func play(_ effect: IslandSoundEffect, loops: Bool) {
        playing.removeAll { !$0.isPlaying }
        let data = files[effect] ?? IslandSound.aiff(effect)
        files[effect] = data
        guard let sound = NSSound(data: data) else { return }
        sound.loops = loops
        playing.append(sound)
        sound.play()
    }

    func stopAll() {
        playing.forEach { $0.stop() }
        playing.removeAll()
    }
}
