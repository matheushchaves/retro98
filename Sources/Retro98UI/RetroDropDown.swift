import AppKit

/// A drop-down list: a white sunken field showing the current choice (icon and text) with an arrow button
/// on its right; a click anywhere on it opens the choices as a menu underneath.
@MainActor
public final class RetroDropDown: PixelView {
    public static let height: CGFloat = 22
    nonisolated public static let arrowWidth: CGFloat = 16

    public var items: () -> [RetroMenuItem]
    public private(set) var text = ""
    private var icon: PixelIcon?
    private var openList: RetroMenu?

    public init(items: @escaping () -> [RetroMenuItem]) {
        self.items = items
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    public func set(text: String, icon: PixelIcon?) {
        self.text = text
        self.icon = icon
        needsDisplay = true
    }

    /// The arrow button, inside the 2-pt field border on the right.
    nonisolated public static func arrowFrame(in bounds: CGRect) -> CGRect {
        CGRect(x: bounds.maxX - 2 - arrowWidth, y: bounds.minY + 2, width: arrowWidth, height: bounds.height - 4)
    }

    override public func mouseDown(with event: NSEvent) {
        if let openList, openList.isOpen {
            openList.close()
            return
        }
        guard let window else { return }
        let bottomLeft = window.convertPoint(toScreen: convert(CGPoint(x: 0, y: bounds.maxY), to: nil))
        let menu = RetroMenu(items: items(), style: .standard)
        // A click on the box while the list is open closes it here, not by the menu's own outside-click rule.
        menu.ignoresClick = { [weak self] event in
            guard let self, event.window === self.window else { return false }
            return self.bounds.contains(self.convert(event.locationInWindow, from: nil))
        }
        openList = menu
        menu.show(at: bottomLeft, opensUpward: false) {}
    }

    override public func drawPixels(in context: CGContext, size: CGSize) {
        let bounds = CGRect(origin: .zero, size: size)
        Bevel.fill(bounds, color: .white, context: context)
        Bevel.draw(.field, in: bounds, context: context)
        let arrow = Self.arrowFrame(in: bounds)
        var textX: CGFloat = 4
        if let icon {
            icon.draw(at: CGPoint(x: 4, y: ((size.height - CGFloat(icon.height)) / 2).rounded(.down)), context: context)
            textX = 24
        }
        PixelText.draw(RetroText.fit(text, maxWidth: Int(arrow.minX - textX - 2)), font: .regular, color: .black,
                       at: CGPoint(x: textX, y: ((size.height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down)),
                       context: context)
        Bevel.fillFace(arrow, context: context)
        Bevel.draw(.raised, in: arrow, context: context)
        let tip = CGPoint(x: arrow.midX.rounded(.down), y: arrow.midY.rounded(.down) + 2)
        for row in 0..<4 {
            Bevel.fill(CGRect(x: tip.x - 3 + CGFloat(row), y: tip.y - 3 + CGFloat(row), width: CGFloat(7 - row * 2), height: 1),
                       color: .black, context: context)
        }
    }
}
