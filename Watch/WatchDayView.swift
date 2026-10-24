import SwiftUI
import WatchKit

/* The day on the watch: the phone's page with everything taken off it that
   the watch has no room for, or already says. No date and no clock — the
   watch has its own at the top of the screen — no teachers, no holiday
   countdown, no picker. What is left is each class with the time it starts
   and its room, the breaks between them, and behind it all the same sky. A
   weekday off for a holiday is still said, since the day under it is then
   not today's.

   It follows the clock, as the phone's does: today until the last bell, and
   after that the next school day. That is the first of a row of pages, one
   to a school day, with the days after it to its right: a swipe from right
   to left goes on a day, and one back the other way. Each is named at its
   top, with which of the two weeks it falls in, since the same weekday is a
   different day in the other week.

   A day arriving is seen as it comes on: its name gives a start and its
   rows come in from the side the swipe comes from, each a moment behind
   the one above (Arriving), from the moment the finger sets off toward it,
   while the page slides in; and the wrist is clicked as the swipe is let
   go. The pages say which one is on only once a swipe has settled, half a
   second after it ends, and set off from that, the day had arrived and
   stopped before it moved again. The Digital Crown scrolls the day on
   screen, up and down; only a swipe goes to another day. Today's name is
   in red.

   Under the day is the way into setup (WatchSetupView), to change the
   classes; with no profile yet, it is all there is. */
struct WatchDayView: View {
    let profile: Profile?
    /// Called with a profile out of setup.
    let use: (Profile) -> Void
    @State private var weather = WeatherModel()
    @State private var settingUp = false
    /// Which of the days is on screen: 0 is the one the clock leads to.
    @State private var page = 0
    /// How many times each day has been swiped to, and which way the last
    /// swipe went. A count going up is that day arriving: the click and the
    /// movement both go by it, which is what keeps them together.
    @State private var arrivals = [Int](repeating: 0, count: reach)
    @State private var forward = true
    /// The day the swipe under way is bringing on, once it is known which
    /// way it is going.
    @State private var coming: Int?
    /// One more each time a swipe is let go toward another day: the click.
    @State private var clicks = 0
    /// The day the last swipe brought on, so that its settling does not
    /// play the arrival again.
    @State private var brought: Int?
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How many school days there are to swipe through: a fortnight of them,
    /// so every day of both weeks is among them.
    private static let reach = 10

