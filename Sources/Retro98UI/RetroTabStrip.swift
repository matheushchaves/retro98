import AppKit

/// Where each part of a tab strip sits, in the strip's coordinates (tabs already scrolled).
public struct TabStripLayout: Equatable, Sendable {
    public let tabs: [CGRect]
    public let closeBoxes: [CGRect]
    public let newButton: CGRect
}

/// A row of 98-style tabs, each with a title and a close box, and a "+" button after the last one. Tabs share
/// the width; when even the narrowest don't fit, the row scrolls just enough to show the selected tab whole.
@MainActor
public final class RetroTabStrip: PixelView {
    nonisolated public static let height: CGFloat = 24
    nonisolated public static let maxTabWidth: CGFloat = 160, minTabWidth: CGFloat = 60, newButtonWidth: CGFloat = 22
    nonisolated static let edge: CGFloat = 2, tabTop: CGFloat = 2, closeSize: CGFloat = 14, closeInset: CGFloat = 4
    /// Room a tab keeps for its padding and close box: the title gets the rest.
    nonisolated static let labelReserve: CGFloat = 30
    /// Longer titles are cut before measuring, which is slow for huge ones.
    nonisolated static let longestLabel = 200

    public var titles: [String] = [] { didSet { needsDisplay = true } }
    public var selected = 0 { didSet { needsDisplay = true } }
    public var onSelect: ((Int) -> Void)?
    public var onClose: ((Int) -> Void)?
    public var onNew: (() -> Void)?

    private enum Part: Equatable {
        case close(Int), new
    }

    /// The close box or "+" button under the pressed mouse button.
    private var pressed: Part? { didSet { needsDisplay = true } }

    nonisolated public static func layout(count: Int, selected: Int, width: CGFloat) -> TabStripLayout {
        let reserved = edge + edge + newButtonWidth
        let available = max(width - reserved, 0)
        let buttonY = ((height - newButtonWidth) / 2).rounded(.down) + 1
        guard count > 0 else {
            return TabStripLayout(tabs: [], closeBoxes: [], newButton: CGRect(x: edge, y: buttonY, width: newButtonWidth, height: newButtonWidth - 2))
        }
        let tabWidth = min(maxTabWidth, max(minTabWidth, (available / CGFloat(count)).rounded(.down)))
        let total = tabWidth * CGFloat(count)
        let overflow = max(total - available, 0)
        let selected = min(max(selected, 0), count - 1)
        // Scrolled only as far as needed for the selected tab's right edge to show.
        let offset = min(max(CGFloat(selected + 1) * tabWidth - available, 0), overflow)
        let tabs = (0..<count).map { CGRect(x: edge + CGFloat($0) * tabWidth - offset, y: tabTop, width: tabWidth, height: height - tabTop) }
        let boxes = tabs.map {
            CGRect(x: $0.maxX - closeInset - closeSize, y: $0.minY + (($0.height - closeSize) / 2).rounded(.down), width: closeSize, height: closeSize)
        }
        let buttonX = edge + min(total, available) + edge
        return TabStripLayout(tabs: tabs, closeBoxes: boxes,
                              newButton: CGRect(x: buttonX, y: buttonY, width: newButtonWidth, height: newButtonWidth - 2))
    }

    /// One line that fits the tab: line breaks become spaces, long titles end in "…".
    nonisolated public static func label(_ title: String, tabWidth: CGFloat) -> String {
        let oneLine = String(title.prefix(longestLabel + 1).map { $0.isNewline || $0 == "\t" ? " " : $0 })
        let capped = oneLine.count > longestLabel ? String(oneLine.prefix(longestLabel)) + "…" : oneLine
        return RetroText.fit(capped, maxWidth: Int(tabWidth - labelReserve))
    }

    private var layout: TabStripLayout { Self.layout(count: titles.count, selected: selected, width: bounds.width) }
    /// Tabs show (and take clicks) only between the left edge and the "+" button.
    private var tabsArea: CGRect {
        CGRect(x: Self.edge, y: 0, width: max(bounds.width - Self.edge * 2 - Self.newButtonWidth, 0), height: bounds.height)
    }

    private func tab(at point: CGPoint, in layout: TabStripLayout) -> Int? {
        guard tabsArea.contains(point) else { return nil }
        return layout.tabs.firstIndex { $0.contains(point) }
    }

    private func part(at point: CGPoint, in layout: TabStripLayout) -> Part? {
        if layout.newButton.contains(point) { return .new }
        guard let index = tab(at: point, in: layout), layout.closeBoxes[index].contains(point) else { return nil }
        return .close(index)
    }

