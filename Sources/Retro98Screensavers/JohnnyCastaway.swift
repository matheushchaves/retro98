// MARK: - Castaway puppet
//
// Johnny é um boneco articulado: membros magrelos traçados entre juntas,
// cada parte com contorno próprio, e uma cabeça desenhada à mão por cima.
// Coordenadas locais: origem no chão entre os pés, y negativo = para cima,
// olhando para a direita.

struct CastawayPose {
    struct Limb {
        let from: PixelPoint
        let joint: PixelPoint
        let end: PixelPoint
        /// Direção da ponta (dedos do pé); zero para braços.
        var toe = PixelPoint(x: 0, y: 0)
    }

    var neck: PixelPoint
    var hip: PixelPoint
    var nearArm: Limb
    var farArm: Limb
    var nearLeg: Limb
    var farLeg: Limb
    var head: CastawayHead = .normal
    var headOffset = PixelPoint(x: 0, y: 0)
    /// Braço da frente passa por cima do rosto (mão na testa).
    var nearArmOverHead = false
    /// Vara de pescar: do punho até a ponta.
    var rodTip: PixelPoint?
}

extension CastawayPose {
    private static let forward = PixelPoint(x: 2, y: 0)
    private static let upward = PixelPoint(x: 0, y: -2)

    private static let standingNearLeg = Limb(
        from: PixelPoint(x: 2, y: -13), joint: PixelPoint(x: 2, y: -7), end: PixelPoint(x: 2, y: -1), toe: forward)
    private static let standingFarLeg = Limb(
        from: PixelPoint(x: -1, y: -13), joint: PixelPoint(x: -1, y: -7), end: PixelPoint(x: -1, y: -1), toe: forward)

    static let standing = CastawayPose(
        neck: PixelPoint(x: 0, y: -24), hip: PixelPoint(x: 0, y: -15),
        nearArm: Limb(from: PixelPoint(x: 3, y: -24), joint: PixelPoint(x: 4, y: -19), end: PixelPoint(x: 4, y: -14)),
        farArm: Limb(from: PixelPoint(x: -2, y: -24), joint: PixelPoint(x: -4, y: -19), end: PixelPoint(x: -4, y: -14)),
        nearLeg: standingNearLeg, farLeg: standingFarLeg)

    /// Mão em viseira, vasculhando o horizonte.
    static let lookout: CastawayPose = {
        var pose = standing
        pose.nearArm = Limb(from: PixelPoint(x: 3, y: -24), joint: PixelPoint(x: 10, y: -27), end: PixelPoint(x: 7, y: -36))
        pose.farArm = Limb(from: PixelPoint(x: -2, y: -24), joint: PixelPoint(x: -5, y: -20), end: PixelPoint(x: -3, y: -16))
        pose.nearArmOverHead = true
        return pose
    }()

    static let armsOut: CastawayPose = {
        var pose = standing
        pose.nearArm = Limb(from: PixelPoint(x: 3, y: -24), joint: PixelPoint(x: 9, y: -25), end: PixelPoint(x: 14, y: -28))
        pose.farArm = Limb(from: PixelPoint(x: -2, y: -24), joint: PixelPoint(x: -8, y: -25), end: PixelPoint(x: -13, y: -28))
        pose.head = .yawn
        return pose
    }()

    static let armsUp: CastawayPose = {
        var pose = standing
        pose.nearArm = Limb(from: PixelPoint(x: 3, y: -24), joint: PixelPoint(x: 9, y: -29), end: PixelPoint(x: 11, y: -38))
        pose.farArm = Limb(from: PixelPoint(x: -2, y: -24), joint: PixelPoint(x: -8, y: -29), end: PixelPoint(x: -10, y: -38))
        pose.head = .yawn
        pose.headOffset = PixelPoint(x: 0, y: -1)
        return pose
    }()

    /// Sentado, recostado para trás, pernas esticadas.
    static let asleep = CastawayPose(
        neck: PixelPoint(x: -6, y: -12), hip: PixelPoint(x: 0, y: -4),
        nearArm: Limb(from: PixelPoint(x: -4, y: -11), joint: PixelPoint(x: -1, y: -6), end: PixelPoint(x: 3, y: -7)),
        farArm: Limb(from: PixelPoint(x: -6, y: -11), joint: PixelPoint(x: -9, y: -6), end: PixelPoint(x: -7, y: -2)),
        nearLeg: Limb(from: PixelPoint(x: 1, y: -3), joint: PixelPoint(x: 9, y: -3), end: PixelPoint(x: 17, y: -2), toe: upward),
        farLeg: Limb(from: PixelPoint(x: 1, y: -4), joint: PixelPoint(x: 8, y: -9), end: PixelPoint(x: 13, y: -2), toe: forward),
        head: .asleep)

