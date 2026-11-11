import CoreGraphics

public enum FileIconKind: CaseIterable, Sendable {
    case folder, document, image, audio, video, archive, text, hardDisk, removableDisk, networkDisk,
         myComputer, myDocuments, recycleBinEmpty, recycleBinFull, desktop
}

/// Original file, place and toolbar icons. Each kind is sketched once on a 16-unit grid and
/// drawn at 16 or 32 pixels; outlines stay 1 pixel at both sizes, so 32 keeps crisp edges.
public enum FileIcons {
    private static let yellow = PixelIcon.color("Y"), olive = PixelIcon.color("O"), teal = PixelIcon.color("T")
    private static let cyan = PixelIcon.color("C"), green = PixelIcon.color("E"), lime = PixelIcon.color("L")
    private static let navy = PixelIcon.color("N"), blue = PixelIcon.color("B"), red = PixelIcon.color("R")
    private static let gray = Palette.face, dark = Palette.shadow

    public static func icon(_ kind: FileIconKind, size: Int) -> PixelIcon {
        PixelIcon(width: size, height: size) { context in
            sketch(kind, Sketch(context: context, scale: CGFloat(size) / 16))
        }
    }

    // MARK: Toolbar (16×16)

    public static let back = arrow(pointing: .left)
    public static let forward = arrow(pointing: .right)
    public static let up = toolbarIcon { s in
        drawFolder(s, top: 5)
        s.fill(7, 1, 2, 7, .black)
        s.fill(5, 3, 6, 1, .black)
        s.fill(6, 2, 4, 1, .black)
    }
    public static let cut = toolbarIcon { s in
        s.box(2, 9, 5, 5, fill: .white)
        s.box(9, 9, 5, 5, fill: .white)
        s.fill(5, 2, 1, 7, .black); s.fill(6, 4, 1, 3, .black)
        s.fill(10, 2, 1, 7, .black); s.fill(9, 4, 1, 3, .black)
    }
    public static let copy = toolbarIcon { s in
        s.box(1, 1, 8, 10, fill: .white)
        s.box(6, 5, 8, 10, fill: .white)
        for y in stride(from: 8, to: 14, by: 2) { s.fill(8, y, 4, 1, dark) }
    }
    public static let paste = toolbarIcon { s in
        s.box(2, 2, 10, 13, fill: olive)
        s.box(5, 1, 4, 3, fill: gray)
        s.box(7, 6, 7, 9, fill: .white)
        for y in stride(from: 8, to: 14, by: 2) { s.fill(9, y, 3, 1, dark) }
    }
    public static let undo = toolbarIcon { s in
        s.fill(4, 5, 8, 2, navy); s.fill(11, 6, 2, 6, navy); s.fill(6, 11, 6, 2, navy)
        s.fill(2, 5, 1, 2, navy); s.fill(3, 3, 1, 6, navy); s.fill(4, 2, 1, 8, navy)
    }
    public static let delete = toolbarIcon { s in
        for i in 0..<10 {
            s.fill(3 + i, 3 + i, 2, 1, red)
            s.fill(12 - i, 3 + i, 2, 1, red)
        }
    }
    public static let properties = toolbarIcon { s in
        s.box(3, 1, 10, 14, fill: .white)
        s.fill(5, 4, 6, 1, dark); s.fill(5, 6, 6, 1, dark)
        s.box(6, 8, 6, 6, fill: gray)
        s.fill(8, 10, 2, 2, navy)
    }
    public static let views = toolbarIcon { s in
        for (x, y) in [(1, 2), (9, 2), (1, 9), (9, 9)] {
            s.box(CGFloat(x), CGFloat(y), 6, 5, fill: .white)
            s.fill(CGFloat(x) + 1, CGFloat(y) + 1, 4, 2, navy)
        }
    }

    /// The Explorer's own icon (app icon and quick launch): a folder with a magnifying glass.
    public static let explorerApp = PixelIcon(width: 32, height: 32) { drawExplorer(Sketch(context: $0, scale: 2)) }
    public static let explorerAppSmall = PixelIcon(width: 16, height: 16) { drawExplorer(Sketch(context: $0, scale: 1)) }

    private static func drawExplorer(_ s: Sketch) {
        drawFolder(s, top: 3)
        s.box(8, 6, 7, 7, fill: cyan)
        s.fill(9, 7, 2, 2, .white)
        s.fill(13, 12, 2, 2, .black)
        s.fill(14, 13, 2, 2, .black)
    }

    // MARK: Sketches

