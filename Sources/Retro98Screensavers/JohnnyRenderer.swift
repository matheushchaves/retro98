import AppKit

// MARK: - Public renderer

/// Johnny Castaway screensaver — pixel art original, não baseado em assets da Sierra.
/// Este arquivo cuida do roteiro (cenas, frames, timer); a arte vive em `JohnnyScene`.
@MainActor
public final class JohnnyRenderer: ScreensaverRenderer {
    private var johnnyView: JohnnyView?
    private var timer: Timer?

    public private(set) var currentSceneKind: JohnnySceneKind = .idle
    public private(set) var currentFrame: Int = 0
    private var sceneElapsed: TimeInterval = 0
    private var frameElapsed: TimeInterval = 0
    /// Ticks desde o início da cena / do protetor: movem ondas, nuvens e bichos.
    private var sceneTick = 0
    private var worldTick = 0
    private let tickInterval: TimeInterval = 1 / TimeInterval(JohnnyClock.ticksPerSecond)
    private static let sceneSequence: [JohnnySceneKind] = [
        .idle, .sleeping, .fishing, .shark, .idle, .bird, .stretching
    ]
    private var sceneIndex = 0
    /// Onde tocam os sons da ilha: nil quando o protetor está sem som.
    private let sound: (any JohnnySoundOutput)?

    public convenience init(sound: Bool = false) {
        self.init(output: sound ? JohnnySpeaker() : nil)
    }

    init(output: (any JohnnySoundOutput)?) {
        sound = output
    }

    public func start(in view: NSView) {
        let jv = JohnnyView(frame: view.bounds)
        jv.autoresizingMask = [.width, .height]
        jv.renderer = self
        view.addSubview(jv)
        johnnyView = jv
        startSceneForTesting()
        sound?.play(.surf, loops: true)
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickInternal() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        sound?.stopAll()
        johnnyView?.removeFromSuperview()
        johnnyView = nil
    }

    public func startSceneForTesting() {
        sceneIndex = 0
        currentSceneKind = Self.sceneSequence[0]
        currentFrame = 0
        sceneElapsed = 0
        frameElapsed = 0
        sceneTick = 0
    }

    public func advanceSceneForTesting() {
        sceneIndex = (sceneIndex + 1) % Self.sceneSequence.count
        currentSceneKind = Self.sceneSequence[sceneIndex]
        currentFrame = 0
        sceneElapsed = 0
        frameElapsed = 0
        sceneTick = 0
        play(currentSceneKind.openingSound)
    }

    public func tickFrameForTesting() { tickInternal() }

    var hasSoundForTesting: Bool { sound != nil }

    public func renderFrameForTesting(size: CGSize) -> NSImage? {
        let img = NSImage(size: size)
        img.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else { img.unlockFocus(); return nil }
        JohnnyScene.draw(currentSceneKind, clock: clock, in: ctx, size: size)
        img.unlockFocus()
        return img
    }

    var clock: JohnnyClock {
        JohnnyClock(frame: currentFrame, sceneTick: sceneTick, worldTick: worldTick)
    }

    private func tickInternal() {
        frameElapsed += tickInterval
        sceneElapsed += tickInterval
        sceneTick += 1
        worldTick += 1
        let scene = currentSceneKind
        if scene == .sleeping, sceneTick % JohnnyActing.snoreCycleTicks == 0 { play(.snore) }
        if frameElapsed >= scene.frameDuration {
            frameElapsed = 0
            currentFrame = (currentFrame + 1) % scene.frameCount
            // O frame 1 da pesca é a mordida: a boia afunda.
            if scene == .fishing, currentFrame == 1 { play(.plop) }
        }
        if sceneElapsed >= scene.sceneDuration {
            advanceSceneForTesting()
        }
        // O fundo (ondas, nuvens, folhas) anima a cada tick, não só na troca de frame.
        johnnyView?.needsDisplay = true
    }

    private func play(_ effect: JohnnySoundEffect?) {
        guard let effect else { return }
        sound?.play(effect, loops: false)
    }
}

// MARK: - Scene kind

public enum JohnnySceneKind: CaseIterable {
    case idle, sleeping, fishing, shark, bird, stretching

    var frameCount: Int {
        switch self {
        case .idle: 2; case .sleeping: 2; case .fishing: 3
        case .shark: 4; case .bird: 3; case .stretching: 2
        }
    }
    var frameDuration: TimeInterval {
        switch self {
        case .idle: 1.5; case .sleeping: 3.0; case .fishing: 2.0
        case .shark: 0.8; case .bird: 0.6; case .stretching: 1.0
        }
    }
    var sceneDuration: TimeInterval {
        switch self {
        case .idle: 7; case .sleeping: 10; case .fishing: 10
        case .shark: 5; case .bird: 4; case .stretching: 3
        }
    }
    /// O efeito que toca quando a cena começa (a pesca espera a mordida).
    var openingSound: JohnnySoundEffect? {
        switch self {
        case .sleeping: .snore; case .shark: .shark; case .bird: .gull; case .stretching: .yawn
        case .idle, .fishing: nil
        }
    }
}

// MARK: - View

final class JohnnyView: NSView {
    weak var renderer: JohnnyRenderer?

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let r = renderer else { return }
        JohnnyScene.draw(r.currentSceneKind, clock: r.clock, in: ctx, size: bounds.size)
    }
}
