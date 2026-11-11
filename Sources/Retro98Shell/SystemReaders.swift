import CoreAudio
import Foundation
import IOKit.ps
import Retro98ShellCore

/// Reads battery and output volume through public IOKit and CoreAudio APIs.
enum SystemReaders {
    /// Nil on Macs without an internal battery. "Charging" means plugged into power.
    static func battery() -> BatteryState? {
        guard let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef]
        else { return nil }
        for source in sources {
            guard let description = IOPSGetPowerSourceDescription(info, source)?.takeUnretainedValue() as? [String: Any],
                  description[kIOPSTypeKey] as? String == kIOPSInternalBatteryType
            else { continue }
            let current = description[kIOPSCurrentCapacityKey] as? Int ?? 0
            let maximum = max(description[kIOPSMaxCapacityKey] as? Int ?? 100, 1)
            let pluggedIn = description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue
            return BatteryState(percent: current * 100 / maximum, isCharging: pluggedIn)
        }
        return nil
    }

    static func volume() -> VolumeState? {
        guard let device = defaultOutputDevice() else { return nil }
        let level = scalar(kAudioDevicePropertyVolumeScalar, device: device, element: kAudioObjectPropertyElementMain)
            ?? scalar(kAudioDevicePropertyVolumeScalar, device: device, element: 1)
            ?? 0
        var muted: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioDevicePropertyMute,
                                                 mScope: kAudioDevicePropertyScopeOutput,
                                                 mElement: kAudioObjectPropertyElementMain)
        let muteStatus = AudioObjectGetPropertyData(device, &address, 0, nil, &size, &muted)
        return VolumeState(level: level, isMuted: muteStatus == noErr && muted != 0)
    }

    private static func defaultOutputDevice() -> AudioObjectID? {
        var device = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(mSelector: kAudioHardwarePropertyDefaultOutputDevice,
                                                 mScope: kAudioObjectPropertyScopeGlobal,
                                                 mElement: kAudioObjectPropertyElementMain)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device)
        return status == noErr && device != 0 ? device : nil
    }

    private static func scalar(_ selector: AudioObjectPropertySelector, device: AudioObjectID, element: UInt32) -> Float? {
        var value = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        var address = AudioObjectPropertyAddress(mSelector: selector, mScope: kAudioDevicePropertyScopeOutput, mElement: element)
        return AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr ? value : nil
    }
}
