import AppKit

/// Johnny Castaway screensaver: a small island with animated scenes drawn with Core Graphics.
@MainActor
public final class JohnnyRenderer: ScreensaverRenderer {
    private var johnnyView: JohnnyView?
    private var timer: Timer?

    // MARK: - Test seams
    public private(set) var currentSceneKind: JohnnySceneKind = .idle
    public private(set) var currentFrame: Int = 0
    private var sceneElapsed: TimeInterval = 0
    private var frameElapsed: TimeInterval = 0
    private let tickInterval: TimeInterval = 0.1
    private static let sceneSequence: [JohnnySceneKind] = [
        .idle, .sleeping, .fishing, .shark, .idle, .bird, .stretching
    ]
    private var sceneIndex = 0

    public init() {}

    public func start(in view: NSView) {
        let jv = JohnnyView(frame: view.bounds)
        jv.autoresizingMask = [.width, .height]
        jv.renderer = self
        view.addSubview(jv)
        johnnyView = jv
        startSceneForTesting()
        timer = Timer.scheduledTimer(withTimeInterval: tickInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tickInternal() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
        johnnyView?.removeFromSuperview()
        johnnyView = nil
    }

    public func startSceneForTesting() {
        sceneIndex = 0
        currentSceneKind = Self.sceneSequence[0]
        currentFrame = 0
        sceneElapsed = 0
        frameElapsed = 0
    }

    public func advanceSceneForTesting() {
        sceneIndex = (sceneIndex + 1) % Self.sceneSequence.count
        currentSceneKind = Self.sceneSequence[sceneIndex]
        currentFrame = 0
        sceneElapsed = 0
        frameElapsed = 0
    }

    public func tickFrameForTesting() { tickInternal() }

    public func renderFrameForTesting(size: CGSize) -> NSImage? {
        let img = NSImage(size: size)
        img.lockFocus()
        guard let ctx = NSGraphicsContext.current?.cgContext else { img.unlockFocus(); return nil }
        JohnnyView.drawScene(currentSceneKind, frame: currentFrame, in: ctx, size: size)
        img.unlockFocus()
        return img
    }

    private func tickInternal() {
        frameElapsed += tickInterval
        sceneElapsed += tickInterval

        let scene = currentSceneKind
        if frameElapsed >= scene.frameDuration {
            frameElapsed = 0
            currentFrame = (currentFrame + 1) % scene.frameCount
            johnnyView?.needsDisplay = true
        }
        if sceneElapsed >= scene.sceneDuration {
            advanceSceneForTesting()
            johnnyView?.needsDisplay = true
        }
    }
}

// MARK: - Scene kind

public enum JohnnySceneKind: CaseIterable {
    case idle, sleeping, fishing, shark, bird, stretching

    var frameCount: Int {
        switch self { case .idle: 2; case .sleeping: 2; case .fishing: 3;
                      case .shark: 4; case .bird: 3; case .stretching: 2 }
    }
    var frameDuration: TimeInterval {
        switch self { case .idle: 1.5; case .sleeping: 3.0; case .fishing: 2.0;
                      case .shark: 0.8; case .bird: 0.6; case .stretching: 1.0 }
    }
    var sceneDuration: TimeInterval {
        switch self { case .idle: 7; case .sleeping: 10; case .fishing: 10;
                      case .shark: 5; case .bird: 4; case .stretching: 3 }
    }
}

// MARK: - Drawing

final class JohnnyView: NSView {
    weak var renderer: JohnnyRenderer?

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext, let r = renderer else { return }
        JohnnyView.drawScene(r.currentSceneKind, frame: r.currentFrame, in: ctx, size: bounds.size)
    }

    static func drawScene(_ scene: JohnnySceneKind, frame: Int, in ctx: CGContext, size: CGSize) {
        // Ocean background
        ctx.setFillColor(NSColor(deviceRed: 0, green: 0.3, blue: 0.5, alpha: 1).cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))

        let cx = size.width / 2
        let cy = size.height * 0.52
        let islandR = min(size.width, size.height) * 0.18

