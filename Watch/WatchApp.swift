import SwiftUI
import WatchKit
import WidgetKit

/* Timetable on the Apple Watch: the day's classes over the sky outside, a
   widget for the Smart Stack that says what is on and what is next, and the
   reminders before each class.

   It stands on its own: it has a setup (WatchSetupView), and needs no
   phone to show the day. Where there is a phone that has been set up, the
   phone hands its profile across (DeviceLink), and whichever of the two was
   changed last is the one the watch shows. */
@main
struct TimetableWatchApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var profile = Timetable.profile

    init() {
        ReminderPresenter.shared.install()
        // with the app in front the system shows a reminder silently, so the
        // tap on the wrist is given here
        ReminderPresenter.shared.shown = { WKInterfaceDevice.current().play(.notification) }
        DeviceLink.shared.start()
    }

    var body: some Scene {
        WindowGroup {
            WatchDayView(profile: profile) { new in
                // out of setup on the wrist: keep it, and lay the fortnight out for it
                new.save()
                Timetable.profile = new
                profile = new
                Task { await Self.settle() }
            }
            .task {
                DeviceLink.shared.received = {
                    Task { @MainActor in
                        profile = Timetable.profile
                        await Self.settle()
                    }
                }
                await Self.settle()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                profile = Timetable.profile
                Task { await Self.settle() }
            }
        }
        // the reminders are laid down some four days ahead; this tops them up
        // on days the app is not opened
        .backgroundTask(.appRefresh("reminders")) {
            await Self.settle()
        }
    }

    /// Lay the reminders down again, tell the phone how far they run, have
    /// the widget lay out afresh, and ask to be woken tomorrow to do it again.
    static func settle() async {
        let until = await ClassReminders.schedule()
        DeviceLink.shared.report(remindersUntil: until)
        WidgetCenter.shared.reloadAllTimelines()
        // and say afresh which hours it is worth a look in (WatchProvider.relevance)
        WidgetCenter.shared.invalidateRelevance(ofKind: "NowNextWatch")
        WKApplication.shared().scheduleBackgroundRefresh(withPreferredDate: .now.addingTimeInterval(12 * 3600),
                                                         userInfo: nil) { _ in }
    }
}
