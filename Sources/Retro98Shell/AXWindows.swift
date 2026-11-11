import AppKit
import ApplicationServices
import Retro98ShellCore

/// A window identified by its Accessibility element; equality and hashing use CFEqual/CFHash
/// (public API, valid while the window exists).
struct AXWindowID: Hashable, @unchecked Sendable {
    let element: AXUIElement
    let pid: pid_t

    static func == (lhs: AXWindowID, rhs: AXWindowID) -> Bool { CFEqual(lhs.element, rhs.element) }
    func hash(into hasher: inout Hasher) { hasher.combine(CFHash(element)) }
}

enum AX {
    /// A frozen app must never freeze the taskbar.
    static let messagingTimeout: Float = 0.25
    static let windowSubroles: Set<String> = [kAXStandardWindowSubrole as String, kAXDialogSubrole as String]

    struct ReadFailure: Error {
        let status: AXError
    }

    static func application(_ pid: pid_t) -> AXUIElement {
        let element = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(element, messagingTimeout)
        return element
    }

    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        return AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success ? value : nil
    }

    static func string(_ element: AXUIElement, _ name: String) -> String? {
        attribute(element, name) as? String
    }

    static func bool(_ element: AXUIElement, _ name: String) -> Bool? {
        attribute(element, name) as? Bool
    }

    static func element(_ element: AXUIElement, _ name: String) -> AXUIElement? {
        guard let value = attribute(element, name), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    /// Window frame in Accessibility coordinates (top-left origin of the main screen).
    static func frame(_ element: AXUIElement) -> CGRect? {
        guard let position = attribute(element, kAXPositionAttribute), CFGetTypeID(position) == AXValueGetTypeID(),
              let size = attribute(element, kAXSizeAttribute), CFGetTypeID(size) == AXValueGetTypeID()
        else { return nil }
        var origin = CGPoint.zero
        var extent = CGSize.zero
        guard AXValueGetValue(unsafeDowncast(position, to: AXValue.self), .cgPoint, &origin),
              AXValueGetValue(unsafeDowncast(size, to: AXValue.self), .cgSize, &extent)
        else { return nil }
        return CGRect(origin: origin, size: extent)
    }

    @discardableResult
    static func setSize(_ element: AXUIElement, _ size: CGSize) -> Bool {
        var value = size
        guard let wrapped = AXValueCreate(.cgSize, &value) else { return false }
        return AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, wrapped) == .success
    }

    static func windows(of application: AXUIElement) throws -> [AXUIElement] {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &value)
        guard status == .success, let windows = value as? [AXUIElement] else { throw ReadFailure(status: status) }
        return windows
    }

    static func regularApps() -> [NSRunningApplication] {
        let own = ProcessInfo.processInfo.processIdentifier
        return NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.processIdentifier != own }
    }
}

/// Windows of regular apps on the current Space (Accessibility only reports those).
final class AXWindowSource: WindowSource {
    func snapshot() -> [WindowSnapshot<AXWindowID>] {
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        return WindowCollector.collect(apps: AX.regularApps().map { app in
            { try Self.windows(of: app, isFrontmost: app.processIdentifier == frontPID) }
        })
    }

    private static func windows(of app: NSRunningApplication, isFrontmost: Bool) throws -> [WindowSnapshot<AXWindowID>] {
        let application = AX.application(app.processIdentifier)
        let focused = isFrontmost ? AX.element(application, kAXFocusedWindowAttribute) : nil
        let appName = app.localizedName ?? ""
        return try AX.windows(of: application).compactMap { window in
            guard let subrole = AX.string(window, kAXSubroleAttribute), AX.windowSubroles.contains(subrole) else { return nil }
            let title = AX.string(window, kAXTitleAttribute) ?? ""
            return WindowSnapshot(
                id: AXWindowID(element: window, pid: app.processIdentifier),
                title: title.isEmpty ? appName : title, appName: appName, appURL: app.bundleURL,
                isMinimized: AX.bool(window, kAXMinimizedAttribute) ?? false,
                isFocused: focused.map { CFEqual($0, window) } ?? false
            )
        }
    }
}

