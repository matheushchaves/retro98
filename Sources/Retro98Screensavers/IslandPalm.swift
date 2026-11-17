import Foundation

// MARK: - Palm tree
//
// Tronco: curva de Bézier quadrática, segmentado em anéis.
// Copa: folhas procedurais (nervura em arco que cai com a "gravidade" e
// folíolos serrilhados dos dois lados), cada uma com contorno próprio.

enum IslandPalm {
    /// Camada local onde a palmeira é montada antes de ir para a cena.
    private static let layerSize = 128
    private static let baseInLayer = PixelPoint(x: 64, y: 120)

    // Tronco (deslocamentos relativos à base).
    private static let trunkControl = (x: 12.0, y: -44.0)
    private static let trunkTop = (x: -16.0, y: -78.0)
    private static let trunkSamples = 240
    private static let trunkBaseHalfWidth = 3.6
    private static let trunkTopHalfWidth = 2.1
    private static let trunkFlare = 1.6
    private static let ringSpacing = 5

    private struct Frond {
        let angleDegrees: Double
        let length: Double
        let droop: Double
        let leaflet: Double
        let isBack: Bool
    }

    private static let fronds: [Frond] = [
        Frond(angleDegrees: 100, length: 26, droop: 6, leaflet: 4, isBack: true),
        Frond(angleDegrees: 55, length: 38, droop: 20, leaflet: 4.5, isBack: true),
        Frond(angleDegrees: 132, length: 38, droop: 22, leaflet: 4.5, isBack: true),
        Frond(angleDegrees: 215, length: 26, droop: 22, leaflet: 4, isBack: false),
        Frond(angleDegrees: -32, length: 28, droop: 22, leaflet: 4, isBack: false),
        Frond(angleDegrees: 178, length: 42, droop: 30, leaflet: 5, isBack: false),
        Frond(angleDegrees: 6, length: 44, droop: 30, leaflet: 5, isBack: false),
        Frond(angleDegrees: 152, length: 42, droop: 20, leaflet: 5, isBack: false),
        Frond(angleDegrees: 30, length: 42, droop: 20, leaflet: 5, isBack: false),
        Frond(angleDegrees: 78, length: 24, droop: 8, leaflet: 4, isBack: false),
    ]

    private static let swayCycle = [0.0, 1.0, 2.0, 1.0]
    private static let swayPeriodTicks = 6
    private static let serrationPeriod = 3
    private static let serrationDepth = 2.0
    /// Fração do folíolo que sobe acima da nervura (o resto pende).
    private static let upperLeafletShare = 0.4
    private static let leafletSag = 0.5

    private static let coconutOffsets = [PixelPoint(x: -4, y: 3), PixelPoint(x: 3, y: 4), PixelPoint(x: -1, y: 6)]

    static func draw(into canvas: inout PixelCanvas, layout: IslandLayout, tick: Int) {
        var layer = PixelCanvas(width: layerSize, height: layerSize)
        let crown = PixelPoint(x: baseInLayer.x + Int(trunkTop.x), y: baseInLayer.y + Int(trunkTop.y))

        for (index, frond) in fronds.enumerated() where frond.isBack {
            layer.draw(frondLayer(frond, index: index, crown: crown, tick: tick), x: 0, y: 0)
        }
        layer.draw(trunkLayer(), x: 0, y: 0)
        for (index, frond) in fronds.enumerated() where !frond.isBack {
            layer.draw(frondLayer(frond, index: index, crown: crown, tick: tick), x: 0, y: 0)
        }
        layer.draw(coconutLayer(crown: crown), x: 0, y: 0)

        let base = layout.palmBase
        canvas.fillEllipse(cx: Double(base.x) - 7, cy: Double(base.y) + 1, rx: 13, ry: 3,
                           color: IslandPalette.sandShadow, level: 0.5)
        canvas.draw(layer, x: base.x - baseInLayer.x, y: base.y - baseInLayer.y)
    }

    // MARK: Trunk

    private static func trunkPoint(_ t: Double) -> (x: Double, y: Double) {
        // Bézier quadrática com P0 na base (origem), então só P1 e P2 pesam.
        let b = 2 * t * (1 - t), c = t * t
        return (Double(baseInLayer.x) + b * trunkControl.x + c * trunkTop.x,
                Double(baseInLayer.y) + b * trunkControl.y + c * trunkTop.y)
    }

