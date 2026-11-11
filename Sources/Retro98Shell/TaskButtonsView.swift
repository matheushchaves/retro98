import AppKit
import Retro98ShellCore
import Retro98UI

/// The strip of window buttons between Start and the tray.
@MainActor
final class TaskButtonsView: PixelView {
    static let iconSize: CGFloat = 16
    static let padding: CGFloat = 4
    static let iconGap: CGFloat = 3

    typealias Model = TaskButtonsModel<AXWindowSource, AXWindowCommands>

    private let model: Model
    private let languages: [String]
    private var iconCache: [URL: PixelIcon] = [:]
    private var contextMenu: RetroMenu?

    init(model: Model, languages: [String]) {
        self.model = model
        self.languages = languages
        super.init(frame: .zero)
        model.onChange = { [weak self] in self?.needsDisplay = true }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private var buttonArea: CGRect {
        CGRect(x: 0, y: ((bounds.height - TaskButtonLayout.height) / 2).rounded(.down) + 1,
               width: bounds.width, height: TaskButtonLayout.height)
    }

    private func frames() -> [CGRect?] {
        TaskButtonLayout.frames(count: model.windows.count, area: buttonArea)
    }

    private func window(at point: CGPoint) -> WindowSnapshot<AXWindowID>? {
        zip(model.windows, frames()).first { $0.1?.contains(point) == true }?.0
    }

    // MARK: Input

    override func mouseUp(with event: NSEvent) {
        guard let window = window(at: convert(event.locationInWindow, from: nil)) else { return }
        model.click(window.id)
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let window = window(at: convert(event.locationInWindow, from: nil)) else { return }
        let id = window.id
        let items = [
            RetroMenuItem(title: TaskButtonMenuText.restore(languages), kind: .action({ [weak self] in self?.model.restore(id) }),
                          isEnabled: window.isMinimized),
            RetroMenuItem(title: TaskButtonMenuText.minimize(languages), kind: .action({ [weak self] in self?.model.minimize(id) }),
                          isEnabled: !window.isMinimized),
            .separator,
            RetroMenuItem(title: TaskButtonMenuText.close(languages), kind: .action({ [weak self] in self?.model.close(id) })),
        ]
        let menu = RetroMenu(items: items, style: .standard)
        let point = NSEvent.mouseLocation
        menu.show(at: CGPoint(x: point.x, y: (self.window?.frame.maxY ?? point.y)), opensUpward: true) { [weak self] in
            self?.contextMenu = nil
        }
        contextMenu = menu
    }

    // MARK: Drawing

    override func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        for (window, frame) in zip(model.windows, frames()) {
            guard let frame else { continue }
            drawButton(window, in: frame, context: context)
        }
    }

    private func drawButton(_ window: WindowSnapshot<AXWindowID>, in frame: CGRect, context: CGContext) {
        let pressed = window.isFocused && !window.isMinimized
        if pressed {
            drawDither(in: frame.insetBy(dx: 2, dy: 2), context: context)
        }
        Bevel.draw(pressed ? .buttonPressed : .raised, in: frame, context: context)
        let shift: CGFloat = pressed ? 1 : 0
        let iconOrigin = CGPoint(x: frame.minX + Self.padding + shift,
                                 y: frame.minY + ((frame.height - Self.iconSize) / 2).rounded(.down) + shift)
        icon(for: window).draw(at: iconOrigin, context: context)
        let textX = iconOrigin.x + Self.iconSize + Self.iconGap
        let title = TitleFitting.fit(window.title, maxWidth: Int(frame.maxX - Self.padding - textX)) {
            PixelText.width(of: $0, font: .regular)
        }
        PixelText.draw(title, font: .regular, color: .black,
                       at: CGPoint(x: textX, y: frame.minY + ((frame.height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down) + shift),
                       context: context)
    }

    /// The classic 1-pixel white/face checkerboard of an active taskbar button.
    private func drawDither(in rect: CGRect, context: CGContext) {
        Bevel.fill(rect, color: Palette.face, context: context)
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in stride(from: Int(rect.minX) + (y % 2), to: Int(rect.maxX), by: 2) {
                Bevel.fill(CGRect(x: x, y: y, width: 1, height: 1), color: .white, context: context)
            }
        }
    }

    private func icon(for window: WindowSnapshot<AXWindowID>) -> PixelIcon {
        guard let url = window.appURL else { return Icons.application }
        if let cached = iconCache[url] { return cached }
        let image = PixelIcon.appIcon(for: url, size: Int(Self.iconSize))
        let icon = PixelIcon(width: Int(Self.iconSize), height: Int(Self.iconSize)) { context in
            PixelIcon.drawUpright(image, in: CGRect(x: 0, y: 0, width: Self.iconSize, height: Self.iconSize), context: context)
        }
        iconCache[url] = icon
        return icon
    }
}
