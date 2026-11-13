import CoreAudio

/// A device that can play sound, such as the built-in speakers, AirPods, or a display.
nonisolated struct AudioOutputDevice: Equatable, Identifiable, Sendable {
    let id: AudioDeviceID
    var name: String
    var transportType: UInt32

    var systemImage: String {
        Self.systemImage(name: name, transportType: transportType)
    }

    /// Picks a symbol from the device's name when it's recognizable, otherwise from how it's connected.
    static func systemImage(name: String, transportType: UInt32) -> String {
        let name = name.lowercased()
        if name.contains("airpods max") { return "airpodsmax" }
        if name.contains("airpods pro") { return "airpodspro" }
        if name.contains("airpods") { return "airpods" }
        if name.contains("beats") { return "beats.headphones" }
        if name.contains("homepod") { return "homepod" }

        switch transportType {
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE:
            return "headphones"
        case kAudioDeviceTransportTypeAirPlay:
            return "airplayaudio"
        case kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeDisplayPort:
            return "tv"
        case kAudioDeviceTransportTypeBuiltIn:
            return name.contains("headphone") ? "headphones" : "laptopcomputer"
        default:
            return "hifispeaker"
        }
    }
}
