import SwiftUI

/* What the phone and the Mac both put on the page: the date and the time,
   whose timetable it is with the weather beside it, the class that is on,
   the next holiday, the ten-day picker, and the day picked. Each lays them
   out in its own way — the phone in one column it can rearrange, the Mac in
   a window as wide as it is given — but the boxes are the same ones. */

// MARK: - Date and time

/// Today's date, and the time to the second.
struct DateHeader: View {
    var body: some View {
        // from midnight, so each tick lands on the second
        TimelineView(.periodic(from: Timetable.calendar.startOfDay(for: .now), by: 1)) { context in
            VStack(alignment: .leading, spacing: 0) {
                Text(context.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(Timetable.clock(context.date))
                    .font(.title2.weight(.medium).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Who, and the weather

/* Under the date: whose timetable this is — a name and a form, which open
   setup again when tapped — and, when the weather is known, the reading. With
   weather the strip is kept tall, so there is open sky beside the two for the
   sun or moon and the clouds to show in, clear of the boxes. */
struct SkyStrip: View {
    let profile: Profile
    let weather: Weather?
    let isDay: Bool
    let edit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            NameButton(profile: profile, edit: edit)
            if let weather {
                WeatherReading(weather: weather, isDay: isDay)
            }
        }
        .frame(maxWidth: .infinity, minHeight: weather == nil ? nil : 112, alignment: .bottomLeading)
    }
}

/// Whose timetable this is, a name and a form, on glass; tapped, it opens setup again.
struct NameButton: View {
    let profile: Profile
    let edit: () -> Void

    var body: some View {
        Button(action: edit) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                Text(profile.name)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Text(profile.form)
                    .font(.footnote.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.35), in: .capsule)
            }
            .font(.subheadline)
            .padding(.horizontal, 14)
            .frame(minHeight: 38)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .accessibilityLabel("\(profile.name), \(profile.form)")
        .accessibilityHint("Changes your name, form and classes")
    }
}

/// The temperature and the conditions, then the place and the day's high and low.
struct WeatherReading: View {
    let weather: Weather
    let isDay: Bool

    var body: some View {
        let range = [weather.high.map { "H " + Weather.degrees($0) }, weather.low.map { "L " + Weather.degrees($0) }]
            .compactMap { $0 }.joined(separator: "  ")
        let detail = [weather.place, range].filter { !$0.isEmpty }
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(Weather.degrees(weather.temperature))
                    .font(.title2.weight(.bold))
                Label(weather.sky.label(isDay: isDay), systemImage: weather.sky.symbol(isDay: isDay))
                    .font(.subheadline.weight(.semibold))
            }
            if !detail.isEmpty {
                Text(detail.joined(separator: " · "))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Holidays

/* The next national holiday and how long until it: whole days while it is
   more than a day off, then hours, minutes and seconds. The few after it are
   listed underneath. */
struct HolidayCard: View {
    let now: Date
    /// The column the later holidays' symbols sit in; it grows with the text size.
    @ScaledMetric(relativeTo: .subheadline) private var iconWidth: CGFloat = 22

    var body: some View {
        let upcoming = Holidays.upcoming(at: now)
        if let next = upcoming.first {
            let countdown = Holidays.countdown(to: next, at: now)
            VStack(alignment: .leading, spacing: 12) {
                Label(countdown == .today ? "Holiday today" : "Next holiday", systemImage: next.symbol)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.red)
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(next.name)
                            .font(.title2.weight(.bold))
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                        Text("\(next.localName) · \(next.dateText)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if let off = next.dayOffText {
                            Text(off)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer(minLength: 0)
                    CountdownBadge(countdown: countdown, now: now)
                }
                let later = upcoming.dropFirst().prefix(3)
                if !later.isEmpty {
                    Divider()
                    ForEach(later) { holiday in
                        let name = Text(holiday.name).font(.subheadline.weight(.semibold))
                        let date = Text(Holidays.short(holiday.start)).font(.footnote).foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            Image(systemName: holiday.symbol)
                                .foregroundStyle(.red)
                                .frame(width: iconWidth)
                            // on one line while there is room; with larger text the date drops under the name
                            ViewThatFits(in: .horizontal) {
                                HStack(spacing: 4) {
                                    name.lineLimit(1)
                                    Spacer(minLength: 4)
                                    date.lineLimit(1)
                                }
                                VStack(alignment: .leading, spacing: 0) {
                                    name
                                    date
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            CountdownLabel(countdown: Holidays.countdown(to: holiday, at: now), now: now)
                                .font(.footnote.weight(.semibold).monospacedDigit())
                                .frame(minWidth: 62, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(Color.red.opacity(0.08)), in: .rect(cornerRadius: 28))
        }
    }
}

/// The count, large: "6 days", or the clock running down once it is under one.
struct CountdownBadge: View {
    let countdown: Countdown
    let now: Date

    var body: some View {
        VStack(alignment: .trailing, spacing: -2) {
            switch countdown {
            case .today:
                Text("Today")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
            case .timer(let start):
                Text(timerInterval: now...start, countsDown: true)
                    .font(.system(size: 34, weight: .bold, design: .rounded).monospacedDigit())
                    .multilineTextAlignment(.trailing)
                Text("to go")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            case .days(let days):
                Text("\(days)")
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                Text("days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.red)
    }
}


// MARK: - Now

struct NowCard: View {
    let snapshot: Snapshot
    let now: Date

    var body: some View {
        let tint = snapshot.holidayToday != nil ? .red : snapshot.focus?.segment.tint ?? .accentColor
        VStack(alignment: .leading, spacing: 10) {
            if let current = snapshot.current {
                Label("Now", systemImage: current.segment.symbol)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(current.segment.tint)
                Text(current.segment.shortTitle)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Details(segment: current.segment)
                ProgressView(value: current.progress(at: now))
                    .tint(current.segment.tint)
                HStack {
                    Text("\(minutesLeft(current)) min left")
                    Spacer()
                    Text("until \(Timetable.hhmm(current.segment.end))")
                }
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
                if let next = snapshot.upcoming.first {
                    Divider()
                    NextLine(item: next, label: "Next")
                }
            } else if let holiday = snapshot.holidayToday {
                // a weekday with no school on it says so, and why, before it says what is next
                Label("No class today", systemImage: holiday.symbol)
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(.red)
                Text(holiday.name)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text("\(holiday.localName) · \(holiday.offReason)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let next = snapshot.upcoming.first {
                    Divider()
                    NextLine(item: next, label: snapshot.dayLabel)
                }
                daysOffAhead
            } else if let next = snapshot.upcoming.first {
                Label("Next · \(snapshot.dayLabel)", systemImage: "arrow.forward.circle")
                    .font(.caption.weight(.bold))
                    .textCase(.uppercase)
                    .foregroundStyle(next.segment.tint)
                Text(next.segment.shortTitle)
                    .font(.largeTitle.weight(.bold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text("\(Timetable.hhmm(next.segment.start))–\(Timetable.hhmm(next.segment.end))")
                    .font(.headline.monospacedDigit())
                Details(segment: next.segment)
                if snapshot.isToday {
                    Text("in \(minutesLeft(until: next.start)) min")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                daysOffAhead
            } else {
                Label("Nothing on the timetable", systemImage: "calendar")
                    .font(.headline)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(tint.opacity(0.15)), in: .rect(cornerRadius: 28))
    }

    /// Why the next class is not on the next day: the holiday in between.
    @ViewBuilder
    private var daysOffAhead: some View {
        if let note = snapshot.daysOffAhead {
            Label(note, systemImage: "flag.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.red)
        }
    }

    private func minutesLeft(_ item: TimedSegment) -> Int { minutesLeft(until: item.end) }

    private func minutesLeft(until date: Date) -> Int {
        max(0, Int((date.timeIntervalSince(now) / 60).rounded(.up)))
    }
}

/// Room and teacher, under a name.
struct Details: View {
    let segment: Segment

    var body: some View {
        let parts = [segment.place, segment.staff].filter { !$0.isEmpty }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct NextLine: View {
    let item: TimedSegment
    let label: String

    var body: some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Capsule()
                .fill(item.segment.tint)
                .frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 0) {
                Text(item.segment.title)
                    .font(.subheadline.weight(.semibold))
                Text([Timetable.hhmm(item.segment.start), item.segment.place].filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - The ten days

/* Each week gets a row of its own, marked ١ and ٢ in the gutter as the dock
   marks them. The published timetable numbers Week 1's columns and names
   Week 2's, so the rows carry 1-5 and Mon-Fri. */
struct DayPicker: View {
    @Binding var picked: Int?
    let shown: Int
    let today: Int?
    /// The day the page shows when it is left to follow the clock.
    let followed: Int?
    /// The days off for a national holiday, by cycle day, in this fortnight.
    let daysOff: [DayOff?]

    var body: some View {
        VStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { week in
                HStack(spacing: 6) {
                    Text(Timetable.weekMarks[week])
                        .font(DayPicker.big ? .system(size: 14.5) : .title3)
                        .foregroundStyle(.secondary)
                        .frame(width: 24)
                        .accessibilityHidden(true)
                    ForEach(0..<5, id: \.self) { weekday in
                        dayButton(week * 5 + weekday)
                    }
                }
            }
        }
        .padding(10)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
    }

    /// Larger on a Mac, where the picker is a window's half and not a
    /// phone's width, and the days read small across it.
    #if os(macOS)
    static let big = true
    #else
    static let big = false
    #endif

    private func dayButton(_ day: Int) -> some View {
        let week = day / 5, weekday = day % 5
        let isShown = day == shown
        let holiday = daysOff[day]?.holiday
        return Button {
            // picking the day the clock is on anyway is going back to the clock,
            // not a pick: left as one, "Today" stayed up over today's own list
            withAnimation(.snappy) { picked = day == followed ? nil : day }
        } label: {
            VStack(spacing: 3) {
                Text(week == 0 ? "\(weekday + 1)" : Timetable.dayNames[weekday])
                    .font((Self.big ? Font.system(size: 14.5) : .subheadline).weight(isShown ? .bold : .regular))
                Circle()
                    .fill(day == today ? Color.yellow : .clear)
                    .frame(width: Self.big ? 6 : 5, height: Self.big ? 6 : 5)
            }
            .frame(maxWidth: .infinity, minHeight: Self.big ? 46 : 44)
            // a day off is in red, as a calendar prints one
            .foregroundStyle(holiday != nil ? Color.red : isShown ? Color.primary : .secondary)
            .background {
                if isShown { Capsule().fill(.tint.opacity(0.2)) }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(Timetable.dayNames[weekday]), Week \(week + 1)" + (holiday.map { ", no class, \($0.name)" } ?? ""))
        .accessibilityAddTraits(isShown ? .isSelected : [])
    }
}

extension Snapshot {
    /* The day the page is on when left to follow the clock: the one the
       snapshot has turned to, except on a weekday off for a holiday, which is
       today all day — it has no last bell to turn over at, and its own list
       is what says there is no class. */
    var followedDay: Int? {
        let today = Timetable.cycleDay(of: date)
        return holidayToday != nil ? today : day.first?.cycleDay ?? today
    }

    /* Which of the ten days are off for a national holiday, by cycle day.
       The picker's days are days of the cycle and carry no dates, so each is
       taken for the date it falls on this week or next; the day the page
       follows the clock to is the one date known for certain. */
    var cycleDaysOff: [DayOff?] {
        var dates = Timetable.fortnight(at: date)
        if let first = day.first { dates[first.cycleDay] = dayDate }
        return dates.map { date in Holidays.off(on: date).map { DayOff(date: date, holiday: $0) } }
    }
}

// MARK: - The day

/// The day picked, or the one the clock is on: its name, and its classes.
struct DayCard: View {
    let day: Int
    let today: Int?
    let snapshot: Snapshot
    let now: Date
    let dayOff: DayOff?
    @Binding var picked: Int?
    /// How far the card has gone up under the Mac's header: its title stays
    /// at the top of what is left, and the lessons go on up under the title.
    @Environment(\.tucked) private var tucked
    @State private var height: CGFloat = 0

    private static let weekdays = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday"]

    var body: some View {
        // the title rides down the card as it goes under, until there is only room for the title
        let pinned = max(0, min(tucked, height - 72))
        VStack(alignment: .leading, spacing: 6) {
            header
                .offset(y: pinned)
                .zIndex(1)
            DayList(day: day, live: day == today, now: now, dayOff: dayOff)
                .mask(alignment: .top) { Rectangle().padding(.top, pinned) }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 28))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { height = $0 }
    }

    /// Which day the list underneath is: "Tomorrow · Monday · Week 2", with
    /// the way back to the clock once a day has been picked by hand.
    private var header: some View {
        let lead: String? = day == today ? "Today"
            : !snapshot.isToday && snapshot.day.first?.cycleDay == day ? snapshot.dayLabel
            : nil
        let name = Self.weekdays[day % 5]
        // the button is set on the middle of the title's line, not on its
        // baseline: its own text is smaller, and by the baseline it hung low
        return HStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(lead == name ? name : lead ?? name)
                    .font(.title3.weight(.bold))
                Text((lead == nil || lead == name ? "" : name + " · ") + "Week \(day / 5 + 1)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if picked != nil {
                Button {
                    withAnimation(.snappy) { picked = nil }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Today")
                    }
                }
                .buttonStyle(PillButtonStyle(compact: true))
            }
        }
        // a row of some height, so the title has room over and under it; and
        // the same with the button in it or not, so the list does not shift
        .frame(minHeight: 44)
        .padding(.horizontal, 12)
    }
}

extension EnvironmentValues {
    /// How far a box has gone up under the header that the Mac's page tucks
    /// its boxes under: nought on the phone, whose page scrolls plainly.
    @Entry var tucked: CGFloat = 0
}

extension Color {
    /// The plain background of a page, light or dark: the colour the words
    /// on a pill are cut out in.
    static var plainBackground: Color {
        #if os(macOS)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(uiColor: .systemBackground)
        #endif
    }
}

/* The buttons on a day's card, Today and Show: a pill filled in the text's
   own colour, with the words cut out of it in the background's, lifted a
   little off the card and giving under the finger. As tinted text, and then
   as a pale pill of the tint, Today was first lost against a blue sky and
   then read as a label; filled, it stands off any sky and looks like what it
   is. The fill is not quite solid, so some of the sky comes through it. */
struct PillButtonStyle: ButtonStyle {
    /// The small one, for the end of a title's line: no taller than the title.
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        // what it takes a touch on reaches this far past what is drawn
        let reach: CGFloat = compact ? 9 : 5
        configuration.label
            .font((compact ? Font.footnote : .subheadline).weight(.semibold))
            .foregroundStyle(Color.plainBackground)
            .padding(.horizontal, compact ? 10 : 14)
            .frame(minHeight: compact ? 26 : 34)
            .background(Color.primary.opacity(configuration.isPressed ? 0.5 : 0.7), in: .capsule)
            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.snappy(duration: 0.15), value: configuration.isPressed)
            .padding(reach)
            .contentShape(.rect)
            .padding(-reach)
    }
}

/* In place of a day's classes when it is off for a national holiday: that
   there are none, which holiday it is, and the date it takes out. Show
   brings the day's usual classes up under it all the same, for looking at
   what the cycle has there, and Hide puts them away again. */
struct DayOffNotice: View {
    let dayOff: DayOff
    @Binding var showsUsual: Bool

    var body: some View {
        let holiday = dayOff.holiday
        VStack(spacing: 4) {
            VStack(spacing: 4) {
                Image(systemName: holiday.symbol)
                    .font(.largeTitle)
                    .foregroundStyle(.red)
                    .padding(.bottom, 6)
                    .accessibilityHidden(true)
                Text("No class")
                    .font(.title3.weight(.bold))
                Text("\(holiday.name) · \(holiday.localName)")
                    .font(.subheadline.weight(.semibold))
                Text("\(Holidays.short(dayOff.date)) · \(holiday.offReason)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
            Button {
                withAnimation(.snappy) { showsUsual.toggle() }
            } label: {
                Label(showsUsual ? "Hide" : "Show", systemImage: showsUsual ? "eye.slash" : "eye")
            }
            .buttonStyle(PillButtonStyle())
            .padding(.top, 12)
            .accessibilityLabel(showsUsual ? "Hide the usual classes" : "Show the usual classes")
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 28)
        .padding(.bottom, showsUsual ? 12 : 22)
        .padding(.horizontal, 12)
    }
}

/// One day, in order. When it is today, what's done is greyed back and the
/// block running now fills across as it runs down. A day off for a holiday
/// has none of it: the cycle's classes for that day are not on, and are
/// only listed, under the notice, when asked for.
struct DayList: View {
    let day: Int
    let live: Bool
    let now: Date
    var dayOff: DayOff?
    /// Whether a day off has its usual classes listed under its notice.
    @State private var showsUsual = false

    var body: some View {
        Group {
            if let dayOff {
                VStack(spacing: 4) {
                    DayOffNotice(dayOff: dayOff, showsUsual: $showsUsual)
                    if showsUsual {
                        Text("Usual classes — not on")
                            .font(.caption.weight(.bold))
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                        // none of it is running, whatever the time
                        rows(live: false)
                    }
                }
            } else {
                rows(live: live)
            }
        }
        // asked for on one day off, not on every one after it
        .onChange(of: day) { showsUsual = false }
    }

    private func rows(live: Bool) -> some View {
        let cal = Timetable.calendar
        let minute = Double(cal.component(.hour, from: now) * 60 + cal.component(.minute, from: now))
            + Double(cal.component(.second, from: now)) / 60
        let line = Timetable.lines[day]
        return VStack(spacing: 4) {
            if line.isEmpty {
                Text("Nothing on this day.")
                    .foregroundStyle(.secondary)
                    .padding()
            }
            ForEach(Array(line.enumerated()), id: \.offset) { _, segment in
                let isNow = live && Double(segment.start) <= minute && minute < Double(segment.end)
                let isDone = live && minute >= Double(segment.end)
                let progress = isNow ? (minute - Double(segment.start)) / Double(segment.minutes) : 0
                Group {
                    if segment.isLesson {
                        LessonRow(segment: segment, isNow: isNow, minutesLeft: Int((Double(segment.end) - minute).rounded(.up)))
                    } else {
                        GapRow(segment: segment)
                    }
                }
                .background(alignment: .leading) {
                    if isNow {
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 16).fill(segment.tint.opacity(0.08))
                            GeometryReader { geo in
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(segment.tint.opacity(0.22))
                                    .frame(width: max(16, geo.size.width * progress))
                            }
                        }
                    }
                }
                .opacity(isDone ? 0.45 : 1)
            }
        }
    }
}

/* The width of the time column down the left of a day, and the gap either
   side of the colour bar. Both grow with the text size in Settings, so a time
   is never broken over two lines and the rows stay in line with each other. */
struct RowMetrics: DynamicProperty {
    @ScaledMetric(relativeTo: .subheadline) var time: CGFloat = 54
    @ScaledMetric(relativeTo: .subheadline) var gap: CGFloat = 12
}

/// A class in the day's list. Clicked, it shows the class's homework.
struct LessonRow: View {
    let segment: Segment
    let isNow: Bool
    let minutesLeft: Int
    var metrics = RowMetrics()
    @State private var showsHomework = false

    var body: some View {
        Button {
            showsHomework = true
        } label: {
            row
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showsHomework) {
            HomeworkList(segment: segment, now: .now)
        }
        .accessibilityHint("Shows its homework")
    }

    private var row: some View {
        HStack(alignment: .top, spacing: metrics.gap) {
            VStack(alignment: .trailing, spacing: 1) {
                Text(Timetable.hhmm(segment.start))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text("\(segment.minutes) min")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: metrics.time, alignment: .trailing)
            RoundedRectangle(cornerRadius: 2)
                .fill(segment.tint)
                .frame(width: 4)
            VStack(alignment: .leading, spacing: 8) {
                ForEach(segment.lessons, id: \.self) { lesson in
                    VStack(alignment: .leading, spacing: 1) {
                        Text(lesson.name)
                            .font(.body.weight(.semibold))
                        let detail = [lesson.room, lesson.staff.joined(separator: ", ")].filter { !$0.isEmpty }
                        if !detail.isEmpty {
                            Text(detail.joined(separator: " · "))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 6) {
                if isNow {
                    Text("\(minutesLeft) min")
                        .font(.footnote.weight(.semibold).monospacedDigit())
                        .foregroundStyle(segment.tint)
                }
                HomeworkBadge(segment: segment, tint: segment.tint)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .fixedSize(horizontal: false, vertical: true)
    }
}

struct GapRow: View {
    let segment: Segment
    var metrics = RowMetrics()

    var body: some View {
        HStack(spacing: metrics.gap) {
            Text(Timetable.hhmm(segment.start))
                .font(.footnote.monospacedDigit())
                .lineLimit(1)
                .frame(width: metrics.time, alignment: .trailing)
            Image(systemName: segment.symbol)
                .frame(width: 4)
            Text("\(segment.title) — \(segment.minutes) min")
            Spacer(minLength: 0)
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
    }
}
