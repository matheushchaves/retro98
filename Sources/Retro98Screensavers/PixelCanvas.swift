import CoreGraphics
import Foundation

// MARK: - Pixel primitives
//
// O protetor Ilha Deserta é pintado num framebuffer de baixa resolução (1 elemento =
// 1 pixel virtual) e só depois ampliado sem interpolação. Assim tudo — fundo
// procedural, dithering, sprites — compartilha a mesma grade de pixels.

/// Cor opaca no formato 0xFFRRGGBB; `PixelCanvas.clear` (0) = transparente.
typealias PixelColor = UInt32

struct PixelPoint: Equatable {
    var x: Int
    var y: Int

    static func + (lhs: PixelPoint, rhs: PixelPoint) -> PixelPoint {
        PixelPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y)
    }
}

/// Sprite imutável descrito como linhas de texto (1 caractere = 1 pixel).
struct PixelSprite {
    let width: Int
    let height: Int
    let pixels: [PixelColor]

    /// Caracteres ausentes em `palette` (ex.: ".") ficam transparentes.
    init(_ rows: [String], palette: [Character: PixelColor]) {
        let widest = rows.map(\.count).max() ?? 0
        width = widest
        height = rows.count
        pixels = rows.flatMap { row -> [PixelColor] in
            let colors = row.map { palette[$0] ?? PixelCanvas.clear }
            return colors + Array(repeating: PixelCanvas.clear, count: widest - colors.count)
        }
    }

    func color(x: Int, y: Int) -> PixelColor { pixels[y * width + x] }
}

/// Framebuffer de pixels virtuais; y = 0 é o topo.
struct PixelCanvas {
    static let clear: PixelColor = 0
    private static let bytesPerPixel = 4
    private static let bitsPerComponent = 8

    let width: Int
    let height: Int
    private(set) var pixels: [PixelColor]

    init(width: Int, height: Int, fill: PixelColor = PixelCanvas.clear) {
        self.width = max(1, width)
        self.height = max(1, height)
        pixels = Array(repeating: fill, count: self.width * self.height)
    }

    /// Leitura fora dos limites devolve transparente; escrita fora é ignorada.
    subscript(x: Int, y: Int) -> PixelColor {
        get {
            guard x >= 0, y >= 0, x < width, y < height else { return Self.clear }
            return pixels[y * width + x]
        }
        set {
            guard x >= 0, y >= 0, x < width, y < height else { return }
            pixels[y * width + x] = newValue
        }
    }

    mutating func fillRect(x: Int, y: Int, width w: Int, height h: Int, color: PixelColor) {
        for py in y..<(y + h) {
            for px in x..<(x + w) { self[px, py] = color }
        }
    }

    /// Linha de Bresenham com pincel quadrado de `brush` pixels.
    mutating func line(from a: PixelPoint, to b: PixelPoint, color: PixelColor, brush: Int = 1) {
        let dx = abs(b.x - a.x), dy = -abs(b.y - a.y)
        let sx = a.x < b.x ? 1 : -1, sy = a.y < b.y ? 1 : -1
        var err = dx + dy
        var p = a
        while true {
            stamp(at: p, color: color, brush: brush)
            if p == b { break }
            let e2 = 2 * err
            if e2 >= dy { err += dy; p.x += sx }
            if e2 <= dx { err += dx; p.y += sy }
        }
    }

    mutating func stamp(at p: PixelPoint, color: PixelColor, brush: Int) {
        let lead = brush / 2
        fillRect(x: p.x - lead, y: p.y - lead, width: brush, height: brush, color: color)
    }

