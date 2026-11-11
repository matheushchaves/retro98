import AppKit

/// A classic scroll bar: arrow buttons at both ends, a checkered track and a raised knob.
/// Modern macOS has no scroll arrows, so drawing and mouse tracking are done here.
public final class RetroScroller: NSScroller {
    public enum Arrow: Sendable { case up, down, left, right }
    private enum Part { case decrement, increment, pageBack, pageForward, knob }

    nonisolated public static let thickness: CGFloat = 16
    nonisolated public static let minimumKnob: CGFloat = 8
    static let lineStep: CGFloat = 16
    static let repeatDelay: TimeInterval = 0.3
    static let repeatPeriod: TimeInterval = 0.05

    weak var scrollView: NSScrollView?
    private var pressedPart: Part? { didSet { needsDisplay = true } }

    override public class var isCompatibleWithOverlayScrollers: Bool { false }
    override public class func scrollerWidth(for controlSize: NSControl.ControlSize, scrollerStyle: NSScroller.Style) -> CGFloat {
        thickness
    }
    override public var isFlipped: Bool { true }

    private var isVertical: Bool { bounds.height >= bounds.width }
    private var length: CGFloat { isVertical ? bounds.height : bounds.width }
    private var hasKnob: Bool { isEnabled && knobProportion < 1 && length > Self.thickness * 2 + Self.minimumKnob }

    // MARK: Factory

    @MainActor public static func makeScrollView(document: NSView) -> NSScrollView {
        let scroll = NSScrollView()
        scroll.scrollerStyle = .legacy
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = true
        scroll.autohidesScrollers = false
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        let vertical = RetroScroller()
        let horizontal = RetroScroller()
        vertical.scrollView = scroll
        horizontal.scrollView = scroll
        scroll.verticalScroller = vertical
        scroll.horizontalScroller = horizontal
        scroll.documentView = document
        return scroll
    }

    // MARK: Geometry

    /// Knob rect along a scroller of `length` (top-left coordinates), between the two arrow buttons.
    nonisolated public static func knobRect(length: CGFloat, thickness: CGFloat, value: Double, proportion: CGFloat,
                                            vertical: Bool) -> CGRect {
        let slot = max(length - thickness * 2, 0)
        let knob = min(max((slot * proportion).rounded(), minimumKnob), slot)
        let offset = thickness + ((slot - knob) * CGFloat(min(max(value, 0), 1))).rounded()
        return vertical
            ? CGRect(x: 0, y: offset, width: thickness, height: knob)
            : CGRect(x: offset, y: 0, width: knob, height: thickness)
    }

    private var knobFrame: CGRect {
        Self.knobRect(length: length, thickness: Self.thickness, value: doubleValue, proportion: knobProportion, vertical: isVertical)
    }

    private func part(at point: CGPoint) -> Part? {
        let position = isVertical ? point.y : point.x
        if position < Self.thickness { return .decrement }
        if position >= length - Self.thickness { return .increment }
        guard hasKnob else { return nil }
        let knob = knobFrame
        let knobStart = isVertical ? knob.minY : knob.minX
        let knobEnd = isVertical ? knob.maxY : knob.maxX
        if position < knobStart { return .pageBack }
        if position >= knobEnd { return .pageForward }
        return .knob
    }

    // MARK: Drawing

