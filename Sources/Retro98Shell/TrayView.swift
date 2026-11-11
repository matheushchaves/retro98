import AppKit
import Retro98ShellCore
import Retro98UI

/// The notification area: volume, battery (when there is one) and the clock.
@MainActor
final class TrayView: PixelView {
    static let height: CGFloat = 22
    static let padding: CGFloat = 4
    static let iconSize: CGFloat = 16
    static let gap: CGFloat = 4
    static let statusInterval: TimeInterval = 30
    static let secondsPerMinute: TimeInterval = 60

    private let languages: [String]
    private var battery: BatteryState?
    private var volume: VolumeState?
    private var clock = ""
    private var timers: [Timer] = []
    private var tracking: NSTrackingArea?

    init(languages: [String]) {
        self.languages = languages
        super.init(frame: CGRect(x: 0, y: 0, width: 80, height: Self.height))
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func start() {
        refreshStatus()
        refreshClock()
        timers.append(Timer.scheduledTimer(timeInterval: Self.statusInterval, target: self,
                                           selector: #selector(statusTick), userInfo: nil, repeats: true))
        scheduleNextMinute()
    }

    /// Recomputes the width from what is shown and keeps the given height.
    func relayout(height: CGFloat) {
        let clockWidth = CGFloat(PixelText.width(of: clock, font: .regular))
        let icons = CGFloat(battery == nil ? 1 : 2)
        let width = Self.padding * 2 + icons * (Self.iconSize + Self.gap) + clockWidth + 2
        setFrameSize(CGSize(width: width.rounded(.up), height: height))
        needsDisplay = true
    }

    // MARK: Refresh

    private func refreshStatus() {
        battery = SystemReaders.battery()
        volume = SystemReaders.volume()
        relayoutKeepingRightEdge()
    }

    private func refreshClock() {
        clock = ClockText.time(Date(), locale: .current, timeZone: .current)
        relayoutKeepingRightEdge()
    }

    private func scheduleNextMinute() {
        let now = Date().timeIntervalSince1970
        let delay = Self.secondsPerMinute - now.truncatingRemainder(dividingBy: Self.secondsPerMinute) + 0.1
        timers.append(Timer.scheduledTimer(timeInterval: delay, target: self,
                                           selector: #selector(minuteTick), userInfo: nil, repeats: false))
    }

    @objc private func statusTick() {
        refreshStatus()
    }

    @objc private func minuteTick() {
        refreshClock()
        scheduleNextMinute()
    }

    private func relayoutKeepingRightEdge() {
        let right = frame.maxX
        relayout(height: Self.height)
        if superview != nil { setFrameOrigin(CGPoint(x: right - frame.width, y: frame.minY)) }
    }

    // MARK: Layout of items

    private var volumeRect: CGRect {
        CGRect(x: Self.padding, y: (Self.height - Self.iconSize) / 2, width: Self.iconSize, height: Self.iconSize)
    }

    private var batteryRect: CGRect? {
        battery == nil ? nil : volumeRect.offsetBy(dx: Self.iconSize + Self.gap, dy: 0)
    }

    private var clockRect: CGRect {
        let x = (batteryRect ?? volumeRect).maxX + Self.gap
        return CGRect(x: x, y: 0, width: bounds.width - x, height: bounds.height)
    }

    // MARK: Input

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let tracking { removeTrackingArea(tracking) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseMoved, .mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        tracking = area
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        guard clockRect.contains(point), let window else {
            RetroTooltip.hide()
            return
        }
        let screenPoint = window.convertPoint(toScreen: convert(CGPoint(x: clockRect.minX, y: 0), to: nil))
        RetroTooltip.show(ClockText.tooltip(Date(), locale: .current, timeZone: .current),
                          near: CGPoint(x: screenPoint.x, y: window.frame.maxY))
    }

    override func mouseExited(with event: NSEvent) {
        RetroTooltip.hide()
    }

    override func mouseUp(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        RetroTooltip.hide()
        if volumeRect.contains(point) {
            NSWorkspace.shared.open(TraySettingsURL.sound)
        } else if let batteryRect, batteryRect.contains(point) {
            NSWorkspace.shared.open(TraySettingsURL.battery)
        } else if clockRect.contains(point) {
            NSWorkspace.shared.open(TraySettingsURL.dateTime)
        }
        refreshStatus()
    }

    // MARK: Drawing

    override func drawPixels(in context: CGContext, size: CGSize) {
        let rect = CGRect(origin: .zero, size: size)
        Bevel.fillFace(rect, context: context)
        Bevel.draw(.statusField, in: rect, context: context)
        let volumeIcon = volume.map(volumeIsSilent) == true ? Icons.volumeMuted : Icons.volume
        volumeIcon.draw(at: volumeRect.origin, context: context)
        if let battery, let batteryRect {
            batteryIcon(battery).draw(at: batteryRect.origin, context: context)
        }
        let textY = ((size.height - CGFloat(PixelText.lineHeight)) / 2).rounded(.down)
        PixelText.draw(clock, font: .regular, color: .black, at: CGPoint(x: clockRect.minX, y: textY), context: context)
    }

    private func batteryIcon(_ state: BatteryState) -> PixelIcon {
        switch batteryIconKind(state) {
        case .full: Icons.batteryFull
        case .half: Icons.batteryHalf
        case .low: Icons.batteryLow
        case .charging: Icons.batteryCharging
        }
    }
}
