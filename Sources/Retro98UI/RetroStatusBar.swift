import AppKit

/// Sunken status fields with a resize grip at the bottom-right corner.
@MainActor
public final class RetroStatusBar: PixelView {
    nonisolated static let gap: CGFloat = 4
    nonisolated static let gripSize: CGFloat = 12

    public var fields: [(text: String, width: CGFloat?)] = [] { didSet { needsDisplay = true } }

    /// Fields start at x = 2 with 4 pt between them; a nil width takes what is left before the grip.
    nonisolated public static func fieldFrames(widths: [CGFloat?], totalWidth: CGFloat, height: CGFloat) -> [CGRect] {
        let end = totalWidth - gap - gripSize
        var x: CGFloat = 2
        return widths.map { width in
            let fieldWidth = width ?? max(end - x, 0)
            defer { x += fieldWidth + gap }
            return CGRect(x: x, y: 2, width: fieldWidth, height: height - 4)
        }
    }

    private var gripRect: CGRect {
        CGRect(x: bounds.width - Self.gripSize - 1, y: bounds.height - Self.gripSize - 1, width: Self.gripSize, height: Self.gripSize)
    }

    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        let frames = Self.fieldFrames(widths: fields.map(\.width), totalWidth: size.width, height: size.height)
        for (field, frame) in zip(fields, frames) {
            Bevel.draw(.statusField, in: frame, context: context)
            let text = RetroText.fit(field.text, maxWidth: Int(frame.width - 8))
            PixelText.draw(text, font: .regular, color: .black,
                           at: CGPoint(x: frame.minX + 4, y: frame.minY + ((frame.height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down)),
                           context: context)
        }
        // Grip: three diagonal light/shadow pairs.
        let grip = gripRect
        for line in 0..<3 {
            let offset = CGFloat(line * 4)
            for step in 0..<Int(Self.gripSize - offset) {
                let x = grip.maxX - 1 - CGFloat(step)
                let y = grip.minY + offset + CGFloat(step)
                Bevel.fill(CGRect(x: x, y: y, width: 1, height: 1), color: Palette.light, context: context)
                Bevel.fill(CGRect(x: x, y: y + 1, width: 1, height: 1), color: Palette.shadow, context: context)
            }
        }
    }

    override public func mouseDown(with event: NSEvent) {
        guard gripRect.contains(convert(event.locationInWindow, from: nil)) else { return }
        (window as? RetroAppWindow)?.beginResize([.right, .bottom], with: event)
    }
}
