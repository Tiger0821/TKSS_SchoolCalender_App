import ActivityKit
import SwiftUI
import WidgetKit

/* The Live Activity's views.

   The Lock Screen panel is the full thing: a stack of panels, one per block
   of the day, that TimeSwitch uncovers in turn as their times come, each
   with its own countdown. The Dynamic Island is kept light, because every
   presentation is saved into the one file and the file has a limit (see
   BlockPanel): its compact form names the class that is on and, beside it,
   says how many minutes are left of it — to the end of the class, where the
   Lock Screen counts to the end of the period — or, on a day too full to
   afford that, leaves the label by itself. */
struct ClassLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ClassActivityAttributes.self) { context in
            ActivityPanel(day: context.attributes)
                .activityBackgroundTint(Color.black)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let day = context.attributes
            return DynamicIsland {
                DynamicIslandExpandedRegion(.bottom) {
                    DaySummary(day: day)
                }
            } compactLeading: {
                TimeSwitch(stages: day.labelStages) { stage in
                    IslandLabel(day: day, stage: stage)
                }
            } compactTrailing: {
                if day.affordsMinutes {
                    TimeSwitch(stages: day.minuteStages) { stage in
                        IslandMinutes(day: day, stage: stage)
                    }
                    // one width for every stage, so the ones in hiding sit
                    // exactly behind the one that is showing
                    .frame(width: 50)
                }
            } minimal: {
                /* Where another app has the island too and this is cut down
                   to a dot. The class that is on was tried here, and it is
                   a second set of the label's curtains: 70 KB more on the
                   fullest day as the curtains then were, of an allowance
                   with some 160 KB to spare (see BlockPanel). A mark that says whose dot it is costs
                   nothing. */
                Image(systemName: "graduationcap.fill")
                    .foregroundStyle(.white)
            }
        }
        // the small size is what a paired Apple Watch shows in its Smart Stack;
        // without it the watch makes do with the island's two compact views
        .supplementalActivityFamilies([.small])
    }
}

/// The Lock Screen's panel on the phone; the day strip on the Apple Watch.
struct ActivityPanel: View {
    @Environment(\.activityFamily) private var family
    let day: ClassActivityAttributes

    var body: some View {
        switch family {
        case .small: DayStrip(day: day)
        default: LockScreenPanel(day: day)
        }
    }
}

// MARK: - Time

/* What the Live Activity shows over the day: the wait before the first bell
   (plainly while it is long, counted down once it is under two hours), then
   each block, then the end. */
enum Stage: Hashable {
    case before
    case soon
    case block(Int)
    case after
}

extension ClassActivityAttributes {
    /// How long before the first bell the wait starts being counted down. A
    /// countdown's share of the saved drawing grows with the time it runs
    /// for (see BlockPanel), and one counting from the evening before took a
    /// quarter of the whole allowance by itself.
    static let lead: TimeInterval = 2 * 60 * 60

    /// When the countdown to the first bell begins.
    var countdownStart: Date? {
        blocks.first.map { max(made, $0.start.addingTimeInterval(-Self.lead)) }
    }

    /// Every stage with the moment it begins. The first has none: it is what
    /// shows until the next one's time comes.
    var stages: [(stage: Stage, from: Date?)] {
        guard let last = blocks.last, let countdownStart else { return [(.before, nil)] }
        var out: [(Stage, Date?)] = made < countdownStart ? [(.before, nil), (.soon, countdownStart)] : [(.soon, nil)]
        for (index, block) in blocks.enumerated() { out.append((.block(index), block.start)) }
        out.append((.after, last.end))
        return out
    }

    /* The stages of the island's label, which are fewer: it only names what
       is on, so a double period is one stage, the wait before school is one,
       and a short break already names the class that follows it. Fewer
       stages are fewer curtains to pay for. */
    var labelStages: [(stage: Stage, from: Date?)] {
        var out: [(Stage, Date?)] = [(.before, nil)]
        var shown: String?
        var breakStart: Date?
        for (index, block) in blocks.enumerated() {
            if block.isShortBreak {
                breakStart = breakStart ?? block.start
                continue
            }
            if block.short != shown {
                out.append((.block(index), breakStart ?? block.start))
                shown = block.short
            }
            breakStart = nil
        }
        if let last = blocks.last { out.append((.after, last.end)) }
        return out
    }

