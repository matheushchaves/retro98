import AppKit

// MARK: - Clock

/// Tempo da cena: `frame` vem do roteiro; os ticks movem o que desliza
/// (tubarão, gaivota) e o que nunca para (ondas, nuvens, folhas).
struct JohnnyClock {
    static let ticksPerSecond = 10

    var frame: Int
    /// Ticks desde o início da cena atual.
    var sceneTick: Int
    /// Ticks desde que o protetor começou.
    var worldTick: Int
}

extension JohnnySceneKind {
    var durationTicks: Int { Int(sceneDuration * Double(JohnnyClock.ticksPerSecond)) }
}

// MARK: - Scene composition

enum JohnnyScene {
    /// Resolução virtual de referência (16:9). Telas com outra proporção
    /// ganham mais céu/mar em vez de barras.
    static let vw: CGFloat = 320
    static let vh: CGFloat = 180

    static func draw(_ scene: JohnnySceneKind, frame: Int, in ctx: CGContext, size: CGSize) {
        let sceneTick = Int(Double(frame) * scene.frameDuration * Double(JohnnyClock.ticksPerSecond))
        let clock = JohnnyClock(frame: frame, sceneTick: sceneTick, worldTick: sceneTick)
        draw(scene, clock: clock, in: ctx, size: size)
    }

    static func draw(_ scene: JohnnySceneKind, clock: JohnnyClock, in ctx: CGContext, size: CGSize) {
        guard size.width >= 1, size.height >= 1 else { return }
        let scale = pixelScale(for: size)
        let width = Int((size.width / scale).rounded(.up))
        let height = Int((size.height / scale).rounded(.up))
        let canvas = render(scene, clock: clock, width: width, height: height)
        guard let image = canvas.makeImage() else { return }

        ctx.saveGState()
        ctx.setShouldAntialias(false)
        ctx.interpolationQuality = .none
        let drawn = CGSize(width: CGFloat(width) * scale, height: CGFloat(height) * scale)
        ctx.draw(image, in: CGRect(x: 0, y: size.height - drawn.height, width: drawn.width, height: drawn.height))
        ctx.restoreGState()
    }

    /// Pixels reais por pixel virtual; inteiro sempre que a tela comporta.
    private static func pixelScale(for size: CGSize) -> CGFloat {
        let fit = min(size.width / vw, size.height / vh)
        return fit >= 1 ? fit.rounded(.down) : fit
    }

    static func render(_ scene: JohnnySceneKind, clock: JohnnyClock, width: Int, height: Int) -> PixelCanvas {
        var canvas = PixelCanvas(width: width, height: height)
        let layout = JohnnyLayout(width: width, height: height)
        JohnnyBackdrop.draw(into: &canvas, layout: layout, tick: clock.worldTick)
        JohnnyIsland.draw(into: &canvas, layout: layout, tick: clock.worldTick)
        JohnnyPalm.draw(into: &canvas, layout: layout, tick: clock.worldTick)
        JohnnyActing.draw(scene, into: &canvas, layout: layout, clock: clock)
        return canvas
    }
}

// MARK: - Acting (o que Johnny e os bichos fazem em cada cena)

enum JohnnyActing {
    private static let standOffsetX = -22
    private static let fishingOffsetX = -47
    private static let sleepOffsetFromPalm = -13
    private static let blinkPeriodTicks = 34
    private static let blinkLengthTicks = 2

    static func draw(_ scene: JohnnySceneKind, into canvas: inout PixelCanvas,
                     layout: JohnnyLayout, clock: JohnnyClock) {
        switch scene {
        case .idle:
            drawStanding(clock.frame == 0 ? .standing : .lookout, into: &canvas, layout: layout, clock: clock)
        case .sleeping:
            drawSleeping(into: &canvas, layout: layout, clock: clock)
        case .fishing:
            drawFishing(into: &canvas, layout: layout, clock: clock)
        case .shark:
            drawShark(into: &canvas, layout: layout, clock: clock)
        case .bird:
            drawStanding(.standing, into: &canvas, layout: layout, clock: clock)
            drawGull(into: &canvas, layout: layout, clock: clock)
        case .stretching:
            drawStanding(clock.frame == 0 ? .armsOut : .armsUp, into: &canvas, layout: layout, clock: clock)
        }
    }

