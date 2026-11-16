import CoreGraphics

/// The Browser's own icon and its toolbar icons: original pixel art on FileIcons' 16-unit grid.
public enum BrowserIcons {
    private static let gray = Palette.face, dark = Palette.shadow
    private static let navy = PixelIcon.color("N"), blue = PixelIcon.color("B"), green = PixelIcon.color("E")
    private static let yellow = PixelIcon.color("Y"), red = PixelIcon.color("R")
    /// A 12-row disk on the 16-unit grid: each row's first column and width, from row 2 down.
    private static let disk: [(x: Int, width: Int)] = [(5, 6), (3, 10), (2, 12), (1, 14), (1, 14), (1, 14), (1, 14), (1, 14), (1, 14),
                                                       (2, 12), (3, 10), (5, 6)]

    /// A globe: blue seas and green land.
    public static let app = PixelIcon(width: 32, height: 32) { drawGlobe(Sketch(context: $0, scale: 2)) }
    public static let appSmall = PixelIcon(width: 16, height: 16) { drawGlobe(Sketch(context: $0, scale: 1)) }

    /// A red cross over a page.
    public static let stop = icon { s in
        drawSheet(s)
        for step in 0..<6 {
            s.fill(5 + step, 5 + step, 2, 1, red)
            s.fill(10 - step, 5 + step, 2, 1, red)
        }
    }

    /// Two arrows going round.
    public static let refresh = icon { s in
        s.fill(4, 3, 8, 2, green)
        s.fill(11, 3, 2, 5, green)
        s.fill(9, 8, 6, 1, green)
        s.fill(10, 9, 4, 1, green)
        s.fill(11, 10, 2, 1, green)
        s.fill(4, 11, 8, 2, navy)
        s.fill(3, 8, 2, 5, navy)
        s.fill(1, 7, 6, 1, navy)
        s.fill(2, 6, 4, 1, navy)
        s.fill(3, 5, 2, 1, navy)
    }

    /// A small house.
    public static let home = icon { s in
        for step in 0..<6 { s.fill(7 - step, 2 + step, 2 + step * 2, 1, red) }
        s.box(3, 8, 10, 7, fill: .white)
        s.fill(7, 10, 2, 4, navy)
    }

    /// A folder with a star.
    public static let favorites = icon { s in
        s.box(1, 2, 6, 3, fill: yellow)
        s.box(1, 4, 14, 10, fill: yellow)
        s.fill(7, 6, 2, 6, navy)
        s.fill(5, 8, 6, 2, navy)
        s.fill(6, 7, 4, 4, navy)
    }

    /// A clock.
    public static let history = icon { s in
        drawDisk(s, outline: .black, fill: .white)
        s.fill(8, 4, 1, 5, .black)
        s.fill(8, 8, 3, 1, .black)
        s.fill(8, 3, 1, 1, red)
    }

    /// A sheet with lines of text.
    public static let page = icon { s in
        drawSheet(s)
        s.fill(5, 5, 4, 1, navy)
        s.fill(5, 8, 6, 1, dark)
        s.fill(5, 10, 6, 1, dark)
        s.fill(5, 12, 4, 1, dark)
    }

    private static func icon(_ draw: (Sketch) -> Void) -> PixelIcon {
        PixelIcon(width: 16, height: 16) { draw(Sketch(context: $0, scale: 1)) }
    }

    private static func drawSheet(_ s: Sketch) {
        s.box(3, 1, 10, 14, fill: .white)
        s.fill(10, 1, 3, 3, gray)
        s.fill(10, 1, 1, 3, .black)
        s.fill(10, 3, 3, 1, .black)
    }

    private static func drawDisk(_ s: Sketch, outline: PixelColor, fill: PixelColor) {
        for (row, span) in disk.enumerated() { s.fill(span.x, 2 + row, span.width, 1, outline) }
        for (row, span) in disk.enumerated() where row > 0 && row < disk.count - 1 {
            s.fill(span.x + 1, 2 + row, span.width - 2, 1, fill)
        }
    }

    private static func drawGlobe(_ s: Sketch) {
        drawDisk(s, outline: navy, fill: blue)
        s.fill(4, 4, 3, 2, green)
        s.fill(5, 6, 3, 3, green)
        s.fill(6, 9, 2, 2, green)
        s.fill(10, 4, 3, 1, green)
        s.fill(9, 7, 4, 3, green)
        s.fill(10, 10, 2, 2, green)
    }
}
