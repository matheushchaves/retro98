import AppKit

/// A resizable 98-style app window: window bevel, gradient title bar with icon and bold title,
/// minimize / maximize-restore / close buttons, drag to move, drag the frame to resize,
/// double-click the title to maximize or restore.
@MainActor
public final class RetroAppWindow: NSWindow {
    public let contentContainer: NSView
    public private(set) var isMaximized = false
    /// Height kept free at the bottom when maximizing (the app passes 28 while the taskbar runs).
    public var taskbarHeight: () -> CGFloat = { 0 }
    private var restoreFrame: CGRect?
    private let frameView: AppWindowFrameView

    public init(title: String, icon: PixelIcon, contentSize: CGSize) {
        let border = WindowGeometry.border
        let top = border + WindowGeometry.titleHeight + 1
        let size = CGSize(width: contentSize.width + border * 2, height: contentSize.height + top + border)
        frameView = AppWindowFrameView(frame: CGRect(origin: .zero, size: size), title: title, icon: icon)
        contentContainer = FlippedContainer(frame: CGRect(x: border, y: top, width: contentSize.width, height: contentSize.height))
        contentContainer.autoresizingMask = [.width, .height]
        super.init(contentRect: CGRect(origin: .zero, size: size),
                   styleMask: [.borderless, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        self.title = title
        isReleasedWhenClosed = false
        hasShadow = true
        minSize = WindowGeometry.minimumSize
        contentView = frameView
        frameView.addSubview(contentContainer)
        center()
    }

    override public var canBecomeKey: Bool { true }
    override public var canBecomeMain: Bool { true }

    public func setTitle(_ title: String, icon: PixelIcon) {
        self.title = title
        frameView.title = title
        frameView.icon = icon
        frameView.needsDisplay = true
    }

    public func toggleMaximize() {
        if isMaximized, let restoreFrame {
            setFrame(restoreFrame, display: true)
            isMaximized = false
        } else {
            guard let screen = screen ?? NSScreen.main else { return }
            restoreFrame = frame
            setFrame(WindowGeometry.maximizedFrame(visibleFrame: screen.visibleFrame, taskbarHeight: taskbarHeight()), display: true)
            isMaximized = true
        }
        frameView.needsDisplay = true
    }

    /// Starts a resize drag (also used by the status bar's grip).
    public func beginResize(_ edge: ResizeEdge, with event: NSEvent) {
        let startMouse = NSEvent.mouseLocation
        let startFrame = frame
        while let next = nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            let now = NSEvent.mouseLocation
            let delta = CGVector(dx: now.x - startMouse.x, dy: now.y - startMouse.y)
            setFrame(WindowGeometry.resized(startFrame, edge: edge, delta: delta, minimumSize: minSize), display: true)
            if next.type == .leftMouseUp { break }
        }
        isMaximized = false
    }

    override public func becomeKey() {
        super.becomeKey()
        frameView.needsDisplay = true
    }

    override public func resignKey() {
        super.resignKey()
        frameView.needsDisplay = true
    }

    private final class FlippedContainer: NSView {
        override var isFlipped: Bool { true }
    }
}

@MainActor
private final class AppWindowFrameView: PixelView {
    enum Caption { case minimize, maximize, close }

    static let buttonSize = CGSize(width: 16, height: 14)
    static let closeGlyph = ["KK....KK", ".KK..KK.", "..KKKK..", "...KK...", "..KKKK..", ".KK..KK.", "KK....KK"]

    var title: String
    var icon: PixelIcon
    private var pressed: Caption?

