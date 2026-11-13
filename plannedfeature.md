# Planned Features & Ideas

A feature backlog for MacBook Notch: useful information and quick actions within reach of the notch, without opening another full-size window.

These are suggestions, not committed scope. Unchecked items are proposed work. Integration ideas need a feasibility check before implementation; their inclusion does not imply that macOS exposes the required data or controls.

## Current baseline

The app includes Home, Calendar, Music, Timers, and Shelf tabs; compact activities; a configurable keyboard shortcut; tab ordering; built-in or primary display selection; a virtual notch; and launch at login. See the [README](README.md) for the current feature overview.

The milestones below preserve the original planning sequence. Several later milestones are already implemented; unchecked items remain ideas for future work.

## Suggested first release

Start with a small set that makes the notch useful throughout the day:

1. **Quick timers** — create a timer in a couple of clicks and see its remaining time while the panel is collapsed.
2. **File shelf** — drop files onto the notch and drag them into another app later.
3. **Charging activities** — briefly show when power connects or disconnects, then return to the previous state.
4. **Widget customization** — choose which widgets appear and in what order.
5. **Keyboard access and accessibility** — make essential actions usable without hovering or dragging.

Keep media and calendar integrations in the next milestone so the first release can work without connecting other apps or accounts.

## 1. Notch interaction and layout

- [x] **Compact activity state:** add a state between collapsed and fully expanded for a countdown, charging status, or another active task.
- [ ] **Pin open:** let users keep the panel expanded until they dismiss it.
- [ ] **Configurable collapse delay:** control how long the panel stays open after the pointer leaves.
- [x] **Keyboard toggle:** let users assign a shortcut to open and close the panel, with a clear way to change conflicting bindings.
- [x] **Escape to dismiss:** close the panel and return keyboard focus predictably.
- [x] **Widget ordering:** reorder widgets and remember the arrangement between launches.
- [ ] **Compact and comfortable layouts:** offer two content densities with readable text and reliable click targets.
- [ ] **Context menu:** expose settings, pause, and common actions from a secondary click on the notch.
- [ ] **Temporary pause:** hide the notch for a chosen duration, with a menu bar action to restore it immediately.
- [ ] **Full-screen behavior preference:** choose whether the panel appears over full-screen apps.

## 2. Timers and focus

- [x] **Quick timer presets:** start common durations such as 5, 15, 25, and 60 minutes.
- [x] **Custom timer:** enter a duration and an optional label without leaving the panel.
- [x] **Persistent countdown:** show remaining time in the compact state, with pause, resume, and cancel in the expanded view.
- [x] **Completion options:** choose a visual cue, sound, or system notification when a timer finishes.
- [ ] **Focus sessions:** alternate work and break periods with configurable durations.
- [ ] **Stopwatch:** start, pause, and reset a simple elapsed-time counter.
- [x] **Multiple timers:** manage several named timers while showing only the nearest completion in compact mode.
- [x] **Restore active timers:** retain deadlines across app restarts and handle sleep/wake without silently resetting them.

## 3. File shelf

- [x] **Drop to collect:** open a shelf when files are dragged onto the notch.
- [x] **Drag back out:** move a file reference from the shelf into Finder, a document, or another accepting app.
- [x] **File previews:** show a thumbnail, filename, and type so similar items are distinguishable.
- [x] **Quick Look:** preview a selected item without opening its default app.
- [x] **Reveal in Finder:** jump to the original file location.
- [x] **Shelf cleanup:** remove individual references or clear the shelf without deleting original files.
- [x] **Pinned items:** keep frequently used files or folders available across sessions.
- [ ] **Links and text snippets:** collect dropped URLs and text alongside files.
- [ ] **Share action:** expose compatible system sharing options for selected items.

Start with references to original files rather than duplicating file contents. Show a clear unavailable state if a file moves, is deleted, or loses access. Decide sandbox access and persistence behavior before promising a shelf that survives relaunches.

## 4. Battery and device status

- [x] **Power connection activity:** briefly show a charging or unplugged indicator when power changes.
- [ ] **Battery threshold alerts:** let users choose a low-battery threshold and suppress repeated alerts for the same discharge period.
- [ ] **Charge target reminder:** optionally alert when the battery reaches a chosen percentage; this is a reminder, not charging control.
- [ ] **Battery detail view:** explain whether the Mac is charging, running on battery, or connected to power without charging, where that information is available.
- [ ] **Accessory battery cards:** explore battery status for supported connected accessories, with device-specific availability clearly shown.
- [ ] **Power-aware updates:** reduce optional animations and background refresh when running on battery.

Avoid promising accurate time-to-empty estimates or universal accessory support before validating the available data.

## 5. Music and audio

- [x] **Now Playing card:** display track title, artist, and artwork for an explicitly supported media source.
- [x] **Playback controls:** offer play/pause and previous/next where the chosen integration supports them.
- [x] **Compact playback indicator:** show a subtle activity indicator while media is playing, with a reduced-motion alternative.
- [x] **Track change preview:** optionally display a short-lived preview when the track changes.
- [x] **Seek control:** add a progress bar only for sources that support reliable playback position and seeking.
- [x] **Audio output picker:** explore switching between supported output devices from the panel.
- [ ] **Per-source preferences:** let users choose which integrations can provide media content.

Prototype one media source first. Confirm supported APIs, automation permissions, and distribution constraints before promising system-wide playback control. Do not make private frameworks a core dependency.

## 6. Calendar and daily planning