    nonisolated public static func drawArrowButton(_ arrow: Arrow, pressed: Bool, in rect: CGRect, context: CGContext) {
        Bevel.fillFace(rect, context: context)
        if pressed {
            Bevel.fill(CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: 1), color: Palette.shadow, context: context)
            Bevel.fill(CGRect(x: rect.minX, y: rect.maxY - 1, width: rect.width, height: 1), color: Palette.shadow, context: context)
            Bevel.fill(CGRect(x: rect.minX, y: rect.minY, width: 1, height: rect.height), color: Palette.shadow, context: context)
            Bevel.fill(CGRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: rect.height), color: Palette.shadow, context: context)
        } else {
            Bevel.draw(.window, in: rect, context: context)
        }
        let shift: CGFloat = pressed ? 1 : 0
        let centerX = (rect.midX - 1).rounded(.down) + shift
        let centerY = (rect.midY - 1).rounded(.down) + shift
        // A 7-wide, 4-tall black triangle pointing at `arrow`.
        for step in 0..<4 {
            let span = CGFloat(7 - step * 2)
            let offset = CGFloat(step)
            let row: CGRect
            switch arrow {
            case .up: row = CGRect(x: centerX - 3 + offset, y: centerY + 2 - offset, width: span, height: 1)
            case .down: row = CGRect(x: centerX - 3 + offset, y: centerY - 1 + offset, width: span, height: 1)
            case .left: row = CGRect(x: centerX + 2 - offset, y: centerY - 3 + offset, width: 1, height: span)
            case .right: row = CGRect(x: centerX - 1 + offset, y: centerY - 3 + offset, width: 1, height: span)
            }
            Bevel.fill(row, color: .black, context: context)
        }
    }

    /// 1-pixel white/face checkerboard.
    nonisolated public static func drawTrack(in rect: CGRect, context: CGContext) {
        Bevel.fill(rect, color: Palette.face, context: context)
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in stride(from: Int(rect.minX) + (y % 2 == 0 ? 0 : 1), to: Int(rect.maxX), by: 2) {
                Bevel.fill(CGRect(x: x, y: y, width: 1, height: 1), color: .white, context: context)
            }
        }
    }

    nonisolated public static func drawKnob(in rect: CGRect, context: CGContext) {
        Bevel.fillFace(rect, context: context)
        Bevel.draw(.window, in: rect, context: context)
    }

    override public func draw(_ dirtyRect: NSRect) {
        guard let target = NSGraphicsContext.current?.cgContext else { return }
        let vertical = isVertical
        let length = self.length
        let thickness = Self.thickness
        let pressed = pressedPart
        let knob = hasKnob ? knobFrame : nil
        let image = PixelCanvas.render(width: Int(bounds.width), height: Int(bounds.height)) { context in
            Self.drawTrack(in: CGRect(origin: .zero, size: self.bounds.size), context: context)
            let first = CGRect(x: 0, y: 0, width: thickness, height: thickness)
            let last = vertical
                ? CGRect(x: 0, y: length - thickness, width: thickness, height: thickness)
                : CGRect(x: length - thickness, y: 0, width: thickness, height: thickness)
            Self.drawArrowButton(vertical ? .up : .left, pressed: pressed == .decrement, in: first, context: context)
            Self.drawArrowButton(vertical ? .down : .right, pressed: pressed == .increment, in: last, context: context)
            if let knob { Self.drawKnob(in: knob, context: context) }
        }
        PixelIcon.drawUpright(image.cgImage, in: bounds, context: target)
    }

    override public func drawKnob() {}
    override public func drawKnobSlot(in slotRect: NSRect, highlight flag: Bool) {}

    // MARK: Mouse

    override public func mouseDown(with event: NSEvent) {
        guard let part = part(at: convert(event.locationInWindow, from: nil)) else { return }
        if part == .knob {
            trackKnob(from: event)
            return
        }
        pressedPart = part
        perform(part)
        NSEvent.startPeriodicEvents(afterDelay: Self.repeatDelay, withPeriod: Self.repeatPeriod)
        defer {
            NSEvent.stopPeriodicEvents()
            pressedPart = nil
        }
        while let next = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged, .periodic]) {
            if next.type == .leftMouseUp { return }
            if next.type == .periodic, self.part(at: convert(window?.mouseLocationOutsideOfEventStream ?? .zero, from: nil)) == part {
                perform(part)
            }
        }
    }

    private func trackKnob(from event: NSEvent) {
        let start = convert(event.locationInWindow, from: nil)
        let startValue = doubleValue
        let travel = max(length - Self.thickness * 2 - (isVertical ? knobFrame.height : knobFrame.width), 1)
        while let next = window?.nextEvent(matching: [.leftMouseUp, .leftMouseDragged]) {
            let point = convert(next.locationInWindow, from: nil)
            let delta = isVertical ? point.y - start.y : point.x - start.x
            setScrollValue(startValue + Double(delta / travel))
            if next.type == .leftMouseUp { return }
        }
    }

    private func perform(_ part: Part) {
        guard let scrollView, let document = scrollView.documentView else { return }
        let visible = scrollView.contentView.bounds
        let page = max((isVertical ? visible.height : visible.width) - Self.lineStep, Self.lineStep)
        let step: CGFloat
        switch part {
        case .decrement: step = -Self.lineStep
        case .increment: step = Self.lineStep
        case .pageBack: step = -page
        case .pageForward: step = page
        case .knob: return
        }
        var origin = visible.origin
        if isVertical {
            origin.y += document.isFlipped ? step : -step
        } else {
            origin.x += step
        }
        scroll(scrollView, to: origin)
    }

    private func setScrollValue(_ value: Double) {
        guard let scrollView, let document = scrollView.documentView else { return }
        let visible = scrollView.contentView.bounds
        let clamped = CGFloat(min(max(value, 0), 1))
        var origin = visible.origin
        if isVertical {
            let maxOffset = max(document.frame.height - visible.height, 0)
            origin.y = document.isFlipped ? maxOffset * clamped : maxOffset * (1 - clamped)
        } else {
            origin.x = max(document.frame.width - visible.width, 0) * clamped
        }
        scroll(scrollView, to: origin)
    }

    private func scroll(_ scrollView: NSScrollView, to origin: CGPoint) {
        let clip = scrollView.contentView
        clip.scroll(to: clip.constrainBoundsRect(CGRect(origin: origin, size: clip.bounds.size)).origin)
        scrollView.reflectScrolledClipView(clip)
    }
}