    /// The day in fewer, longer pieces: a double period is one run, since
    /// drawn side by side the two would be the one block anyway.
    var runs: [Block] {
        var out: [Block] = []
        for block in blocks {
            if let last = out.last, last.isLesson == block.isLesson, last.short == block.short, last.end == block.start {
                out[out.count - 1].end = block.end
            } else {
                out.append(block)
            }
        }
        return out
    }

    /* The stages of the island's minutes: one for each class — a double
       period is one, as it is for the label — and one for each short break,
       which shows when the class after it starts. A stage for every period
       would be the Lock Screen's count exactly, but each stage with a
       countdown in it costs some 40 KB of a file that may not pass 2,000
       (see BlockPanel), and a day of sixteen periods came to 94% of that. */
    var minuteStages: [(stage: Stage, from: Date?)] {
        let firsts = classFirsts
        var out: [(Stage, Date?)] = [(.before, nil)]
        for index in blocks.indices where firsts[index] == index {
            out.append((.block(index), blocks[index].start))
        }
        if let last = blocks.last { out.append((.after, last.end)) }
        return out
    }

    /// The longest a class is counted down as one: the island's minutes have
    /// two digits, and their countdown runs a minute over.
    private static let longestClass: TimeInterval = 98 * 60

    /// For each block, the block its class began with: itself, unless it is
    /// a later period of a double — the same class going straight on, with
    /// no break between.
    private var classFirsts: [Int] {
        var firsts: [Int] = []
        for index in blocks.indices {
            let block = blocks[index]
            if index > 0, !block.isShortBreak, !blocks[index - 1].isShortBreak,
               blocks[index - 1].short == block.short, blocks[index - 1].end == block.start,
               block.end.timeIntervalSince(blocks[firsts[index - 1]].start) <= Self.longestClass {
                firsts.append(firsts[index - 1])
            } else {
                firsts.append(index)
            }
        }
        return firsts
    }

    /// When the class that starts at `index` is over: the end of its last
    /// period, where it is a double.
    func classEnd(from index: Int) -> Date {
        let firsts = classFirsts
        let last = blocks.indices.last { firsts[$0] == firsts[index] } ?? index
        return blocks[last].end
    }

    /* Whether the day's drawing has room for the minutes in the island (see
       BlockPanel for what things weigh). The system shows nothing at all
       over 2,000,000 bytes (1,953 KB), and the ten days of the cycle were
       measured against that on iOS 27, which saves the larger file; the
       figures are in the README. A day of more blocks than the fullest of
       those does without them, which takes some 300 KB back off it. */
    var affordsMinutes: Bool { blocks.count <= 16 }

    /// Its colour as it goes on black, which the panel and the island are
    /// whatever the phone is set to.
    func tint(_ block: Block) -> Color {
        if block.isLesson { return Timetable.tone(for: block.tint).onDark }
        return (block.tint == "Lunch" ? Tone.butter : .slate).onDark
    }
}

/* Shows one panel at a time, changing at set moments, with nothing sent from
   the app. All the panels are drawn, one on top of another, and the clock
   hides every one but the one whose time it is. There are two ways of
   hiding, because each costs something different (see Shutter and Curtain):
   shutters are quick to draw and heavy to save, and curtains the reverse.
   The Lock Screen's panel is large and is dragged about with the
   notifications, so it has the shutters; the island's are a few letters
   each, and have the curtains. */
struct TimeSwitch<Panel: View>: View {
    enum Means { case shutters, curtains }

    let stages: [(stage: Stage, from: Date?)]
    var by = Means.curtains
    @ViewBuilder var panel: (Stage) -> Panel

    var body: some View {
        switch by {
        case .shutters:
            ZStack {
                Color.black
                ForEach(stages.indices, id: \.self) { index in
                    whole(index).shuttered(from: stages[index].from,
                                           until: index + 1 < stages.count ? stages[index + 1].from : nil)
                }
                Shutter.restored
            }
        case .curtains:
            nest(from: 0)
        }
    }

