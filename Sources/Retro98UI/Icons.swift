import CoreText
import Foundation

/// Original Retro98 pixel art. 16×16 icons are ASCII maps; 32×32 icons are drawn with
/// aliased shapes. None of them copy Microsoft artwork.
public enum Icons {
    // MARK: 16×16

    /// A tiny monitor showing a window on a teal desktop.
    public static let startLogo = PixelIcon(rows: [
        "................",
        ".WWWWWWWWWWWWWK.",
        ".WGGGGGGGGGGGDK.",
        ".WGKKKKKKKKKGDK.",
        ".WGKTTTTTTTKGDK.",
        ".WGKTNNNNTTKGDK.",
        ".WGKTWWWWTTKGDK.",
        ".WGKTWWWWTTKGDK.",
        ".WGKTTTTTTTKGDK.",
        ".WGKKKKKKKKKGDK.",
        ".WGGGGGGGGGGGDK.",
        ".WDDDDDDDDDDDDK.",
        ".KKKKKKKKKKKKKK.",
        ".....KGGGGK.....",
        "...KKKKKKKKKK...",
        "................",
    ])

    public static let folder = PixelIcon(rows: [
        "................",
        "................",
        "..KKKKK.........",
        ".KWYYYYK........",
        "KWYYYYYYKKKKKKK.",
        "KWYYYYYYYYYYYYYK",
        "KWYYYYYYYYYYYYYK",
        "KWYYYYYYYYYYYYYK",
        "KWYYYYYYYYYYYYYK",
        "KWYYYYYYYYYYYYYK",
        "KWYYYYYYYYYYYYYK",
        "KWYYYYYYYYYYYYYK",
        "KOOOOOOOOOOOOOOK",
        "KKKKKKKKKKKKKKKK",
        "................",
        "................",
    ])

    public static let document = PixelIcon(rows: [
        "..KKKKKKKKK.....",
        "..KWWWWWWWKK....",
        "..KWWWWWWWKWK...",
        "..KWWWWWWWKKKK..",
        "..KWWWWWWWWWWK..",
        "..KWDDDDDDDWWK..",
        "..KWWWWWWWWWWK..",
        "..KWDDDDDDDWWK..",
        "..KWWWWWWWWWWK..",
        "..KWDDDDDDDWWK..",
        "..KWWWWWWWWWWK..",
        "..KWDDDDDWWWWK..",
        "..KWWWWWWWWWWK..",
        "..KWWWWWWWWWWK..",
        "..KKKKKKKKKKKK..",
        "................",
    ])

    public static let application = PixelIcon(rows: [
        "................",
        "................",
        ".KKKKKKKKKKKKKK.",
        ".KNNNNNNNNNNWNK.",
        ".KNNNNNNNNNNNNK.",
        ".KKKKKKKKKKKKKK.",
        ".KWWWWWWWWWWWWK.",
        ".KWWWWWWWWWWWWK.",
        ".KWWWWWWWWWWWWK.",
        ".KWWWWWWWWWWWWK.",
        ".KWWWWWWWWWWWWK.",
        ".KWWWWWWWWWWWWK.",
        ".KKKKKKKKKKKKKK.",
        "................",
        "................",
        "................",
    ])

    /// A gray panel with two sliders.
    public static let systemSettings = PixelIcon(rows: [
        "................",
        ".KKKKKKKKKKKKKK.",
        ".KWWWWWWWWWWWDK.",
        ".KWGGGGGGGGGGDK.",
        ".KWGGNNGGGGGGDK.",
        ".KWKKNNKKKKKKDK.",
        ".KWGGNNGGGGGGDK.",
        ".KWGGGGGGGGGGDK.",
        ".KWGGGGGGGNNGDK.",
        ".KWKKKKKKKNNKDK.",
        ".KWGGGGGGGNNGDK.",
        ".KWGGGGGGGGGGDK.",
        ".KDDDDDDDDDDDDK.",
        ".KKKKKKKKKKKKKK.",
        "................",
        "................",
    ])

