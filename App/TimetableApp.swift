import SwiftUI
import WidgetKit

@main
struct TimetableApp: App {
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if DEBUG
        ClassActivityManager.isTesting = ProcessInfo.processInfo.environment["LIVE_TEST"] != nil
        #endif
        ReminderPresenter.shared.install()
        // the watch saying it has the reminders, or that it no longer has
        DeviceLink.shared.received = { Self.remind() }
        DeviceLink.shared.start()
    }

    /// Hand the watch the profile, and lay the class reminders down again —
    /// or clear them, where the watch has them in hand.
    static func remind() {
        DeviceLink.shared.send()
        // the watch's own two are left to it, once it has them
        Task { await ClassReminders.schedule(skipping: DeviceLink.shared.watchHasReminders ? ClassReminders.watchLeads : []) }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                #if DEBUG
                .task {
                    // Ways to try the Live Activity out. LIVE_TEST=<seconds> starts a made-up
                    // day with blocks that long; "day" starts the next real school day now;
                    // "size:<n>" starts the day n days off as it would be booked; "book"
                    // books the made-up day for 30 seconds' time.
                    guard let test = ProcessInfo.processInfo.environment["LIVE_TEST"] else { return }
                    await ClassActivityManager.endAll()
                    do {
                        if let seconds = Double(test) {
                            try ClassActivityManager.start(ClassActivityManager.testDay(blockSeconds: seconds))
                        } else if test == "day", let next = Timetable.nextSchoolDay(after: .now),
                                  let day = ClassActivityAttributes(day: next, made: .now) {
                            try ClassActivityManager.start(day)
                        } else if test.hasPrefix("size:"), let offset = Int(test.dropFirst(5)),
                                  let date = Timetable.calendar.date(byAdding: .day, value: offset, to: .now),
                                  let day = ClassActivityAttributes(day: date, made: Timetable.calendar.startOfDay(for: date).addingTimeInterval(6 * 3600)) {
                            // the day `offset` days from now, laid out as it is when booked for 06:00:
                            // the fullest it gets, to weigh the drawing the system saves for it
                            try ClassActivityManager.start(day)
                            NSLog("TTLIVE size %d: %@ blocks=%d stages=%d", offset, day.day, day.blocks.count, day.blocks.count + 3)
                        } else if test == "book" {
                            try ClassActivityManager.bookTestDay(in: 30)
                        }
                        NSLog("TTLIVE %@ ok", test)
                    } catch {
                        NSLog("TTLIVE %@ failed: %@", test, "\(error)")
                    }
                }
                #endif
        }
        // the widgets lay out two days at a time; opening the app is a good
        // moment to have them lay out afresh
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                WidgetCenter.shared.reloadAllTimelines()
                Self.remind()
            }
        }
    }
}