    private func whole(_ index: Int) -> some View {
        panel(stages[index].stage)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black)
    }

    /* The panel for the stage at `index`, with all the later ones on top of
       it, behind that stage's curtain. Each is solid, and hides the ones
       before it once it is let in. They are one inside another, and not
       side by side, so that anything a shut curtain lets through has as
       many curtains to get through as its panel is stages away. */
    private func nest(from index: Int) -> AnyView {
        guard index < stages.count else { return AnyView(EmptyView()) }
        let stack = ZStack {
            whole(index)
            nest(from: index + 1)
        }
        if let from = stages[index].from {
            return AnyView(stack.mask { Curtain(opensAt: from) })
        }
        return AnyView(stack)
    }
}

/* A progress bar set to run over the instant before `at`, far larger than
   any panel: the system fills such a bar in by itself, which makes it one
   of the two things a Live Activity can animate (the other is a countdown).
   Shutter and Curtain are each one of these, put to a different use.

   The Lock Screen is not redrawn continuously; it is redrawn when a
   countdown ticks, and the one that matters is the last tick of the block
   before, which lands on `at` itself. So the run is a twentieth of a second
   and ends there: that redraw finds the bar already run. Run after the
   moment instead, it caught the bar part-way and left the panel half
   uncovered until the next tick — which, once the day's last countdown had
   finished, was a long time coming. */
struct InstantBar: View {
    let at: Date
    /// Full until then, and empty after.
    var empties = false
    var mirrored = false

    var body: some View {
        ProgressView(timerInterval: at.addingTimeInterval(-0.05)...at, countsDown: empties) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .progressViewStyle(.linear)
        /* A few points tall with round ends: stretched this far, the part
           left in view is a plain rectangle. It is laid out small and then
           scaled, rather than laid out wide, because of what it costs: the
           system saves a Live Activity's drawing to a file with a size limit,
           and a bar's share of that file grows with the width it is laid out
           at. At 900 points wide the day came to 2.2 MB and was refused. */
        .frame(width: 24)
        .scaleEffect(x: mirrored ? -40 : 40, y: 150, anchor: .center)
        .frame(minWidth: 0, maxWidth: .infinity, minHeight: 0, maxHeight: .infinity)
        .clipped()
    }
}

/* Black over the panel it is in until `at`, and nothing after — or, with
   `opens` false, the other way about. A panel has one of each: shut until
   its block begins, and shut again once the next one has. A shut panel is
   black all over, and the panels are added together, light on light, so the
   shut ones add nothing and the open one is all there is to see.

   The bar is black and is laid on as hard light, under which black makes
   black of whatever is behind it. That is the full part of the bar. The
   empty part is not clear — the system draws a faint track there, a quarter
   solid, and nothing that can be set on the bar removes it — but the track
   is the system's mid grey, and hard light leaves alone whatever a mid grey
   is laid on. (It is not quite the middle: 120, 120, 128 of 255, so the red
   and green behind each shutter come out a fiftieth down. `restored` puts
   that back.)

   It is done this way for the Lock Screen's 120 frames a second. It was
   done with masks first: every panel behind four of them to be rid of that
   track, and all the later panels behind those again, seventy deep by the
   end of a day. A mask is drawn apart and then laid on, each one, every
   time the panel moves, and with that many, scrolling the notifications
   under a school day fell to 60. This way a panel is drawn apart once, and
   none is inside another.

   What it costs is room in the file the drawing is saved to (see
   BlockPanel): a bar that is seen is three times the weight of one that is
   only a mask. */
struct Shutter: View {
    let at: Date
    let opens: Bool

    var body: some View {
        /* One that opens is turned to face the other way, so that it draws
           back from the same side the one shutting the panel before comes
           in from, and the two panels are never both on show. */
        InstantBar(at: at, empties: opens, mirrored: opens)
            .tint(.black)
            .blendMode(.hardLight)
    }

    /// Goes over all the shuttered panels together. Colour dodge divides
    /// what is behind by what this leaves of one: the fiftieth, twice over,
    /// that the open panel's two shutters took off its red and green. (The
    /// first panel of a day and the last have one shutter, and so come out
    /// a fiftieth up.)
    static var restored: some View {
        Color(red: 0.04, green: 0.04, blue: 0)
            .blendMode(.colorDodge)
    }
}

