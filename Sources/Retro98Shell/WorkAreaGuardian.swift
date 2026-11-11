import AppKit
import ApplicationServices
import Retro98ShellCore

/// Shrinks standard windows that reach the bottom of the main screen so they stop at the taskbar.
@MainActor
final class WorkAreaGuardian {
    var isEnabled = false
    private let taskbarHeight: () -> CGFloat

    init(taskbarHeight: @escaping () -> CGFloat) {
        self.taskbarHeight = taskbarHeight
    }

    func windowChanged(_ window: AXUIElement) {
        guard isEnabled else { return }
        adjust(window)
    }

    /// Checks every window, e.g. when the permission arrives or the taskbar changes height.
    func sweep() {
        guard isEnabled else { return }
        for app in AX.regularApps() {
            (try? AX.windows(of: AX.application(app.processIdentifier)))?.forEach(adjust)
        }
    }

    /// If the app refuses the new size, its frame doesn't change, so no new event comes and nothing loops.
    private func adjust(_ window: AXUIElement) {
        guard AX.string(window, kAXSubroleAttribute) == kAXStandardWindowSubrole as String,
              AX.bool(window, kAXMinimizedAttribute) != true,
              let frame = AX.frame(window),
              let mainScreen = NSScreen.screens.first
        else { return }
        let screen = CGRect(origin: .zero, size: mainScreen.frame.size)
        guard let size = WorkAreaGuard.adjustedSize(window: frame, screen: screen, taskbarHeight: taskbarHeight()) else { return }
        AX.setSize(window, size)
    }
}
