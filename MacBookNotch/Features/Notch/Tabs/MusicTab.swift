import SwiftUI

/// Now Playing for Music and Spotify, with playback controls.
struct MusicTab: View {
    let music: MusicController
    let audio: AudioOutputController
    let model: NotchViewModel

    var body: some View {
        Group {
            switch music.state {
            case .nowPlaying(let track):
                NowPlayingView(track: track, artwork: music.artwork, music: music, audio: audio, model: model)
            case .idle(let source):
                MessageCard(
                    systemImage: "music.note",
                    title: "Nothing playing in \(source.displayName)"
                ) {
                    Button("Play") { music.playPause() }
                }
            case .needsPermission(let source):
                MessageCard(
                    systemImage: "music.note.list",
                    title: "Show what's playing in \(source.displayName)",
                    detail: "macOS will ask you to allow MacBook Notch to control \(source.displayName)."
                ) {
                    Button("Connect to \(source.displayName)…") { music.requestPermission(for: source) }
                        .disabled(music.isRequestingPermission)
                }
            case .denied(let source):
                MessageCard(
                    systemImage: "lock",
                    title: "MacBook Notch can't control \(source.displayName)",
                    detail: "Turn it on in System Settings > Privacy & Security > Automation."
                ) {
                    Button("Open System Settings") { music.openAutomationSettings() }
                }
            case .noPlayer:
                MessageCard(
                    systemImage: "music.note",
                    title: "Nothing playing",
                    detail: music.installedSources.isEmpty ? "Install Music or Spotify to control playback here." : nil
                ) {
                    ForEach(music.installedSources, id: \.self) { source in
                        Button("Open \(source.displayName)") { music.open(source) }
                    }
                }
            }
        }
        .onAppear { music.setDetailVisible(true) }
        .onDisappear { music.setDetailVisible(false) }
    }
}

struct NowPlayingView: View {
    let track: NowPlaying
    let artwork: NSImage?
    let music: MusicController
    let audio: AudioOutputController
    let model: NotchViewModel

    var body: some View {
        HStack(spacing: Theme.Spacing.large) {
            ArtworkView(image: artwork, size: 108)

            VStack(alignment: .leading, spacing: Theme.Spacing.xSmall) {
                HStack(alignment: .firstTextBaseline) {
                    Text(track.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    Spacer(minLength: Theme.Spacing.small)
                    Text(track.source.displayName)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.Colors.tertiaryText)
                }
                Text([track.artist, track.album].filter { !$0.isEmpty }.joined(separator: " — "))
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if track.canSeek {
                    PlaybackProgress(track: track) { music.seek(to: $0) }
                }

                HStack(spacing: 0) {
                    OutputPicker(audio: audio, model: model)
                        .frame(width: Self.sideControlWidth, alignment: .leading)
                    Spacer(minLength: 0)
                    PlaybackControls(isPlaying: track.isPlaying, music: music)
                    Spacer(minLength: 0)
                    VolumeControl(audio: audio)
                        .frame(width: Self.sideControlWidth, alignment: .trailing)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Now playing: \(track.title) by \(track.artist)")
    }

    private static let sideControlWidth: CGFloat = 110
}

/// Shows the current sound output and switches to another from a menu.
private struct OutputPicker: View {
    let audio: AudioOutputController
    let model: NotchViewModel

    var body: some View {
        Button(action: showMenu) {
            HStack(spacing: Theme.Spacing.xSmall) {
                Image(systemName: audio.currentDevice?.systemImage ?? "speaker.wave.2")
                    .font(.system(size: 12, weight: .semibold))
                Text(audio.currentDevice?.name ?? "Output")
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundStyle(Theme.Colors.secondaryText)
            .padding(.horizontal, Theme.Spacing.small)
            .frame(height: 22)
            .background(Theme.Colors.controlBackground, in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(audio.devices.isEmpty)
        .help("Sound output")
        .accessibilityLabel("Sound output")
        .accessibilityValue(audio.currentDevice?.name ?? "None")
    }

    /// Pops up a menu at the pointer and waits for it to close. The notch stays open meanwhile.
    private func showMenu() {
        let menu = NSMenu()
        for device in audio.devices {
            let item = ActionMenuItem.make(title: device.name) { audio.select(device) }
            item.state = device.id == audio.currentDeviceID ? .on : .off
            item.image = NSImage(systemSymbolName: device.systemImage, accessibilityDescription: nil)
            menu.addItem(item)
        }
        model.hold(.menu)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
        model.release(.menu)
    }
}

/// System output volume for the current device, when it has one.
private struct VolumeControl: View {
    let audio: AudioOutputController

    var body: some View {
        if let volume = audio.volume {
            HStack(spacing: Theme.Spacing.xSmall) {
                Image(systemName: Self.symbol(for: volume))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.Colors.secondaryText)
                    .frame(width: 16)
                Slider(
                    value: Binding(get: { Double(volume) }, set: { audio.setVolume(Float($0)) }),
                    in: 0...1
                )
                .controlSize(.mini)
                .tint(Theme.Colors.primaryText)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Volume")
            .accessibilityValue("\(Int((volume * 100).rounded())) percent")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: audio.setVolume(volume + 0.0625)
                case .decrement: audio.setVolume(volume - 0.0625)
                @unknown default: break
                }
            }
        }
    }

    private static func symbol(for volume: Float) -> String {
        switch volume {
        case 0: "speaker.slash.fill"
        case ..<0.34: "speaker.wave.1.fill"
        case ..<0.67: "speaker.wave.2.fill"
        default: "speaker.wave.3.fill"
        }
    }
}

private struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.35, weight: .medium))
                    .foregroundStyle(Theme.Colors.tertiaryText)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.Colors.cardBackground)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .accessibilityHidden(true)
    }
}

