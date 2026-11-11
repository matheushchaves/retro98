import AppKit

public struct RetroMenuBarMenu: Sendable {
    public let title: String
    public let items: @Sendable @MainActor () -> [RetroMenuItem]

    public init(title: String, items: @escaping @Sendable @MainActor () -> [RetroMenuItem]) {
        self.title = title
        self.items = items
    }
}

/// The menu bar inside a retro window: click a title to open its menu; while one is open,
/// moving over another title switches to it.
@MainActor
public final class RetroMenuBar: PixelView {
    nonisolated static let padding: CGFloat = 7
    nonisolated static let start: CGFloat = 2

    public var menus: [RetroMenuBarMenu] { didSet { needsDisplay = true } }
    private var openIndex: Int?
    private var openMenu: RetroMenu?
    private var tracking: NSTrackingArea?

    public init(menus: [RetroMenuBarMenu]) {
        self.menus = menus
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    nonisolated public static func titleFrames(titles: [String], height: CGFloat) -> [CGRect] {
        var x = start
        return titles.map { title in
            let width = CGFloat(PixelText.width(of: title, font: .regular)) + padding * 2
            defer { x += width }
            return CGRect(x: x, y: 0, width: width, height: height)
        }
    }

    private var frames: [CGRect] { Self.titleFrames(titles: menus.map(\.title), height: bounds.height) }

    private func index(at point: CGPoint) -> Int? { frames.firstIndex { $0.contains(point) } }

    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        for (index, frame) in frames.enumerated() {
            if index == openIndex { Bevel.draw(.statusField, in: frame, context: context) }
            let shift: CGFloat = index == openIndex ? 1 : 0
            PixelText.draw(menus[index].title, font: .regular, color: .black,
                           at: CGPoint(x: frame.minX + Self.padding + shift,
                                       y: ((frame.height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down) + shift),
                           context: context)
        }
    }

    override public func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .activeAlways, .inVisibleRect], owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override public func mouseDown(with event: NSEvent) {
        guard let index = index(at: convert(event.locationInWindow, from: nil)) else { return }
        if index == openIndex {
            openMenu?.close()
        } else {
            open(index)
        }
    }

    override public func mouseMoved(with event: NSEvent) {
        guard openIndex != nil, let index = index(at: convert(event.locationInWindow, from: nil)), index != openIndex else { return }
        open(index)
    }

    private func open(_ index: Int) {
        openMenu?.close()
        guard let window else { return }
        let frame = frames[index]
        let bottomLeft = window.convertPoint(toScreen: convert(CGPoint(x: frame.minX, y: frame.maxY), to: nil))
        let menu = RetroMenu(items: menus[index].items(), style: .standard)
        menu.ignoresClick = { [weak self] event in
            guard let self, event.window === self.window else { return false }
            return self.bounds.contains(self.convert(event.locationInWindow, from: nil))
        }
        openIndex = index
        openMenu = menu
        needsDisplay = true
        menu.show(at: bottomLeft, opensUpward: false) { [weak self, weak menu] in
            guard let self, self.openMenu === menu else { return }
            self.openIndex = nil
            self.openMenu = nil
            self.needsDisplay = true
        }
    }
}
