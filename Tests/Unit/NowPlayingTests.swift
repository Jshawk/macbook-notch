import Foundation
import Testing
@testable import MacBookNotch

struct NowPlayingTests {
    private let date = Date(timeIntervalSinceReferenceDate: 800_000_000)
    private let separator = String(PlayerSnapshot.fieldSeparator)

    private func output(_ fields: String...) -> String {
        fields.joined(separator: separator)
    }

    private func track(
        source: MusicSource = .spotify,
        id: String = "track",
        isPlaying: Bool = true,
        position: TimeInterval = 30,
        at positionDate: Date? = nil
    ) -> NowPlaying {
        NowPlaying(
            source: source,
            trackID: id,
            title: "Song",
            artist: "Artist",
            album: "Album",
            isPlaying: isPlaying,
            duration: 200,
            position: position,
            positionDate: positionDate ?? date,
            artworkURL: nil
        )
    }

    // MARK: Parsing

    @Test func parsesMusicOutput() throws {
        let snapshot = PlayerSnapshot.parse(
            output("playing", "Song", "Artist", "Album", "215500", "12250", "ABC123"),
            source: .music,
            at: date
        )

        guard case .track(let track) = snapshot else {
            Issue.record("Expected a track, got \(String(describing: snapshot))")
            return
        }
        #expect(track.source == .music)
        #expect(track.title == "Song")
        #expect(track.artist == "Artist")
        #expect(track.album == "Album")
        #expect(track.isPlaying)
        #expect(track.duration == 215.5)
        #expect(track.position == 12.25)
        #expect(track.trackID == "ABC123")
        #expect(track.artworkURL == nil)
    }

    @Test func parsesSpotifyArtwork() {
        let snapshot = PlayerSnapshot.parse(
            output("paused", "Song", "Artist", "Album", "180000", "0", "spotify:track:1", "https://i.scdn.co/image/abc"),
            source: .spotify,
            at: date
        )

        guard case .track(let track) = snapshot else {
            Issue.record("Expected a track")
            return
        }
        #expect(!track.isPlaying)
        #expect(track.artworkURL == URL(string: "https://i.scdn.co/image/abc"))
    }

    @Test func keepsSeparatorFreeFieldsIntact() {
        let snapshot = PlayerSnapshot.parse(
            output("playing", "Song: Part 1, 2", "", "", "0", "0", "id"),
            source: .music,
            at: date
        )

        guard case .track(let track) = snapshot else {
            Issue.record("Expected a track")
            return
        }
        #expect(track.title == "Song: Part 1, 2")
        #expect(track.artist.isEmpty)
        #expect(!track.canSeek, "Streams report no duration")
    }

    @Test func parsesStoppedAndRejectsGarbage() {
        #expect(PlayerSnapshot.parse("stopped", source: .music, at: date) == .stopped)
        #expect(PlayerSnapshot.parse("", source: .music, at: date) == nil)
        #expect(PlayerSnapshot.parse("playing", source: .music, at: date) == nil)
        #expect(PlayerSnapshot.parse("«constant ****kPSP»", source: .music, at: date) == nil)
    }

    // MARK: Position

    @Test func estimatesPositionWhilePlaying() {
        let playing = track(position: 30)

        #expect(playing.elapsed(at: date.addingTimeInterval(10)) == 40)
        #expect(playing.elapsed(at: date.addingTimeInterval(1000)) == 200, "Never runs past the end")
    }

    @Test func pausedPositionStaysPut() {
        #expect(track(isPlaying: false, position: 30).elapsed(at: date.addingTimeInterval(10)) == 30)
    }

    @Test func newReadingContinuesOldOneWhenOnSchedule() {
        let old = track(position: 30)

        #expect(old.isContinued(by: track(position: 40.4, at: date.addingTimeInterval(10))))
        #expect(!old.isContinued(by: track(position: 90, at: date.addingTimeInterval(10))), "The user seeked")
        #expect(!old.isContinued(by: track(isPlaying: false, position: 40, at: date.addingTimeInterval(10))))
        #expect(!old.isContinued(by: track(id: "next", position: 0, at: date.addingTimeInterval(10))))
    }