    init(frame: CGRect, title: String, icon: PixelIcon) {
        self.title = title
        self.icon = icon
        super.init(frame: frame)
        autoresizingMask = [.width, .height]
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var appWindow: RetroAppWindow? { window as? RetroAppWindow }

    private var titleRect: CGRect {
        CGRect(x: WindowGeometry.border - 1, y: WindowGeometry.border - 1,
               width: bounds.width - (WindowGeometry.border - 1) * 2, height: WindowGeometry.titleHeight)
    }

    private func captionRect(_ caption: Caption) -> CGRect {
        let size = Self.buttonSize
        let closeX = titleRect.maxX - 2 - size.width
        let x: CGFloat
        switch caption {
        case .close: x = closeX
        case .maximize: x = closeX - 2 - size.width
        case .minimize: x = closeX - 2 - size.width * 2
        }
        return CGRect(x: x, y: titleRect.minY + 2, width: size.width, height: size.height)
    }

    private func caption(at point: CGPoint) -> Caption? {
        [Caption.minimize, .maximize, .close].first { captionRect($0).contains(point) }
    }

    // MARK: Drawing

    override func drawPixels(in context: CGContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        Bevel.fillFace(rect, context: context)
        Bevel.draw(.window, in: rect, context: context)
        RetroWindow.drawTitleGradient(active: window?.isKeyWindow ?? true, in: titleRect, context: context)
        icon.draw(at: CGPoint(x: titleRect.minX + 2, y: titleRect.minY + 1), context: context)
        let maxTitleWidth = Int(captionRect(.minimize).minX - titleRect.minX - 24)
        let fitted = RetroText.fit(title, maxWidth: maxTitleWidth, font: .bold)
        PixelText.draw(fitted, font: .bold, color: .white, at: CGPoint(x: titleRect.minX + 21, y: titleRect.minY + 1), context: context)
        for caption in [Caption.minimize, .maximize, .close] { drawCaption(caption, context: context) }
    }

    private func drawCaption(_ caption: Caption, context: CGContext) {
        let rect = captionRect(caption)
        let isPressed = pressed == caption
        Bevel.fillFace(rect, context: context)
        Bevel.draw(isPressed ? .buttonPressed : .raised, in: rect, context: context)
        let x = rect.minX + (isPressed ? 1 : 0)
        let y = rect.minY + (isPressed ? 1 : 0)
        switch caption {
        case .minimize:
            Bevel.fill(CGRect(x: x + 4, y: y + 9, width: 6, height: 2), color: .black, context: context)
        case .maximize:
            if appWindow?.isMaximized == true {
                // Restore: two overlapping boxes.
                Bevel.fill(CGRect(x: x + 5, y: y + 2, width: 6, height: 2), color: .black, context: context)
                Bevel.fill(CGRect(x: x + 10, y: y + 2, width: 1, height: 5), color: .black, context: context)
                Bevel.fill(CGRect(x: x + 3, y: y + 5, width: 6, height: 6), color: .black, context: context)
                Bevel.fill(CGRect(x: x + 4, y: y + 7, width: 4, height: 3), color: Palette.face, context: context)
            } else {
                Bevel.fill(CGRect(x: x + 3, y: y + 2, width: 9, height: 9), color: .black, context: context)
                Bevel.fill(CGRect(x: x + 4, y: y + 4, width: 7, height: 6), color: Palette.face, context: context)
            }
        case .close:
            for (row, line) in Self.closeGlyph.enumerated() {
                for (column, character) in line.enumerated() where character == "K" {
                    Bevel.fill(CGRect(x: x + 4 + CGFloat(column), y: y + 3 + CGFloat(row), width: 1, height: 1),
                               color: .black, context: context)
                }
            }
        }
    }

    // MARK: Mouse

    override func resetCursorRects() {
        let border = WindowGeometry.border
        addCursorRect(CGRect(x: 0, y: 0, width: border, height: bounds.height), cursor: .resizeLeftRight)
        addCursorRect(CGRect(x: bounds.width - border, y: 0, width: border, height: bounds.height), cursor: .resizeLeftRight)
        addCursorRect(CGRect(x: 0, y: 0, width: bounds.width, height: border), cursor: .resizeUpDown)
        addCursorRect(CGRect(x: 0, y: bounds.height - border, width: bounds.width, height: border), cursor: .resizeUpDown)
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        if let caption = caption(at: point) {
            pressed = caption
            needsDisplay = true
            return
        }
        if let edge = WindowGeometry.edge(at: point, windowSize: bounds.size) {
            appWindow?.beginResize(edge, with: event)
            return
        }
        if titleRect.contains(point) {
            if event.clickCount == 2 {
                appWindow?.toggleMaximize()
            } else if appWindow?.isMaximized != true {
                window?.performDrag(with: event)
            }
        }
    }

    override func mouseUp(with event: NSEvent) {
        guard let caption = pressed else { return }
        pressed = nil
        needsDisplay = true
        guard captionRect(caption).contains(convert(event.locationInWindow, from: nil)) else { return }
        switch caption {
        case .minimize: window?.miniaturize(nil)
        case .maximize: appWindow?.toggleMaximize()
        case .close: window?.performClose(nil)
        }
    }
}