    /// Elipse preenchida; `level` < 1 aplica dithering ordenado.
    mutating func fillEllipse(cx: Double, cy: Double, rx: Double, ry: Double,
                              color: PixelColor, level: Double = 1) {
        guard rx > 0, ry > 0 else { return }
        for py in Int((cy - ry).rounded(.down))...Int((cy + ry).rounded(.up)) {
            for px in Int((cx - rx).rounded(.down))...Int((cx + rx).rounded(.up)) {
                let nx = (Double(px) - cx) / rx, ny = (Double(py) - cy) / ry
                guard nx * nx + ny * ny <= 1 else { continue }
                if PixelDither.isOn(x: px, y: py, level: level) { self[px, py] = color }
            }
        }
    }

    mutating func draw(_ sprite: PixelSprite, x: Int, y: Int, flipped: Bool = false) {
        for sy in 0..<sprite.height {
            for sx in 0..<sprite.width {
                let color = sprite.color(x: flipped ? sprite.width - 1 - sx : sx, y: sy)
                if color != Self.clear { self[x + sx, y + sy] = color }
            }
        }
    }

    /// Compõe outra camada por cima (pixels transparentes são pulados).
    mutating func draw(_ layer: PixelCanvas, x: Int, y: Int, flipped: Bool = false) {
        for ly in 0..<layer.height {
            for lx in 0..<layer.width {
                let color = layer[flipped ? layer.width - 1 - lx : lx, ly]
                if color != Self.clear { self[x + lx, y + ly] = color }
            }
        }
    }

    /// Cópia com contorno de 1 pixel (vizinhança em cruz) ao redor do conteúdo.
    func outlined(with color: PixelColor) -> PixelCanvas {
        var result = self
        for y in 0..<height {
            for x in 0..<width where self[x, y] == Self.clear {
                let touches = self[x - 1, y] != Self.clear || self[x + 1, y] != Self.clear
                    || self[x, y - 1] != Self.clear || self[x, y + 1] != Self.clear
                if touches { result[x, y] = color }
            }
        }
        return result
    }

    func makeImage() -> CGImage? {
        let data = pixels.withUnsafeBufferPointer { Data(buffer: $0) }
        guard let provider = CGDataProvider(data: data as CFData),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let info = CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
        return CGImage(width: width, height: height,
                       bitsPerComponent: Self.bitsPerComponent,
                       bitsPerPixel: Self.bitsPerComponent * Self.bytesPerPixel,
                       bytesPerRow: width * Self.bytesPerPixel,
                       space: space, bitmapInfo: CGBitmapInfo(rawValue: info),
                       provider: provider, decode: nil,
                       shouldInterpolate: false, intent: .defaultIntent)
    }
}

// MARK: - Dithering

enum PixelDither {
    private static let matrixSide = 4
    private static let bayer: [Double] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5]

    /// Dithering ordenado (Bayer 4×4): `level` 0 = nunca, 1 = sempre.
    static func isOn(x: Int, y: Int, level: Double) -> Bool {
        let mask = matrixSide - 1
        let threshold = bayer[(y & mask) * matrixSide + (x & mask)] + 0.5
        return level * Double(bayer.count) > threshold
    }

    /// Escolhe uma cor da rampa em `t` (0…1), pontilhando entre vizinhas.
    static func ramp(_ colors: [PixelColor], t: Double, x: Int, y: Int) -> PixelColor {
        guard let last = colors.last else { return PixelCanvas.clear }
        let position = min(max(t, 0), 1) * Double(colors.count - 1)
        let base = Int(position)
        guard base < colors.count - 1 else { return last }
        return isOn(x: x, y: y, level: position - Double(base)) ? colors[base + 1] : colors[base]
    }

    /// Hash determinístico não-negativo para espalhar detalhes (brilhos, grãos).
    static func hash(_ a: Int, _ b: Int) -> Int {
        var h = UInt32(truncatingIfNeeded: a) &* 0x9E37_79B1
        h ^= UInt32(truncatingIfNeeded: b) &* 0x85EB_CA6B
        h ^= h >> 15
        h = h &* 0xC2B2_AE35
        h ^= h >> 13
        return Int(h & 0x7FFF_FFFF)
    }
}