    // MARK: Choosing an app

    @Test func prefersAppThatIsPlaying() {
        let snapshots: [MusicSource: PlayerSnapshot] = [
            .music: .track(track(source: .music, isPlaying: false)),
            .spotify: .track(track(source: .spotify, isPlaying: true)),
        ]

        #expect(PlayerSnapshot.preferredSource(among: snapshots, current: .music) == .spotify)
    }

    @Test func keepsCurrentAppWhenBothPlay() {
        let snapshots: [MusicSource: PlayerSnapshot] = [
            .music: .track(track(source: .music)),
            .spotify: .track(track(source: .spotify)),
        ]

        #expect(PlayerSnapshot.preferredSource(among: snapshots, current: .spotify) == .spotify)
    }

    @Test func keepsCurrentAppWhenNothingPlays() {
        let snapshots: [MusicSource: PlayerSnapshot] = [
            .music: .track(track(source: .music, isPlaying: false)),
            .spotify: .stopped,
        ]

        #expect(PlayerSnapshot.preferredSource(among: snapshots, current: .spotify) == .spotify)
        #expect(PlayerSnapshot.preferredSource(among: snapshots, current: nil) == .music, "Paused track beats stopped app")
        #expect(PlayerSnapshot.preferredSource(among: [:], current: .music) == nil)
    }
}

@MainActor
struct MusicActivityTests {
    private let defaults = TestSupport.makeDefaults()

    private func playing(_ isPlaying: Bool) -> NowPlaying {
        NowPlaying(
            source: .spotify,
            trackID: "track",
            title: "Song",
            artist: "Artist",
            album: "",
            isPlaying: isPlaying,
            duration: 200,
            position: 0,
            positionDate: .now,
            artworkURL: nil
        )
    }

    @Test func showsMusicOnlyWhilePlaying() {
        let music = MusicController()
        let center = ActivityCenter(timers: TimerStore(defaults: defaults), music: music, settings: AppSettings(defaults: defaults))

        music.apply(.nowPlaying(playing(true)))
        #expect(center.current?.kind == .nowPlaying)

        music.apply(.nowPlaying(playing(false)))
        #expect(center.current == nil)
    }

    @Test func timerOutranksMusic() {
        let timers = TimerStore(defaults: defaults)
        let music = MusicController()
        let center = ActivityCenter(timers: timers, music: music, settings: AppSettings(defaults: defaults))
        music.apply(.nowPlaying(playing(true)))

        timers.start(duration: 60)

        #expect(center.current?.kind == .timer)
    }

    @Test func reportsTrackChangesButNotTheFirstSong() {
        let music = MusicController()
        var changes: [String] = []
        music.onTrackChange = { changes.append($0.title) }

        music.apply(.nowPlaying(song("first", isPlaying: true)))
        music.apply(.nowPlaying(song("second", isPlaying: true)))
        music.apply(.nowPlaying(song("third", isPlaying: false)))
        music.apply(.idle(.spotify))
        music.apply(.nowPlaying(song("fourth", isPlaying: true)))

        #expect(changes == ["second"], "Paused and first-seen songs aren't announced")
    }

    private func song(_ id: String, isPlaying: Bool) -> NowPlaying {
        var track = playing(isPlaying)
        track.trackID = id
        track.title = id
        return track
    }

    @Test func settingHidesMusicActivity() {
        let settings = AppSettings(defaults: defaults)
        let music = MusicController()
        let center = ActivityCenter(timers: TimerStore(defaults: defaults), music: music, settings: settings)
        music.apply(.nowPlaying(playing(true)))

        settings.showMusicActivity = false

        #expect(center.current == nil)
    }
}
