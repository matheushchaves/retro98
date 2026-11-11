import Foundation

public enum ClockText {
    /// Hours and minutes in the locale's clock style (24 h in Brazil).
    public static func time(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("jj:mm")
        return formatter.string(from: date)
    }

    public static func tooltip(_ date: Date, locale: Locale, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
}

public struct BatteryState: Equatable, Sendable {
    public let percent: Int
    public let isCharging: Bool

    public init(percent: Int, isCharging: Bool) {
        self.percent = percent
        self.isCharging = isCharging
    }
}

public enum BatteryIconKind: Equatable, Sendable {
    case full, half, low, charging
}

public func batteryIconKind(_ state: BatteryState) -> BatteryIconKind {
    if state.isCharging { return .charging }
    if state.percent >= 70 { return .full }
    if state.percent >= 25 { return .half }
    return .low
}

public struct VolumeState: Equatable, Sendable {
    public let level: Float
    public let isMuted: Bool

    public init(level: Float, isMuted: Bool) {
        self.level = level
        self.isMuted = isMuted
    }
}

public func volumeIsSilent(_ state: VolumeState) -> Bool {
    state.isMuted || state.level <= 0
}

/// System Settings panes opened when tray items are clicked.
public enum TraySettingsURL {
    public static let sound = URL(string: "x-apple.systempreferences:com.apple.Sound-Settings.extension")!
    public static let battery = URL(string: "x-apple.systempreferences:com.apple.Battery-Settings.extension")!
    public static let dateTime = URL(string: "x-apple.systempreferences:com.apple.Date-Time-Settings.extension")!
}
