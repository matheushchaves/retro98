import Foundation

// MARK: - Backdrop (céu, nuvens, mar)

/// Nuvem cúmulo: círculos sobrepostos cortados numa base reta.
private struct CloudShape {
    struct Puff {
        let dx: Double
        let dy: Double
        let radius: Double
    }

    /// Posição inicial como fração da largura da tela.
    let startFraction: Double
    /// Altura da base como fração da altura do céu.
    let baseFraction: Double
    /// Ticks necessários para a nuvem andar 1 pixel.
    let ticksPerPixel: Int
    let puffs: [Puff]

    var halfWidth: Int {
        Int(puffs.map { abs($0.dx) + $0.radius }.max() ?? 0) + 1
    }

    func contains(dx: Double, dy: Double) -> Bool {
        guard dy <= 0 else { return false }
        return puffs.contains { puff in
            let ox = dx - puff.dx, oy = dy - puff.dy
            return ox * ox + oy * oy <= puff.radius * puff.radius
        }
    }
}

enum IslandBackdrop {
    private static let clouds: [CloudShape] = [
        CloudShape(startFraction: 0.16, baseFraction: 0.34, ticksPerPixel: 10, puffs: [
            .init(dx: -22, dy: -3, radius: 6), .init(dx: -12, dy: -7, radius: 9),
            .init(dx: 1, dy: -10, radius: 12), .init(dx: 14, dy: -6, radius: 9),
            .init(dx: 24, dy: -3, radius: 5),
        ]),
        CloudShape(startFraction: 0.86, baseFraction: 0.20, ticksPerPixel: 14, puffs: [
            .init(dx: -14, dy: -3, radius: 5), .init(dx: -5, dy: -6, radius: 8),
            .init(dx: 6, dy: -5, radius: 7), .init(dx: 15, dy: -2, radius: 4),
        ]),
        CloudShape(startFraction: 0.48, baseFraction: 0.13, ticksPerPixel: 18, puffs: [
            .init(dx: -8, dy: -2, radius: 4), .init(dx: 0, dy: -4, radius: 6),
            .init(dx: 9, dy: -2, radius: 4),
        ]),
    ]

    /// Banco de nuvens distante colado ao horizonte: (fração x, meia-largura, altura).
    private static let farClouds: [(fraction: Double, halfWidth: Int, height: Int)] = [
        (0.06, 16, 4), (0.24, 9, 3), (0.40, 22, 5), (0.93, 14, 4),
    ]

    private static let cloudShadeRows = 2.0
    private static let cloudDitherRows = 5.0
    private static let cloudRimDepth = 2.0

    static func draw(into canvas: inout PixelCanvas, layout: IslandLayout, tick: Int) {
        drawSky(into: &canvas, layout: layout)
        drawFarClouds(into: &canvas, layout: layout)
        for cloud in clouds { draw(cloud, into: &canvas, layout: layout, tick: tick) }
        drawSea(into: &canvas, layout: layout)
        drawWaves(into: &canvas, layout: layout, tick: tick)
    }

    // MARK: Sky

    private static func drawSky(into canvas: inout PixelCanvas, layout: IslandLayout) {
        for y in 0..<layout.horizonY {
            let t = Double(y) / Double(layout.horizonY)
            for x in 0..<layout.width {
                canvas[x, y] = PixelDither.ramp(IslandPalette.sky, t: t, x: x, y: y)
            }
        }
    }

    private static func drawFarClouds(into canvas: inout PixelCanvas, layout: IslandLayout) {
        for cloud in farClouds {
            let cx = Double(layout.width) * cloud.fraction
            canvas.fillEllipse(cx: cx, cy: Double(layout.horizonY),
                               rx: Double(cloud.halfWidth), ry: Double(cloud.height),
                               color: IslandPalette.cloudFar)
            canvas.fillEllipse(cx: cx - Double(cloud.halfWidth) * 0.3, cy: Double(layout.horizonY),
                               rx: Double(cloud.halfWidth) * 0.5, ry: Double(cloud.height) + 2,
                               color: IslandPalette.cloudFar)
        }
    }

