import Carbon.HIToolbox
import Foundation

/// Global ⌃⎋ shortcut through the public Carbon hot-key API (no permission needed).
@MainActor
final class HotKey {
    private static let signature: OSType = 0x5239_3821   // "R98!"
    nonisolated(unsafe) private static var handler: (@MainActor () -> Void)?
    private var reference: EventHotKeyRef?

    init(action: @escaping @MainActor () -> Void) {
        Self.handler = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { MainActor.assumeIsolated { HotKey.handler?() } }
            return noErr
        }, 1, &spec, nil, nil)
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        RegisterEventHotKey(UInt32(kVK_Escape), UInt32(controlKey), id, GetApplicationEventTarget(), 0, &reference)
    }
}
