import AppKit
import Observation
import os

/// Reads and controls playback in Music and Spotify through AppleScript.
///
/// macOS asks the user once per app before MacBook Notch may control it. The controller never triggers that
/// prompt on its own: it checks permission silently and waits for `requestPermission(for:)`, which the Music tab
/// calls when the user asks to connect. Scripts only run against apps that are already open, so reading
/// playback never launches an app.
@Observable
final class MusicController {
    enum State: Equatable {
        /// Neither Music nor Spotify is open.
        case noPlayer
        /// An app is open, but the user hasn't been asked whether MacBook Notch may control it.
        case needsPermission(MusicSource)
        /// The user turned off MacBook Notch's access to the app in System Settings.
        case denied(MusicSource)
        /// An app is open with nothing loaded.
        case idle(MusicSource)
        case nowPlaying(NowPlaying)
    }

    nonisolated enum Permission: Equatable, Sendable {
        case granted
        case notDetermined
        case denied
        case notRunning
        /// The check failed for another reason, such as the app being busy. Try again on the next refresh.
        case unknown
    }

    /// Readable with `log show --predicate 'subsystem == "com.example.MacBookNotch" AND category == "Music"'`.
    nonisolated private static let logger = Logger(subsystem: "com.example.MacBookNotch", category: "Music")

    private(set) var state: State = .noPlayer
    /// Artwork for the current track, when the app provides it.
    private(set) var artwork: NSImage?
    private(set) var isRequestingPermission = false

    /// Called when a different song starts playing, but not for the first song seen after launch.
    @ObservationIgnored var onTrackChange: ((NowPlaying) -> Void)?

    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?
    @ObservationIgnored private var scripts: [String: NSAppleScript] = [:]
    @ObservationIgnored private var artworkTrackID: String?
    @ObservationIgnored private var isDetailVisible = false

    var nowPlaying: NowPlaying? {
        if case .nowPlaying(let track) = state { return track }
        return nil
    }

    /// The app the controls act on.
    var currentSource: MusicSource? {
        switch state {
        case .nowPlaying(let track): track.source
        case .idle(let source), .needsPermission(let source), .denied(let source): source
        case .noPlayer: nil
        }
    }