        // Island
        ctx.setFillColor(NSColor(deviceRed: 0.85, green: 0.75, blue: 0.5, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - islandR, y: cy - islandR * 0.4,
                                    width: islandR * 2, height: islandR * 0.8))

        // Rock
        ctx.setFillColor(NSColor(deviceRed: 0.5, green: 0.5, blue: 0.5, alpha: 1).cgColor)
        ctx.fillEllipse(in: CGRect(x: cx - islandR * 0.6, y: cy - islandR * 0.1,
                                    width: islandR * 0.3, height: islandR * 0.2))

        // Palm tree
        drawPalmTree(ctx: ctx, cx: cx + islandR * 0.1, cy: cy, scale: islandR)

        // Johnny
        drawJohnny(scene: scene, frame: frame, ctx: ctx, cx: cx - islandR * 0.2, cy: cy, scale: islandR)

        // Scene-specific extras
        switch scene {
        case .shark:
            let progress = CGFloat(frame) / 4.0
            let finX = size.width * (progress * 1.4 - 0.2)
            drawSharkFin(ctx: ctx, x: finX, y: cy + islandR * 0.5, scale: islandR)
        case .bird:
            let progress = CGFloat(frame) / 3.0
            let birdX = size.width * (progress * 1.3 - 0.15)
            drawBird(ctx: ctx, x: birdX, y: cy - islandR * 1.2, frame: frame, scale: islandR)
        default:
            break
        }
    }

    private static func drawPalmTree(ctx: CGContext, cx: CGFloat, cy: CGFloat, scale: CGFloat) {
        // Trunk
        ctx.setStrokeColor(NSColor(deviceRed: 0.5, green: 0.35, blue: 0.1, alpha: 1).cgColor)
        ctx.setLineWidth(scale * 0.08)
        ctx.move(to: CGPoint(x: cx, y: cy))
        ctx.addCurve(to: CGPoint(x: cx + scale * 0.15, y: cy - scale * 1.2),
                     control1: CGPoint(x: cx - scale * 0.1, y: cy - scale * 0.5),
                     control2: CGPoint(x: cx + scale * 0.2, y: cy - scale * 0.9))
        ctx.strokePath()

        // Fronds
        let topX = cx + scale * 0.15
        let topY = cy - scale * 1.2
        ctx.setStrokeColor(NSColor(deviceRed: 0.1, green: 0.5, blue: 0.1, alpha: 1).cgColor)
        ctx.setLineWidth(scale * 0.05)
        let fronds: [(CGFloat, CGFloat)] = [(0.5, -0.3), (-0.5, -0.2), (0.1, -0.5), (-0.2, 0.1), (0.4, 0.05)]
        for (dx, dy) in fronds {
            ctx.move(to: CGPoint(x: topX, y: topY))
            ctx.addLine(to: CGPoint(x: topX + scale * dx, y: topY + scale * dy))
            ctx.strokePath()
        }
    }

    private static func drawJohnny(scene: JohnnySceneKind, frame: Int, ctx: CGContext,
                                   cx: CGFloat, cy: CGFloat, scale: CGFloat) {
        let s = scale * 0.12
        let bodyColor = NSColor(deviceRed: 0.9, green: 0.7, blue: 0.5, alpha: 1).cgColor
        let shirtColor = NSColor(deviceRed: 0.2, green: 0.3, blue: 0.6, alpha: 1).cgColor

        switch scene {
        case .sleeping:
            // Lying down
            ctx.setFillColor(shirtColor)
            ctx.fill(CGRect(x: cx - s * 1.5, y: cy - s * 0.5, width: s * 3, height: s))
            ctx.setFillColor(bodyColor)
            ctx.fillEllipse(in: CGRect(x: cx + s * 1.2, y: cy - s * 0.3, width: s * 0.8, height: s * 0.8))
            // Zzz
            if frame == 1 {
                let attrs: [NSAttributedString.Key: Any] = [
                    .font: NSFont.systemFont(ofSize: s * 1.2),
                    .foregroundColor: NSColor.white
                ]
                NSAttributedString(string: "z z Z", attributes: attrs)
                    .draw(at: CGPoint(x: cx + s * 1.5, y: cy - s * 1.5))
            }
        case .stretching:
            // Arms up or down
            ctx.setFillColor(shirtColor)
            ctx.fill(CGRect(x: cx - s * 0.5, y: cy - s * 1.5, width: s, height: s * 1.5))
            ctx.setFillColor(bodyColor)
            ctx.fillEllipse(in: CGRect(x: cx - s * 0.4, y: cy - s * 2.3, width: s * 0.8, height: s * 0.8))
            // Arms
            let armY = frame == 0 ? cy - s * 2 : cy - s * 1.0
            ctx.setStrokeColor(bodyColor)
            ctx.setLineWidth(s * 0.3)
            ctx.move(to: CGPoint(x: cx - s, y: armY))
            ctx.addLine(to: CGPoint(x: cx + s, y: armY))
            ctx.strokePath()
        default:
            // Standing: body
            ctx.setFillColor(shirtColor)
            ctx.fill(CGRect(x: cx - s * 0.5, y: cy - s * 1.5, width: s, height: s * 1.5))
            ctx.setFillColor(bodyColor)
            ctx.fillEllipse(in: CGRect(x: cx - s * 0.4, y: cy - s * 2.3, width: s * 0.8, height: s * 0.8))
            // Legs
            ctx.setFillColor(NSColor(deviceRed: 0.2, green: 0.1, blue: 0.0, alpha: 1).cgColor)
            let legOffset = frame == 0 ? s * 0.2 : -s * 0.2
            ctx.fill(CGRect(x: cx - s * 0.5 + legOffset, y: cy - s * 0.1, width: s * 0.4, height: s * 0.6))
            ctx.fill(CGRect(x: cx + s * 0.1 - legOffset, y: cy - s * 0.1, width: s * 0.4, height: s * 0.6))
            if scene == .fishing {
                // Fishing rod
                ctx.setStrokeColor(NSColor(deviceRed: 0.6, green: 0.4, blue: 0.1, alpha: 1).cgColor)
                ctx.setLineWidth(s * 0.15)
                ctx.move(to: CGPoint(x: cx + s * 0.4, y: cy - s * 1.5))
                ctx.addLine(to: CGPoint(x: cx + s * 2.5, y: cy - s * 2.5))
                ctx.strokePath()
                if frame > 0 {
                    ctx.setStrokeColor(NSColor.white.cgColor)
                    ctx.setLineWidth(s * 0.05)
                    ctx.move(to: CGPoint(x: cx + s * 2.5, y: cy - s * 2.5))
                    ctx.addLine(to: CGPoint(x: cx + s * 2.5, y: cy + s * 0.5))
                    ctx.strokePath()
                }
            }
        }
    }

    private static func drawSharkFin(ctx: CGContext, x: CGFloat, y: CGFloat, scale: CGFloat) {
        ctx.setFillColor(NSColor(deviceRed: 0.3, green: 0.3, blue: 0.4, alpha: 1).cgColor)
        ctx.move(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + scale * 0.3, y: y - scale * 0.4))
        ctx.addLine(to: CGPoint(x: x + scale * 0.5, y: y))
        ctx.closePath()
        ctx.fillPath()
    }

    private static func drawBird(ctx: CGContext, x: CGFloat, y: CGFloat, frame: Int, scale: CGFloat) {
        ctx.setStrokeColor(NSColor.black.cgColor)
        ctx.setLineWidth(scale * 0.04)
        let wing = frame == 1 ? scale * 0.1 : -scale * 0.1
        ctx.move(to: CGPoint(x: x - scale * 0.2, y: y + wing))
        ctx.addLine(to: CGPoint(x: x, y: y))
        ctx.addLine(to: CGPoint(x: x + scale * 0.2, y: y + wing))
        ctx.strokePath()
    }
}
