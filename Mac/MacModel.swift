import AppKit
import SwiftUI
import WidgetKit

/* What the window, the menu bar and Settings share: whose timetable it is,
   whether setup is open over the window, and the minute it is.

   The window has a TimelineView of its own to go by, but the menu bar's
   label does not move with one, so the minute is kept here and the label
   reads it. It turns over on the minute, which is when every bell rings. */
@MainActor @Observable
final class MacModel {
    static let shared = MacModel()

    /// Whose timetable it is; nil until setup has been done.
    private(set) var profile = Timetable.profile
    /// Setup again, over the window, to change the name, the form or the classes.
    var editing = false
    /// The minute it is, for the menu bar.
    private(set) var now = Date.now

    private var clock: Task<Void, Never>?

    /// Take up a profile from setup: keep it, lay the fortnight out for it,
    /// and have the widgets and the reminders do the same.
    func use(_ new: Profile) {
        new.save()
        Timetable.profile = new
        withAnimation(.snappy) { profile = new }
        settle()
    }

    /// Have the widgets lay out afresh, and lay the reminders down again.
    func settle() {
        WidgetCenter.shared.reloadAllTimelines()
        Task { await ClassReminders.schedule() }
    }

    /* Start keeping the minute. The reminders are laid down some four
       school days ahead, and a Mac can be left running for longer than that,
       so they are laid down again each new day, and on waking from sleep. */
    func start() {
        settle()
        clock = Task { [weak self] in
            var day = Timetable.calendar.startOfDay(for: .now)
            while !Task.isCancelled {
                // to the start of the next minute; the clock this sleeps by runs on
                // while the Mac is asleep, so it is not left behind by a night shut
                let seconds = Date.now.timeIntervalSinceReferenceDate
                try? await Task.sleep(for: .seconds((seconds / 60).rounded(.down) * 60 + 60 - seconds))
                guard let self else { return }
                now = .now
                let today = Timetable.calendar.startOfDay(for: now)
                if today != day {
                    day = today
                    settle()
                }
            }
        }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil,
                                                          queue: .main) { _ in
            Task { @MainActor in
                MacModel.shared.now = .now
                MacModel.shared.settle()
            }
        }
    }
}