    public static let batteryFull = battery(fill: "LLLLLLLLLLL")
    public static let batteryHalf = battery(fill: "LLLLLLWWWWW")
    public static let batteryLow = battery(fill: "RRWWWWWWWWW")
    public static let batteryCharging = PixelIcon(rows: [
        "................",
        "................",
        "................",
        "................",
        ".KKKKKKKKKKKKK..",
        ".KLLLLLLKLLLLK..",
        ".KLLLLLKKLLLLKK.",
        ".KLLLLKKKKKLLKK.",
        ".KLLLLLKKLLLLKK.",
        ".KLLLLLKLLLLLKK.",
        ".KLLLLLLLLLLLK..",
        ".KKKKKKKKKKKKK..",
        "................",
        "................",
        "................",
        "................",
    ])

    public static let volume = PixelIcon(rows: [
        "................",
        "................",
        "......K.........",
        ".....KK....K....",
        "....KWK.....K...",
        "KKKKWWK..K...K..",
        "KWWWWWK...K..K..",
        "KWWWWWK...K..K..",
        "KWWWWWK...K..K..",
        "KWWWWWK...K..K..",
        "KKKKWWK..K...K..",
        "....KWK.....K...",
        ".....KK....K....",
        "......K.........",
        "................",
        "................",
    ])

    public static let volumeMuted = PixelIcon(rows: [
        "................",
        "................",
        "......K.........",
        ".....KK.........",
        "....KWK.........",
        "KKKKWWK.R...R...",
        "KWWWWWK..R.R....",
        "KWWWWWK...R.....",
        "KWWWWWK..R.R....",
        "KWWWWWK.R...R...",
        "KKKKWWK.........",
        "....KWK.........",
        ".....KK.........",
        "......K.........",
        "................",
        "................",
    ])

    // MARK: 32×32

    public static let programs = PixelIcon(width: 32, height: 32) { context in
        let paint = Painter(context: context)
        paint.folder(top: 5)
        paint.window(x: 11, y: 12, width: 16, height: 12)
    }

    public static let documents = PixelIcon(width: 32, height: 32) { context in
        let paint = Painter(context: context)
        paint.folderBack(top: 5)
        paint.page(x: 9, y: 2, width: 14, height: 18)
        paint.folderFront(top: 13)
    }

    public static let settings = PixelIcon(width: 32, height: 32) { context in
        let paint = Painter(context: context)
        paint.folder(top: 5)
        paint.sliderPanel(x: 10, y: 12, width: 18, height: 13)
    }

    /// A navy book with a yellow question mark.
    public static let help = PixelIcon(width: 32, height: 32) { context in
        let paint = Painter(context: context)
        paint.rect(7, 3, 20, 25, .white)
        paint.rect(5, 2, 20, 25, Palette.selection)
        paint.frame(5, 2, 20, 25, .black)
        paint.rect(6, 3, 2, 23, .black)
        paint.rect(25, 4, 2, 24, PixelIcon.color("D"))
        paint.rect(7, 27, 20, 1, .black)
        paint.glyph("?", size: 18, color: PixelIcon.color("Y"), centerX: 16, top: 6)
    }

    /// A window with a green "go" arrow.
    public static let run = PixelIcon(width: 32, height: 32) { context in
        let paint = Painter(context: context)
        paint.window(x: 2, y: 4, width: 28, height: 24)
        paint.triangleRight(x: 11, y: 12, height: 13, color: PixelIcon.color("E"), outline: .black)
    }

    /// A monitor with a red power symbol.
    public static let shutDown = PixelIcon(width: 32, height: 32) { context in
        let paint = Painter(context: context)
        paint.rect(4, 3, 24, 19, Palette.face)
        Bevel.draw(.raised, in: CGRect(x: 4, y: 3, width: 24, height: 19), context: context)
        paint.rect(7, 6, 18, 13, .black)
        paint.ring(x: 11, y: 7, diameter: 10, color: PixelIcon.color("R"), gapTop: true)
        paint.rect(15, 6, 2, 6, PixelIcon.color("R"))
        paint.rect(13, 22, 6, 3, Palette.shadow)
        paint.rect(8, 25, 16, 3, Palette.face)
        paint.frame(8, 25, 16, 3, .black)
    }

