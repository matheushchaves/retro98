import AppKit
import Retro98UI

/// Horizontal etched separator (shadow over light).
final class EtchedLine: PixelView {
    override func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fill(CGRect(x: 0, y: 0, width: size.width, height: 1), color: Palette.shadow, context: context)
        Bevel.fill(CGRect(x: 0, y: 1, width: size.width, height: 1), color: Palette.light, context: context)
    }
}

/// A sunken 2-pt field border around a scroll view (tree and icon panes).
final class FieldFrame: PixelView {
    init(wrapping scroll: NSScrollView) {
        super.init(frame: scroll.frame)
        scroll.frame = bounds.insetBy(dx: 2, dy: 2)
        scroll.autoresizingMask = [.width, .height]
        addSubview(scroll)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.draw(.sunken, in: CGRect(origin: .zero, size: size), context: context)
    }
}

/// "Address" label, a white field with the place's icon, an editable path, and a drop-down
/// arrow listing the places above the current one.
@MainActor
final class AddressBar: PixelView {
    static let arrowWidth: CGFloat = 16
    var onSubmit: ((String) -> Void)?
    var dropDownItems: (() -> [RetroMenuItem])?
    private var dropDown: RetroMenu?
    private let label: String
    private let field = NSTextField()
    private var icon: PixelIcon?

    init(label: String) {
        self.label = label
        super.init(frame: .zero)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = true
        field.backgroundColor = .white
        field.focusRingType = .none
        field.font = NSFont(name: "Tahoma", size: PixelFont.regular.size)
        field.target = self
        field.action = #selector(submit)
        addSubview(field)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var labelWidth: CGFloat { CGFloat(PixelText.width(of: label, font: .regular)) + 16 }
    private var fieldFrame: CGRect { CGRect(x: labelWidth, y: 2, width: bounds.width - labelWidth - 4, height: bounds.height - 4) }

    private var arrowFrame: CGRect {
        CGRect(x: fieldFrame.maxX - 2 - Self.arrowWidth, y: fieldFrame.minY + 2, width: Self.arrowWidth, height: fieldFrame.height - 4)
    }

    override func resizeSubviews(withOldSize oldSize: NSSize) {
        super.resizeSubviews(withOldSize: oldSize)
        field.frame = CGRect(x: fieldFrame.minX + 23, y: fieldFrame.minY + 3,
                             width: arrowFrame.minX - fieldFrame.minX - 25, height: fieldFrame.height - 6)
    }

    override func mouseDown(with event: NSEvent) {
        guard arrowFrame.contains(convert(event.locationInWindow, from: nil)), let items = dropDownItems?(), let window else { return }
        if let dropDown, dropDown.isOpen {
            dropDown.close()
            return
        }
        let topLeft = window.convertPoint(toScreen: convert(CGPoint(x: fieldFrame.minX, y: fieldFrame.maxY), to: nil))
        let menu = RetroMenu(items: items, style: .standard)
        menu.ignoresClick = { [weak self] event in
            guard let self, event.window === self.window else { return false }
            return self.arrowFrame.contains(self.convert(event.locationInWindow, from: nil))
        }
        dropDown = menu
        menu.show(at: topLeft, opensUpward: false) {}
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        resizeSubviews(withOldSize: newSize)
    }

    func set(text: String, icon: PixelIcon) {
        field.stringValue = text
        self.icon = icon
        needsDisplay = true
    }

    @objc private func submit() { onSubmit?(field.stringValue) }

    override func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        PixelText.draw(label, font: .regular, color: .black,
                       at: CGPoint(x: 8, y: ((size.height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down)), context: context)
        Bevel.draw(.field, in: fieldFrame, context: context)
        icon?.draw(at: CGPoint(x: fieldFrame.minX + 4, y: fieldFrame.midY.rounded(.down) - 8), context: context)
        let arrow = arrowFrame
        Bevel.draw(.raised, in: arrow, context: context)
        let tip = CGPoint(x: arrow.midX.rounded(.down), y: arrow.midY.rounded(.down) + 2)
        for row in 0..<4 {
            Bevel.fill(CGRect(x: tip.x - 3 + CGFloat(row), y: tip.y - 3 + CGFloat(row), width: CGFloat(7 - row * 2), height: 1),
                       color: .black, context: context)
        }
    }
}

/// Shown instead of the icons when a place can't be listed (with "Open in Finder" for the Recycle Bin).
@MainActor
final class MessageView: PixelView {
    var message = "" { didSet { needsDisplay = true } }
    var showsFinderButton = false { didSet { button.isHidden = !showsFinderButton } }
    var onOpenFinder: (() -> Void)?
    private lazy var button = RetroButton(title: Locale.preferredLanguages.first?.hasPrefix("pt") == true ? "Abrir no Finder" : "Open in Finder") {
        [weak self] in self?.onOpenFinder?()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(button)
        button.isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        button.setFrameOrigin(CGPoint(x: 16, y: 16 + CGFloat(lines.count * PixelText.lineHeight) + 12))
    }

    private var lines: [String] { RetroText.wrap(message, maxWidth: Int(max(bounds.width - 32, 100))) }

    override func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fill(CGRect(origin: .zero, size: size), color: .white, context: context)
        for (index, line) in lines.enumerated() {
            PixelText.draw(line, font: .regular, color: .black, at: CGPoint(x: 16, y: 16 + index * PixelText.lineHeight), context: context)
        }
    }
}