extension View {
    /// On show from `from` until `until`, and black the rest of the time;
    /// nil is no shutter on that side.
    func shuttered(from: Date?, until: Date?) -> some View {
        ZStack {
            self
            if let from { Shutter(at: from, opens: true) }
            if let until { Shutter(at: until, opens: false) }
        }
        .compositingGroup()
        .blendMode(.plusLighter)
    }
}

/* Clear until `opensAt`, then solid: a mask for the panel that comes in
   then. The bar is white on black, and how bright the picture is becomes
   how solid the mask is. Its empty part is not black — there is the track,
   which would let a ghost of the hidden panel through — so before that the
   picture is darkened and its contrast raised, until everything less than
   about nine tenths white is black and the white is white still.

   The line is drawn that high for the Mac, whose menu bar shows the
   island's two ends when the phone is near. It was first drawn at a half,
   with a colour burn, which is all the phone's own track needs (it is an
   eighth as bright as the bar); and on the Mac every stage of the day
   showed at once, each through the one before. What the Mac draws for a
   track has not been seen by itself, only that it came through that.

   (This was once four bars, each a mask inside the last, since each
   multiplied the track's quarter by a quarter again. A colour filter set on
   the bar itself does nothing useful, which is why that was done; set on
   the bar and the black behind it taken together, it does.) */
struct Curtain: View {
    let opensAt: Date

    var body: some View {
        ZStack {
            Color.black
            InstantBar(at: opensAt)
                .tint(.white)
        }
        .compositingGroup()
        .brightness(-0.38)
        .contrast(16)
        .luminanceToAlpha()
    }
}

// MARK: - Lock Screen

struct LockScreenPanel: View {
    let day: ClassActivityAttributes

