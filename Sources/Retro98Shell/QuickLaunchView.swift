import AppKit
import Retro98Settings
import Retro98ShellCore
import Retro98UI

/// An etched separator after Start, then a flat 22×22 button that opens the Explorer's Desktop.
/// Flat at rest, raised on hover, sunken while pressed.
final class QuickLaunchView: PixelView {
    static let buttonSize: CGFloat = 22
    static let width: CGFloat = 6 + buttonSize
    private static let tooltip = LocalizedText(en: "Show Desktop", ptBR: "Mostrar a Área de Trabalho")

    private let languages: [String]
    private var isHovered = false { didSet { needsDisplay = true } }
    private var isPressed = false { didSet { needsDisplay = true } }
    private var tracking: NSTrackingArea?

    init(languages: [String]) {
        self.languages = languages
        super.init(frame: CGRect(x: 0, y: 0, width: Self.width, height: TaskbarGeometry.minimumHeight))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var buttonFrame: CGRect {
        CGRect(x: 6, y: ((bounds.height - Self.buttonSize) / 2).rounded(.down) + 1, width: Self.buttonSize, height: Self.buttonSize)
    }

    override func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        let button = buttonFrame
        Bevel.fill(CGRect(x: 1, y: button.minY, width: 1, height: button.height), color: Palette.shadow, context: context)
        Bevel.fill(CGRect(x: 2, y: button.minY, width: 1, height: button.height), color: Palette.light, context: context)
        if isPressed && isHovered {
            Bevel.draw(.sunken, in: button, context: context)
        } else if isHovered {
            Bevel.draw(.raised, in: button, context: context)
        }
        let offset: CGFloat = isPressed && isHovered ? 1 : 0
        FileIcons.explorerAppSmall.draw(at: CGPoint(x: button.minX + 3 + offset, y: button.minY + 3 + offset), context: context)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: buttonFrame, options: [.mouseEnteredAndExited, .activeAlways], owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        guard let window else { return }
        let top = window.convertPoint(toScreen: convert(CGPoint(x: buttonFrame.minX, y: buttonFrame.minY), to: nil))
        RetroTooltip.show(Self.tooltip.resolve(for: languages), near: top)
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        RetroTooltip.hide()
    }

    override func mouseDown(with event: NSEvent) {
        guard buttonFrame.contains(convert(event.locationInWindow, from: nil)) else { return }
        RetroTooltip.hide()
        isPressed = true
    }

    override func mouseDragged(with event: NSEvent) {
        isHovered = buttonFrame.contains(convert(event.locationInWindow, from: nil))
    }

    override func mouseUp(with event: NSEvent) {
        let inside = buttonFrame.contains(convert(event.locationInWindow, from: nil))
        isPressed = false
        if inside { NSWorkspace.shared.open(QuickLaunch.desktopURL) }
    }
}