    /// Music apps installed on this Mac, for offering to open one.
    var installedSources: [MusicSource] {
        MusicSource.allCases.filter {
            NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.bundleIdentifier) != nil
        }
    }

    func start() {
        guard observers.isEmpty else { return }

        let distributed = DistributedNotificationCenter.default()
        for source in MusicSource.allCases {
            let token = distributed.addObserver(forName: source.playbackNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.refresh() }
            }
            observers.append((distributed, token))
        }

        let workspace = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            let token = workspace.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let isMusicApp = MusicSource.allCases.contains { $0.bundleIdentifier == app?.bundleIdentifier }
                guard isMusicApp else { return }
                MainActor.assumeIsolated { self?.scheduleRefresh(after: .milliseconds(500)) }
            }
            observers.append((workspace, token))
        }

        refresh()
        restartPolling()
    }

    func stop() {
        observers.forEach { center, token in center.removeObserver(token) }
        observers.removeAll()
        pollTask?.cancel()
        pollTask = nil
        pendingRefresh?.cancel()
    }

    /// Polls more often while the Music tab is on screen so the progress bar stays accurate.
    func setDetailVisible(_ isVisible: Bool) {
        guard isVisible != isDetailVisible else { return }
        isDetailVisible = isVisible
        if isVisible { refresh() }
        restartPolling()
    }

    // MARK: Playback

    func playPause() {
        if case .nowPlaying(var track) = state {
            // Update immediately; the next refresh confirms it.
            track.position = track.elapsed(at: .now)
            track.positionDate = .now
            track.isPlaying.toggle()
            state = .nowPlaying(track)
        }
        send("playpause")
    }

    func nextTrack() {
        send("next track")
    }

    func previousTrack() {
        send("previous track")
    }

    func seek(to seconds: TimeInterval) {
        guard case .nowPlaying(var track) = state, track.canSeek else { return }
        let target = min(max(seconds, 0), track.duration)
        track.position = target
        track.positionDate = .now
        state = .nowPlaying(track)
        send("set player position to \(Int(target * 1000)) / 1000")
    }

    func open(_ source: MusicSource) {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: source.bundleIdentifier) else { return }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
    }

    // MARK: Permission

    /// Shows the system prompt asking whether MacBook Notch may control the app.
    func requestPermission(for source: MusicSource) {
        guard !isRequestingPermission else { return }
        isRequestingPermission = true
        Self.logger.notice("Asking for permission to control \(source.displayName, privacy: .public)")
        Task {
            // Asking blocks until the user answers the prompt, so keep it off the main thread.
            let result = await Task.detached { Self.requestAccess(to: source) }.value
            Self.logger.notice("Permission to control \(source.displayName, privacy: .public): \(String(describing: result), privacy: .public)")
            isRequestingPermission = false
            refresh()
        }
    }

    /// Shows the consent prompt if the user hasn't decided yet, and returns their decision.
    nonisolated static func requestAccess(to source: MusicSource) -> Permission {
        let asked = permission(for: source, askingUser: true)
        guard asked == .notDetermined else { return asked }
        // Asking doesn't always show the prompt. Sending a real event does, so send a harmless one.
        return sendNameRequest(to: source)
    }

    func openAutomationSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
        }
    }

    nonisolated static func permission(for source: MusicSource, askingUser: Bool) -> Permission {
        let target = NSAppleEventDescriptor(bundleIdentifier: source.bundleIdentifier)
        guard let address = target.aeDesc else { return .denied }
        // Ask about the "get data" event the status scripts send. Asking about every event with
        // `typeWildCard` reports that consent is needed without showing the prompt.
        let status = AEDeterminePermissionToAutomateTarget(
            address,
            AEEventClass(kCoreEventClass),
            AEEventID(kAEGetData),
            askingUser
        )
        if askingUser {
            logger.notice("AEDeterminePermissionToAutomateTarget(\(source.displayName, privacy: .public)) returned \(status)")
        }
        switch Int(status) {
        case Int(noErr): return .granted
        case errAEEventWouldRequireUserConsent: return .notDetermined
        case procNotFound: return .notRunning
        case errAEEventNotPermitted: return .denied
        default:
            logger.error("Permission check for \(source.displayName, privacy: .public) returned \(status)")
            return .unknown
        }
    }

    /// Sends a read-only "get name" event to the app. The first event to an app shows the consent prompt,
    /// and the send waits while the user answers.
    nonisolated private static func sendNameRequest(to source: MusicSource) -> Permission {
        let target = NSAppleEventDescriptor(bundleIdentifier: source.bundleIdentifier)
        let event = NSAppleEventDescriptor(
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEGetData),
            targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransactionID)
        )
        guard let property = NSAppleEventDescriptor.record().coerce(toDescriptorType: DescType(typeObjectSpecifier)) else {
            return permission(for: source, askingUser: false)
        }
        property.setDescriptor(NSAppleEventDescriptor(typeCode: DescType(typeProperty)), forKeyword: AEKeyword(keyAEDesiredClass))
        property.setDescriptor(NSAppleEventDescriptor(enumCode: DescType(formPropertyID)), forKeyword: AEKeyword(keyAEKeyForm))
        property.setDescriptor(NSAppleEventDescriptor(typeCode: DescType(pName)), forKeyword: AEKeyword(keyAEKeyData))
        property.setDescriptor(NSAppleEventDescriptor.null(), forKeyword: AEKeyword(keyAEContainer))
        event.setParam(property, forKeyword: AEKeyword(keyDirectObject))

        do {
            // Allow time for the user to read and answer the prompt.
            _ = try event.sendEvent(options: [.waitForReply], timeout: 120)
            logger.notice("Name request to \(source.displayName, privacy: .public) succeeded")
            return .granted
        } catch {
            logger.error("Name request to \(source.displayName, privacy: .public) failed: \((error as NSError).code)")
            return permission(for: source, askingUser: false)
        }
    }

    // MARK: Reading state

    func refresh() {
        var snapshots: [MusicSource: PlayerSnapshot] = [:]
        var blocked: State?

        for source in MusicSource.allCases where Self.isRunning(source) {
            switch Self.permission(for: source, askingUser: false) {
            case .granted:
                if let snapshot = readStatus(of: source) {
                    snapshots[source] = snapshot
                }
            case .notDetermined:
                blocked = blocked ?? .needsPermission(source)
            case .denied:
                blocked = blocked ?? .denied(source)
            case .notRunning, .unknown:
                continue
            }
        }

        if let chosen = PlayerSnapshot.preferredSource(among: snapshots, current: currentSource),
           let snapshot = snapshots[chosen] {
            switch snapshot {
            case .stopped: apply(.idle(chosen))
            case .track(let track): apply(.nowPlaying(track))
            }
        } else {
            apply(blocked ?? .noPlayer)
        }
    }

    /// Applies a new state. Exposed to tests; the app calls `refresh()`.
    func apply(_ newState: State) {
        if case .nowPlaying(let current) = state, case .nowPlaying(let newer) = newState, current.isContinued(by: newer) {
            return
        }
        if case .nowPlaying(let current) = state, case .nowPlaying(let newer) = newState,
           newer.trackID != current.trackID, newer.isPlaying {
            onTrackChange?(newer)
        }
        if newState != state {
            if !Self.isSameCase(newState, state) {
                Self.logger.notice("Music state: \(String(describing: newState), privacy: .public)")
            }
            state = newState
        }
        updateArtwork()
    }

    private func readStatus(of source: MusicSource) -> PlayerSnapshot? {
        guard let output = run(Self.statusScript(for: source))?.stringValue else { return nil }
        return PlayerSnapshot.parse(output, source: source, at: .now)
    }

    private func updateArtwork() {
        guard let track = nowPlaying else {
            artwork = nil
            artworkTrackID = nil
            return
        }
        guard track.trackID != artworkTrackID else { return }
        artworkTrackID = track.trackID
        artwork = nil

        switch track.source {
        case .music:
            guard Self.isRunning(.music) else { return }
            if let data = run(Self.musicArtworkScript)?.data, let image = NSImage(data: data) {
                artwork = image
            }
        case .spotify:
            guard let url = track.artworkURL else { return }
            Task {
                guard let (data, _) = try? await URLSession.shared.data(from: url),
                      let image = NSImage(data: data),
                      artworkTrackID == track.trackID
                else { return }
                artwork = image
            }
        }
    }

    // MARK: Scripts

    private func send(_ command: String) {
        // Scripting an app that isn't running would launch it.
        guard let source = currentSource,
              Self.isRunning(source),
              Self.permission(for: source, askingUser: false) == .granted
        else { return }
        _ = run("""
            with timeout of 3 seconds
                tell application id "\(source.bundleIdentifier)" to \(command)
            end timeout
            """)
        scheduleRefresh(after: .milliseconds(300))
    }

    private func run(_ source: String) -> NSAppleEventDescriptor? {
        let script = scripts[source] ?? {
            let script = NSAppleScript(source: source)
            scripts[source] = script
            return script
        }()
        guard let script else { return nil }

        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            if error[NSAppleScript.errorNumber] as? Int == errAEEventNotPermitted, let current = currentSource {
                apply(.denied(current))
            }
            return nil
        }
        return result
    }

    private func scheduleRefresh(after delay: Duration) {
        pendingRefresh?.cancel()
        pendingRefresh = Task { [weak self] in
            try? await Task.sleep(for: delay)
            guard !Task.isCancelled else { return }
            self?.refresh()
        }
    }

    private func restartPolling() {
        pollTask?.cancel()
        let interval: Duration = isDetailVisible ? .seconds(1) : .seconds(3)
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }
    }

    private static func isSameCase(_ a: State, _ b: State) -> Bool {
        switch (a, b) {
        case (.nowPlaying, .nowPlaying): true
        default: a == b
        }
    }

    private static func isRunning(_ source: MusicSource) -> Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: source.bundleIdentifier).isEmpty
    }

    private static func statusScript(for source: MusicSource) -> String {
        switch source {
        case .music:
            """
            with timeout of 3 seconds
                tell application id "com.apple.Music"
                    set sep to character id 31
                    set playerState to player state as string
                    if playerState is "stopped" then return playerState
                    set t to current track
                    set trackDuration to 0
                    try
                        set trackDuration to duration of t
                    end try
                    set playerPosition to 0
                    try
                        set playerPosition to player position
                    end try
                    return playerState & sep & (name of t) & sep & (artist of t) & sep & (album of t) & sep & ((round (trackDuration * 1000)) as integer as string) & sep & ((round (playerPosition * 1000)) as integer as string) & sep & (persistent ID of t)
                end tell
            end timeout
            """
        case .spotify:
            """
            with timeout of 3 seconds
                tell application id "com.spotify.client"
                    set sep to character id 31
                    set playerState to player state as string
                    if playerState is "stopped" then return playerState
                    set t to current track
                    set playerPosition to 0
                    try
                        set playerPosition to player position
                    end try
                    return playerState & sep & (name of t) & sep & (artist of t) & sep & (album of t) & sep & ((duration of t) as integer as string) & sep & ((round (playerPosition * 1000)) as integer as string) & sep & (id of t) & sep & (artwork url of t)
                end tell
            end timeout
            """
        }
    }

    private static let musicArtworkScript = """
        with timeout of 3 seconds
            tell application id "com.apple.Music" to get raw data of artwork 1 of current track
        end timeout
        """
}
