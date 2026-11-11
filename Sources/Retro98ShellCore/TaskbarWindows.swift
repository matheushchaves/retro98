import CoreGraphics
import Foundation
import Retro98Settings

/// One window as the taskbar sees it.
public struct WindowSnapshot<ID: Hashable & Sendable>: Equatable, Sendable {
    public let id: ID
    public let title: String
    public let appName: String
    public let appURL: URL?
    public let isMinimized: Bool
    public let isFocused: Bool

    public init(id: ID, title: String, appName: String, appURL: URL?, isMinimized: Bool, isFocused: Bool) {
        self.id = id
        self.title = title
        self.appName = appName
        self.appURL = appURL
        self.isMinimized = isMinimized
        self.isFocused = isFocused
    }
}

public enum TaskbarOrdering {
    /// Known windows keep their previous order; new ones go last, in the order received.
    public static func order<ID>(previous: [ID], current: [WindowSnapshot<ID>]) -> [WindowSnapshot<ID>] {
        let byID = Dictionary(current.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let kept = previous.compactMap { byID[$0] }
        let known = Set(previous)
        return kept + current.filter { !known.contains($0.id) }
    }
}

public enum TaskButtonLayout {
    public static let maxWidth: CGFloat = 160
    public static let minWidth: CGFloat = 40
    public static let gap: CGFloat = 3
    public static let height: CGFloat = 22

    /// One frame per button (equal widths, rounded down), or nil for buttons that don't fit.
    public static func frames(count: Int, area: CGRect) -> [CGRect?] {
        guard count > 0 else { return [] }
        let fitWidth = ((area.width - gap * CGFloat(count - 1)) / CGFloat(count)).rounded(.down)
        let width = min(maxWidth, max(fitWidth, minWidth))
        let visible = fitWidth >= minWidth ? count : max(Int(((area.width + gap) / (minWidth + gap)).rounded(.down)), 0)
        return (0..<count).map { index in
            guard index < visible else { return nil }
            return CGRect(x: area.minX + CGFloat(index) * (width + gap), y: area.minY, width: width, height: area.height)
        }
    }
}

public enum TitleFitting {
    public static let ellipsis = "…"

    /// The whole title if it fits; else the longest prefix plus "…" that fits; "" if not even "…" fits.
    public static func fit(_ title: String, maxWidth: Int, measure: (String) -> Int) -> String {
        guard measure(title) > maxWidth else { return title }
        for length in stride(from: title.count - 1, through: 0, by: -1) {
            let candidate = String(title.prefix(length)).trimmingCharacters(in: .whitespaces) + ellipsis
            if measure(candidate) <= maxWidth { return candidate }
        }
        return ""
    }
}

public enum TaskButtonAction: Equatable, Sendable {
    case activate, minimize
}

public enum TaskButtonClick {
    /// Clicking the active, visible window minimizes it (like Windows 98); otherwise it is activated.
    public static func action(isFocused: Bool, isMinimized: Bool) -> TaskButtonAction {
        isFocused && !isMinimized ? .minimize : .activate
    }
}

public enum TaskButtonMenuText {
    public static func restore(_ languages: [String]) -> String {
        LocalizedText(en: "Restore", ptBR: "Restaurar").resolve(for: languages)
    }

    public static func minimize(_ languages: [String]) -> String {
        LocalizedText(en: "Minimize", ptBR: "Minimizar").resolve(for: languages)
    }

    public static func close(_ languages: [String]) -> String {
        LocalizedText(en: "Close", ptBR: "Fechar").resolve(for: languages)
    }
}
