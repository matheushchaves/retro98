import CoreGraphics
import Foundation

public enum ControlPanelIcon: CaseIterable, Sendable {
    case display, appearance, mouse, sounds, components, network, printers, keyboard, dateTime, users, screensaver
}

/// The Control Panel's own icon and its applets' icons: original pixel art on FileIcons' 16-unit grid.
public enum ControlPanelIcons {
    private static let gray = Palette.face, dark = Palette.shadow
    private static let navy = PixelIcon.color("N"), blue = PixelIcon.color("B"), teal = PixelIcon.color("T")
    private static let green = PixelIcon.color("E"), lime = PixelIcon.color("L"), yellow = PixelIcon.color("Y")
    private static let red = PixelIcon.color("R")

    /// A gray control box with two sliders and a round knob.
    public static let app = PixelIcon(width: 32, height: 32) { drawApp(Sketch(context: $0, scale: 2)) }
    public static let appSmall = PixelIcon(width: 16, height: 16) { drawApp(Sketch(context: $0, scale: 1)) }

    public static func icon(_ kind: ControlPanelIcon, size: Int) -> PixelIcon {
        cache.icon(kind: kind, size: size) {
            PixelIcon(width: size, height: size) { draw(kind, Sketch(context: $0, scale: CGFloat(size) / 16)) }
        }
    }

    private final class Cache: @unchecked Sendable {
        private let lock = NSLock()
        private var icons: [String: PixelIcon] = [:]

        func icon(kind: ControlPanelIcon, size: Int, draw: () -> PixelIcon) -> PixelIcon {
            let key = "\(kind)-\(size)"
            if let icon = lock.withLock({ icons[key] }) { return icon }
            let icon = draw()
            lock.withLock { icons[key] = icon }
            return icon
        }
    }

    private static let cache = Cache()

    private static func drawApp(_ s: Sketch) {
        s.box(1, 2, 14, 12, fill: gray)
        s.fill(4, 4, 1, 8, .black)
        s.fill(8, 4, 1, 8, .black)
        s.box(3, 5, 3, 3, fill: navy)
        s.box(7, 8, 3, 3, fill: navy)
        s.box(11, 5, 3, 3, fill: .white)
        s.fill(12, 5, 1, 1, red)
    }

    private static func draw(_ kind: ControlPanelIcon, _ s: Sketch) {
        switch kind {
        case .display:
            s.box(1, 1, 14, 11, fill: gray)
            s.box(3, 3, 10, 7, fill: teal)
            s.fill(6, 12, 4, 1, dark)
            s.box(4, 13, 8, 2, fill: gray)
        case .appearance:
            s.box(1, 1, 11, 9, fill: gray)
            s.fill(2, 2, 9, 2, navy)
            s.box(4, 11, 4, 4, fill: blue)
            s.box(7, 9, 4, 4, fill: red)
            s.box(10, 11, 4, 4, fill: yellow)
        case .mouse:
            s.fill(8, 2, 5, 1, .black)
            s.fill(8, 2, 1, 3, .black)
            s.box(4, 5, 8, 10, fill: .white)
            s.fill(5, 9, 6, 1, .black)
            s.fill(8, 5, 1, 4, .black)
        case .sounds:
            s.box(1, 5, 4, 6, fill: gray)
            s.fill(5, 4, 1, 8, .black)
            s.fill(6, 3, 1, 10, .black)
            s.fill(7, 2, 1, 12, .black)
            s.fill(9, 5, 1, 1, .black); s.fill(10, 6, 1, 4, .black); s.fill(9, 10, 1, 1, .black)
            s.fill(11, 3, 1, 1, .black); s.fill(12, 4, 1, 1, .black); s.fill(13, 5, 1, 6, .black)
            s.fill(12, 11, 1, 1, .black); s.fill(11, 12, 1, 1, .black)
        case .components:
            s.box(2, 1, 10, 6, fill: green)
            s.box(4, 9, 10, 6, fill: navy)
            s.box(6, 6, 4, 4, fill: yellow)
        case .network:
            s.box(0, 1, 7, 6, fill: gray)
            s.fill(1, 2, 5, 4, teal)
            s.box(9, 6, 7, 6, fill: gray)
            s.fill(10, 7, 5, 4, teal)
            s.fill(3, 7, 1, 7, .black)
            s.fill(3, 13, 10, 1, .black)
            s.fill(12, 12, 1, 2, .black)
        case .printers:
            s.box(4, 1, 8, 6, fill: .white)
            s.box(1, 6, 14, 7, fill: gray)
            s.fill(3, 8, 10, 1, .black)
            s.fill(12, 10, 2, 1, lime)
            s.box(3, 12, 10, 3, fill: .white)
        case .keyboard:
            s.box(0, 5, 16, 8, fill: gray)
            for row in 0..<2 {
                for column in 0..<6 { s.fill(2 + column * 2, 7 + row * 2, 1, 1, .white) }
            }
            s.fill(4, 11, 8, 1, .white)
        case .dateTime:
            s.fill(3, 3, 10, 10, .white); s.fill(5, 2, 6, 12, .white); s.fill(2, 5, 12, 6, .white)
            s.fill(5, 1, 6, 1, .black); s.fill(5, 14, 6, 1, .black); s.fill(1, 5, 1, 6, .black); s.fill(14, 5, 1, 6, .black)
            s.fill(3, 2, 2, 1, .black); s.fill(11, 2, 2, 1, .black); s.fill(2, 3, 1, 2, .black); s.fill(13, 3, 1, 2, .black)
            s.fill(3, 13, 2, 1, .black); s.fill(11, 13, 2, 1, .black); s.fill(2, 11, 1, 2, .black); s.fill(13, 11, 1, 2, .black)
            s.fill(8, 2, 1, 1, red)
            s.fill(8, 4, 1, 4, navy)
            s.fill(8, 8, 3, 1, navy)
        case .users:
            s.box(2, 1, 5, 5, fill: navy)
            s.box(0, 6, 9, 7, fill: navy)
            s.box(9, 4, 5, 5, fill: teal)
            s.box(7, 9, 9, 6, fill: teal)
        case .screensaver:
            // Monitor with star burst: a small screen showing a star
            s.box(1, 1, 14, 10, fill: gray)
            s.fill(2, 2, 12, 8, navy)
            // Star in center of screen
            s.fill(7, 4, 2, 6, yellow)   // vertical bar
            s.fill(5, 6, 6, 2, yellow)   // horizontal bar
            s.fill(5, 4, 2, 2, yellow)   // top-left diagonal
            s.fill(9, 4, 2, 2, yellow)   // top-right diagonal
            s.fill(5, 8, 2, 2, yellow)   // bottom-left diagonal
            s.fill(9, 8, 2, 2, yellow)   // bottom-right diagonal
            // Stand
            s.fill(6, 11, 4, 1, dark)
            s.box(4, 12, 8, 2, fill: gray)
        }
    }
}
