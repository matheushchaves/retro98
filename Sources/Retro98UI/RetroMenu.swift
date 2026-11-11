import AppKit

public struct RetroMenuItem: Sendable {
    public enum Kind: Sendable {
        case action(@Sendable @MainActor () -> Void)
        case submenu(@Sendable @MainActor () -> [RetroMenuItem])
        case separator
    }

    public let title: String
    public let icon: PixelIcon?
    public let kind: Kind
    public let isEnabled: Bool

    public init(title: String, icon: PixelIcon? = nil, kind: Kind, isEnabled: Bool = true) {
        self.title = title
        self.icon = icon
        self.kind = kind
        self.isEnabled = isEnabled
    }

    public static let separator = RetroMenuItem(title: "", kind: .separator)

    var isSeparator: Bool {
        if case .separator = kind { return true }
        return false
    }

    var isSelectable: Bool { isEnabled && !isSeparator }
}

public struct RetroMenuStyle: Sendable {
    public let itemHeight: Int
    public let iconSize: Int
    public let banner: String?

    public init(itemHeight: Int, iconSize: Int, banner: String?) {
        self.itemHeight = itemHeight
        self.iconSize = iconSize
        self.banner = banner
    }

    public static let startMenu = RetroMenuStyle(itemHeight: 34, iconSize: 32, banner: "Retro98")
    public static let standard = RetroMenuStyle(itemHeight: 22, iconSize: 16, banner: nil)
}

public struct MenuColumnLayout: Equatable, Sendable {
    public let columns: [[Int]]
}

public enum RetroMenuLayout {
    public static let separatorHeight = 8

    /// Fills columns top to bottom; a new column starts when the next item would exceed `maxHeight`.
    public static func columns(itemHeights: [Int], maxHeight: Int) -> MenuColumnLayout {
        var columns: [[Int]] = []
        var current: [Int] = []
        var height = 0
        for (index, itemHeight) in itemHeights.enumerated() {
            if !current.isEmpty && height + itemHeight > maxHeight {
                columns.append(current)
                current = []
                height = 0
            }
            current.append(index)
            height += itemHeight
        }
        if !current.isEmpty { columns.append(current) }
        return MenuColumnLayout(columns: columns)
    }
}

public enum RetroMenuPlacement {
    /// x of a submenu: right of the item when it fits, else left of the parent when that fits,
    /// else the side with more room, always clamped inside the screen.
    public static func submenuX(parentFrame: CGRect, itemMaxX: CGFloat, width: CGFloat, visibleFrame: CGRect) -> CGFloat {
        let right = itemMaxX + 1
        let left = parentFrame.minX - width
        let x: CGFloat
        if right + width <= visibleFrame.maxX {
            x = right
        } else if left >= visibleFrame.minX {
            x = left
        } else {
            x = visibleFrame.maxX - right >= parentFrame.minX - visibleFrame.minX ? right : left
        }
        return min(max(x, visibleFrame.minX), visibleFrame.maxX - width)
    }
}

public enum RetroMenuNavigation {
    public enum Direction: Sendable { case up, down }

    /// Next selectable index in `direction`, wrapping around; nil when nothing is selectable.
    public static func next(from current: Int?, direction: Direction, selectable: [Bool]) -> Int? {
        guard selectable.contains(true) else { return nil }
        let count = selectable.count
        let step = direction == .down ? 1 : -1
        var index = current ?? (direction == .down ? -1 : count)
        for _ in 0..<count {
            index = ((index + step) % count + count) % count
            if selectable[index] { return index }
        }
        return nil
    }
}

/// A cascading 98-style menu shown in its own borderless panel.
@MainActor
public final class RetroMenu {
    static let inset: CGFloat = 3
    static let bannerWidth: CGFloat = 21
    static let hoverDelay: TimeInterval = 0.4

