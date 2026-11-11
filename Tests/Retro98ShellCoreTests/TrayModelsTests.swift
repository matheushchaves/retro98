import Foundation
import Testing
@testable import Retro98ShellCore

private let sample = Date(timeIntervalSince1970: 1_762_850_400)  // 2025-11-11 08:40 UTC
private let utc = TimeZone(identifier: "UTC")!

@Test func clockUses24HourInBrazil() {
    #expect(ClockText.time(sample, locale: Locale(identifier: "pt_BR"), timeZone: utc) == "08:40")
}

@Test func clockFollowsLocaleTwelveHour() {
    #expect(ClockText.time(sample, locale: Locale(identifier: "en_US"), timeZone: utc).contains("8:40"))
}

@Test func clockTooltipIsLongDate() {
    let tooltip = ClockText.tooltip(sample, locale: Locale(identifier: "pt_BR"), timeZone: utc)
    #expect(tooltip.contains("novembro"))
    #expect(tooltip.contains("2025"))
}

@Test func batteryIconThresholds() {
    #expect(batteryIconKind(BatteryState(percent: 80, isCharging: false)) == .full)
    #expect(batteryIconKind(BatteryState(percent: 70, isCharging: false)) == .full)
    #expect(batteryIconKind(BatteryState(percent: 40, isCharging: false)) == .half)
    #expect(batteryIconKind(BatteryState(percent: 25, isCharging: false)) == .half)
    #expect(batteryIconKind(BatteryState(percent: 10, isCharging: false)) == .low)
    #expect(batteryIconKind(BatteryState(percent: 10, isCharging: true)) == .charging)
}

@Test func volumeSilenceWhenMutedOrZero() {
    #expect(volumeIsSilent(VolumeState(level: 0.5, isMuted: true)))
    #expect(volumeIsSilent(VolumeState(level: 0, isMuted: false)))
    #expect(!volumeIsSilent(VolumeState(level: 0.3, isMuted: false)))
}

@Test func traySettingsURLs() {
    #expect(TraySettingsURL.sound.absoluteString == "x-apple.systempreferences:com.apple.Sound-Settings.extension")
    #expect(TraySettingsURL.battery.absoluteString == "x-apple.systempreferences:com.apple.Battery-Settings.extension")
    #expect(TraySettingsURL.dateTime.absoluteString == "x-apple.systempreferences:com.apple.Date-Time-Settings.extension")
}
