import AppKit
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let launchAtLogin: LaunchAtLogin
    let hotKeys: GlobalHotKeyCenter
    let timerAlerts: TimerAlerts
    let calendar: CalendarService

    @State private var notificationMessage: String?

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
    }

    var body: some View {
        Form {
            behaviorSection
            keyboardSection
            tabsSection
            calendarSection
            musicSection
            activitiesSection
            displaySection
            generalSection

            Section {
                LabeledContent("Version \(version)") {
                    Button("Quit MacBook Notch") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 640)
        .onAppear { launchAtLogin.refresh() }
    }

    private var behaviorSection: some View {
        Section("Behavior") {
            Picker("Open the notch on", selection: $settings.expansionTrigger) {
                ForEach(ExpansionTrigger.allCases) { trigger in
                    Text(trigger.title).tag(trigger)
                }
            }
            .pickerStyle(.segmented)

            LabeledContent("Hover delay") {
                HStack {
                    Slider(value: $settings.hoverDelay, in: AppSettings.hoverDelayRange, step: 0.05)
                    Text(settings.hoverDelay, format: .number.precision(.fractionLength(2)))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    Text("s")
                        .foregroundStyle(.secondary)
                }
            }
            .disabled(settings.expansionTrigger != .hover)
        }
    }

    private var keyboardSection: some View {
        Section {
            LabeledContent("Open and close the notch") {
                ShortcutRecorder(hotKey: $settings.toggleShortcut)
            }
            if let error = hotKeys.registrationError {
                Text(message(for: error))
                    .font(.callout)
                    .foregroundStyle(.red)
            }
        } header: {
            Text("Keyboard")
        } footer: {
            Text("Press Escape to close the notch after opening it with the shortcut. If the shortcut doesn't respond, another app may already use it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var tabsSection: some View {
        Section {
            ForEach(Array(settings.tabOrder.enumerated()), id: \.element) { index, tab in
                HStack {
                    Toggle(isOn: Binding(
                        get: { settings.isVisible(tab) },
                        set: { settings.setVisible(tab, $0) }
                    )) {
                        Label(tab.title, systemImage: tab.systemImage)
                    }
                    // The last visible tab stays on so the notch always has something to show.
                    .disabled(settings.visibleTabs == [tab])
                    Spacer()
                    Button {
                        settings.moveTab(tab, by: -1)
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .disabled(index == 0)
                    .accessibilityLabel("Move \(tab.title) earlier")
                    Button {
                        settings.moveTab(tab, by: 1)
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .disabled(index == settings.tabOrder.count - 1)
                    .accessibilityLabel("Move \(tab.title) later")
                }
                .buttonStyle(.borderless)
            }
        } header: {
            Text("Tabs")
        } footer: {
            Text("Tabs appear left to right in this order. With the notch open from the keyboard shortcut, ⌘1, ⌘2, and so on switch tabs. Files on the shelf are links; removing them never deletes the originals.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var calendarSection: some View {
        Section {
            Picker("Remind me before events", selection: $settings.meetingReminderMinutes) {
                ForEach(AppSettings.meetingReminderChoices, id: \.self) { minutes in
                    Text(minutes == 0 ? "Off" : minutes == 1 ? "1 minute" : "\(minutes) minutes").tag(minutes)
                }
            }
            Toggle("Show all-day events", isOn: $settings.showAllDayEvents)

            switch calendar.access {
            case .granted:
                ForEach(calendar.calendars) { info in
                    Toggle(isOn: Binding(
                        get: { !settings.hiddenCalendarIDs.contains(info.id) },
                        set: { isShown in
                            if isShown {
                                settings.hiddenCalendarIDs.remove(info.id)
                            } else {
                                settings.hiddenCalendarIDs.insert(info.id)
                            }
                        }
                    )) {
                        Label {
                            Text(info.title)
                        } icon: {
                            Circle()
                                .fill(info.color.map(Color.init) ?? .accentColor)
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            case .notDetermined:
                LabeledContent("Calendars") {
                    Button("Connect Calendar…") { calendar.requestAccess() }
                }
            case .denied:
                LabeledContent("Calendar access is off.") {
                    Button("Open System Settings") { calendar.openPrivacySettings() }
                }
            }
        } header: {
            Text("Calendar")
        } footer: {
            Text("Reminders appear beside the notch before an event starts. Events with a Zoom, Google Meet, Teams, or Webex link get a Join button.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var musicSection: some View {
        Section {
            Toggle("Show what's playing beside the notch", isOn: $settings.showMusicActivity)
            Toggle("Show the new song when the track changes", isOn: $settings.showTrackChanges)
        } header: {
            Text("Music")
        } footer: {
            Text("Works with Music and Spotify. The first time you connect each app from the Music tab, macOS asks for permission to control it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var activitiesSection: some View {
        Section("Activities") {
            Toggle("Show when power connects or disconnects", isOn: $settings.showChargingAlerts)
            Toggle("Play a sound when a timer ends", isOn: $settings.timerSound)
            Toggle("Send a notification when a timer ends", isOn: Binding(
                get: { settings.timerNotifications },
                set: { setTimerNotifications($0) }
            ))
            if let notificationMessage {
                Text(notificationMessage)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var displaySection: some View {
        Section("Display") {
            Picker("Show the notch on", selection: $settings.displayPreference) {
                ForEach(DisplayPreference.allCases) { preference in
                    Text(preference.title).tag(preference)
                }
            }
            Toggle("Show on displays without a notch", isOn: $settings.showOnDisplaysWithoutNotch)
        }
    }

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at login", isOn: Binding(
                get: { launchAtLogin.isEnabled || launchAtLogin.requiresApproval },
                set: { launchAtLogin.setEnabled($0) }
            ))
            if launchAtLogin.requiresApproval {
                LabeledContent("Allow MacBook Notch in Login Items to finish turning this on.") {
                    Button("Open System Settings") { launchAtLogin.openSystemSettings() }
                }
                .font(.callout)
            }
            if let error = launchAtLogin.lastError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }

            Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
        }
    }

    private func setTimerNotifications(_ isOn: Bool) {
        guard isOn else {
            settings.timerNotifications = false
            notificationMessage = nil
            return
        }
        Task {
            let granted = await timerAlerts.requestNotificationPermission()
            settings.timerNotifications = granted
            notificationMessage = granted
                ? nil
                : "Notifications are off for MacBook Notch. Turn them on in System Settings > Notifications."
        }
    }

    private func message(for error: GlobalHotKeyCenter.RegistrationError) -> String {
        switch error {
        case .inUse:
            "Another app already uses this shortcut. Choose a different one."
        case .failed(let status):
            "The shortcut couldn't be registered (error \(status)). Choose a different one."
        }
    }
}

#Preview {
    let settings = AppSettings(defaults: UserDefaults(suiteName: "preview")!)
    SettingsView(
        settings: settings,
        launchAtLogin: LaunchAtLogin(),
        hotKeys: GlobalHotKeyCenter(),
        timerAlerts: TimerAlerts(settings: settings),
        calendar: CalendarService(settings: settings)
    )
}