    public static let info = PixelIcon(width: 32, height: 32) { context in
        let paint = Painter(context: context)
        paint.disc(x: 2, y: 2, diameter: 28, fill: .white, outline: .black)
        let blue = PixelIcon.color("B")
        paint.rect(14, 7, 4, 3, blue)
        paint.rect(12, 12, 6, 2, blue)
        paint.rect(14, 12, 4, 11, blue)
        paint.rect(12, 22, 8, 2, blue)
    }

    public static let warning = PixelIcon(width: 32, height: 32) { context in
        let paint = Painter(context: context)
        paint.triangleUp(apex: CGPoint(x: 16, y: 2), base: 28, height: 27, fill: PixelIcon.color("Y"), outline: .black)
        paint.rect(15, 10, 3, 10, .black)
        paint.rect(15, 22, 3, 3, .black)
    }

    public static let error = PixelIcon(width: 32, height: 32) { context in
        let paint = Painter(context: context)
        paint.disc(x: 2, y: 2, diameter: 28, fill: PixelIcon.color("R"), outline: PixelIcon.color("M"))
        paint.line(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 22, y: 22), width: 3, color: .white)
        paint.line(from: CGPoint(x: 22, y: 10), to: CGPoint(x: 10, y: 22), width: 3, color: .white)
    }

    public static let question = PixelIcon(width: 32, height: 32) { context in
        let paint = Painter(context: context)
        paint.disc(x: 2, y: 2, diameter: 28, fill: .white, outline: .black)
        paint.glyph("?", size: 20, color: PixelIcon.color("B"), centerX: 16, top: 5)
    }

    // MARK: Helpers

    private static func battery(fill: String) -> PixelIcon {
        let body = ".K\(fill)K"
        return PixelIcon(rows: [
            "................", "................", "................", "................",
            ".KKKKKKKKKKKKK..",
            body + "..", body + "K.", body + "K.", body + "K.", body + "K.", body + "..",
            ".KKKKKKKKKKKKK..",
            "................", "................", "................", "................",
        ])
    }
}

extension PixelIcon {
    static func color(_ character: Character) -> PixelColor { asciiPalette[character]! }
}

/// Aliased drawing helpers for 32×32 icons, in a top-left 1x canvas.
private struct Painter {
    let context: CGContext

    func rect(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: PixelColor) {
        Bevel.fill(CGRect(x: x, y: y, width: width, height: height), color: color, context: context)
    }

    func frame(_ x: Int, _ y: Int, _ width: Int, _ height: Int, _ color: PixelColor) {
        rect(x, y, width, 1, color)
        rect(x, y + height - 1, width, 1, color)
        rect(x, y, 1, height, color)
        rect(x + width - 1, y, 1, height, color)
    }

    func folderBack(top: Int) {
        let yellow = PixelIcon.color("Y")
        rect(3, top, 11, 4, yellow)
        frame(3, top, 11, 4, .black)
        rect(2, top + 3, 28, 21, yellow)
        frame(2, top + 3, 28, 21, .black)
    }

    func folderFront(top: Int) {
        let yellow = PixelIcon.color("Y")
        let height = 29 - top
        rect(2, top, 28, height, yellow)
        frame(2, top, 28, height, .black)
        rect(3, top + 1, 1, height - 2, .white)
        rect(3, top + height - 2, 26, 1, PixelIcon.color("O"))
    }

    func folder(top: Int) {
        folderBack(top: top)
        rect(3, top + 4, 1, 19, .white)
        rect(3, top + 22, 26, 1, PixelIcon.color("O"))
    }