private struct PlaybackControls: View {
    let isPlaying: Bool
    let music: MusicController

    var body: some View {
        HStack(spacing: Theme.Spacing.large * 1.5) {
            control("backward.fill", size: 14, label: "Previous track", action: music.previousTrack)
            control(isPlaying ? "pause.fill" : "play.fill", size: 22, label: isPlaying ? "Pause" : "Play", action: music.playPause)
            control("forward.fill", size: 14, label: "Next track", action: music.nextTrack)
        }
    }

    private func control(_ systemImage: String, size: CGFloat, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: size, weight: .semibold))
                .frame(width: 32, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// A progress bar the user can click or drag to seek.
private struct PlaybackProgress: View {
    let track: NowPlaying
    let seek: (TimeInterval) -> Void

    @State private var dragFraction: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let elapsed = dragFraction.map { $0 * track.duration } ?? track.elapsed(at: timeline.date)
            let fraction = track.duration > 0 ? elapsed / track.duration : 0

            HStack(spacing: Theme.Spacing.small) {
                Text(Self.timeString(elapsed))
                    .frame(width: 36, alignment: .trailing)
                bar(fraction: fraction)
                Text("-" + Self.timeString(track.duration - elapsed))
                    .frame(width: 40, alignment: .leading)
            }
            .font(.system(size: 10, weight: .medium))
            .monospacedDigit()
            .foregroundStyle(Theme.Colors.secondaryText)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Playback position")
            .accessibilityValue("\(Self.timeString(elapsed)) of \(Self.timeString(track.duration))")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: seek(elapsed + 10)
                case .decrement: seek(elapsed - 10)
                @unknown default: break
                }
            }
        }
    }

    private func bar(fraction: Double) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Theme.Colors.controlBackground)
                Capsule()
                    .fill(Theme.Colors.primaryText)
                    .frame(width: geometry.size.width * min(max(fraction, 0), 1))
            }
            .frame(height: dragFraction == nil ? 4 : 6)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        dragFraction = min(max(value.location.x / geometry.size.width, 0), 1)
                    }
                    .onEnded { value in
                        let fraction = min(max(value.location.x / geometry.size.width, 0), 1)
                        seek(fraction * track.duration)
                        dragFraction = nil
                    }
            )
        }
        .frame(height: 14)
    }

    static func timeString(_ seconds: TimeInterval) -> String {
        let total = Int(max(0, seconds))
        let hours = total / 3600
        let minutes = total % 3600 / 60
        let remainder = total % 60
        return hours > 0
            ? String(format: "%d:%02d:%02d", hours, minutes, remainder)
            : String(format: "%d:%02d", minutes, remainder)
    }
}
