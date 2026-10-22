import SwiftUI
import WidgetKit

/* Holiday Countdown: the days to Taiwan's next national holiday, and once it
   is under a day away the hours, minutes and seconds. The medium size puts
   today's date and a running clock beside it. */
struct HolidayWidget: Widget {
    let kind = "Holiday"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HolidayProvider()) { entry in
            HolidayView(entry: entry)
                .widgetTextSize()
                .containerBackground(for: .widget) { Backdrop(tint: .red) }
        }
        .configurationDisplayName("Holiday Countdown")
        .description("Days to Taiwan's next national holiday — and the hours, minutes and seconds once it's under a day away.")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryCircular, .accessoryInline])
        #else
        // a Mac has no Lock Screen to put the rest on
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

struct HolidayEntry: TimelineEntry {
    let date: Date
}

/* A day count only changes at midnight, which is also when a holiday comes
   within a day, starts, and ends — and when the running clock needs a new
   midnight to count from. So the timeline is just the next fortnight's
   midnights (and each 1 am, for the clock); the seconds in between are drawn
   by the system. */
struct HolidayProvider: TimelineProvider {
    func placeholder(in context: Context) -> HolidayEntry {
        HolidayEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (HolidayEntry) -> Void) {
        completion(HolidayEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HolidayEntry>) -> Void) {
        let cal = Timetable.calendar
        let now = Date.now
        let midnight = cal.startOfDay(for: now)
        // each midnight, and 1 am after it for the clock's sake
        let turns = (0...14).flatMap { day -> [Date] in
            let start = cal.date(byAdding: .day, value: day, to: midnight)!
            return [start, start.addingTimeInterval(3600)]
        }
        let entries = ([now] + turns.filter { $0 > now }).map(HolidayEntry.init)
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct HolidayView: View {
    @Environment(\.widgetFamily) private var family
    let entry: HolidayEntry

    var body: some View {
        let next = Holidays.upcoming(at: entry.date).first
        switch family {
        #if os(iOS)
        case .accessoryInline: HolidayInline(holiday: next, now: entry.date)
        case .accessoryCircular: HolidayCircular(holiday: next, now: entry.date)
        case .accessoryRectangular: HolidayRectangular(holiday: next, now: entry.date)
        #endif
        case .systemMedium:
            HStack(alignment: .top, spacing: 14) {
                TodayBlock(now: entry.date)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HolidayBlock(holiday: next, now: entry.date)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            HolidayBlock(holiday: next, now: entry.date)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Today: the weekday, the date, and the time to the second.
struct TodayBlock: View {
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(now.formatted(.dateTime.weekday(.wide)))
                .font(.caption2.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.red)
                .widgetAccentable()
            Text(now.formatted(.dateTime.day()))
                .font(.system(size: 44, weight: .bold, design: .rounded))
            Text(now.formatted(.dateTime.month(.wide).year()))
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            // a timer counting up from midnight reads as the time of day, and
            // is the one way a widget can show seconds. Before 1 am it has no
            // hours to show and would read "29:25", so the hour is written in;
            // the timeline has an entry at 1 am to take it out again.
            let midnight = Timetable.calendar.startOfDay(for: now)
            Group {
                if now.timeIntervalSince(midnight) < 3600 {
                    Text("0:\(Text(midnight, style: .timer))")
                } else {
                    Text(midnight, style: .timer)
                }
            }
            .font(.title3.weight(.semibold).monospacedDigit())
        }
    }
}

/// The next holiday and its count.
struct HolidayBlock: View {
    let holiday: Holiday?
    let now: Date

    var body: some View {
        if let holiday {
            let countdown = Holidays.countdown(to: holiday, at: now)
            VStack(alignment: .leading, spacing: 2) {
                Text(countdown == .today ? "Holiday today" : "Next holiday")
                    .font(.caption2.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.red)
                    .widgetAccentable()
                Text(holiday.name)
                    .font(.headline)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Text("\(holiday.localName) · \(Holidays.short(holiday.start))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if let off = holiday.dayOffText {
                    Text(off)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                count(countdown)
                    .foregroundStyle(.red)
                    .widgetAccentable()
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "flag")
                    .font(.title3)
                Text("No holidays listed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func count(_ countdown: Countdown) -> some View {
        switch countdown {
        case .today:
            Text("Today")
                .font(.system(size: 30, weight: .bold, design: .rounded))
        case .timer(let start):
            VStack(alignment: .leading, spacing: -2) {
                Text(timerInterval: now...start, countsDown: true)
                    .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                Text("to go")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .days(let days):
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text("\(days)")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                Text("days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Lock Screen

#if os(iOS)
struct HolidayRectangular: View {
    let holiday: Holiday?
    let now: Date

    var body: some View {
        if let holiday {
            VStack(alignment: .leading, spacing: 1) {
                Text(holiday.name)
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                Text(Holidays.short(holiday.start))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                CountdownLabel(countdown: Holidays.countdown(to: holiday, at: now), now: now)
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text("No holidays listed")
        }
    }
}

struct HolidayCircular: View {
    let holiday: Holiday?
    let now: Date

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            if let holiday {
                switch Holidays.countdown(to: holiday, at: now) {
                case .today:
                    Image(systemName: holiday.symbol)
                        .font(.title3)
                        .widgetAccentable()
                case .timer(let start):
                    VStack(spacing: 0) {
                        Image(systemName: holiday.symbol)
                            .font(.caption2)
                        Text(timerInterval: now...start, countsDown: true)
                            .font(.system(size: 11, weight: .semibold).monospacedDigit())
                            .multilineTextAlignment(.center)
                    }
                    .widgetAccentable()
                case .days(let days):
                    VStack(spacing: -3) {
                        Text("\(days)")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .widgetAccentable()
                        Text("days")
                            .font(.system(size: 10))
                    }
                }
            } else {
                Image(systemName: "flag")
            }
        }
    }
}

struct HolidayInline: View {
    let holiday: Holiday?
    let now: Date

    var body: some View {
        if let holiday {
            switch Holidays.countdown(to: holiday, at: now) {
            case .today:
                Label("\(holiday.name) today", systemImage: holiday.symbol)
            case .timer(let start):
                Label {
                    Text("\(holiday.name) in \(Text(timerInterval: now...start, countsDown: true))")
                } icon: {
                    Image(systemName: holiday.symbol)
                }
            case .days(let days):
                Label("\(holiday.name) in \(days) days", systemImage: holiday.symbol)
            }
        } else {
            Label("No holidays listed", systemImage: "flag")
        }
    }
}

#endif

#Preview("Holiday", as: .systemSmall) {
    HolidayWidget()
} timeline: {
    HolidayEntry(date: .now)
    // under a day to go
    HolidayEntry(date: Holidays.date("2026-10-09").addingTimeInterval(15 * 3600))
    HolidayEntry(date: Holidays.date("2026-10-10").addingTimeInterval(9 * 3600))
}

#Preview("Date and holiday", as: .systemMedium) {
    HolidayWidget()
} timeline: {
    HolidayEntry(date: .now)
    HolidayEntry(date: Holidays.date("2026-10-09").addingTimeInterval(15 * 3600))
}