    func window(x: Int, y: Int, width: Int, height: Int) {
        rect(x, y, width, height, Palette.face)
        Bevel.draw(.window, in: CGRect(x: x, y: y, width: width, height: height), context: context)
        rect(x + 2, y + 2, width - 4, 4, Palette.selection)
        rect(x + width - 5, y + 3, 2, 2, Palette.face)
        rect(x + 2, y + 7, width - 4, height - 9, .white)
    }

    func page(x: Int, y: Int, width: Int, height: Int) {
        rect(x, y, width, height, .white)
        frame(x, y, width, height, .black)
        for line in stride(from: y + 3, to: y + height - 2, by: 2) {
            rect(x + 2, line, width - 4, 1, Palette.shadow)
        }
    }

    func sliderPanel(x: Int, y: Int, width: Int, height: Int) {
        rect(x, y, width, height, Palette.face)
        Bevel.draw(.raised, in: CGRect(x: x, y: y, width: width, height: height), context: context)
        rect(x + 3, y + 4, width - 6, 1, .black)
        rect(x + 5, y + 2, 3, 5, Palette.selection)
        rect(x + 3, y + 9, width - 6, 1, .black)
        rect(x + width - 8, y + 7, 3, 5, Palette.selection)
    }

    func disc(x: Int, y: Int, diameter: Int, fill: PixelColor, outline: PixelColor) {
        let outer = CGRect(x: x, y: y, width: diameter, height: diameter)
        context.setFillColor(outline.cgColor)
        context.fillEllipse(in: outer)
        context.setFillColor(fill.cgColor)
        context.fillEllipse(in: outer.insetBy(dx: 1, dy: 1))
    }

    func ring(x: Int, y: Int, diameter: Int, color: PixelColor, gapTop: Bool) {
        let outer = CGRect(x: x, y: y, width: diameter, height: diameter)
        context.setFillColor(color.cgColor)
        context.fillEllipse(in: outer)
        context.setFillColor(PixelColor.black.cgColor)
        context.fillEllipse(in: outer.insetBy(dx: 2, dy: 2))
        if gapTop {
            rect(x + diameter / 2 - 2, y, 4, diameter / 2, .black)
        }
    }

    func line(from start: CGPoint, to end: CGPoint, width: CGFloat, color: PixelColor) {
        context.setStrokeColor(color.cgColor)
        context.setLineWidth(width)
        context.setLineCap(.square)
        context.strokeLineSegments(between: [start, end])
    }

    func triangleUp(apex: CGPoint, base: CGFloat, height: CGFloat, fill: PixelColor, outline: PixelColor) {
        let path = CGMutablePath()
        path.move(to: apex)
        path.addLine(to: CGPoint(x: apex.x + base / 2, y: apex.y + height))
        path.addLine(to: CGPoint(x: apex.x - base / 2, y: apex.y + height))
        path.closeSubpath()
        context.addPath(path)
        context.setFillColor(fill.cgColor)
        context.setStrokeColor(outline.cgColor)
        context.setLineWidth(1)
        context.drawPath(using: .fillStroke)
    }

    func triangleRight(x: Int, y: Int, height: Int, color: PixelColor, outline: PixelColor) {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: x, y: y))
        path.addLine(to: CGPoint(x: x + height * 3 / 4, y: y + height / 2))
        path.addLine(to: CGPoint(x: x, y: y + height))
        path.closeSubpath()
        context.addPath(path)
        context.setFillColor(color.cgColor)
        context.setStrokeColor(outline.cgColor)
        context.setLineWidth(1)
        context.drawPath(using: .fillStroke)
    }

    /// One big glyph (Tahoma bold), horizontally centered.
    func glyph(_ text: String, size: CGFloat, color: PixelColor, centerX: CGFloat, top: CGFloat) {
        let font = CTFontCreateWithName("Tahoma-Bold" as CFString, size, nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): color.cgColor,
        ]
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
        let width = CTLineGetTypographicBounds(line, nil, nil, nil)
        context.saveGState()
        context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
        context.textPosition = CGPoint(x: (centerX - width / 2).rounded(), y: top + CTFontGetAscent(font).rounded())
        CTLineDraw(line, context)
        context.restoreGState()
    }
}