- [x] **Next event:** show the next selected-calendar event and time until it begins.
- [x] **Today's agenda:** present a short list of upcoming events in the expanded panel.
- [x] **Join meeting:** open the meeting URL attached to a calendar event with one explicit click.
- [x] **Meeting countdown:** show a compact reminder shortly before an event starts.
- [x] **Calendar selection:** let users exclude calendars and choose whether all-day events appear.
- [ ] **Privacy display mode:** replace event titles with a generic label when users want less information visible.
- [x] **Quick personal checklist:** keep a small local list of today's tasks without requiring an external task service.
- [ ] **Reminders integration:** explore viewing and completing selected reminders as a separate optional integration.

Request calendar or reminder access when the user enables the corresponding feature. Include denied-access and empty states so the rest of the app stays useful.

## 7. Quick utilities

- [ ] **World clocks:** add a few named time zones alongside the local clock.
- [ ] **Quick note:** keep a small, locally stored scratchpad in the panel.
- [ ] **App and folder shortcuts:** pin a handful of frequently opened destinations.
- [ ] **User-configured actions:** explore launching selected Shortcuts from explicit buttons.
- [ ] **Clipboard pinboard:** let users explicitly save and reuse selected snippets; start without automatic clipboard history.
- [ ] **Weather card:** optionally show current conditions for a manually selected location after choosing a data source and refresh budget.

## 8. Personalization

- [ ] **Accent colors:** customize controls and progress indicators while preserving the black notch surface.
- [x] **Widget visibility:** independently toggle clock, battery, timers, shelf, and future integrations.
- [ ] **Clock formatting:** support 12/24-hour time, optional seconds, and date formatting preferences.
- [ ] **Animation settings:** offer restrained motion and a no-animation option.
- [ ] **Saved layouts:** switch between a few named arrangements, such as Work and Personal.
- [ ] **Settings export/import:** transfer preferences without exporting private content or credentials.
- [ ] **Reset to defaults:** restore layout and behavior with a clear explanation of what will reset.

## 9. Displays and accessibility

- [ ] **Specific display selection:** choose a particular connected display rather than only built-in or primary.
- [ ] **Independent external-display layout:** adjust virtual-notch dimensions without affecting the physical-notch layout.
- [ ] **Display reconnection recovery:** restore placement after docking, undocking, resolution changes, and sleep/wake.
- [ ] **Optional multiple panels:** explore showing a panel on more than one display, with an explicit rule for where activities appear.
- [ ] **VoiceOver support:** label widgets, controls, and changing activity states meaningfully.
- [ ] **Complete keyboard navigation:** provide visible focus and logical navigation through every primary action.
- [ ] **Contrast and motion preferences:** respect system accessibility settings across all widgets.
- [ ] **Larger content option:** increase text and control sizes while keeping the panel within the selected screen.
- [ ] **Alternatives to dragging:** offer buttons or menus for core shelf actions so drag-and-drop is optional.

## 10. Activity coordination and reliability

- [x] **Activity priority rules:** decide which item is visible when a timer, charging event, and meeting reminder overlap.
- [x] **Return to previous content:** restore the user's selected widget after a temporary activity ends.
- [x] **Alert deduplication:** prevent repeated charging, battery, or event alerts from overwhelming the panel.
- [ ] **Notification preferences:** configure which app-generated activities may interrupt and which stay passive.
- [ ] **Privacy pause:** provide a manual mode that hides sensitive widget content during presentations or recording.
- [ ] **Permission management:** show which optional integrations are enabled, their access state, and how to disable them.
- [ ] **Efficient background behavior:** avoid unnecessary polling and stop inactive integrations from doing work.
- [ ] **Local diagnostics export:** create a user-initiated troubleshooting report that excludes notes, filenames, event titles, and credentials.
- [ ] **Update flow:** choose an update mechanism appropriate to the eventual distribution channel.

Treat automatic screen-sharing detection and reading other apps' notifications as separate research ideas; neither is assumed to be universally available.

## Proposed milestones

| Milestone | Scope | Ready when |
| --- | --- | --- |
| 1 — Everyday essentials | One timer, compact activity state, basic file shelf, charging activity, widget visibility, keyboard access | The main flows work across sleep/wake, accidental hover is manageable, and removing shelf items never deletes source files. |
| 2 — Connected information | One media integration, next calendar event, world clocks, activity priority rules | Missing permissions, disconnected sources, and overlapping activities have clear behavior. |
| 3 — Personal workspace | Reordering, saved layouts, pinned shelf items, quick notes, selected-display support | Preferences persist, unavailable files recover gracefully, and display changes keep the panel reachable. |
| 4 — Release polish | Accessibility review, power-use review, diagnostics, distribution and updates | Core actions work with keyboard and VoiceOver, idle resource use is measured, and installation/update paths are verified. |

Accessibility and reliability work should accompany each milestone; the final review is a release check, not the first time they are considered.

## Decisions to make before expanding scope

- Which use case should lead: productivity shelf, glanceable information, or media controls?
- Should the app ship through the Mac App Store, direct download, or both?
- Which content should remain available after relaunch, and for how long?
- Should temporary activities open the panel automatically or only widen the compact notch?
- What happens when several activities need attention at once?
- Which integrations are valuable enough to justify extra permissions and ongoing maintenance?

## Keep out of the initial release

- A third-party plugin marketplace.
- Cloud accounts, cross-device sync, and collaboration.
- An AI assistant embedded in the notch.
- A replacement for the entire macOS notification center.
- A large theme editor or arbitrary widget scripting.

Revisit these only after the core notch interactions prove useful and reliable.
