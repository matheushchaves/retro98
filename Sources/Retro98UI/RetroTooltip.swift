import AppKit

/// A pale-yellow 98-style tooltip shown above a screen point.
@MainActor
public final class RetroTooltip {
    static let padding: CGFloat = 3
    private static var panel: NSPanel?

    public static func show(_ text: String, near point: CGPoint) {
        hide()
        let size = CGSize(width: CGFloat(PixelText.width(of: text, font: .regular)) + padding * 2 + 2,
                          height: CGFloat(PixelText.lineHeight) + padding * 2)
        let panel = NSPanel(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.level = .popUpMenu
        panel.ignoresMouseEvents = true
        panel.hasShadow = false
        panel.contentView = TooltipView(frame: CGRect(origin: .zero, size: size), text: text)
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        let maxX = (screen?.frame.maxX ?? point.x + size.width) - size.width
        panel.setFrameOrigin(CGPoint(x: min(point.x, maxX).rounded(), y: (point.y + 4).rounded()))
        panel.orderFrontRegardless()
        self.panel = panel
    }

    public static func hide() {
        panel?.orderOut(nil)
        panel = nil
    }

    private final class TooltipView: PixelView {
        let text: String

        init(frame: CGRect, text: String) {
            self.text = text
            super.init(frame: frame)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func drawPixels(in context: CGContext, size: CGSize) {
            let rect = CGRect(origin: .zero, size: size)
            Bevel.fill(rect, color: .black, context: context)
            Bevel.fill(rect.insetBy(dx: 1, dy: 1), color: Palette.tooltip, context: context)
            PixelText.draw(text, font: .regular, color: .black,
                           at: CGPoint(x: RetroTooltip.padding + 1, y: RetroTooltip.padding), context: context)
        }
    }
}
