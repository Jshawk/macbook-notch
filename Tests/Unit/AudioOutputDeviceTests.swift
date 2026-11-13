import AppKit
import CoreAudio
import Testing
@testable import MacBookNotch

struct AudioOutputDeviceTests {
    @Test func recognizesDevicesByName() {
        #expect(AudioOutputDevice.systemImage(name: "Jayden's AirPods Pro", transportType: kAudioDeviceTransportTypeBluetooth) == "airpodspro")
        #expect(AudioOutputDevice.systemImage(name: "AirPods Max", transportType: kAudioDeviceTransportTypeBluetooth) == "airpodsmax")
        #expect(AudioOutputDevice.systemImage(name: "AirPods", transportType: kAudioDeviceTransportTypeBluetooth) == "airpods")
        #expect(AudioOutputDevice.systemImage(name: "Beats Studio", transportType: kAudioDeviceTransportTypeBluetooth) == "beats.headphones")
    }

    @Test func fallsBackToConnectionType() {
        #expect(AudioOutputDevice.systemImage(name: "MacBook Pro Speakers", transportType: kAudioDeviceTransportTypeBuiltIn) == "laptopcomputer")
        #expect(AudioOutputDevice.systemImage(name: "External Headphones", transportType: kAudioDeviceTransportTypeBuiltIn) == "headphones")
        #expect(AudioOutputDevice.systemImage(name: "Sony WH-1000XM5", transportType: kAudioDeviceTransportTypeBluetooth) == "headphones")
        #expect(AudioOutputDevice.systemImage(name: "LG UltraFine", transportType: kAudioDeviceTransportTypeDisplayPort) == "tv")
        #expect(AudioOutputDevice.systemImage(name: "Living Room", transportType: kAudioDeviceTransportTypeAirPlay) == "airplayaudio")
        #expect(AudioOutputDevice.systemImage(name: "Scarlett 2i2", transportType: kAudioDeviceTransportTypeUSB) == "hifispeaker")
    }

    @Test func everySymbolExists() {
        let names = ["AirPods Pro", "AirPods Max", "AirPods", "Beats", "HomePod", "Headphone", "Speakers", "Other"]
        let transports = [
            kAudioDeviceTransportTypeBuiltIn, kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeAirPlay,
            kAudioDeviceTransportTypeHDMI, kAudioDeviceTransportTypeUSB,
        ]
        for name in names {
            for transport in transports {
                let symbol = AudioOutputDevice.systemImage(name: name, transportType: transport)
                #expect(NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil, "\(symbol)")
            }
        }
    }
}