    var body: some View {
        TimeSwitch(stages: day.stages, by: .shutters) { stage in
            Group {
                switch stage {
                case .before: BeforePanel(day: day, counts: false)
                case .soon: BeforePanel(day: day, counts: true)
                case .block(let index): BlockPanel(day: day, index: index)
                case .after: AfterPanel(day: day)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .foregroundStyle(.white)
    }
}

/* What the drawing costs. The system saves a Live Activity's drawing — the
   Lock Screen panel and every form of the Dynamic Island together — to one
   file, and refuses it over 2,000,000 bytes. When that happens nothing is
   shown at all, and nothing is reported to the app. It is not the layout
   that fills the file but the parts the system animates. Measured:

       a countdown        about 38 KB (51 KB in a rounded, fixed-width face)
       a progress bar     about  9 KB
       a shutter          about  9 KB, and a panel on the Lock Screen has two
       a curtain          about  5 KB, and a panel in the island has one
       the rest of a panel   20 KB or so

   (A shutter is a progress bar. So is a curtain, but a bar that is only a
   mask is saved as 3 KB of the 5.)

   A school day is sixteen or seventeen panels. Drawn in full on the Lock
   Screen and again in the island, with a countdown in each, it came to
   2.2 MB. So: the countdowns are in the plain face; the wait before the
   first bell is only counted down for its last two hours; and the island
   counts to the end of a class, not of each period, so that a double
   period is one countdown there and not two, and gives the five- and
   ten-minute breaks none. On the Lock Screen those breaks did without one
   too, and said "10 min" for the whole ten minutes. They count down there
   now: a countdown that runs so short a time is about 23 KB, and the five
   breaks of the fullest day came to 114 KB. The same drawing saves about
   an eighth larger on iOS 27 than on iOS 26, so it is iOS 27's figure that
   has to fit. */
extension ClassActivityAttributes.Block {
    /// A break too short for the island to count down: there it names the
    /// class to come and says when that starts.
    var isShortBreak: Bool { !isLesson && end.timeIntervalSince(start) <= 15 * 60 }
}

extension Font {
    /// The face for countdowns: the plain one, which costs least to save.
    static func countdown(_ size: CGFloat) -> Font { .system(size: size, weight: .semibold) }
}

/// The class running now: its name and room, the time left, how far through
/// it is, and what's next.
struct BlockPanel: View {
    let day: ClassActivityAttributes
    let index: Int

    var body: some View {
        let block = day.blocks[index]
        let tint = day.tint(block)
        let next = day.lesson(after: index)
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline) {
                Text(block.isLesson ? "NOW" : block.title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(tint)
                Text("until \(Timetable.hhmm(block.end))")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Text(day.day)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.6))
            }
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(block.isLesson ? block.title : (next.map { "Next: \($0.title)" } ?? block.title))
                        .font(.system(size: 22, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Text(block.isLesson ? block.place : (next?.place ?? ""))
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                Text(timerInterval: block.start...block.end, countsDown: true)
                    .font(.countdown(30))
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(tint)
                    .frame(width: 110, alignment: .trailing)
            }
            ProgressView(timerInterval: block.start...block.end, countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .progressViewStyle(.linear)
            .tint(tint)
            if block.isLesson {
                Text(next.map { "Next  \($0.title) · \(Timetable.hhmm($0.start))\($0.place.isEmpty ? "" : " · " + $0.place)" }
                     ?? "Last class today")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            } else if let next {
                Text("starts \(Timetable.hhmm(next.start))")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
    }
}

/// Before the first bell: the first class, and — once `counts` — how long
/// until it.
struct BeforePanel: View {
    let day: ClassActivityAttributes
    let counts: Bool

    var body: some View {
        if let first = day.blocks.first, let from = day.countdownStart {
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text("FIRST CLASS")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(day.tint(first))
                    Text("at \(Timetable.hhmm(first.start))")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text(day.day)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(first.title)
                            .font(.system(size: 22, weight: .bold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        Text(first.place)
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    if counts {
                        Text(timerInterval: min(from, first.start)...first.start, countsDown: true)
                            .font(.countdown(30))
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(day.tint(first))
                            .frame(width: 130, alignment: .trailing)
                    } else {
                        Text(Timetable.hhmm(first.start))
                            .font(.countdown(30))
                            .foregroundStyle(day.tint(first))
                    }
                }
                if counts {
                    ProgressView(timerInterval: min(from, first.start)...first.start, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        EmptyView()
                    }
                    .progressViewStyle(.linear)
                    .tint(day.tint(first))
                }
                if let then = day.lesson(after: 0) {
                    Text("Then  \(then.title) · \(Timetable.hhmm(then.start))")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.75))
                        .lineLimit(1)
                }
            }
        }
    }
}

struct AfterPanel: View {
    let day: ClassActivityAttributes

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 30))
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("That's the day")
                    .font(.system(size: 20, weight: .bold))
                Text("\(day.day) · \(day.blocks.filter(\.isLesson).count) classes done")
                    .font(.system(size: 13))
                    .foregroundStyle(.white.opacity(0.6))
            }
            Spacer()
            /* Time since the last bell. It is here to be read, but it also
               has a job: the Lock Screen is only redrawn while something is
               counting, and with the last class's countdown finished there
               would be nothing left to bring this panel into view. */
            if let last = day.blocks.last {
                VStack(alignment: .trailing, spacing: 0) {
                    Text(last.end, style: .timer)
                        .font(.countdown(17))
                        .multilineTextAlignment(.trailing)
                        .frame(width: 90, alignment: .trailing)
                    Text("ago")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
    }
}

// MARK: - Apple Watch

/* What a paired Apple Watch shows of the Live Activity. The phone's panels
   can't be used there. Tried when they were all hidden by curtains (see
   Curtain), the curtains hid nothing on the watch — worn before the first
   bell, it showed the last panel, "That's the day". A bar run by the clock
   is drawn finished there whatever the time is: a bar for the day, tried
   next, was full at half past two. The one thing the watch does keep moving is a
   countdown.

   A strip of the whole day with its hours was tried after that, and was
   true, and was too much to read on a wrist. So this is only what can be
   said plainly and stay right all day: which day it is, and how long school
   has left. What is on now and what is next is the watch app's own widget
   (WatchWidget), which is given a timeline and can change at every bell. */
struct DayStrip: View {
    let day: ClassActivityAttributes

