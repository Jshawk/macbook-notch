import Carbon.HIToolbox
import Observation

/// Registers one system-wide shortcut through the Carbon hot key API, which needs no Accessibility permission.
@Observable
final class GlobalHotKeyCenter {
    enum RegistrationError: Equatable {
        /// Another app has already registered the same shortcut.
        case inUse
        case failed(OSStatus)
    }

    private(set) var registrationError: RegistrationError?

    @ObservationIgnored var onPress: (() -> Void)?

    @ObservationIgnored private var hotKeyRef: EventHotKeyRef?
    @ObservationIgnored private var handlerRef: EventHandlerRef?

    /// "MBNt"
    private static let signature: OSType = 0x4D42_4E74

    /// Replaces the current shortcut. Pass `nil` to remove it.
    func register(_ hotKey: HotKey?) {
        unregisterHotKey()
        registrationError = nil
        guard let hotKey, hotKey.isValid else { return }

        installHandlerIfNeeded()

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(hotKey.keyCode),
            hotKey.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: 1),
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr {
            hotKeyRef = ref
        } else {
            registrationError = status == OSStatus(eventHotKeyExistsErr) ? .inUse : .failed(status)
        }
    }

    func unregisterAll() {
        unregisterHotKey()
        if let handlerRef {
            RemoveEventHandler(handlerRef)
        }
        handlerRef = nil
    }

    private func unregisterHotKey() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                // Application event handlers run on the main thread.
                MainActor.assumeIsolated {
                    Unmanaged<GlobalHotKeyCenter>.fromOpaque(userData).takeUnretainedValue().onPress?()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )
    }
}