    /// Sentado na beirada, pernas penduradas, vara para a frente.
    static let fishing = CastawayPose(
        neck: PixelPoint(x: 1, y: -14), hip: PixelPoint(x: 0, y: -4),
        nearArm: Limb(from: PixelPoint(x: 3, y: -13), joint: PixelPoint(x: 6, y: -8), end: PixelPoint(x: 10, y: -10)),
        farArm: Limb(from: PixelPoint(x: 0, y: -13), joint: PixelPoint(x: 4, y: -7), end: PixelPoint(x: 8, y: -8)),
        nearLeg: Limb(from: PixelPoint(x: 1, y: -3), joint: PixelPoint(x: 8, y: -3), end: PixelPoint(x: 9, y: 4), toe: forward),
        farLeg: Limb(from: PixelPoint(x: 1, y: -4), joint: PixelPoint(x: 6, y: -4), end: PixelPoint(x: 6, y: 3), toe: forward),
        rodTip: PixelPoint(x: 36, y: -25))

    static let fishingBite: CastawayPose = {
        var pose = fishing
        pose.neck = PixelPoint(x: 3, y: -14)
        pose.head = .surprised
        pose.rodTip = PixelPoint(x: 35, y: -15)
        return pose
    }()

    static let fishingCatch: CastawayPose = {
        var pose = fishing
        pose.neck = PixelPoint(x: -1, y: -14)
        pose.nearArm = Limb(from: PixelPoint(x: 1, y: -13), joint: PixelPoint(x: 5, y: -11), end: PixelPoint(x: 8, y: -15))
        pose.farArm = Limb(from: PixelPoint(x: -1, y: -13), joint: PixelPoint(x: 3, y: -10), end: PixelPoint(x: 6, y: -13))
        pose.rodTip = PixelPoint(x: 22, y: -40)
        return pose
    }()

    /// Pânico: braços para o alto, joelhos dobrados.
    static let panic: CastawayPose = {
        var pose = armsUp
        pose.head = .surprised
        pose.nearLeg = Limb(from: PixelPoint(x: 2, y: -13), joint: PixelPoint(x: 4, y: -7), end: PixelPoint(x: 3, y: -1), toe: forward)
        pose.farLeg = Limb(from: PixelPoint(x: -1, y: -13), joint: PixelPoint(x: -3, y: -7), end: PixelPoint(x: -2, y: -1), toe: forward)
        return pose
    }()
}

enum JohnnyCastaway {
    private static let layerWidth = 96
    private static let layerHeight = 88
    private static let origin = PixelPoint(x: 48, y: 72)

    private static let limbBrush = 2
    private static let handBrush = 3
    private static let torsoBrush = 5
    private static let thighBrush = 4
    private static let hipBrush = 6

    /// Desenha Johnny com os pés (origem local) em `feet`.
    static func draw(_ pose: CastawayPose, into canvas: inout PixelCanvas,
                     at feet: PixelPoint, facingLeft: Bool) {
        let layer = layer(for: pose)
        let originX = facingLeft ? layerWidth - 1 - origin.x : origin.x
        canvas.draw(layer, x: feet.x - originX, y: feet.y - origin.y, flipped: facingLeft)
    }

    /// Converte um ponto local da pose para coordenadas da cena.
    static func scenePoint(_ local: PixelPoint, feet: PixelPoint, facingLeft: Bool) -> PixelPoint {
        PixelPoint(x: feet.x + (facingLeft ? -local.x : local.x), y: feet.y + local.y)
    }

