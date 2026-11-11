import AppKit

public enum MessageBoxIcon: Sendable {
    case info, warning, error, question

    var icon: PixelIcon {
        switch self {
        case .info: Icons.info
        case .warning: Icons.warning
        case .error: Icons.error
        case .question: Icons.question
        }
    }
}

public struct MessageBoxLayout: Equatable, Sendable {
    public let lines: [String]
    public let contentSize: CGSize
}

/// A modal 98-style message box: icon, wrapped text and a row of buttons.
public enum RetroMessageBox {
    public static let maxTextWidth = 300
    static let margin: CGFloat = 12
    static let iconSize: CGFloat = 32
    static let buttonGap: CGFloat = 6

    /// Wraps the text to `maxTextWidth` and sizes the content area.
    public static func layout(message: String, buttons: [String]) -> MessageBoxLayout {
        let lines = message.components(separatedBy: "\n").flatMap(wrap)
        let textWidth = CGFloat(lines.map { PixelText.width(of: $0, font: .regular) }.max() ?? 0)
        let textHeight = CGFloat(lines.count * PixelText.lineHeight)
        let buttonsWidth = buttons.map { RetroButton.preferredSize(title: $0, icon: nil, bold: false).width }
            .reduce(0, +) + buttonGap * CGFloat(max(buttons.count - 1, 0))
        let width = max(margin + iconSize + margin + textWidth + margin, buttonsWidth + margin * 2)
        let height = margin + max(iconSize, textHeight) + margin + RetroButton.height + margin
        return MessageBoxLayout(lines: lines, contentSize: CGSize(width: width.rounded(.up), height: height))
    }

    /// Shows the box modally and returns the index of the chosen button
    /// (Esc and × choose the last button).
    @MainActor
    public static func run(title: String, message: String, icon: MessageBoxIcon, buttons: [String]) -> Int {
        let layout = layout(message: message, buttons: buttons)
        let window = RetroWindow(title: title, contentSize: layout.contentSize)
        let content = window.contentContainer
        let iconView = RetroIconView(icon: icon.icon)
        iconView.frame.origin = CGPoint(x: margin, y: margin)
        content.addSubview(iconView)
        let textView = RetroLabel(lines: layout.lines)
        textView.frame = CGRect(x: margin + iconSize + margin, y: margin,
                                width: layout.contentSize.width - (margin * 3 + iconSize),
                                height: CGFloat(layout.lines.count * PixelText.lineHeight))
        content.addSubview(textView)

        let sizes = buttons.map { RetroButton.preferredSize(title: $0, icon: nil, bold: false) }
        let total = sizes.map(\.width).reduce(0, +) + buttonGap * CGFloat(max(buttons.count - 1, 0))
        var x = ((layout.contentSize.width - total) / 2).rounded(.down)
        for (index, title) in buttons.enumerated() {
            let button = RetroButton(title: title, isDefault: index == 0) { NSApp.stopModal(withCode: .init(index)) }
            button.frame.origin = CGPoint(x: x, y: layout.contentSize.height - margin - RetroButton.height)
            content.addSubview(button)
            if index == 0 { window.defaultButton = button }
            x += sizes[index].width + buttonGap
        }
        window.onCancel = { NSApp.stopModal(withCode: .init(buttons.count - 1)) }
        window.showCentered()
        window.makeFirstResponder(window.defaultButton)
        let response = NSApp.runModal(for: window)
        window.orderOut(nil)
        return response.rawValue
    }

    private static func wrap(_ paragraph: String) -> [String] {
        var lines: [String] = []
        var current = ""
        for word in paragraph.split(separator: " ", omittingEmptySubsequences: true).map(String.init) {
            let candidate = current.isEmpty ? word : current + " " + word
            if PixelText.width(of: candidate, font: .regular) <= maxTextWidth || current.isEmpty {
                current = candidate
            } else {
                lines.append(current)
                current = word
            }
        }
        return lines + [current]
    }
}

/// Draws a PixelIcon at its natural size on the face color.
@MainActor
public final class RetroIconView: PixelView {
    public let icon: PixelIcon

    public init(icon: PixelIcon) {
        self.icon = icon
        super.init(frame: CGRect(x: 0, y: 0, width: icon.width, height: icon.height))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        icon.draw(at: .zero, context: context)
    }
}

/// Lines of regular black text on the face color.
@MainActor
public final class RetroLabel: PixelView {
    public let lines: [String]

    public init(lines: [String]) {
        self.lines = lines
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override public func drawPixels(in context: CGContext, size: CGSize) {
        Bevel.fillFace(CGRect(origin: .zero, size: size), context: context)
        for (index, line) in lines.enumerated() {
            PixelText.draw(line, font: .regular, color: .black,
                           at: CGPoint(x: 0, y: index * PixelText.lineHeight), context: context)
        }
    }
}