    private static func draw(_ cloud: CloudShape, into canvas: inout PixelCanvas,
                             layout: IslandLayout, tick: Int) {
        let span = layout.width + cloud.halfWidth * 2
        let start = Int(Double(layout.width) * cloud.startFraction)
        let cx = (start + tick / cloud.ticksPerPixel + cloud.halfWidth) % span - cloud.halfWidth
        let baseY = Int(Double(layout.horizonY) * cloud.baseFraction)
        let top = Int(cloud.puffs.map { $0.dy - $0.radius }.min() ?? 0) - 1

        for dy in top...0 {
            for dx in -cloud.halfWidth...cloud.halfWidth {
                guard cloud.contains(dx: Double(dx), dy: Double(dy)) else { continue }
                let x = cx + dx, y = baseY + dy
                canvas[x, y] = cloudColor(cloud, dx: Double(dx), dy: Double(dy), x: x, y: y)
            }
        }
    }

    private static func cloudColor(_ cloud: CloudShape, dx: Double, dy: Double,
                                   x: Int, y: Int) -> PixelColor {
        let depth = -dy
        if depth < cloudShadeRows { return IslandPalette.cloudShade }
        if depth < cloudDitherRows {
            let level = (cloudDitherRows - depth) / (cloudDitherRows - cloudShadeRows)
            return PixelDither.isOn(x: x, y: y, level: level * 0.8)
                ? IslandPalette.cloudShade : IslandPalette.cloudBody
        }
        // Borda superior iluminada: logo acima deste pixel já é céu.
        let isRim = !cloud.contains(dx: dx - 1, dy: dy - cloudRimDepth)
        return isRim ? IslandPalette.cloudLit : IslandPalette.cloudBody
    }

    // MARK: Sea

    private static func drawSea(into canvas: inout PixelCanvas, layout: IslandLayout) {
        let depth = Double(layout.height - layout.horizonY)
        for y in layout.horizonY..<layout.height {
            let t = Double(y - layout.horizonY) / depth
            for x in 0..<layout.width {
                canvas[x, y] = PixelDither.ramp(IslandPalette.sea, t: t, x: x, y: y)
            }
        }
        canvas.fillRect(x: 0, y: layout.horizonY, width: layout.width, height: 1,
                        color: IslandPalette.horizonLine)
    }

    /// Faixas de ondulação: traços claros que deslizam e traços escuros de vale.
    /// Ficam mais longos e espaçados perto do observador (perspectiva).
    private static func drawWaves(into canvas: inout PixelCanvas, layout: IslandLayout, tick: Int) {
        let depth = Double(layout.height - layout.horizonY)
        var y = layout.horizonY + 2
        var band = 0
        while y < layout.height {
            let t = Double(y - layout.horizonY) / depth
            drawWaveBand(into: &canvas, layout: layout, y: y, t: t, band: band, tick: tick)
            y += 2 + Int(t * 5)
            band += 1
        }
    }

    private static func drawWaveBand(into canvas: inout PixelCanvas, layout: IslandLayout,
                                     y: Int, t: Double, band: Int, tick: Int) {
        let cell = 10 + Int(t * 26)
        let dash = 3 + Int(t * 12)
        let direction = band.isMultiple(of: 2) ? 1 : -1
        let drift = direction * tick / (6 - min(3, Int(t * 4)))
        let phase = tick / 8

        for cellIndex in -1...(layout.width / cell + 1) {
            let seed = PixelDither.hash(cellIndex - drift / cell, band)
            guard seed % 3 != 0 else { continue }
            let x = cellIndex * cell + seed % cell + drift % cell
            let length = max(2, dash - (seed / 7) % 4)
            let sparkles = (seed / 31 + phase) % 5 == 0
            canvas.fillRect(x: x, y: y, width: length, height: 1, color: IslandPalette.seaGlint)
            if sparkles {
                canvas.fillRect(x: x + 1, y: y, width: max(1, length / 3), height: 1,
                                color: IslandPalette.seaGlintBright)
            }
            canvas.fillRect(x: x + length / 2, y: y + 1, width: length, height: 1,
                            color: IslandPalette.seaTrough)
        }
    }
}
