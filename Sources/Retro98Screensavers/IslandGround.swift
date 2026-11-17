import Foundation

// MARK: - Layout

/// Geometria da cena para um framebuffer de `width` × `height` pixels virtuais.
/// A cena se ancora no horizonte e na ilha, então qualquer proporção de tela
/// é preenchida sem barras.
struct IslandLayout {
    private static let horizonFraction = 0.58
    private static let waterlineFraction = 0.58
    private static let islandFraction = 0.57

    static let islandHalfWidth = 62
    private static let domeHeight = 14.0
    private static let domeRoundness = 0.55
    private static let shoreDepth = 7.0
    /// Distância entre a silhueta do topo e onde os pés pisam.
    private static let footInset = 5

    let width: Int
    let height: Int
    let horizonY: Int
    let islandCenterX: Int
    /// Linha d'água da ilha (centro da elipse da praia).
    let waterlineY: Int

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        horizonY = Int((Double(height) * Self.horizonFraction).rounded())
        let seaDepth = Double(height - horizonY)
        waterlineY = horizonY + Int((seaDepth * Self.waterlineFraction).rounded())
        islandCenterX = Int((Double(width) * Self.islandFraction).rounded())
    }

    /// 1 no centro da ilha, 0 nas pontas; nil fora dela.
    private func islandProfile(atX x: Int) -> Double? {
        let u = Double(x - islandCenterX) / Double(Self.islandHalfWidth)
        guard abs(u) <= 1 else { return nil }
        return 1 - u * u
    }

    func islandTop(atX x: Int) -> Int? {
        islandProfile(atX: x).map {
            waterlineY - Int((Self.domeHeight * pow($0, Self.domeRoundness)).rounded())
        }
    }

    func islandBottom(atX x: Int) -> Int? {
        islandProfile(atX: x).map { waterlineY + Int((Self.shoreDepth * $0.squareRoot()).rounded()) }
    }

    /// Altura do chão onde um personagem pisa em `x`.
    func groundY(atX x: Int) -> Int {
        guard let top = islandTop(atX: x), let bottom = islandBottom(atX: x) else { return waterlineY }
        return min(top + Self.footInset, bottom)
    }

    /// Base do tronco da palmeira.
    var palmBase: PixelPoint {
        let x = islandCenterX + 22
        return PixelPoint(x: x, y: groundY(atX: x) + 1)
    }
}

// MARK: - Island

enum IslandGround {
    private static let lagoonReach = 16.0
    private static let lagoonDepth = 15.0
    private static let lagoonFringe = 9.0
    private static let wetRows = 2
    private static let grainRarity = 23
    private static let foamPeriodTicks = 5
    private static let rockInset = 6

    static func draw(into canvas: inout PixelCanvas, layout: IslandLayout, tick: Int) {
        drawLagoon(into: &canvas, layout: layout)
        drawSand(into: &canvas, layout: layout)
        drawFoam(into: &canvas, layout: layout, tick: tick)
        drawRock(into: &canvas, layout: layout)
        drawTrinkets(into: &canvas, layout: layout)
    }

    /// Água rasa turquesa em volta da ilha, com franja pontilhada.
    private static func drawLagoon(into canvas: inout PixelCanvas, layout: IslandLayout) {
        let cx = Double(layout.islandCenterX), cy = Double(layout.waterlineY) + 3
        let rx = Double(IslandLayout.islandHalfWidth) + lagoonReach
        canvas.fillEllipse(cx: cx, cy: cy, rx: rx + lagoonFringe, ry: lagoonDepth + lagoonFringe * 0.5,
                           color: IslandPalette.lagoonDeep, level: 0.5)
        canvas.fillEllipse(cx: cx, cy: cy, rx: rx, ry: lagoonDepth, color: IslandPalette.lagoonDeep)
        canvas.fillEllipse(cx: cx, cy: cy, rx: rx - 5, ry: lagoonDepth - 3,
                           color: IslandPalette.lagoon, level: 0.5)
        canvas.fillEllipse(cx: cx, cy: cy, rx: rx - 9, ry: lagoonDepth - 5, color: IslandPalette.lagoon)
    }

