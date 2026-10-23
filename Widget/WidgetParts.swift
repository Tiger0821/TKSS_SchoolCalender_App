import SwiftUI
import WidgetKit

/* Pieces the widgets share. */

extension Timetable {
    /// What a widget says when there is no class to show: before setup, where
    /// to go to do it.
    static var nothingToShow: String { profile == nil ? "Open Timetable to set up" : "No classes" }
}

extension View {
    /// A widget's frame doesn't grow with its text, so the text is only
    /// allowed to grow so far with the phone's text-size setting. Past this
    /// the last line of a widget is the first thing to be pushed out.
    func widgetTextSize() -> some View {
        dynamicTypeSize(...DynamicTypeSize.large)
    }
}

/// The small caps line over a block: "NOW · until 11:05".
struct Eyebrow: View {
    let title: String
    let detail: String
    let tint: Color

    var body: some View {
        HStack(spacing: 4) {
            Text(title)
                .fontWeight(.bold)
                .foregroundStyle(tint)
                .widgetAccentable()
            Text(detail)
                .foregroundStyle(.secondary)
        }
        .font(.caption2)
        .textCase(.uppercase)
        .lineLimit(1)
    }
}

/// A progress bar the system fills in by itself between two bells.
struct BellBar: View {
    let segment: TimedSegment

    var body: some View {
        ProgressView(timerInterval: segment.interval, countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        .tint(segment.segment.tint)
    }
}

/// "32:10 left", counting down live.
struct TimeLeft: View {
    let segment: TimedSegment

    var body: some View {
        Text("\(Text(timerInterval: segment.interval, countsDown: true)) left")
            .monospacedDigit()
    }
}

/// "Next Econ": a quiet word, then the name.
struct LeadIn: View {
    let label: String
    let name: String

    var body: some View {
        Text("\(Text(label).foregroundStyle(.secondary)) \(Text(name).fontWeight(.semibold))")
    }
}

/// One upcoming class: colour bar, name, time and room.
struct UpcomingRow: View {
    let item: TimedSegment

    var body: some View {
        HStack(spacing: 7) {
            Capsule()
                .fill(item.segment.tint)
                .frame(width: 3)
                .widgetAccentable()
            VStack(alignment: .leading, spacing: 0) {
                Text(item.segment.shortTitle)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text([Timetable.hhmm(item.segment.start), item.segment.place].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// The class running now, or the next one when nothing is: the left-hand
/// half of the medium widget, and the whole of the small one.
struct FocusBlock: View {
    let snapshot: Snapshot
    var showsNext = true

    var body: some View {
        if let now = snapshot.current {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(title: "Now", detail: "until " + Timetable.hhmm(now.segment.end), tint: now.segment.tint)
                Text(now.segment.shortTitle)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()
                if !now.segment.place.isEmpty {
                    Text(now.segment.place)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                BellBar(segment: now)
                TimeLeft(segment: now)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if showsNext, let next = snapshot.upcoming.first {
                    LeadIn(label: "Next", name: next.segment.shortTitle)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.top, 4)
                } else if showsNext {
                    Text("Last block today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }
        } else if let holiday = snapshot.holidayToday {
            // a weekday off for a holiday: that first, and the next class under it
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(title: "No class today", detail: "", tint: .red)
                Text(holiday.name)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()
                Text(holiday.localName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if showsNext, let next = snapshot.upcoming.first {
                    LeadIn(label: "Next", name: next.segment.shortTitle)
                        .font(.caption)
                        .lineLimit(1)
                    Text("\(snapshot.dayLabel) \(Timetable.hhmm(next.segment.start))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        } else if let next = snapshot.upcoming.first {
            VStack(alignment: .leading, spacing: 2) {
                Eyebrow(title: "Next", detail: snapshot.dayLabel, tint: next.segment.tint)
                Text(next.segment.shortTitle)
                    .font(.title3.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .widgetAccentable()
                Text([Timetable.hhmm(next.segment.start), next.segment.place].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 6)
                if snapshot.isToday {
                    Text("starts in \(Text(timerInterval: snapshot.date...next.start, countsDown: true))")
                        .monospacedDigit()
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if showsNext, snapshot.upcoming.count > 1 {
                    LeadIn(label: "Then", name: snapshot.upcoming[1].segment.shortTitle)
                        .font(.caption)
                        .lineLimit(1)
                        .padding(.top, 4)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Image(systemName: "calendar")
                    .font(.title3)
                Text(Timetable.profile == nil ? "Open Timetable to set it up" : "Nothing on the timetable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// The colour behind a Home Screen widget: the subject's tint washing in from
/// the corner. Lock Screen widgets keep the system's own.
struct Backdrop: View {
    @Environment(\.widgetFamily) private var family
    @Environment(\.widgetRenderingMode) private var renderingMode
    let tint: Color?

    var body: some View {
        switch family {
        #if os(iOS)
        case .accessoryCircular, .accessoryRectangular, .accessoryInline:
            Color.clear
        #endif
        default:
            ZStack {
                Rectangle().fill(.background)
                if let tint, renderingMode == .fullColor {
                    LinearGradient(colors: [tint.opacity(0.30), tint.opacity(0.04)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
        }
    }
}
