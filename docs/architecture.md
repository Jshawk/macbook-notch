# Architecture

MacBook Notch is an agent app (`LSUIElement`): it has no Dock icon and no main window. It draws a black shape over the camera housing. The shape widens to show a short activity (such as an upcoming meeting, a timer, or the song that's playing) and expands into a tabbed panel — Home, Calendar, Music, Timers, and Shelf — when hovered, clicked, or opened with a keyboard shortcut.

## Startup

1. `MacBookNotchApp` declares a `MenuBarExtra` (Settings, Quit) and hands lifecycle to `AppDelegate`.
2. `AppDelegate` owns the shared services (`AppSettings`, `BatteryMonitor`, `TimerStore`, `CalendarService`, `MusicController`, `AudioOutputController`, `ActivityCenter`, `ShelfStore`, `ChecklistStore`, `GlobalHotKeyCenter`, `TimerAlerts`, `LaunchAtLogin`), connects them, starts `NotchWindowController`, and creates the settings window on demand.
3. When the app is hosting unit tests (`XCTestConfigurationFilePath` is set), the delegate skips opening the panel.

## The notch panel

| Piece | Folder | Responsibility |
| --- | --- | --- |
| `NotchGeometry` | Platform/Screens | Finds the notch rect from `safeAreaInsets` and the auxiliary top areas, or builds a centered virtual notch on displays without one. |
| `ScreenSelector` | Platform/Screens | Picks the built-in or primary display based on settings. |
| `NotchLayout` | Features/Notch | Pure math: shape size per presentation, the panel frame, and the rect that captures the pointer. |
| `NotchViewModel` | Features/Notch | Collapsed/expanded state, the selected tab, hover and collapse delays, click-outside handling, and reasons to hold the notch open. |
| `ExpandedNotchContent` | Features/Notch | The header (tab bar and Settings button) and the selected tab from `Features/Notch/Tabs`. |
| `NotchView` | Features/Notch | Draws `NotchShape`, animates between presentations, and accepts file drops for the shelf. |
| `NotchPanel` | Platform/Windows | Borderless, non-activating `NSPanel` above the menu bar on every Space, including full-screen Spaces. |
| `NotchWindowController` | Platform/Windows | Positions the panel, listens for screen, settings, and layout changes, and routes mouse and keyboard events to the view model. |

### State and presentation

`NotchViewModel.state` records what the user asked for: `collapsed` or `expanded`. `presentation` is what's drawn, and adds two cases for a collapsed notch while `ActivityCenter` has something to show:

- `compact` stays in the menu bar strip and uses the space on either side of the camera housing.
- `banner` adds one line of text below, used for the name of a new song.

### Tabs

The expanded notch shows one tab at a time. The tab bar sits in the header to the left of the camera housing.

- The selected tab is kept between openings.
- Clicking a compact activity opens its tab: a meeting opens Calendar, a timer opens Timers, music opens Music, and a power change opens Home.
- Dragging files over the notch opens Shelf.
- When the notch has keyboard focus, ⌘1, ⌘2, and so on switch tabs.
- Settings can hide or reorder tabs. The last visible tab can't be hidden.

### Holding the notch open

Normally the notch closes shortly after the pointer leaves it. `NotchViewModel.HoldReason` covers the cases where that would get in the way:

- `keyboard`: opened with the shortcut. It stays open until Escape, the shortcut again, or a click elsewhere.
- `editing`: the user is typing a custom timer.
- `dragging`: a file is being dragged out of the shelf. The drag's source view must stay alive until the drop finishes.
- `menu`: a menu from the notch is open, such as a shelf item's menu or the sound output list. The menus run modally, and closing the notch would remove their anchor.
- `previewing`: a Quick Look preview of a shelf item is open.

When a hold ends and the pointer has already left, the notch closes as it would have without the hold.

### Why the panel never resizes during animation

The panel is sized for the expanded state (plus room for a shadow) and only moves when the screen changes. The SwiftUI shape does the animating, so expanding never waits on window resizing.

The open notch is shorter when the current tab shows only a one-row `MessageCard`, such as "Nothing playing" or a permission prompt. `NotchContext.showsMessage(on:)` decides this and `NotchViewModel.layout` reads it, so the layout updates when the tab changes or when that state does (for example when a song starts). The panel keeps its full height; only the shape and the pointer area shrink.

Because the panel is larger than the collapsed notch, it must not swallow clicks meant for the menu bar or the windows below it. The controller watches mouse movement (a global monitor while the pointer is over other apps, and a tracking area while the panel receives events) and sets `ignoresMouseEvents` to `false` only while the pointer is inside `NotchLayout.interactiveRect(for:)`. Global monitoring of mouse events doesn't require Accessibility permission.

### Keyboard focus

The panel is non-activating and uses `becomesKeyOnlyIfNeeded`, so clicking a widget button doesn't take keyboard focus from the app the user is working in. The panel becomes key only when:

- the keyboard shortcut opens it, so Escape can close it, or
- the user starts entering a custom timer.

After the notch collapses, the controller orders the panel out and back in so keyboard focus returns to the previously active app.

The toggle shortcut is registered with the Carbon `RegisterEventHotKey` API (`GlobalHotKeyCenter`). It needs no Accessibility permission and works in the sandbox. Registration only reports conflicts with other apps' registered hot keys. It can't detect a shortcut that another app handles in its own menus.

### Coordinates

`NotchGeometry` and `NotchLayout` use AppKit global screen coordinates (origin at the bottom-left of the primary display), which is what `NSEvent.mouseLocation` returns. SwiftUI only sees sizes, so it doesn't need to convert coordinates.

## Activities

`ActivityCenter` chooses what the compact notch shows, using `NotchActivity.resolve(alerts:ongoing:)`:

| Activity | Kind | Priority | Lasts |
| --- | --- | --- | --- |
| Timer finished | Alert | 4 | 10 seconds |
| Power connected or disconnected | Alert | 3 | 4 seconds |
| Song changed (shown as a banner) | Alert | 3 | 4 seconds |
| Event starting soon | Ongoing | 2 | From the reminder time until a minute after it starts |
| Next running timer | Ongoing | 1 | Until the timer ends |
| Song playing in Music or Spotify | Ongoing | 0 | While playing; can be turned off |

- The highest priority wins. Among equals, the newest alert wins.
- A new alert replaces an older one of the same kind, so repeated events (such as plugging in and out quickly) don't pile up.
- When alerts expire, the notch returns to the ongoing activity, or to plain collapsed.
- Opening the notch counts as seeing the alerts and dismisses them.
- VoiceOver announces finished timers, power changes, and meeting reminders. It doesn't announce song changes or ongoing activities, which would be too chatty.

## Timers

`CountdownTimer` stores a deadline (`endDate`) rather than a ticking counter, and stores the remaining time while paused. This keeps the remaining time correct across sleep, wake, and relaunch. `TimerStore` saves timers as JSON in `UserDefaults` and schedules one task for the next deadline. `AppDelegate` also checks for finished timers:

- at launch, for timers that ended while the app wasn't running, and
- on `NSWorkspace.didWakeNotification`.

`TimerAlerts` plays a sound and optionally posts a notification. Notification permission is requested only when the user turns that option on.

## Calendar

`CalendarService` reads events from EventKit for today and tomorrow, plus the month the Calendar tab is showing, and turns them into `CalendarEvent` values, so the rules in `CalendarAgenda` and `MeetingLink` can be tested without the event store.

**Access.** The app asks for full calendar access only when the user clicks Connect, in the Calendar tab or in Settings. It requires:

- the `com.apple.security.personal-information.calendars` entitlement, and
- the `NSCalendarsFullAccessUsageDescription` Info.plist entry.

**Refreshing.** The service reloads on `EKEventStoreChanged`, when the day changes, and when the time zone changes, plus every five minutes as a backstop.

**Reminders.** Every 15 seconds, the service recomputes which event (if any) is within the reminder lead time, so reminders appear and disappear on time.

**Join links.** `MeetingLink` finds Zoom, Google Meet, Teams, Webex, FaceTime, and Whereby links in an event's URL, location, and notes. It uses `NSDataDetector` and then checks each link's host and path, so ordinary links like shared documents don't get a Join button.

**Showing an event in Calendar.** Double-clicking an event opens its `ical://` link, which makes Calendar show the event's details. EventKit builds that link for each occurrence only through a private method (`showEventURLString`), so `CalendarService` uses it when it exists and otherwise falls back to the `ical://ekevent/<calendarItemIdentifier>?method=show&options=more` form that Calendar handles, which shows the first occurrence of a repeating event.

**Settings.** Users can hide calendars, hide all-day events, and choose the reminder lead time, or turn reminders off.

## Music

`MusicController` reads and controls Music and Spotify through AppleScript. There's no public API for system-wide Now Playing; the private MediaRemote framework that offers one is restricted on recent macOS versions, so the app doesn't depend on it. Players other than Music and Spotify, such as browsers, aren't shown.

**Permission.** macOS asks once per app whether MacBook Notch may control it.

- The controller checks with `AEDeterminePermissionToAutomateTarget` without prompting.
- It prompts only when the user clicks Connect in the Music tab. That call blocks until the user answers, so it runs off the main thread.
- If access is denied, the tab links to System Settings > Privacy & Security > Automation.

**Never launching apps.** AppleScript's `tell application` launches an app that isn't running. Every script first checks that its target is already running.

**Staying current.**

- The controller refreshes when either app posts its playback distributed notification, and when either app launches or quits.
- It also polls every 3 seconds, or every second while the Music tab is showing.
- The playback position is estimated between readings. A reading that only confirms the estimate is ignored, to avoid redrawing.

**Parsing.** The status scripts return fields separated by U+001F, with times as whole milliseconds, so the output doesn't depend on the locale's decimal separator. `PlayerSnapshot.parse` turns that output into a `NowPlaying` and is covered by unit tests.

**Artwork.** Music artwork comes from the script. Spotify returns an artwork URL, which is downloaded.

**Song changes.** `MusicController.onTrackChange` fires when a different song starts playing, but not for the first song seen after launch. `AppDelegate` posts a `trackChanged` alert, which the notch shows as a banner.

**Sound output.** `AudioOutputController` (Platform/Audio) uses CoreAudio to:

- list output devices,
- switch the system default output, and
- read and set the current device's volume through `kAudioHardwareServiceDeviceProperty_VirtualMainVolume`.

It listens for device, default-output, and volume changes, so the Music tab updates when AirPods connect or the volume keys are pressed. Devices without adjustable volume, such as some displays, hide the slider.

**Entitlements** (`MacBookNotch/MacBookNotch.entitlements`):

- `com.apple.security.automation.apple-events`, required by the hardened runtime.
- A sandbox temporary exception that allows Apple Events to `com.apple.Music` and `com.spotify.client`.
- `com.apple.security.network.client`, for Spotify artwork.

The temporary exception is fine for direct download. For the Mac App Store, Music can use `com.apple.security.scripting-targets` instead, but Spotify control would likely be rejected.

## Today's checklist

`ChecklistStore` keeps up to five tasks (`ChecklistStore.maximumItems`), which is as many rows as fit on the Home tab. Tasks are saved as JSON in `UserDefaults`, like timers.

- A task that's checked off stays visible, struck through, for the rest of the day. `clearTasksFinishedBeforeToday()` removes it on a later day. It runs at launch and whenever the Home tab appears. Unfinished tasks carry over.
- Adding a task holds the notch open (`editing`) and makes the panel key so the field can take typing, as the custom timer field does. Return adds the task and keeps the field open for the next one; Escape or clicking away ends.

## File shelf

`ShelfStore` keeps references to dropped files until the user removes them.

**Surviving relaunch.** Access to a dropped file normally ends when a sandboxed app quits.

- Each item stores a security-scoped bookmark (`com.apple.security.files.bookmarks.app-scope`) in `Shelf.json`, in the app container's Application Support folder.
- On launch, the store resolves each bookmark and reopens access to the file.
- If a bookmark has gone stale, the store refreshes it.
- A bookmark follows the file if it's moved or renamed.

**Pinning.** Pinned items appear first and stay when the shelf is cleared.

**Quick Look.** It previews an item through the shared `QLPreviewPanel`. `NotchPanel` answers the panel's responder-chain query and hands over `QuickLookPresenter`. The app activates so the preview can take keyboard focus, and it reactivates the previous app when the preview closes.

**Safety.**

- Removing items or clearing the shelf never touches the files.
- Dragging out of the shelf offers only `.copy`, so dropping into Finder copies the file rather than moving it.
- Clicking or right-clicking an item shows a menu (Quick Look, Open, Reveal in Finder, Copy, AirDrop, Pin, Remove from Shelf), so dragging isn't the only way to use an item. VoiceOver users get the same actions.
- An item whose file was moved or deleted is dimmed and marked unavailable.

**AirDrop.** An AirDrop card sits beside the shelf. Files dropped on it go straight to `NSSharingService(named: .sendViaAirDrop)` and aren't added to the shelf. It has its own `onDrop`, which takes the drop instead of the notch-wide one in `NotchView`. Clicking the card AirDrops every shelf item that still exists. The app activates first so the AirDrop window comes to the front.

## Settings

`AppSettings` is an `@Observable` class that writes each change to `UserDefaults`.

- Launch arguments such as `-expansionTrigger click` override stored values for one launch, and the UI tests rely on this.
- Loading settings never writes, so these overrides aren't saved. An optional property's `didSet` runs during `init`, and a guard prevents it from writing.
- `NotchWindowController` uses `withObservationTracking` to reposition or hide the panel when display settings change.
- Settings saved before tabs existed (`showBattery`, `widgetOrder`, `hiddenWidgets`) are removed on launch.

## Concurrency

The app target uses Swift 6 with `MainActor` as the default isolation. Value types that are used off the main actor or in tests are marked `nonisolated`:

- `NotchGeometry`, `NotchLayout`, and `NotchShape`
- `BatteryStatus`, `CountdownTimer`, `NotchActivity`, `NotchTab`, `NowPlaying`, `PlayerSnapshot`, `CalendarEvent`, `ChecklistItem`, `AudioOutputDevice`, `HotKey`, and `ShelfItem`
- the settings enums

Several callbacks run on the main thread and use `MainActor.assumeIsolated`:

- the C callbacks for power source and hot key events,
- CoreAudio listener blocks, which are scheduled on the main queue, and
- the Quick Look responder hooks, which AppKit declares nonisolated.

## Ideas for next features

See [plannedfeature.md](../plannedfeature.md) for the backlog. Milestone 1 is implemented, along with calendar, music, and shelf features from later milestones.

The main open question is whether to distribute through the Mac App Store. Direct download works as the app is. The App Store would need these changes:

- Replace the Apple Events temporary exception with `com.apple.security.scripting-targets` for Music.
- Likely drop Spotify control.