    private static func layer(for pose: CastawayPose) -> PixelCanvas {
        var layer = blank()
        layer.draw(limbPart(pose.farArm, color: JohnnyPalette.skinShade), x: 0, y: 0)
        layer.draw(limbPart(pose.farLeg, color: JohnnyPalette.skinShade), x: 0, y: 0)
        layer.draw(limbPart(pose.nearLeg, color: JohnnyPalette.skin), x: 0, y: 0)
        layer.draw(shortsPart(pose), x: 0, y: 0)
        layer.draw(torsoPart(pose), x: 0, y: 0)
        if let tip = pose.rodTip { drawRod(into: &layer, pose: pose, tip: tip) }
        if !pose.nearArmOverHead {
            layer.draw(limbPart(pose.nearArm, color: JohnnyPalette.skin), x: 0, y: 0)
        }
        drawHead(into: &layer, pose: pose)
        if pose.nearArmOverHead {
            layer.draw(limbPart(pose.nearArm, color: JohnnyPalette.skin), x: 0, y: 0)
        }
        return layer
    }

    private static func blank() -> PixelCanvas { PixelCanvas(width: layerWidth, height: layerHeight) }

    private static func place(_ local: PixelPoint) -> PixelPoint { origin + local }

    private static func limbPart(_ limb: CastawayPose.Limb, color: PixelColor) -> PixelCanvas {
        var part = blank()
        part.line(from: place(limb.from), to: place(limb.joint), color: color, brush: limbBrush)
        part.line(from: place(limb.joint), to: place(limb.end), color: color, brush: limbBrush)
        let hasToe = limb.toe != PixelPoint(x: 0, y: 0)
        if hasToe {
            part.line(from: place(limb.end), to: place(limb.end + limb.toe), color: color, brush: limbBrush)
        } else {
            part.stamp(at: place(limb.end), color: color, brush: handBrush)
        }
        return part.outlined(with: JohnnyPalette.outline)
    }

    /// Bermuda jeans rasgada: quadril + metade de cada coxa.
    private static func shortsPart(_ pose: CastawayPose) -> PixelCanvas {
        var part = blank()
        for (leg, color) in [(pose.farLeg, JohnnyPalette.shortsDark), (pose.nearLeg, JohnnyPalette.shorts)] {
            let mid = PixelPoint(x: (leg.from.x + leg.joint.x) / 2, y: (leg.from.y + leg.joint.y) / 2)
            part.line(from: place(leg.from), to: place(mid), color: color, brush: thighBrush)
        }
        part.stamp(at: place(pose.hip), color: JohnnyPalette.shorts, brush: hipBrush)
        let patch = place(pose.hip)
        part[patch.x + 1, patch.y] = JohnnyPalette.shortsLight
        part[patch.x + 1, patch.y - 1] = JohnnyPalette.shortsLight
        part[patch.x - 2, patch.y + 1] = JohnnyPalette.shortsDark
        return part.outlined(with: JohnnyPalette.outline)
    }

    /// Tronco magro com luz no peito e costelas marcadas.
    private static func torsoPart(_ pose: CastawayPose) -> PixelCanvas {
        var part = blank()
        let neck = place(pose.neck), hip = place(pose.hip)
        let waist = PixelPoint(x: (neck.x + hip.x * 2) / 3, y: (neck.y + hip.y * 2) / 3)
        part.line(from: neck, to: waist, color: JohnnyPalette.skin, brush: torsoBrush)
        if pose.neck.x == pose.hip.x {
            for y in (neck.y - 1)...waist.y {
                part[neck.x + 1, y] = JohnnyPalette.skinLight
                part[neck.x - 2, y] = JohnnyPalette.skinShade
            }
            for rib in [2, 4] { part[neck.x - 1, neck.y + rib] = JohnnyPalette.skinShade }
        }
        return part.outlined(with: JohnnyPalette.outline)
    }

    private static func drawRod(into layer: inout PixelCanvas, pose: CastawayPose, tip: PixelPoint) {
        let grip = pose.nearArm.end
        let butt = PixelPoint(x: grip.x - 4, y: grip.y + 2)
        layer.line(from: place(butt), to: place(grip), color: JohnnyPalette.rod, brush: limbBrush)
        layer.line(from: place(grip), to: place(tip), color: JohnnyPalette.rod)
    }

    private static func drawHead(into layer: inout PixelCanvas, pose: CastawayPose) {
        let sprite = JohnnySprites.head(pose.head)
        let anchor = JohnnySprites.headNeckAnchor
        let neck = place(pose.neck + pose.headOffset)
        layer.draw(sprite, x: neck.x - anchor.x, y: neck.y - anchor.y)
    }
}