    private let items: [RetroMenuItem]
    private let style: RetroMenuStyle
    private weak var parent: RetroMenu?
    private var panel: MenuPanel?
    private var view: MenuView?
    private var child: RetroMenu?
    private var childIndex: Int?
    private var monitors: [Any] = []
    private var workspaceObserver: NSObjectProtocol?
    private var onClose: (() -> Void)?
    private var hoverWork: DispatchWorkItem?
    /// Clicks for which this returns true don't close the menu (e.g. on the Start button, which toggles it itself).
    public var ignoresClick: ((NSEvent) -> Bool)?

    public init(items: [RetroMenuItem], style: RetroMenuStyle) {
        self.items = items
        self.style = style
    }

    public var isOpen: Bool { panel != nil }

    /// `point` is the bottom-left corner when `opensUpward`, otherwise the top-left corner (screen coordinates).
    public func show(at point: CGPoint, opensUpward: Bool, onClose: @escaping () -> Void) {
        self.onClose = onClose
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main ?? NSScreen.screens[0]
        let view = MenuView(items: items, style: style, maxHeight: screen.visibleFrame.height - Self.inset * 2)
        view.owner = self
        let size = view.frame.size
        var origin = opensUpward ? point : CGPoint(x: point.x, y: point.y - size.height)
        origin.x = min(origin.x, screen.visibleFrame.maxX - size.width)
        origin.y = max(min(origin.y, screen.visibleFrame.maxY - size.height), screen.visibleFrame.minY)
        let panel = MenuPanel(contentRect: CGRect(origin: origin, size: size))
        panel.contentView = view
        panel.orderFrontRegardless()
        panel.makeKey()
        panel.makeFirstResponder(view)
        self.panel = panel
        self.view = view
        if parent == nil { installClickMonitors() }
    }

    /// Closes this menu and every open submenu.
    public func close() {
        hoverWork?.cancel()
        child?.close()
        child = nil
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        if let workspaceObserver { NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver) }
        workspaceObserver = nil
        panel?.orderOut(nil)
        panel = nil
        view = nil
        let callback = onClose
        onClose = nil
        callback?()
    }

    private func root() -> RetroMenu { parent?.root() ?? self }

    private func chainWindows() -> [NSWindow] {
        [panel].compactMap { $0 } + (child?.chainWindows() ?? [])
    }

    private func installClickMonitors() {
        let global = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self else { return }
                let inMenu = self.chainWindows().contains { $0 === event.window }
                if Self.shouldClose(clickInMenu: inMenu, ignored: self.ignoresClick?(event) ?? false) { self.close() }
            }
            return event
        }
        monitors = [global, local].compactMap { $0 }
        // Switching apps (e.g. ⌘Tab) closes the menu, like clicking elsewhere.
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.close() }
        }
    }

    nonisolated public static func shouldClose(clickInMenu: Bool, ignored: Bool) -> Bool {
        !clickInMenu && !ignored
    }

    // MARK: Called by MenuView

    fileprivate func hovered(_ index: Int?) {
        hoverWork?.cancel()
        guard let index, case .submenu = items[index].kind, items[index].isEnabled else {
            if index != childIndex { closeChild() }
            return
        }
        guard index != childIndex else { return }
        let work = DispatchWorkItem { [weak self] in self?.openChild(at: index) }
        hoverWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.hoverDelay, execute: work)
    }

    fileprivate func activate(_ index: Int) {
        let item = items[index]
        guard item.isEnabled else { return }
        switch item.kind {
        case .action(let action):
            root().close()
            DispatchQueue.main.async { action() }
        case .submenu:
            openChild(at: index)
            child?.view?.highlight(RetroMenuNavigation.next(from: nil, direction: .down,
                                                             selectable: child?.items.map(\.isSelectable) ?? []))
        case .separator:
            break
        }
    }

    fileprivate func closeLevel() {
        if let parent {
            parent.closeChild()
            parent.panel?.makeKey()
        } else {
            close()
        }
    }

    private func closeChild() {
        child?.close()
        child = nil
        childIndex = nil
    }

    private func openChild(at index: Int) {
        guard case .submenu(let makeItems) = items[index].kind, let view, let panel else { return }
        closeChild()
        let submenu = RetroMenu(items: makeItems(), style: .standard)
        submenu.parent = self
        let itemRect = view.convert(view.rect(forItem: index), to: nil)
        let screenRect = panel.convertToScreen(itemRect)
        submenu.show(at: CGPoint(x: screenRect.maxX + 1, y: screenRect.maxY + Self.inset), opensUpward: false) {}
        if let childPanel = submenu.panel, let screen = panel.screen {
            let x = RetroMenuPlacement.submenuX(parentFrame: panel.frame, itemMaxX: screenRect.maxX,
                                                width: childPanel.frame.width, visibleFrame: screen.visibleFrame)
            childPanel.setFrameOrigin(CGPoint(x: x, y: childPanel.frame.minY))
        }
        child = submenu
        childIndex = index
    }
}

