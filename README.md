# MacBook Notch

[![Build and test](https://github.com/Jshawk/macbook-notch/actions/workflows/ci.yml/badge.svg)](https://github.com/Jshawk/macbook-notch/actions/workflows/ci.yml)

**A native macOS utility that turns the MacBook notch into a home for music, meetings, timers, and files.**

Built with Swift 6, SwiftUI, and AppKit. Hover over the notch, click it, or use a custom keyboard shortcut to open a five-tab panel. When closed, it shows compact activities such as your next meeting, a running timer, the current song, or a charging alert. On displays without a camera notch, it creates a virtual one.

## Features

| Tab | What it does |
| --- | --- |
| **Home** | Clock, battery status, and a persistent checklist of up to five tasks. Completed tasks clear the next day; unfinished tasks carry over. |
| **Calendar** | Month calendar, daily events, upcoming meeting reminders, and Join buttons for supported video call links. |
| **Music** | Music and Spotify artwork, playback controls, seeking, volume, and a system audio output picker. |
| **Timers** | Presets and custom named timers, with pause/resume, compact countdowns, and optional sounds and notifications. Timers survive relaunch and sleep. |
| **Shelf** | Drop files onto the notch, pin them, preview with Quick Look, drag them into other apps, or share through AirDrop. |

Settings let you reorder or hide tabs, choose a display, adjust hover behavior, assign a global shortcut, and enable launch at login. The app runs as a menu bar utility without a Dock icon.

## Under the hood

The project uses Apple frameworks without third-party dependencies:

- **SwiftUI + Observation** for interface composition and observable state, with AppKit handling the borderless, non-activating panel and keyboard focus.
- **Display-aware geometry** to position the panel around real camera housings or a virtual notch. The window stays at a fixed size while the shape animates, avoiding window resizing during expansion.
- **An activity resolver** that prioritizes timer completions, power changes, track changes, meetings, and ongoing playback, then returns to the previous activity when an alert expires.
- **Native integrations:** EventKit for calendars, AppleScript for Music and Spotify, CoreAudio for output devices and volume, security-scoped bookmarks for shelf files, and Carbon for global shortcuts.
- **Deadline-based timers** and local persistence so countdowns remain accurate across sleep, wake, and app restarts.
- **Swift Testing unit tests** covering layout, state transitions, activity priorities, persistence, timers, calendar link parsing, and playback parsing, plus XCTest UI smoke tests.

Read the [architecture notes](docs/architecture.md) for implementation details and design tradeoffs.

## Build and run

Requires **macOS 14 or later** and **Xcode 26.2 or later**. A physical notch is optional.

```bash
git clone https://github.com/Jshawk/macbook-notch.git
cd macbook-notch
open MacBookNotch.xcodeproj
```

Select the **MacBookNotch** scheme and run it. The app appears at the top of the display and in the menu bar.

To build and launch from the terminal:

```bash
xcodebuild -project MacBookNotch.xcodeproj \
  -scheme MacBookNotch \
  -derivedDataPath build/DerivedData build

open build/DerivedData/Build/Products/Debug/MacBookNotch.app
```

Calendar access and Music/Spotify automation access are requested when you connect those features. Notification permission is requested when timer notifications are enabled.

## Tests

```bash
xcodebuild -project MacBookNotch.xcodeproj \
  -scheme MacBookNotch \
  -derivedDataPath build/DerivedData \
  -destination 'platform=macOS' \
  test -only-testing:MacBookNotchTests
```

To run UI smoke tests, replace the final option with `-only-testing:MacBookNotchUITests`. These tests control the mouse and may require macOS automation permission.

## Project layout

```text
MacBookNotch/
├── App/          # Entry point, lifecycle, and service composition
├── Features/     # Notch panel, tabs, widgets, and settings
├── Core/         # Shared models, services, and persistence
├── Platform/     # Windows, display geometry, keyboard input, and audio
├── Shared/       # Reusable components and theme
└── Resources/    # Asset catalogs
Tests/
├── Unit/         # Swift Testing suites
└── UI/           # XCTest smoke tests
docs/             # Architecture notes
```

The Xcode project uses folder-synchronized groups, so new source and test files are picked up by their corresponding targets automatically.

## Project status

This repository is a source showcase and can be built locally. It does not yet include a signed, notarized installer. The app icon and `com.example.MacBookNotch` bundle identifier are placeholders; distribution requires a unique identifier, an app icon, and Developer ID signing and notarization.

Music integration supports Music and Spotify. The [architecture notes](docs/architecture.md) document platform constraints, including the Calendar deep-link fallback. The [feature backlog](plannedfeature.md) contains future ideas alongside implemented milestones.
