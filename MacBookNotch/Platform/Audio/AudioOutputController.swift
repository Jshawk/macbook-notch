import AudioToolbox
import CoreAudio
import Observation
import os

/// The system's sound output devices, the current one, and its volume.
@Observable
final class AudioOutputController {
    private(set) var devices: [AudioOutputDevice] = []
    private(set) var currentDeviceID: AudioDeviceID?
    /// Volume of the current device from 0 to 1, or `nil` when the device has no adjustable volume.
    private(set) var volume: Float?

    nonisolated private static let logger = Logger(subsystem: "com.example.MacBookNotch", category: "Audio")

    @ObservationIgnored private var listeners: [(AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)] = []
    @ObservationIgnored private var volumeListener: (AudioObjectID, AudioObjectPropertyAddress, AudioObjectPropertyListenerBlock)?

    var currentDevice: AudioOutputDevice? {
        devices.first { $0.id == currentDeviceID }
    }

    func start() {
        guard listeners.isEmpty else { return }
        let system = AudioObjectID(kAudioObjectSystemObject)
        for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultOutputDevice] {
            addListener(to: system, address: Self.address(selector)) { [weak self] in self?.refresh() }
        }
        refresh()
    }

    func stop() {
        for (object, address, block) in listeners {
            var address = address
            AudioObjectRemovePropertyListenerBlock(object, &address, .main, block)
        }
        listeners.removeAll()
        removeVolumeListener()
    }

    /// Makes a device the system's sound output, as choosing it in Control Center would.
    func select(_ device: AudioOutputDevice) {
        var id = device.id
        var address = Self.address(kAudioHardwarePropertyDefaultOutputDevice)
        let status = AudioObjectSetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, UInt32(MemoryLayout<AudioDeviceID>.size), &id
        )
        if status != noErr {
            Self.logger.error("Couldn't switch output to \(device.name, privacy: .public): \(status)")
        }
        refresh()
    }

    func setVolume(_ newValue: Float) {
        guard let id = currentDeviceID else { return }
        var value = min(max(newValue, 0), 1)
        var address = Self.volumeAddress
        let status = AudioObjectSetPropertyData(id, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value)
        if status == noErr {
            volume = value
        } else {
            Self.logger.error("Couldn't set volume: \(status)")
        }
    }

    func refresh() {
        let newDevices = Self.outputDeviceIDs().compactMap(Self.makeDevice)
        if newDevices != devices {
            devices = newDevices
        }
        let current = Self.defaultOutputDeviceID()
        if current != currentDeviceID {
            currentDeviceID = current
            observeVolume(of: current)
        }
        updateVolume()
    }

    private func updateVolume() {
        let newVolume = currentDeviceID.flatMap(Self.volume(of:))
        if newVolume != volume {
            volume = newVolume
        }
    }

    // MARK: Listeners

    private func addListener(to object: AudioObjectID, address: AudioObjectPropertyAddress, handler: @escaping () -> Void) {
        var address = address
        // Listener blocks run on the main queue.
        let block: AudioObjectPropertyListenerBlock = { _, _ in
            MainActor.assumeIsolated { handler() }
        }
        if AudioObjectAddPropertyListenerBlock(object, &address, .main, block) == noErr {
            listeners.append((object, address, block))
        }
    }

    private func observeVolume(of device: AudioDeviceID?) {
        removeVolumeListener()
        guard let device, Self.hasVolume(device) else { return }
        var address = Self.volumeAddress
        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            MainActor.assumeIsolated { self?.updateVolume() }
        }
        if AudioObjectAddPropertyListenerBlock(device, &address, .main, block) == noErr {
            volumeListener = (device, address, block)
        }
    }

    private func removeVolumeListener() {
        guard let (device, address, block) = volumeListener else { return }
        var mutableAddress = address
        AudioObjectRemovePropertyListenerBlock(device, &mutableAddress, .main, block)
        volumeListener = nil
    }

    // MARK: CoreAudio queries

    private static let volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    private static func address(
        _ selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal
    ) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }

    private static func outputDeviceIDs() -> [AudioDeviceID] {
        var address = address(kAudioHardwarePropertyDevices)
        let system = AudioObjectID(kAudioObjectSystemObject)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr else { return [] }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &ids) == noErr else { return [] }
        return ids.filter(hasOutputStreams)
    }

    private static func hasOutputStreams(_ id: AudioDeviceID) -> Bool {
        var address = address(kAudioDevicePropertyStreams, scope: kAudioDevicePropertyScopeOutput)
        var size: UInt32 = 0
        return AudioObjectGetPropertyDataSize(id, &address, 0, nil, &size) == noErr && size > 0
    }

    private static func makeDevice(_ id: AudioDeviceID) -> AudioOutputDevice? {
        guard !isHidden(id), let name = name(of: id), !name.hasPrefix("CADefaultDeviceAggregate") else { return nil }
        return AudioOutputDevice(id: id, name: name, transportType: transportType(of: id))
    }

    private static func name(of id: AudioDeviceID) -> String? {
        var address = address(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>?
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &name) == noErr else { return nil }
        return name?.takeRetainedValue() as String?
    }

    private static func transportType(of id: AudioDeviceID) -> UInt32 {
        uint32Property(kAudioDevicePropertyTransportType, of: id) ?? 0
    }

    private static func isHidden(_ id: AudioDeviceID) -> Bool {
        uint32Property(kAudioDevicePropertyIsHidden, of: id) == 1
    }

    private static func uint32Property(_ selector: AudioObjectPropertySelector, of id: AudioObjectID) -> UInt32? {
        var address = address(selector)
        var value: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }

    private static func defaultOutputDeviceID() -> AudioDeviceID? {
        uint32Property(kAudioHardwarePropertyDefaultOutputDevice, of: AudioObjectID(kAudioObjectSystemObject))
            .flatMap { $0 == kAudioObjectUnknown ? nil : $0 }
    }

    private static func hasVolume(_ id: AudioDeviceID) -> Bool {
        var address = volumeAddress
        guard AudioObjectHasProperty(id, &address) else { return false }
        var isSettable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(id, &address, &isSettable) == noErr && isSettable.boolValue
    }

    private static func volume(of id: AudioDeviceID) -> Float? {
        guard hasVolume(id) else { return nil }
        var address = volumeAddress
        var value: Float32 = 0
        var size = UInt32(MemoryLayout<Float32>.size)
        guard AudioObjectGetPropertyData(id, &address, 0, nil, &size, &value) == noErr else { return nil }
        return value
    }
}