    private static func sketch(_ kind: FileIconKind, _ s: Sketch) {
        switch kind {
        case .folder: drawFolder(s, top: 3)
        case .document: drawPage(s, lineColor: dark)
        case .text: drawPage(s, lineColor: .black)
        case .image:
            s.box(1, 2, 14, 12, fill: .white)
            s.fill(2, 3, 12, 10, cyan)
            s.fill(10, 4, 2, 2, yellow)
            for (row, (x, width)) in [(6, 1), (5, 3), (4, 5), (3, 7), (2, 9), (2, 12)].enumerated() {
                s.fill(CGFloat(x), CGFloat(7 + row), CGFloat(width), 1, green)
            }
        case .audio:
            s.fill(7, 2, 1, 9, .black); s.fill(12, 2, 1, 8, .black); s.fill(7, 2, 6, 2, .black)
            s.box(4, 10, 4, 3, fill: navy); s.box(9, 9, 4, 3, fill: navy)
        case .video:
            s.box(1, 3, 14, 10, fill: .black)
            for x in stride(from: 2, to: 14, by: 3) { s.fill(CGFloat(x), 4, 1, 1, .white); s.fill(CGFloat(x), 11, 1, 1, .white) }
            s.fill(2, 5, 12, 6, blue)
        case .archive:
            s.box(2, 2, 12, 12, fill: yellow)
            for y in 2..<14 { s.fill(7, CGFloat(y), 2, 1, y % 2 == 0 ? .black : .white) }
            s.fill(3, 12, 10, 1, olive)
        case .hardDisk:
            drawDrive(s, top: 6)
        case .removableDisk:
            s.box(6, 1, 4, 3, fill: gray)
            s.box(4, 4, 8, 11, fill: navy)
            s.fill(5, 7, 6, 1, .white)
        case .networkDisk:
            drawDrive(s, top: 2)
            s.fill(7, 7, 2, 4, .black)
            s.fill(2, 11, 12, 1, .black); s.fill(2, 11, 1, 3, .black); s.fill(13, 11, 1, 3, .black)
        case .myComputer:
            s.box(2, 1, 12, 9, fill: gray)
            s.fill(4, 3, 8, 5, teal)
            s.fill(6, 10, 4, 1, dark)
            s.box(1, 11, 14, 4, fill: gray)
            for x in stride(from: 3, to: 13, by: 2) { s.fill(CGFloat(x), 12, 1, 1, dark) }
        case .myDocuments:
            s.box(7, 1, 7, 8, fill: .white)
            s.fill(8, 3, 5, 1, dark); s.fill(8, 5, 5, 1, dark)
            drawFolder(s, top: 5)
        case .recycleBinEmpty:
            drawBin(s)
        case .recycleBinFull:
            drawBin(s)
            s.box(4, 0, 4, 3, fill: .white); s.box(8, 1, 4, 2, fill: .white); s.fill(6, 3, 4, 1, .white)
        case .desktop:
            s.box(0, 2, 16, 12, fill: teal)
            s.box(2, 4, 3, 3, fill: yellow); s.box(2, 8, 3, 3, fill: .white)
            s.fill(1, 12, 14, 1, gray); s.fill(1, 12, 3, 1, .white)
        }
    }

    private static func drawFolder(_ s: Sketch, top: CGFloat) {
        s.box(1, top, 6, 3, fill: yellow)
        s.box(0, top + 2, 15, 13 - top, fill: yellow)
        s.fill(1, top + 3, 1, 11 - top, .white)
        s.fill(1, 14, 13, 1, olive)
    }

    private static func drawPage(_ s: Sketch, lineColor: PixelColor) {
        s.box(3, 1, 10, 14, fill: .white)
        s.fill(11, 1, 2, 2, dark)
        for y in stride(from: 4, to: 14, by: 2) { s.fill(5, CGFloat(y), 6, 1, lineColor) }
    }

    private static func drawDrive(_ s: Sketch, top: CGFloat) {
        s.box(0, top, 16, 5, fill: gray)
        s.fill(1, top + 1, 14, 1, .white)
        s.fill(12, top + 3, 2, 1, lime)
    }

    private static func drawBin(_ s: Sketch) {
        s.box(3, 2, 10, 2, fill: gray)
        s.box(4, 4, 8, 11, fill: gray)
        for x in stride(from: 6, to: 11, by: 2) { s.fill(CGFloat(x), 6, 1, 7, dark) }
    }

    private enum Direction { case left, right }

    private static func arrow(pointing direction: Direction) -> PixelIcon {
        toolbarIcon { s in
            let color = direction == .left ? navy : navy
            for i in 0..<5 {
                let x = direction == .left ? CGFloat(2 + i) : CGFloat(13 - i)
                s.fill(x, CGFloat(7 - i), 1, CGFloat(2 + i * 2), color)
            }
            s.fill(direction == .left ? 7 : 3, 6, 6, 4, color)
        }
    }

    private static func toolbarIcon(_ draw: (Sketch) -> Void) -> PixelIcon {
        PixelIcon(width: 16, height: 16) { draw(Sketch(context: $0, scale: 1)) }
    }
}

/// Drawing on a 16-unit grid scaled to the icon size; box outlines are always 1 pixel.
private struct Sketch {
    let context: CGContext
    let scale: CGFloat

    func fill(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, _ color: PixelColor) {
        Bevel.fill(CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale), color: color, context: context)
    }

    func fill(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: PixelColor) {
        fill(CGFloat(x), CGFloat(y), CGFloat(width), CGFloat(height), color)
    }

    func box(_ x: Int, _ y: Int, _ width: Int, _ height: Int, fill color: PixelColor, outline: PixelColor = .black) {
        box(CGFloat(x), CGFloat(y), CGFloat(width), CGFloat(height), fill: color, outline: outline)
    }

    func box(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat, fill color: PixelColor, outline: PixelColor = .black) {
        let rect = CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
        Bevel.fill(rect, color: outline, context: context)
        Bevel.fill(rect.insetBy(dx: 1, dy: 1), color: color, context: context)
    }
}
