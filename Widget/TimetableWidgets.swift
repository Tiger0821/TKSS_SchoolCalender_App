import SwiftUI
import WidgetKit

@main
struct TimetableWidgets: WidgetBundle {
    var body: some Widget {
        NowNextWidget()
        TodayWidget()
        HolidayWidget()
        #if os(iOS)
        // the day on the Lock Screen and in the Dynamic Island; a Mac has its
        // menu bar for that, which the app itself keeps
        ClassLiveActivity()
        #endif
    }
}