    private static func drawSand(into canvas: inout PixelCanvas, layout: IslandLayout) {
        let half = IslandLayout.islandHalfWidth
        for x in (layout.islandCenterX - half)...(layout.islandCenterX + half) {
            guard let top = layout.islandTop(atX: x), let bottom = layout.islandBottom(atX: x),
                  bottom >= top else { continue }
            let u = Double(x - layout.islandCenterX) / Double(half)
            for y in top...bottom {
                canvas[x, y] = sandColor(x: x, y: y, top: top, bottom: bottom, u: u)
            }
        }
    }

    /// Luz vem do alto à esquerda: areia clara no topo, escura na borda direita/baixa.
    private static func sandColor(x: Int, y: Int, top: Int, bottom: Int, u: Double) -> PixelColor {
        if y == top { return IslandPalette.sandRim }
        if y > bottom - wetRows { return IslandPalette.sandWet }
        let v = Double(y - top) / Double(max(1, bottom - top))
        let shade = v * 0.85 + max(0, u) * 0.3 + abs(u) * abs(u) * 0.15
        if v < 0.6, PixelDither.hash(x, y) % grainRarity == 0 { return IslandPalette.sandGrain }
        return PixelDither.ramp(IslandPalette.sand, t: shade, x: x, y: y)
    }

    /// Espuma branca que respira junto à praia, mais uma segunda linha quebrada.
    private static func drawFoam(into canvas: inout PixelCanvas, layout: IslandLayout, tick: Int) {
        let half = IslandLayout.islandHalfWidth
        let breath = [0, 1, 2, 1][(tick / foamPeriodTicks) % 4]
        for x in (layout.islandCenterX - half - 3)...(layout.islandCenterX + half + 3) {
            let edge = layout.islandBottom(atX: x) ?? layout.waterlineY
            let seed = PixelDither.hash(x / 3, 7)
            if (x + tick / foamPeriodTicks) % 9 != 0 {
                canvas[x, edge + 1] = IslandPalette.foam
                if seed % 3 == 0 { canvas[x, edge + 2] = IslandPalette.foam }
            }
            if (seed + tick / (foamPeriodTicks * 2)) % 4 < 2 {
                canvas[x, edge + 4 + breath] = IslandPalette.foam
            }
        }
    }

    private static let rockSprite = PixelSprite([
        "...XXXX....",
        "..XLLLrXX..",
        ".XLLrrrrDX.",
        ".XLrrrrDDX.",
        "XLrrrrrDDDX",
        "XrrrrDDDDDX",
    ], palette: [
        "X": IslandPalette.outline, "L": IslandPalette.rockLight,
        "r": IslandPalette.rock, "D": IslandPalette.rockDark,
    ])

    /// Pedra na ponta direita, meio dentro d'água (a esquerda é o ponto de pesca).
    private static func drawRock(into canvas: inout PixelCanvas, layout: IslandLayout) {
        let x = layout.islandCenterX + IslandLayout.islandHalfWidth - rockInset
        let y = layout.waterlineY - rockSprite.height + 3
        canvas.draw(rockSprite, x: x, y: y)
        canvas.fillRect(x: x - 1, y: y + rockSprite.height, width: rockSprite.width + 2, height: 1,
                        color: IslandPalette.foam)
    }

    /// Concha e tufos de capim para quebrar a areia lisa.
    private static func drawTrinkets(into canvas: inout PixelCanvas, layout: IslandLayout) {
        let shellX = layout.islandCenterX - 6
        let shellY = layout.groundY(atX: shellX) + 6
        canvas.fillRect(x: shellX, y: shellY, width: 2, height: 1, color: IslandPalette.shell)
        canvas[shellX - 1, shellY + 1] = IslandPalette.sandShadow
        canvas.fillRect(x: shellX, y: shellY + 1, width: 2, height: 1, color: IslandPalette.eyeWhite)

        for offset in [38, 44] {
            let x = layout.islandCenterX + offset
            drawGrassTuft(into: &canvas, x: x, y: layout.groundY(atX: x) + 1)
        }
    }

    private static func drawGrassTuft(into canvas: inout PixelCanvas, x: Int, y: Int) {
        let blades: [(dx: Int, lean: Int, height: Int)] = [(-2, -2, 4), (0, 0, 6), (1, 2, 5), (3, 3, 3)]
        for blade in blades {
            canvas.line(from: PixelPoint(x: x + blade.dx, y: y),
                        to: PixelPoint(x: x + blade.dx + blade.lean, y: y - blade.height),
                        color: blade.height > 4 ? IslandPalette.leaf : IslandPalette.leafDark)
        }
    }
}
