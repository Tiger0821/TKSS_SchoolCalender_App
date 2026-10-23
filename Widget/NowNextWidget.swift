import SwiftUI
import WidgetKit

/* Now & Next: the class you're in, the minutes left, and what follows — on
   the Home Screen (small, medium) and the Lock Screen (inline, circular,
   rectangular), and on a Mac's desktop (small, medium). */
struct NowNextWidget: Widget {
    let kind = "NowNext"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClassProvider()) { entry in
            NowNextView(entry: entry)
                .widgetTextSize()
                .containerBackground(for: .widget) { Backdrop(tint: entry.snapshot.focus?.segment.tint) }
        }
        .configurationDisplayName("Now & Next")
        .description("The class you're in, the time left, and what's next.")
        #if os(iOS)
        .supportedFamilies([.systemSmall, .systemMedium,
                            .accessoryRectangular, .accessoryCircular, .accessoryInline])
        #else
        // a Mac has no Lock Screen to put the rest on
        .supportedFamilies([.systemSmall, .systemMedium])
        #endif
    }
}

struct NowNextView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ClassEntry

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryInline: InlineView(snapshot: entry.snapshot)
        case .accessoryCircular: CircularView(snapshot: entry.snapshot)
        case .accessoryRectangular: RectangularView(snapshot: entry.snapshot)
        #endif
        case .systemMedium: MediumView(snapshot: entry.snapshot)
        default: FocusBlock(snapshot: entry.snapshot).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Now on the left; the next few classes on the right.
struct MediumView: View {
    let snapshot: Snapshot

    var body: some View {
        // whatever the left-hand block already shows is left off the list; on a
        // day off that is the holiday, and the list is the whole of the next day
        let dayOff = snapshot.holidayToday != nil
        let later = Array(snapshot.upcoming.dropFirst(snapshot.current == nil && !dayOff ? 1 : 0).prefix(3))
        HStack(alignment: .top, spacing: 14) {
            FocusBlock(snapshot: snapshot, showsNext: false)
                .frame(maxWidth: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 8) {
                Text(dayOff ? snapshot.dayLabel : snapshot.current == nil ? "Then" : snapshot.isToday ? "Up next" : snapshot.dayLabel)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                if later.isEmpty {
                    Text(snapshot.current == nil ? "Nothing after" : "Last block today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                ForEach(later) { UpcomingRow(item: $0) }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Lock Screen

#if os(iOS)
struct RectangularView: View {
    let snapshot: Snapshot

    var body: some View {
        if let now = snapshot.current {
            VStack(alignment: .leading, spacing: 1) {
                Text(now.segment.shortTitle)
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                TimeLeft(segment: now)
                    .font(.caption)
                    .lineLimit(1)
                Text(snapshot.upcoming.first.map { (["Next " + $0.segment.shortTitle, $0.segment.place].filter { !$0.isEmpty }).joined(separator: " · ") } ?? "Last block today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let holiday = snapshot.holidayToday {
            VStack(alignment: .leading, spacing: 1) {
                Text("No class today")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(holiday.name)
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                if let next = snapshot.upcoming.first {
                    Text("Next \(next.segment.shortTitle) · \(snapshot.dayLabel) \(Timetable.hhmm(next.segment.start))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let next = snapshot.upcoming.first {
            VStack(alignment: .leading, spacing: 1) {
                Text("\(snapshot.dayLabel) \(Timetable.hhmm(next.segment.start))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(next.segment.shortTitle)
                    .font(.headline)
                    .widgetAccentable()
                    .lineLimit(1)
                Text(next.segment.place)
                    .font(.caption)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(Timetable.nothingToShow)
        }
    }
}

struct CircularView: View {
    let snapshot: Snapshot

    var body: some View {
        if let now = snapshot.current {
            ProgressView(timerInterval: now.interval, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                Text(now.segment.abbreviation)
            }
            .progressViewStyle(.circular)
            .widgetAccentable()
        } else if let holiday = snapshot.holidayToday {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: holiday.symbol)
                    .font(.title3)
                    .widgetAccentable()
            }
        } else if let next = snapshot.upcoming.first {
            ZStack {
                AccessoryWidgetBackground()
                VStack(spacing: 0) {
                    Text(next.segment.abbreviation)
                        .font(.system(size: 12, weight: .semibold))
                        .widgetAccentable()
                    Text(Timetable.hhmm(next.segment.start))
                        .font(.system(size: 11).monospacedDigit())
                }
            }
        } else {
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: "calendar")
            }
        }
    }
}

struct InlineView: View {
    let snapshot: Snapshot

    var body: some View {
        if let now = snapshot.current {
            Label("\(now.segment.shortTitle) till \(Timetable.hhmm(now.segment.end))", systemImage: now.segment.symbol)
        } else if let holiday = snapshot.holidayToday {
            Label("No class · \(holiday.name)", systemImage: holiday.symbol)
        } else if let next = snapshot.upcoming.first {
            Label("\(next.segment.shortTitle) \(snapshot.isToday ? "at" : snapshot.dayLabel) \(Timetable.hhmm(next.segment.start))",
                  systemImage: "calendar")
        } else {
            Label(Timetable.nothingToShow, systemImage: "calendar")
        }
    }
}

#endif

#Preview("Small", as: .systemSmall) {
    NowNextWidget()
} timeline: {
    ClassEntry.sample(9, 40)
    ClassEntry.sample(12, 10)
    ClassEntry.sample(7, 30)
}

#Preview("Medium", as: .systemMedium) {
    NowNextWidget()
} timeline: {
    ClassEntry.sample(9, 40)
    ClassEntry.sample(17, 0)
}

#if os(iOS)
#Preview("Lock Screen", as: .accessoryRectangular) {
    NowNextWidget()
} timeline: {
    ClassEntry.sample(9, 40)
}

#Preview("Circular", as: .accessoryCircular) {
    NowNextWidget()
} timeline: {
    ClassEntry.sample(9, 40)
    ClassEntry.sample(7, 30)
}
#endif
