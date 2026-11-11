import AppKit

public struct ToolbarItem: Sendable {
    public let title: String
    public let icon: PixelIcon
    public let isEnabled: Bool
    public let action: @Sendable @MainActor () -> Void

    public init(title: String, icon: PixelIcon, isEnabled: Bool, action: @escaping @Sendable @MainActor () -> Void) {
        self.title = title
        self.icon = icon
        self.isEnabled = isEnabled
        self.action = action
    }
}

/// Flat toolbar buttons (icon over label): a thin raised edge on hover, sunken while pressed,
/// embossed gray when disabled. nil items are etched separators.
@MainActor
public final class RetroToolbar: PixelView {
    nonisolated static let start: CGFloat = 4
    nonisolated static let minimumWidth: CGFloat = 48
    nonisolated static let separatorWidth: CGFloat = 8

    public var items: [ToolbarItem?] = [] { didSet { needsDisplay = true } }
    private var hovered: Int?
    private var pressed: Int?
    private var tracking: NSTrackingArea?

    nonisolated public static func frames(items: [ToolbarItem?], height: CGFloat) -> [CGRect] {
        var x = start
        return items.map { item in
            let width = item.map { max(CGFloat(PixelText.width(of: $0.title, font: .regular)) + 10, minimumWidth) } ?? separatorWidth
            defer { x += width }
            return CGRect(x: x, y: 0, width: width, height: height)
        }
    }

    private var frames: [CGRect] { Self.frames(items: items, height: bounds.height) }

    private func index(at point: CGPoint) -> Int? {
        frames.indices.first { frames[$0].contains(point) && items[$0]?.isEnabled == true }
    }

    // MARK: Drawing

    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        for (index, frame) in frames.enumerated() {
            guard let item = items[index] else {
                let x = frame.midX.rounded(.down)
                Bevel.fill(CGRect(x: x, y: 4, width: 1, height: frame.height - 8), color: Palette.shadow, context: context)
                Bevel.fill(CGRect(x: x + 1, y: 4, width: 1, height: frame.height - 8), color: Palette.light, context: context)
                continue
            }
            drawItem(item, in: frame, isHovered: hovered == index, isPressed: pressed == index, context: context)
        }
    }

    private func drawItem(_ item: ToolbarItem, in frame: CGRect, isHovered: Bool, isPressed: Bool, context: CGContext) {
        if item.isEnabled && (isHovered || isPressed) {
            Bevel.draw(.statusField, in: frame, context: context)          // shadow top-left, light bottom-right = sunken
            if !isPressed {                                                  // hover: swap to a thin raised edge
                Bevel.fill(CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 1), color: Palette.light, context: context)
                Bevel.fill(CGRect(x: frame.minX, y: frame.minY, width: 1, height: frame.height), color: Palette.light, context: context)
                Bevel.fill(CGRect(x: frame.minX, y: frame.maxY - 1, width: frame.width, height: 1), color: Palette.shadow, context: context)
                Bevel.fill(CGRect(x: frame.maxX - 1, y: frame.minY, width: 1, height: frame.height), color: Palette.shadow, context: context)
            }
        }
        let shift: CGFloat = isPressed ? 1 : 0
        let iconOrigin = CGPoint(x: (frame.midX - CGFloat(item.icon.width) / 2).rounded(.down) + shift, y: frame.minY + 5 + shift)
        let textWidth = CGFloat(PixelText.width(of: item.title, font: .regular))
        let textOrigin = CGPoint(x: (frame.midX - textWidth / 2).rounded(.down) + shift, y: frame.minY + 22 + shift)
        if item.isEnabled {
            item.icon.draw(at: iconOrigin, context: context)
            PixelText.draw(item.title, font: .regular, color: .black, at: textOrigin, context: context)
        } else {
            item.icon.drawEmbossed(at: iconOrigin, context: context)
            PixelText.draw(item.title, font: .regular, color: Palette.light, at: CGPoint(x: textOrigin.x + 1, y: textOrigin.y + 1), context: context)
            PixelText.draw(item.title, font: .regular, color: Palette.shadow, at: textOrigin, context: context)
        }
    }

    // MARK: Mouse

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override public func mouseMoved(with event: NSEvent) {
        let index = index(at: convert(event.locationInWindow, from: nil))
        if index != hovered { hovered = index; needsDisplay = true }
    }

    override public func mouseExited(with event: NSEvent) {
        hovered = nil
        needsDisplay = true
    }

    override public func mouseDown(with event: NSEvent) {
        pressed = index(at: convert(event.locationInWindow, from: nil))
        needsDisplay = true
    }

    override public func mouseUp(with event: NSEvent) {
        defer { pressed = nil; needsDisplay = true }
        guard let pressed, index(at: convert(event.locationInWindow, from: nil)) == pressed, let item = items[pressed] else { return }
        item.action()
    }
}