    private static func standingFeet(_ layout: JohnnyLayout) -> PixelPoint {
        let x = layout.islandCenterX + standOffsetX
        return PixelPoint(x: x, y: layout.groundY(atX: x) + 2)
    }

    private static func drawGroundShadow(into canvas: inout PixelCanvas, at feet: PixelPoint, halfWidth: Double) {
        canvas.fillEllipse(cx: Double(feet.x), cy: Double(feet.y), rx: halfWidth, ry: 2,
                           color: JohnnyPalette.sandShadow, level: 0.5)
    }

    private static func drawStanding(_ base: CastawayPose, into canvas: inout PixelCanvas,
                                     layout: JohnnyLayout, clock: JohnnyClock, shake: Int = 0) {
        var pose = base
        let isBlinking = clock.sceneTick % blinkPeriodTicks >= blinkPeriodTicks - blinkLengthTicks
        if pose.head == .normal, isBlinking { pose.head = .blink }
        let feet = standingFeet(layout)
        drawGroundShadow(into: &canvas, at: feet, halfWidth: 7)
        JohnnyCastaway.draw(pose, into: &canvas, at: PixelPoint(x: feet.x + shake, y: feet.y), facingLeft: true)
    }

    // MARK: Sleeping

    private static let snorePeriodTicks = 6
    private static let snoreRise: [PixelPoint] = [
        PixelPoint(x: -12, y: -30), PixelPoint(x: -18, y: -38), PixelPoint(x: -26, y: -48),
    ]

    /// Ticks até os Z subirem todos e sumirem: cada volta começa com um ronco.
    static var snoreCycleTicks: Int { snorePeriodTicks * (snoreRise.count + 1) }

    private static func drawSleeping(into canvas: inout PixelCanvas, layout: JohnnyLayout, clock: JohnnyClock) {
        let x = layout.palmBase.x + sleepOffsetFromPalm
        let seat = PixelPoint(x: x, y: layout.groundY(atX: x) + 3)
        var pose = CastawayPose.asleep
        if clock.frame % 2 == 1 { pose.headOffset = PixelPoint(x: 0, y: 1) }
        drawGroundShadow(into: &canvas, at: PixelPoint(x: seat.x - 6, y: seat.y), halfWidth: 13)
        JohnnyCastaway.draw(pose, into: &canvas, at: seat, facingLeft: true)

        let visible = (clock.sceneTick / snorePeriodTicks) % (snoreRise.count + 1)
        var glyphs = PixelCanvas(width: canvas.width, height: canvas.height)
        for index in 0..<visible {
            let at = seat + snoreRise[index]
            glyphs.draw(JohnnySprites.snoreGlyphs[index], x: at.x, y: at.y)
        }
        canvas.draw(glyphs.outlined(with: JohnnyPalette.outline), x: 0, y: 0)
    }

    // MARK: Fishing