    var body: some View {
        if let first = day.blocks.first, let last = day.blocks.last {
            VStack(alignment: .leading, spacing: 2) {
                Text(day.day)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    // a countdown takes all the width there is, so it is given its own
                    Text(timerInterval: first.start...last.end, countsDown: true)
                        .font(.countdown(20))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .frame(width: 92, alignment: .leading)
                    Text("of school left")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
            .foregroundStyle(.white)
            // the tile gives its content no margin of its own
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Dynamic Island

/// A few letters saying what's on.
struct IslandLabel: View {
    let day: ClassActivityAttributes
    let stage: Stage

    var body: some View {
        switch stage {
        case .before, .soon:
            Image(systemName: "sunrise.fill")
                .foregroundStyle(.orange)
        case .block(let index):
            Text(day.blocks[index].short)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(day.tint(day.blocks[index]))
                .lineLimit(1)
        case .after:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
    }
}

/* The minutes left of the class that is on: "32 min", for a double period
   to the end of its second half. In a short break the label beside it is
   already naming the class to come, so this gives the time that class
   starts; before the first bell it is the bell's time, and after the last
   there is nothing to count. */
struct IslandMinutes: View {
    let day: ClassActivityAttributes
    let stage: Stage

    var body: some View {
        switch stage {
        case .before, .soon:
            if let first = day.blocks.first {
                Text(Timetable.hhmm(first.start))
                    .font(.countdown(13))
            }
        case .block(let index):
            let block = day.blocks[index]
            if block.isShortBreak {
                Text(Timetable.hhmm(block.end))
                    .font(.countdown(13))
            } else {
                MinutesLeft(start: block.start, end: day.classEnd(from: index))
                    // grey, which IB Core and the gaps are, is too dim to read at this size
                    .foregroundStyle(block.isLesson && block.tint != Timetable.core ? day.tint(block) : .white)
            }
        case .after:
            Text("done")
                .font(.countdown(13))
                .foregroundStyle(.green)
        }
    }
}

/* "32 min", counting down. The only texts a Live Activity keeps moving are
   its countdowns, which read "32:10" — a text formatted to say "32 min" was
   tried, and stood still for as long as it was watched while a countdown
   beside it ran. So this is a countdown with its seconds cut off, and "min"
   written after it.

   Nothing here is measured in points, because the same numbers did not hold
   from one iOS to the next (on 26.5 a clip worked out for 27 left "1 min"
   with seventeen to go). The sizes come from text set in the same face: an
   unseen "00" is the window, two digits wide; an unseen "00:00" laid from
   the window's left-hand edge is the countdown's box, in which it sits
   hard to the right; and everything of that box beyond the window — the
   colon and the seconds — is clipped away.

   The countdown runs to a minute past the bell. A countdown shows the whole
   minutes left, where the app and the widgets round up ("33 min left" with
   32½ to go); the extra minute makes this agree with them. Two digits is
   all there is room for, so a class is never counted from more than 99
   minutes out: see `minuteStages`. */
struct MinutesLeft: View {
    let start: Date
    let end: Date
    private let font = Font.system(size: 13, weight: .semibold).monospacedDigit()

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text("00")
                .font(font)
                .hidden()
                .overlay(alignment: .leading) {
                    Text("00:00")
                        .font(font)
                        .hidden()
                        .overlay(alignment: .trailing) {
                            Text(timerInterval: start...end.addingTimeInterval(60), countsDown: true, showsHours: false)
                                .font(font)
                                .multilineTextAlignment(.trailing)
                                .lineLimit(1)
                        }
                        .fixedSize()
                }
                .clipped()
                /* and a point more off the right of the window: the colon
                   stands hard against it, and its edge showed as a speck
                   between the minutes and "min" */
                .mask(alignment: .leading) { Rectangle().padding(.trailing, 1) }
            Text("min")
                .font(.countdown(13))
        }
    }
}

/// The island pulled open: the day and its hours.
struct DaySummary: View {
    let day: ClassActivityAttributes

    var body: some View {
        if let first = day.blocks.first, let last = day.blocks.last {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    Text(day.day)
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Text("\(Timetable.hhmm(first.start)) – \(Timetable.hhmm(last.end))")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Text("\(day.blocks.filter(\.isLesson).count) classes · the Lock Screen has the one that's on")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }
            .padding(.horizontal, 4)
        }
    }
}
