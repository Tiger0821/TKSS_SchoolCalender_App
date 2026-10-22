import ServiceManagement
import SwiftUI

/* Settings, as a Mac has them: a window of its own off the app menu (⌘,),
   or the gear that comes out of the person at the top of the timetable's
   window. Whose timetable it is, ManageBac for the homework, the menu
   bar's class and opening at login, the reminders, how to put the widgets
   on the desktop, and where the timetable, the holidays and the weather
   come from. */
struct MacSettings: View {
    @Environment(MacModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @AppStorage(MenuBarClass.shownKey) private var inMenuBar = true
    @AppStorage("classReminders") private var reminders = true
    /// Whether the system opens Timetable at login. It is the system's to
    /// say, and is read back from it after each change.
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("You") {
                LabeledContent {
                    Button(model.profile == nil ? "Set Up…" : "Change…") {
                        if model.profile != nil { model.editing = true }
                        openWindow(id: MacPage.window)
                    }
                } label: {
                    if let profile = model.profile {
                        Text(profile.name.isEmpty ? "Your timetable" : profile.name)
                        Text("\(profile.form) · \(profile.subjects.count) classes")
                    } else {
                        Text("Not set up yet")
                    }
                }
                Text("Your form, your classes and your clubs. Clicking the person at the top of the timetable's window opens this too. The Mac keeps its own: what is picked on the iPhone or the Apple Watch does not come across.")
                    .settingsNote()
            }

            Section("ManageBac") {
                ManageBacSettings()
                Text("Click a class in the day's list to see its homework. Timetable reads what's set from your ManageBac, signed in as you.")
                    .settingsNote()
            }

            Section("Menu bar") {
                Toggle(isOn: $inMenuBar) {
                    Text("Show the class that's on")
                    Text("Its name and the minutes left, as the iPhone's Dynamic Island has them. Click it for the rest.")
                }
                Toggle(isOn: $opensAtLogin) {
                    Text("Open at login")
                    Text("So the menu bar and the reminders are there from the start of the day.")
                }
                .onChange(of: opensAtLogin) { _, on in
                    let service = SMAppService.mainApp
                    try? on ? service.register() : service.unregister()
                    // the system may want it allowed in System Settings first
                    let now = service.status == .enabled
                    if now != on { opensAtLogin = now }
                }
                Text("With the window closed, Timetable keeps going in the menu bar. Quit it from there.")
                    .settingsNote()
            }

            Section("Reminders") {
                Toggle(isOn: $reminders) {
                    Text("Before each class")
                    Text("15 minutes and 5 minutes ahead")
                }
                .onChange(of: reminders) { model.settle() }
                Text("The Mac lays its own down some four school days ahead, and tops them up each day Timetable is running. The iPhone and the Apple Watch send theirs as well.")
                    .settingsNote()
            }

            Section("Widgets") {
                Text("Right-click the desktop, choose Edit Widgets, and search for Timetable: Now & Next, Today, and Holiday Countdown.")
                    .settingsNote()
            }

            Section("Sources") {
                Link(destination: Timetable.source) {
                    Label("Prime Timetable", systemImage: "arrow.up.right.square")
                }
                Text("Read from the school's published timetable on \(TimetableData.readOn) (\(TimetableData.edition)). Week 2 is the week of Mon 7 Sep; the rest alternate.")
                    .settingsNote()
                Text("Holidays are Taiwan's national holidays from the government office calendars for 2026 and 2027.")
                    .settingsNote()
                Link(destination: URL(string: "https://open-meteo.com/")!) {
                    Label("Weather data by Open-Meteo.com", systemImage: "arrow.up.right.square")
                }
                Text("The sky behind the page is the weather near where the Mac is, looked up again every ten minutes while the window is open.")
                    .settingsNote()
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .frame(minHeight: 520, idealHeight: 720)
        .onAppear { opensAtLogin = SMAppService.mainApp.status == .enabled }
        // ManageBac's sign-in page comes up over the timetable's window
        .onChange(of: Homework.shared.signingIn) { _, signingIn in
            if signingIn { openWindow(id: MacPage.window) }
        }
    }
}

private extension View {
    /// The small grey print under a setting.
    func settingsNote() -> some View {
        font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