// MARK: - Panel and view

private final class MenuPanel: NSPanel {
    init(contentRect: CGRect) {
        super.init(contentRect: contentRect, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        level = .popUpMenu
        hasShadow = true
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    override var canBecomeKey: Bool { true }
}

@MainActor
private final class MenuView: PixelView {
    static let arrow = PixelIcon(rows: ["K...", "KK..", "KKK.", "KKKK", "KKK.", "KK..", "K..."])
    static let arrowSelected = PixelIcon(rows: ["W...", "WW..", "WWW.", "WWWW", "WWW.", "WW..", "W..."])
    static let iconGap: CGFloat = 6
    static let arrowArea: CGFloat = 20

    let items: [RetroMenuItem]
    let style: RetroMenuStyle
    let layout: MenuColumnLayout
    let columnWidth: CGFloat
    weak var owner: RetroMenu?
    private(set) var highlighted: Int?
    private var tracking: NSTrackingArea?

    init(items: [RetroMenuItem], style: RetroMenuStyle, maxHeight: CGFloat) {
        self.items = items
        self.style = style
        let heights = items.map { $0.isSeparator ? RetroMenuLayout.separatorHeight : style.itemHeight }
        layout = RetroMenuLayout.columns(itemHeights: heights, maxHeight: Int(maxHeight))
        let textWidth = items.map { PixelText.width(of: $0.title, font: .regular) }.max() ?? 0
        columnWidth = 3 + CGFloat(style.iconSize) + Self.iconGap + CGFloat(textWidth) + Self.arrowArea
        let tallest = layout.columns.map { column in column.map { heights[$0] }.reduce(0, +) }.max() ?? 0
        let banner = style.banner == nil ? 0 : RetroMenu.bannerWidth
        let size = CGSize(width: RetroMenu.inset * 2 + banner + columnWidth * CGFloat(max(layout.columns.count, 1)),
                          height: RetroMenu.inset * 2 + CGFloat(max(tallest, style.itemHeight)))
        super.init(frame: CGRect(origin: .zero, size: size))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var contentLeft: CGFloat { RetroMenu.inset + (style.banner == nil ? 0 : RetroMenu.bannerWidth) }

    func rect(forItem index: Int) -> CGRect {
        guard let column = layout.columns.firstIndex(where: { $0.contains(index) }) else { return .zero }
        var y = RetroMenu.inset
        for other in layout.columns[column] {
            let height = CGFloat(items[other].isSeparator ? RetroMenuLayout.separatorHeight : style.itemHeight)
            if other == index {
                return CGRect(x: contentLeft + columnWidth * CGFloat(column), y: y, width: columnWidth, height: height)
            }
            y += height
        }
        return .zero
    }

    private func index(at point: CGPoint) -> Int? {
        items.indices.first { rect(forItem: $0).contains(point) }
    }

    func highlight(_ index: Int?) {
        guard index != highlighted else { return }
        highlighted = index
        needsDisplay = true
    }

    // MARK: Input

    override var acceptsFirstResponder: Bool { true }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        let index = index(at: convert(event.locationInWindow, from: nil)).flatMap { items[$0].isSelectable ? $0 : nil }
        highlight(index)
        owner?.hovered(index)
    }

    override func mouseUp(with event: NSEvent) {
        if let index = index(at: convert(event.locationInWindow, from: nil)) { owner?.activate(index) }
    }

    override func keyDown(with event: NSEvent) {
        let selectable = items.map(\.isSelectable)
        switch event.keyCode {
        case 125: highlight(RetroMenuNavigation.next(from: highlighted, direction: .down, selectable: selectable))
        case 126: highlight(RetroMenuNavigation.next(from: highlighted, direction: .up, selectable: selectable))
        case 124, 36, 76:
            if let highlighted { owner?.activate(highlighted) }
        case 123, 53: owner?.closeLevel()
        default: super.keyDown(with: event)
        }
    }

    // MARK: Drawing

    override func drawPixels(in context: CGContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        Bevel.fillFace(rect, context: context)
        Bevel.draw(.window, in: rect, context: context)
        if let banner = style.banner { drawBanner(banner, height: size.height - RetroMenu.inset * 2, context: context) }
        for index in items.indices { drawItem(index, context: context) }
    }

    private func drawItem(_ index: Int, context: CGContext) {
        let item = items[index]
        let frame = rect(forItem: index)
        if item.isSeparator {
            let y = frame.midY.rounded(.down) - 1
            Bevel.fill(CGRect(x: frame.minX + 1, y: y, width: frame.width - 2, height: 1), color: Palette.shadow, context: context)
            Bevel.fill(CGRect(x: frame.minX + 1, y: y + 1, width: frame.width - 2, height: 1), color: Palette.light, context: context)
            return
        }
        let isHighlighted = index == highlighted
        if isHighlighted { Bevel.fill(frame, color: Palette.selection, context: context) }
        let iconSize = CGFloat(style.iconSize)
        if let icon = item.icon {
            icon.draw(at: CGPoint(x: frame.minX + 3, y: frame.minY + ((frame.height - iconSize) / 2).rounded(.down)),
                      context: context)
        }
        let textOrigin = CGPoint(x: frame.minX + 3 + iconSize + Self.iconGap,
                                 y: frame.minY + ((frame.height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down))
        if item.isEnabled {
            PixelText.draw(item.title, font: .regular, color: isHighlighted ? Palette.selectionText : .black,
                           at: textOrigin, context: context)
        } else {
            PixelText.draw(item.title, font: .regular, color: Palette.light,
                           at: CGPoint(x: textOrigin.x + 1, y: textOrigin.y + 1), context: context)
            PixelText.draw(item.title, font: .regular, color: Palette.shadow, at: textOrigin, context: context)
        }
        if case .submenu = item.kind {
            let arrow = isHighlighted ? Self.arrowSelected : Self.arrow
            arrow.draw(at: CGPoint(x: frame.maxX - 12, y: frame.minY + ((frame.height - 7) / 2).rounded(.down)),
                       context: context)
        }
    }

    /// Vertical gradient strip with the name written bottom-to-top.
    private func drawBanner(_ text: String, height: CGFloat, context: CGContext) {
        let width = Int(RetroMenu.bannerWidth)
        let strip = PixelCanvas.render(width: Int(height), height: width) { canvas in
            RetroWindow.drawTitleGradient(active: true, in: CGRect(x: 0, y: 0, width: height, height: CGFloat(width)), context: canvas)
            PixelText.draw(text, font: .bold, color: .white, at: CGPoint(x: 6, y: 4), context: canvas)
        }
        // Rotate the horizontal strip 90° counter-clockwise (lossless for pixel art).
        context.saveGState()
        context.translateBy(x: RetroMenu.inset, y: RetroMenu.inset + height)
        context.rotate(by: -.pi / 2)
        PixelIcon.drawUpright(strip.cgImage, in: CGRect(x: 0, y: 0, width: height, height: CGFloat(width)), context: context)
        context.restoreGState()
    }
}