    // MARK: Drawing

    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        Bevel.fill(CGRect(x: 0, y: size.height - 1, width: size.width, height: 1), color: Palette.light, context: context)
        let layout = layout
        context.saveGState()
        context.clip(to: tabsArea)
        for index in layout.tabs.indices where index != selected { drawTab(index, layout: layout, context: context) }
        if layout.tabs.indices.contains(selected) { drawTab(selected, layout: layout, context: context) }
        context.restoreGState()
        drawButton(layout.newButton, isPressed: pressed == .new, context: context)
        let mid = CGPoint(x: layout.newButton.midX.rounded(.down), y: layout.newButton.midY.rounded(.down))
        let shift: CGFloat = pressed == .new ? 1 : 0
        Bevel.fill(CGRect(x: mid.x - 4 + shift, y: mid.y + shift, width: 9, height: 1), color: .black, context: context)
        Bevel.fill(CGRect(x: mid.x + shift, y: mid.y - 4 + shift, width: 1, height: 9), color: .black, context: context)
    }

    /// A raised tab; the selected one is 2 px taller and has no line under it, so it joins the page below.
    private func drawTab(_ index: Int, layout: TabStripLayout, context: CGContext) {
        let isSelected = index == selected
        var frame = layout.tabs[index]
        if isSelected {
            frame = CGRect(x: frame.minX - 1, y: 0, width: frame.width + 2, height: bounds.height)
        } else {
            frame.size.height -= 1
        }
        Bevel.fillFace(frame, context: context)
        Bevel.fill(CGRect(x: frame.minX, y: frame.minY + 1, width: 1, height: frame.height - 1), color: Palette.light, context: context)
        Bevel.fill(CGRect(x: frame.minX + 1, y: frame.minY, width: frame.width - 3, height: 1), color: Palette.light, context: context)
        Bevel.fill(CGRect(x: frame.maxX - 2, y: frame.minY + 1, width: 1, height: frame.height - 1), color: Palette.shadow, context: context)
        Bevel.fill(CGRect(x: frame.maxX - 1, y: frame.minY + 2, width: 1, height: frame.height - 2), color: Palette.darkShadow, context: context)
        let title = Self.label(titles[index], tabWidth: layout.tabs[index].width)
        let textY = layout.tabs[index].minY + ((layout.tabs[index].height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down) - (isSelected ? 1 : 0)
        PixelText.draw(title, font: .regular, color: .black, at: CGPoint(x: layout.tabs[index].minX + 6, y: textY), context: context)
        let box = layout.closeBoxes[index]
        let isPressed = pressed == .close(index)
        if isPressed { drawButton(box, isPressed: true, context: context) }
        let shift: CGFloat = isPressed ? 1 : 0
        for step in 0..<7 {
            let x = box.minX + 3 + CGFloat(step) + shift, top = box.minY + 3 + shift
            Bevel.fill(CGRect(x: x, y: top + CGFloat(step), width: 2, height: 1), color: .black, context: context)
            Bevel.fill(CGRect(x: x, y: top + CGFloat(6 - step), width: 2, height: 1), color: .black, context: context)
        }
    }

    /// A small raised button, sunken while pressed.
    private func drawButton(_ frame: CGRect, isPressed: Bool, context: CGContext) {
        let topLeft = isPressed ? Palette.shadow : Palette.light, bottomRight = isPressed ? Palette.light : Palette.shadow
        Bevel.fillFace(frame, context: context)
        Bevel.fill(CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: 1), color: topLeft, context: context)
        Bevel.fill(CGRect(x: frame.minX, y: frame.minY, width: 1, height: frame.height), color: topLeft, context: context)
        Bevel.fill(CGRect(x: frame.minX, y: frame.maxY - 1, width: frame.width, height: 1), color: bottomRight, context: context)
        Bevel.fill(CGRect(x: frame.maxX - 1, y: frame.minY, width: 1, height: frame.height), color: bottomRight, context: context)
    }

    // MARK: Mouse (points in the strip's coordinates)

    /// A press on a tab's body selects it at once; close boxes and "+" act when the button is let go over them.
    func press(at point: CGPoint) {
        let layout = layout
        if let part = part(at: point, in: layout) {
            pressed = part
        } else if let index = tab(at: point, in: layout) {
            onSelect?(index)
        }
    }

    func release(at point: CGPoint) {
        guard let part = pressed else { return }
        pressed = nil
        guard self.part(at: point, in: layout) == part else { return }
        switch part {
        case .close(let index): onClose?(index)
        case .new: onNew?()
        }
    }

    /// The middle button closes the tab under it.
    func middleClick(at point: CGPoint) {
        if let index = tab(at: point, in: layout) { onClose?(index) }
    }

    override public func mouseDown(with event: NSEvent) { press(at: convert(event.locationInWindow, from: nil)) }
    override public func mouseUp(with event: NSEvent) { release(at: convert(event.locationInWindow, from: nil)) }

    override public func otherMouseDown(with event: NSEvent) {
        if event.buttonNumber == 2 { middleClick(at: convert(event.locationInWindow, from: nil)) } else { super.otherMouseDown(with: event) }
    }
}
