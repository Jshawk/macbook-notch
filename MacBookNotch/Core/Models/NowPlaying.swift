import Foundation

/// A music app MacBook Notch can read and control through its scripting interface.
nonisolated enum MusicSource: String, CaseIterable, Codable, Sendable {
    case music
    case spotify

    var bundleIdentifier: String {
        switch self {
        case .music: "com.apple.Music"
        case .spotify: "com.spotify.client"
        }
    }

    var displayName: String {
        switch self {
        case .music: "Music"
        case .spotify: "Spotify"
        }
    }

    /// Distributed notification the app posts whenever playback or the track changes.
    var playbackNotification: Notification.Name {
        switch self {
        case .music: Notification.Name("com.apple.Music.playerInfo")
        case .spotify: Notification.Name("com.spotify.client.PlaybackStateChanged")
        }
    }
}

/// The track loaded in a music app.
nonisolated struct NowPlaying: Equatable, Sendable {
    var source: MusicSource
    var trackID: String
    var title: String
    var artist: String
    var album: String
    var isPlaying: Bool
    /// Track length in seconds, or 0 when unknown, as with radio streams.
    var duration: TimeInterval
    /// Playback position in seconds when the player was last asked, at `positionDate`.
    var position: TimeInterval
    var positionDate: Date
    var artworkURL: URL?

    var canSeek: Bool {
        duration > 0
    }

    /// The playback position now, estimated from the last reading.
    func elapsed(at now: Date) -> TimeInterval {
        let elapsed = isPlaying ? position + now.timeIntervalSince(positionDate) : position
        return duration > 0 ? min(max(elapsed, 0), duration) : max(elapsed, 0)
    }

    /// Whether a new reading only confirms this one: same track and state, and a position within a second
    /// of the estimate. Keeping the older reading avoids redrawing every time the player is polled.
    func isContinued(by newer: NowPlaying) -> Bool {
        source == newer.source
            && trackID == newer.trackID
            && isPlaying == newer.isPlaying
            && title == newer.title
            && abs(elapsed(at: newer.positionDate) - newer.position) < 1
    }
}

/// What a music app reported when it was last asked.
nonisolated enum PlayerSnapshot: Equatable, Sendable {
    case stopped
    case track(NowPlaying)

    /// Separates fields in the status scripts' output. Track names can't contain this control character.
    static let fieldSeparator: Character = "\u{1F}"

    /// Parses the output of a status script: `state`, or
    /// `state␟title␟artist␟album␟durationMilliseconds␟positionMilliseconds␟trackID[␟artworkURL]`.
    static func parse(_ output: String, source: MusicSource, at date: Date) -> PlayerSnapshot? {
        let fields = output.split(separator: fieldSeparator, omittingEmptySubsequences: false).map(String.init)
        guard let state = fields.first else { return nil }

        switch state {
        case "stopped":
            return .stopped
        case "playing", "paused":
            break
        default:
            return nil
        }

        guard fields.count >= 7 else { return nil }
        let artworkURL = fields.count > 7 ? URL(string: fields[7]) : nil
        return .track(NowPlaying(
            source: source,
            trackID: fields[6],
            title: fields[1],
            artist: fields[2],
            album: fields[3],
            isPlaying: state == "playing",
            duration: (Double(fields[4]) ?? 0) / 1000,
            position: (Double(fields[5]) ?? 0) / 1000,
            positionDate: date,
            artworkURL: artworkURL?.scheme == nil ? nil : artworkURL
        ))
    }

    var isPlaying: Bool {
        if case .track(let track) = self { return track.isPlaying }
        return false
    }

    /// Picks which app to show when more than one is running:
    /// an app that's playing (the current one first), then the current app, then one with a paused track.
    static func preferredSource(among snapshots: [MusicSource: PlayerSnapshot], current: MusicSource?) -> MusicSource? {
        let ordered = MusicSource.allCases.filter { snapshots[$0] != nil }

        if let current, snapshots[current]?.isPlaying == true {
            return current
        }
        if let playing = ordered.first(where: { snapshots[$0]?.isPlaying == true }) {
            return playing
        }
        if let current, snapshots[current] != nil {
            return current
        }
        if let paused = ordered.first(where: { if case .track = snapshots[$0] { true } else { false } }) {
            return paused
        }
        return ordered.first
    }
}