    private static func drawFishing(into canvas: inout PixelCanvas, layout: JohnnyLayout, clock: JohnnyClock) {
        let poses: [CastawayPose] = [.fishing, .fishingBite, .fishingCatch]
        let stage = clock.frame % poses.count
        let pose = poses[stage]
        let x = layout.islandCenterX + fishingOffsetX
        let seat = PixelPoint(x: x, y: layout.groundY(atX: x) + 2)
        JohnnyCastaway.draw(pose, into: &canvas, at: seat, facingLeft: true)

        guard let localTip = pose.rodTip else { return }
        let tip = JohnnyCastaway.scenePoint(localTip, feet: seat, facingLeft: true)
        let waterY = layout.waterlineY + 6
        switch stage {
        case 0:
            let bob = (clock.sceneTick / 5) % 2
            drawLine(into: &canvas, from: tip, toY: waterY - 2 + bob)
            canvas.draw(JohnnySprites.bobber, x: tip.x - 1, y: waterY - 2 + bob)
            drawRipple(into: &canvas, x: tip.x, y: waterY + 2, halfWidth: 4)
        case 1:
            drawLine(into: &canvas, from: tip, toY: waterY + 1)
            let spread = 4 + (clock.sceneTick / 2) % 4
            drawRipple(into: &canvas, x: tip.x, y: waterY + 1, halfWidth: spread)
            drawRipple(into: &canvas, x: tip.x, y: waterY + 3, halfWidth: spread + 3)
        default:
            let swing = [0, 1, 0, -1][(clock.sceneTick / 2) % 4]
            let fishTop = tip.y + 14
            drawLine(into: &canvas, from: tip, toY: fishTop)
            canvas.draw(JohnnySprites.hookedFish, x: tip.x - 2 + swing, y: fishTop)
            drawRipple(into: &canvas, x: tip.x, y: waterY + 2, halfWidth: 5)
        }
    }

    private static func drawLine(into canvas: inout PixelCanvas, from tip: PixelPoint, toY y: Int) {
        guard y > tip.y else { return }
        canvas.fillRect(x: tip.x, y: tip.y, width: 1, height: y - tip.y, color: JohnnyPalette.fishingLine)
    }

    private static func drawRipple(into canvas: inout PixelCanvas, x: Int, y: Int, halfWidth: Int) {
        canvas.fillRect(x: x - halfWidth, y: y, width: halfWidth - 1, height: 1, color: JohnnyPalette.foam)
        canvas.fillRect(x: x + 2, y: y, width: halfWidth - 1, height: 1, color: JohnnyPalette.foam)
    }

    // MARK: Shark

    private static let sharkMargin = 20
    private static let sharkDepthBelowIsland = 24

    private static func drawShark(into canvas: inout PixelCanvas, layout: JohnnyLayout, clock: JohnnyClock) {
        let shake = clock.sceneTick % 2 == 0 ? 0 : 1
        drawStanding(.panic, into: &canvas, layout: layout, clock: clock, shake: shake)

        let totalTicks = JohnnySceneKind.shark.durationTicks
        let travel = layout.width + sharkMargin * 2
        let x = -sharkMargin + (clock.sceneTick % totalTicks) * travel / totalTicks
        let fin = JohnnySprites.sharkFin
        let bob = (clock.sceneTick / 4) % 2
        let baseY = min(layout.waterlineY + sharkDepthBelowIsland, layout.height - 6)
        canvas.draw(fin, x: x, y: baseY - fin.height + bob)
        // Espuma na base da barbatana e esteira atrás.
        canvas.fillRect(x: x - 2, y: baseY, width: fin.width + 5, height: 1, color: JohnnyPalette.foam)
        canvas.fillRect(x: x - 9, y: baseY + 1, width: 6, height: 1, color: JohnnyPalette.foam)
        canvas.fillRect(x: x - 18 - bob * 2, y: baseY, width: 5, height: 1, color: JohnnyPalette.seaGlintBright)
        canvas.fillRect(x: x - 27, y: baseY + 1, width: 4, height: 1, color: JohnnyPalette.seaGlint)
    }

    // MARK: Gull

    private static let gullMargin = 20
    private static let gullAltitudeFraction = 0.2
    private static let gullFlapTicks = 2

    private static func drawGull(into canvas: inout PixelCanvas, layout: JohnnyLayout, clock: JohnnyClock) {
        let totalTicks = JohnnySceneKind.bird.durationTicks
        let travel = layout.width + gullMargin * 2
        let x = -gullMargin + (clock.sceneTick % totalTicks) * travel / totalTicks
        let glide = [0, -1, -2, -1][(clock.sceneTick / 4) % 4]
        let y = Int(Double(layout.horizonY) * gullAltitudeFraction) + glide
        let cycle = JohnnySprites.gullCycle
        canvas.draw(cycle[(clock.sceneTick / gullFlapTicks) % cycle.count], x: x, y: y)
    }
}