    private static func trunkLayer() -> PixelCanvas {
        var layer = PixelCanvas(width: layerSize, height: layerSize)
        for step in 0...trunkSamples {
            let t = Double(step) / Double(trunkSamples)
            let p = trunkPoint(t)
            let flare = max(0, 1 - t * 10) * trunkFlare
            let half = trunkBaseHalfWidth + (trunkTopHalfWidth - trunkBaseHalfWidth) * t + flare
            let y = Int(p.y.rounded())
            let isRing = (Int(baseInLayer.y) - y) % ringSpacing == 0
            for x in Int((p.x - half).rounded())...Int((p.x + half).rounded()) {
                let rel = (Double(x) - p.x) / half
                layer[x, y] = trunkColor(rel: rel, isRing: isRing)
            }
        }
        return layer.outlined(with: IslandPalette.outline)
    }

    private static func trunkColor(rel: Double, isRing: Bool) -> PixelColor {
        if isRing { return rel < -0.5 ? IslandPalette.trunkDark : IslandPalette.trunkRing }
        if rel < -0.35 { return IslandPalette.trunkLight }
        if rel > 0.35 { return IslandPalette.trunkDark }
        return IslandPalette.trunk
    }

    // MARK: Fronds

    private static func frondLayer(_ frond: Frond, index: Int, crown: PixelPoint, tick: Int) -> PixelCanvas {
        var layer = PixelCanvas(width: layerSize, height: layerSize)
        let sway = swayCycle[(tick / swayPeriodTicks + index) % swayCycle.count]
        let angle = frond.angleDegrees * .pi / 180
        let reach = (x: cos(angle) * frond.length, y: -sin(angle) * frond.length)
        let droop = frond.droop + sway
        let samples = Int(frond.length * 2)
        let upper = frond.isBack ? IslandPalette.leafBack : IslandPalette.leaf
        let lower = frond.isBack ? IslandPalette.leafBackDark : IslandPalette.leafDark
        let spine = frond.isBack ? IslandPalette.leafDark : IslandPalette.leafLight
        var spinePoints: [PixelPoint] = []

        for step in 0...samples {
            let t = Double(step) / Double(samples)
            let px = Double(crown.x) + reach.x * t
            let py = Double(crown.y) + reach.y * t + droop * t * t
            let tangent = (x: reach.x, y: reach.y + 2 * droop * t)
            let norm = max(0.001, (tangent.x * tangent.x + tangent.y * tangent.y).squareRoot())
            // Normal apontando para cima (y negativo).
            var normal = (x: -tangent.y / norm, y: tangent.x / norm)
            if normal.y > 0 { normal = (x: -normal.x, y: -normal.y) }

            let taper = pow(sin(.pi * min(1, 0.06 + t * 0.94)), 0.55)
            let notch = step % serrationPeriod == serrationPeriod - 1 ? serrationDepth : 0
            let length = max(0, frond.leaflet * taper - notch)
            let origin = PixelPoint(x: Int(px.rounded()), y: Int(py.rounded()))
            spinePoints.append(origin)

            let up = PixelPoint(x: Int((px + normal.x * length * upperLeafletShare).rounded()),
                                y: Int((py + normal.y * length * upperLeafletShare).rounded()))
            let down = PixelPoint(x: Int((px - normal.x * length).rounded()),
                                  y: Int((py - normal.y * length + length * leafletSag).rounded()))
            layer.line(from: origin, to: down, color: lower)
            layer.line(from: origin, to: up, color: upper)
        }
        for point in spinePoints { layer[point.x, point.y] = spine }
        return layer.outlined(with: IslandPalette.leafOutline)
    }

    // MARK: Coconuts

    private static let coconutSprite = PixelSprite([
        ".XXX.",
        "XLccX",
        "XcccX",
        "XcccX",
        ".XXX.",
    ], palette: [
        "X": IslandPalette.outline, "c": IslandPalette.coconut, "L": IslandPalette.coconutLight,
    ])

    private static func coconutLayer(crown: PixelPoint) -> PixelCanvas {
        var layer = PixelCanvas(width: layerSize, height: layerSize)
        for offset in coconutOffsets {
            layer.draw(coconutSprite, x: crown.x + offset.x - coconutSprite.width / 2, y: crown.y + offset.y)
        }
        return layer
    }
}
