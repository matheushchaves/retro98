import AppKit
import CoreGraphics
import Retro98Settings

/// Monitors idle time and shows/dismisses the screensaver window.
@MainActor
public final class ScreensaverController {
    private let choices: () -> Choices
    private let win: ScreensaverWindow
    private var timer: Timer?

    public private(set) var isShowing = false
    public private(set) var showCount = 0

    // MARK: - Test seams
    public var presentsWindows = true
    public var overrideIdleSeconds: Double? = nil

    public init(choices: @escaping () -> Choices, window: ScreensaverWindow) {
        self.choices = choices
        self.win = window
        win.onDismiss = { [weak self] in self?.didDismiss() }
    }

    public func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.checkIdle() }
        }
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func fireIdleCheckForTesting() { checkIdle() }
    public func dismissForTesting() { win.dismiss() }

    private func checkIdle() {
        guard !isShowing else { return }
        let c = choices()
        guard c.screensaver != .none else { return }

        let idle = overrideIdleSeconds ?? Self.idleSeconds()
        guard idle >= Double(c.screensaverTimeout * 60) else { return }

        guard let renderer = ScreensaverRendererFactory.make(c.screensaver, sound: c.screensaverSound) else { return }
        isShowing = true
        showCount += 1
        win.present(renderer: renderer, presentsWindows: presentsWindows)
    }

    private func didDismiss() {
        isShowing = false
    }

    private static func idleSeconds() -> Double {
        let mouse = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let key   = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let click = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)
        return min(mouse, min(key, click))
    }
}