    var body: some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let snapshot = Timetable.snapshot(at: now)
            let days = Self.days(from: snapshot)
            TabView(selection: $page) {
                ForEach(days.indices, id: \.self) { index in
                    dayPage(index == 0 ? snapshot.day : Timetable.day(of: days[index]), on: days[index],
                            index: index, snapshot: snapshot, now: now)
                        .tag(index)
                }
            }
            // no dots: there are ten days, and each says at its top which it is
            .tabViewStyle(.page(indexDisplayMode: .never))
            // the arrival goes with the finger, not with the pages' settling
            .simultaneousGesture(swipe(days: days.count))
            // the one sky stays put behind the days as they go by
            .background { sky(at: now) }
        }
        .task { await weather.refresh() }
        .sheet(isPresented: $settingUp) {
            WatchSetupView(existing: profile) {
                use($0)
                settingUp = false
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await weather.refresh() } }
            // left and come back to, it is at the day the clock leads to again
            if phase == .background { page = 0 }
        }
        // another profile's days are other days
        .onChange(of: profile) { page = 0 }
        // a day the swipe did not already bring on arrives as it settles; not when the app is
        // left and goes back to the first by itself, with nobody looking
        .onChange(of: page) { old, new in
            defer { brought = nil }
            guard scenePhase == .active, arrivals.indices.contains(new), new != brought else { return }
            forward = new > old
            arrivals[new] += 1
            clicks += 1
        }
        .sensoryFeedback(.selection, trigger: clicks)
    }

    /* The finger, alongside the pages' own swipe. As soon as it is plainly
       going across, the day on that side starts arriving, while it is still
       coming on; let go far enough, or quickly enough, to go there, the
       wrist is clicked. */
    private func swipe(days: Int) -> some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { drag in
                let across = drag.translation.width
                guard coming == nil, abs(across) > 8, abs(across) > abs(drag.translation.height) * 1.2 else { return }
                let next = page + (across < 0 ? 1 : -1)
                coming = next
                guard (0..<days).contains(next) else { return }
                forward = across < 0
                arrivals[next] += 1
            }
            .onEnded { drag in
                defer { coming = nil }
                let width = WKInterfaceDevice.current().screenBounds.width
                guard let next = coming, (0..<days).contains(next),
                      abs(drag.predictedEndTranslation.width) > width / 2 else { return }
                brought = next
                clicks += 1
            }
    }

    /// The day the clock leads to and the school days after it.
    private static func days(from snapshot: Snapshot) -> [Date] {
        var days = [snapshot.dayDate]
        guard !snapshot.day.isEmpty else { return days }
        while days.count < reach, let next = Timetable.nextSchoolDay(after: days[days.count - 1]) { days.append(next) }
        return days
    }

    /// One day's page; the first, at index 0, is the one the clock leads to.
    private func dayPage(_ day: [TimedSegment], on date: Date, index: Int, snapshot: Snapshot, now: Date) -> some View {
        let leads = index == 0
        let arriving = Arriving(count: arrivals[index], forward: forward, still: reduceMotion)
        return ScrollViewReader { reader in
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    if profile == nil {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Choose your classes to see your day.")
                                .font(.footnote)
                            Button("Choose classes") { settingUp = true }
                                .buttonStyle(.borderedProminent)
                            // a phone that has been set up hands its classes over by itself
                            Text("Chosen in Timetable on your iPhone, they come across.")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.black.opacity(0.4), in: .rect(cornerRadius: 12))
                    } else if day.isEmpty {
                        Text("No classes")
                            .font(.headline)
                    } else {
                        if leads, let holiday = snapshot.holidayToday {
                            // a weekday off for a holiday: said first, then the next school day
                            VStack(alignment: .leading, spacing: 1) {
                                Label("No class today", systemImage: holiday.symbol)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.red)
                                Text("\(holiday.name) · \(holiday.localName)")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.black.opacity(0.38), in: .rect(cornerRadius: 12))
                        }
                        dayHeader(date, now: now)
                            .modifier(arriving.start)
                        ForEach(Array(day.enumerated()), id: \.element.id) { order, item in
                            WatchRow(item: item, isOn: item.contains(now), isOver: item.end <= now, now: now)
                                .id(item.id)
                                .modifier(arriving.row(order))
                        }
                    }
                    if profile != nil {
                        Button {
                            settingUp = true
                        } label: {
                            Label("Change classes", systemImage: "slider.horizontal.3")
                                .font(.system(size: 13, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(.black.opacity(0.38), in: .rect(cornerRadius: 12))
                                // the whole tile takes the tap, not only the words on it
                                .contentShape(.rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 6)
                    }
                }
                .padding(.horizontal, 4)
            }
            // open on the class that is on, not on the morning
            .onAppear {
                if leads, let current = snapshot.current { reader.scrollTo(current.id, anchor: .center) }
            }
        }
    }

    /* Which day the page is, and which week it falls in. The timetable's
       Week 1 is the odd week and its Week 2 the even: the weeks of the term
       counted from its first, which was a Week 1. */
    private func dayHeader(_ date: Date, now: Date) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            let label = Timetable.dayLabel(of: date, at: now)
            Text(label)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(label == "Today" ? Color.red : .white)
            Text(Timetable.week(of: date) == 0 ? "Odd week" : "Even week")
                .font(.system(size: 12, weight: .semibold))
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(.white.opacity(0.2), in: .capsule)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
        .padding(.leading, 6)
    }

    /// The sky as it is outside; a plain dusk until the weather is known.
    @ViewBuilder
    private func sky(at now: Date) -> some View {
        if let current = weather.current {
            PixelSky(scene: SkyScene(sky: current.sky, phase: current.phase(at: now), wind: current.wind),
                     // the sun or moon in the corner the clock leaves free
                     window: CGRect(x: 0, y: 28, width: 120, height: 40))
                // dimmed, so the rows read over a bright noon
                .overlay(Color.black.opacity(0.25).ignoresSafeArea())
        } else {
            LinearGradient(colors: [Color(red: 0.1, green: 0.16, blue: 0.3), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        }
    }
}

/* What is seen as a day arrives, at the moment the wrist is clicked: the
   day's name swells and settles, as if it had been tapped too, and the rows
   under it come in from the side the swipe came from, each a moment behind
   the one above it. Both play each time `count` goes up. With Reduce Motion
   on nothing slides or swells; the rows only come up out of the dim. */
struct Arriving {
    let count: Int
    let forward: Bool
    /// Reduce Motion is on.
    let still: Bool

    var start: Start { Start(count: count, still: still) }

    func row(_ order: Int) -> Row { Row(count: count, order: order, from: still ? 0 : forward ? 34 : -34) }

    struct Start: ViewModifier {
        let count: Int
        let still: Bool

        func body(content: Content) -> some View {
            content.keyframeAnimator(initialValue: 1.0, trigger: count) { view, scale in
                view.scaleEffect(scale, anchor: .leading)
            } keyframes: { _ in
                KeyframeTrack {
                    // up at once, as the click is, and then let go of
                    CubicKeyframe(still ? 1 : 1.2, duration: 0.1)
                    SpringKeyframe(1, duration: 0.4, spring: .bouncy)
                    // a spring is cut off a hair short of where it was going,
                    // and words left a hair off their size are drawn soft
                    LinearKeyframe(1, duration: 0.05)
                }
            }
        }
    }

    struct Row: ViewModifier {
        let count: Int
        /// How far down the day the row is: the wait before it moves.
        let order: Int
        /// Where it starts from, in points to the side.
        let from: CGFloat

        struct Place {
            var shift: CGFloat = 0
            var opacity = 1.0
        }

        func body(content: Content) -> some View {
            // past the screen's worth of rows the wait stops growing: what is
            // below the fold should not still be arriving when it is scrolled to
            let wait = 0.01 + Double(min(order, 7)) * 0.035
            return content.keyframeAnimator(initialValue: Place(), trigger: count) { view, place in
                view.offset(x: place.shift).opacity(place.opacity)
            } keyframes: { _ in
                KeyframeTrack(\.shift) {
                    MoveKeyframe(from)
                    LinearKeyframe(from, duration: wait)
                    SpringKeyframe(0, duration: 0.42, spring: .snappy)
                    // as with the name: brought to rest exactly, not a hair off
                    LinearKeyframe(0, duration: 0.05)
                }
                KeyframeTrack(\.opacity) {
                    MoveKeyframe(0.3)
                    LinearKeyframe(0.3, duration: wait)
                    LinearKeyframe(1, duration: 0.22)
                }
            }
        }
    }
}

/// One stretch of the day: a class with its start and its room, or a break.
struct WatchRow: View {
    let item: TimedSegment
    let isOn: Bool
    let isOver: Bool
    let now: Date

    var body: some View {
        let segment = item.segment
        if segment.isLesson {
            let tint = Timetable.tint(for: segment.lessons.first?.subject ?? "")
            HStack(alignment: .top, spacing: 6) {
                Text(Timetable.hhmm(item.start))
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .frame(width: 40, alignment: .leading)
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(tint)
                    .frame(width: 3)
                VStack(alignment: .leading, spacing: 1) {
                    Text(segment.shortTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if !segment.place.isEmpty {
                        Text(segment.place)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                    }
                    if isOn {
                        // the system counts it down between the minute's redraws
                        Text("\(Text(timerInterval: now...item.end, countsDown: true)) left")
                            .font(.system(size: 12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(tint)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.black.opacity(isOn ? 0.6 : 0.38), in: .rect(cornerRadius: 12))
            .overlay {
                if isOn { RoundedRectangle(cornerRadius: 12).strokeBorder(tint, lineWidth: 1.5) }
            }
            .opacity(isOver ? 0.5 : 1)
        } else {
            HStack(spacing: 6) {
                Text(Timetable.hhmm(item.start))
                    .font(.system(size: 11).monospacedDigit())
                    .frame(width: 40, alignment: .leading)
                Image(systemName: segment.title == "Lunch" ? "fork.knife" : "cup.and.saucer")
                    .font(.system(size: 10))
                Text("\(segment.title) · \(segment.minutes) min")
                    .font(.system(size: 11))
                    .lineLimit(1)
            }
            .foregroundStyle(.white.opacity(isOn ? 0.95 : 0.6))
            .padding(.horizontal, 8)
            .padding(.vertical, 1)
            .opacity(isOver ? 0.5 : 1)
        }
    }
}