final class AXWindowCommands: WindowCommands {
    func activate(_ id: AXWindowID) -> Bool {
        if AX.bool(id.element, kAXMinimizedAttribute) == true {
            AXUIElementSetAttributeValue(id.element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }
        let raised = AXUIElementPerformAction(id.element, kAXRaiseAction as CFString) == .success
        if raised { NSRunningApplication(processIdentifier: id.pid)?.activate() }
        return raised
    }

    func minimize(_ id: AXWindowID) -> Bool {
        AXUIElementSetAttributeValue(id.element, kAXMinimizedAttribute as CFString, kCFBooleanTrue) == .success
    }

    func close(_ id: AXWindowID) -> Bool {
        guard let button = AX.element(id.element, kAXCloseButtonAttribute) else { return false }
        return AXUIElementPerformAction(button, kAXPressAction as CFString) == .success
    }
}

/// Wakes the taskbar when windows change: Accessibility observers per app plus workspace
/// notifications, coalesced 100 ms after the last event, with a 5 s safety refresh.
@MainActor
final class WindowChangeMonitor {
    static let coalesceDelay: TimeInterval = 0.1
    static let safetyInterval: TimeInterval = 5
    static let windowNotifications = [
        kAXWindowCreatedNotification, kAXUIElementDestroyedNotification, kAXTitleChangedNotification,
        kAXWindowMiniaturizedNotification, kAXWindowDeminiaturizedNotification, kAXFocusedWindowChangedNotification,
        kAXWindowMovedNotification, kAXWindowResizedNotification,
    ]
    /// Geometry-only events: they don't change the buttons, so they skip the refresh.
    static let geometryNotifications: Set<String> = [kAXWindowMovedNotification, kAXWindowResizedNotification]
    static let geometryCheckNotifications: Set<String> = geometryNotifications.union([kAXWindowCreatedNotification])

    private let onChange: @MainActor () -> Void
    /// Called with the window when it is created, moved or resized.
    var onWindowGeometry: (@MainActor (AXUIElement) -> Void)?
    private var observers: [pid_t: AXObserver] = [:]
    private var workspaceTokens: [NSObjectProtocol] = []
    private var pending: DispatchWorkItem?
    private var safetyTimer: Timer?

    init(onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange
    }

    func start() {
        AX.regularApps().forEach { observe($0.processIdentifier) }
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didActivateApplicationNotification, NSWorkspace.activeSpaceDidChangeNotification,
        ]
        workspaceTokens = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                let pid = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.processIdentifier
                MainActor.assumeIsolated { self?.workspaceChanged(name: name, pid: pid) }
            }
        }
        let timer = Timer(timeInterval: Self.safetyInterval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.schedule() }
        }
        RunLoop.main.add(timer, forMode: .common)
        safetyTimer = timer
        schedule()
    }

    func stop() {
        workspaceTokens.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        workspaceTokens = []
        observers.values.forEach { CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource($0), .commonModes) }
        observers = [:]
        safetyTimer?.invalidate()
        safetyTimer = nil
        pending?.cancel()
    }

    /// Coalesces bursts of events into one refresh.
    func schedule() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in MainActor.assumeIsolated { self?.onChange() } }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.coalesceDelay, execute: work)
    }

    private func workspaceChanged(name: Notification.Name, pid: pid_t?) {
        if let pid {
            if name == NSWorkspace.didLaunchApplicationNotification { observe(pid) }
            if name == NSWorkspace.didTerminateApplicationNotification { unobserve(pid) }
        }
        schedule()
    }

    private func observe(_ pid: pid_t) {
        guard observers[pid] == nil else { return }
        var observer: AXObserver?
        let callback: AXObserverCallback = { _, element, notification, refcon in
            guard let refcon else { return }
            let monitor = Unmanaged<WindowChangeMonitor>.fromOpaque(refcon).takeUnretainedValue()
            nonisolated(unsafe) let window = element
            let name = notification as String
            MainActor.assumeIsolated { monitor.received(name, window: window) }
        }
        guard AXObserverCreate(pid, callback, &observer) == .success, let observer else { return }
        let application = AX.application(pid)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        for name in Self.windowNotifications {
            AXObserverAddNotification(observer, application, name as CFString, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        observers[pid] = observer
    }

    private func received(_ notification: String, window: AXUIElement) {
        if Self.geometryCheckNotifications.contains(notification) { onWindowGeometry?(window) }
        if !Self.geometryNotifications.contains(notification) { schedule() }
    }

    private func unobserve(_ pid: pid_t) {
        guard let observer = observers.removeValue(forKey: pid) else { return }
        CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
    }
}
