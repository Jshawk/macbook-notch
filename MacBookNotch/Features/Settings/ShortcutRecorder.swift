import AppKit
import Carbon.HIToolbox
import SwiftUI

/// Records a global shortcut: click, then press the key combination. Escape cancels; Delete clears.
struct ShortcutRecorder: View {
    @Binding var hotKey: HotKey?

    @State private var isRecording = false
    @State private var monitor: Any?
    @State private var hint: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: Theme.Spacing.xSmall) {
            HStack(spacing: Theme.Spacing.xSmall) {
                Button(action: toggleRecording) {
                    Text(buttonTitle)
                        .monospaced(hotKey != nil && !isRecording)
                        .frame(minWidth: 110)
                }
                .accessibilityLabel(isRecording ? "Recording shortcut" : "Shortcut")
                .accessibilityValue(hotKey?.displayString ?? "None")
                .accessibilityHint("Press to record a new shortcut")

                if hotKey != nil, !isRecording {
                    Button {
                        hotKey = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.borderless)
                    .help("Remove shortcut")
                    .accessibilityLabel("Remove shortcut")
                }
            }
            if let hint {
                Text(hint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onDisappear(perform: stopRecording)
    }

    private var buttonTitle: String {
        if isRecording { return "Type shortcut…" }
        return hotKey?.displayString ?? "Record Shortcut"
    }

    private func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        isRecording = true
        hint = "Press ⌘, ⌥, or ⌃ with a key. Esc cancels."
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        isRecording = false
        hint = nil
    }

    private func handle(_ event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let plain = modifiers.intersection(HotKey.supportedModifiers).isEmpty

        switch Int(event.keyCode) {
        case kVK_Escape where plain:
            stopRecording()
        case kVK_Delete where plain, kVK_ForwardDelete where plain:
            hotKey = nil
            stopRecording()
        default:
            let candidate = HotKey(
                keyCode: event.keyCode,
                modifiers: modifiers,
                keyLabel: HotKey.keyLabel(keyCode: event.keyCode, characters: event.charactersIgnoringModifiers)
            )
            if candidate.isValid {
                hotKey = candidate
                stopRecording()
            } else {
                hint = "Include ⌘, ⌥, or ⌃ so the shortcut doesn't interfere with typing."
            }
        }
    }
}
