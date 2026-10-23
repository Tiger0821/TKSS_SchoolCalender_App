import SwiftUI

/* Timetable on the Mac: the phone's page in a window, the class that is on
   in the menu bar, the widgets for the desktop, and the reminders before
   each class.

   It stands on its own, as the watch can: it has the phone's setup, and
   keeps a profile of its own, since nothing reaches from the phone to the
   Mac without an account to carry it. Closing the window leaves it running
   in the menu bar, which keeps the reminders laid down and the menu bar's
   class up to date; Quit is in the menu bar's panel and the app menu. */
@main
struct TimetableMacApp: App {
    @NSApplicationDelegateAdaptor private var delegate: MacAppDelegate
    @State private var model = MacModel.shared
    @AppStorage(MenuBarClass.shownKey) private var inMenuBar = true

    var body: some Scene {
        Window("Timetable", id: MacPage.window) {
            MacPage()
                .environment(model)
        }
        .defaultSize(width: 980, height: 780)
        // the sky goes up to the top edge, behind the window's buttons
        .windowStyle(.hiddenTitleBar)
        .windowBackgroundDragBehavior(.enabled)

        Settings {
            MacSettings()
                .environment(model)
        }

        MenuBarExtra(isInserted: $inMenuBar) {
            MenuBarPanel()
                .environment(model)
        } label: {
            MenuBarLabel(model: model)
        }
        .menuBarExtraStyle(.window)
    }
}

final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ReminderPresenter.shared.install()
        MacModel.shared.start()
    }

    /// The window closing is not the app quitting: the menu bar and the
    /// reminders go on without it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
