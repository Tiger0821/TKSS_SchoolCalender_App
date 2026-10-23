import SwiftUI

/* The page, in a window: the date and the time, whose timetable it is with
   the weather beside it, and under them the boxes — the class that is on,
   the next holiday, the homework, the ten-day picker and the day picked.
   They are the phone's own boxes (Page/), laid out for a window: in one
   column, as on the phone, while the window is narrow, and in two once there
   is room for them, at first the class, the holiday and the homework on the
   left and the day on the right; held and dragged, they go where they are
   put, as on the phone. The date and the sky stay where they are, and the
   boxes scroll up under them. A class in the day's list, clicked, shows its
   homework.

   Behind it all is the sky as it is outside, when the weather is known, or,
   picked in Settings, Liquid Glass that the desktop shows through
   (`MacBackdrop`). The person in the header opens setup again, and the gear
   that comes out of it under the pointer opens Settings. */
struct MacPage: View {
    /// The window's id, for opening it from the menu bar and from Settings.
    static let window = "timetable"

    @Environment(MacModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(MacBackdrop.key) private var backdropChoice = MacBackdrop.sky
    @AppStorage(MacBackdrop.clearKey) private var clear = MacBackdrop.clearDefault
    @AppStorage(MacBackdrop.blurKey) private var blur = MacBackdrop.blurDefault
    /// Which box is where, as moved by hand.
    @AppStorage(MacLayout.key) private var boxes = MacLayout.standard
    /// A cycle day (0-9) picked by hand; nil follows the clock.
    @State private var picked: Int?
    @State private var weather = WeatherModel()
    @Bindable private var homework = Homework.shared
    /// The strip of open sky under the date, in the window: it places the sun.
    @State private var skyWindow = CGRect.zero
    /// How far the boxes have been scrolled: the header gives way to them.
    @State private var scrolled: CGFloat = 0

    /* The header's height at rest, and gathered up into one line once the
       boxes have been scrolled up into it. Between the two it is pushed
       shorter point for point as they come, as the Weather app's is. */
    // the two lines' own height, and no more: with room to spare, the boxes sat well away under it
    private static let heroTall: CGFloat = 78
    // the one line's own height: at 36 it left a strip of empty sky between the line and the boxes
    private static let heroShort: CGFloat = 26
    /// Room over the header, under the title bar, and in from each side of it.
    private static let heroTop: CGFloat = 14
    private static let heroInset: CGFloat = 10
    /// How far in from that the one line sits once the header has gathered.
    private static let gatheredInset: CGFloat = 48

    /// From this width there is room for the boxes in two columns.
    private static let twoColumns: CGFloat = 820
    /// Wider than this and the page stays this wide, in the middle.
    private static let widest: CGFloat = 1240
    private static let margin: CGFloat = 24
    private static let spacing: CGFloat = 18

    var body: some View {
        @Bindable var model = model
        let _ = homework.signingIn
        Group {
            if let profile = model.profile {
                // the day's rows are laid out from the profile without being handed it,
                // so a changed profile gets a page of its own rather than a stale one
                page(for: profile)
                    .id(profile)
            } else {
                SetupView(existing: nil) { model.use($0) }
            }
        }
        .frame(minWidth: 440, minHeight: 600)
        // under glass, the window is a pane the desktop shows through, behind setup as well as the page
        .background {
            if glass { GlassPane(clear: clear, blur: blur) }
        }
        .containerBackground(glass ? AnyShapeStyle(.clear) : AnyShapeStyle(.windowBackground), for: .window)
        .background(SeeThroughWindow(isOn: glass))
        .modifier(LooksActive(always: glass))
        .sheet(isPresented: $model.editing) {
            SetupView(existing: model.profile) { new in
                model.use(new)
                model.editing = false
            } cancel: {
                model.editing = false
            }
            .frame(width: 520, height: 680)
        }
        .sheet(isPresented: $homework.signingIn) {
            ManageBacSignIn()
        }
    }

    private var glass: Bool { backdropChoice == .glass }

    private func page(for profile: Profile) -> some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let snapshot = Timetable.snapshot(at: now)
            let today = Timetable.cycleDay(of: now)
            let shown = picked ?? snapshot.followedDay ?? 0
            let daysOff = snapshot.cycleDaysOff
            let phase = weather.current?.phase(at: now)
            let scene = weather.current.map { SkyScene(sky: $0.sky, phase: phase ?? .day, wind: $0.wind) }

            GeometryReader { window in
                let content = min(window.size.width, Self.widest) - 2 * Self.margin
                let twoColumns = window.size.width >= Self.twoColumns
                // the two columns the same width, so the gap between them is the page's middle,
                // under the person in the header
                let leftColumn = (content - Self.spacing) / 2
                let nowCard = NowCard(snapshot: snapshot, now: now)
                let holidayCard = HolidayCard(now: now)
                let homeworkCard = HomeworkCard(now: now)
                let picker = DayPicker(picked: $picked, shown: shown, today: today,
                                       followed: snapshot.followedDay, daysOff: daysOff)
                let dayCard = DayCard(day: shown, today: today, snapshot: snapshot, now: now,
                                      dayOff: daysOff[shown], picked: $picked)
                let collapse = Self.heroTall - Self.heroShort
                let gathered = min(1, max(0, scrolled / collapse))
                let heroHeight = Self.heroTall - collapse * gathered
                // where the boxes go under the header: as far below it as they sit at rest, the gap closing
                // up to ten points as the header gathers into its one line
                let edge = heroHeight + Self.heroTop + Self.spacing - (Self.spacing - 10) * gathered
                VStack(alignment: .leading, spacing: 0) {
                    ScrollView {
                      VStack(spacing: 0) {
                        // the header's room at rest; scrolled, the boxes come up into it
                        Color.clear
                            .frame(height: Self.heroTall + Self.heroTop)
                        // held and dragged, the boxes go where they are put (MacBoxes.swift)
                        BoxBoard(layout: $boxes, twoColumns: twoColumns, leftWidth: leftColumn,
                                 spacing: Self.spacing) { box, lifted in
                            switch box {
                            case .now: nowCard.tucksUnder(edge, radius: 28, unless: lifted)
                            case .holiday: holidayCard.tucksUnder(edge, radius: 28, unless: lifted)
                            case .homework: homeworkCard.tucksUnder(edge, radius: 28, unless: lifted)
                            case .days: picker.tucksUnder(edge, radius: 24, unless: lifted)
                            case .timetable: dayCard.tucksUnder(edge, radius: 28, unless: lifted)
                            }
                        }
                        .padding(.horizontal, Self.margin)
                        .padding(.top, Self.spacing)
                        .padding(.bottom, 28)
                      }
                    }
                    .onScrollGeometryChange(for: CGFloat.self) { geometry in
                        geometry.contentOffset.y + geometry.contentInsets.top
                    } action: { _, offset in
                        scrolled = offset
                    }
                    .overlay(alignment: .top) {
                        hero(profile: profile, isDay: phase != .night, gathered: gathered)
                            .frame(height: heroHeight, alignment: .top)
                            .padding(.horizontal, Self.margin + Self.heroInset)
                            .padding(.top, Self.heroTop)
                    }
                }
                .frame(maxWidth: Self.widest)
                .frame(maxWidth: .infinity)
            }
            .background {
                backdrop(scene, tint: snapshot.focus?.segment.tint ?? .accentColor)
                    .ignoresSafeArea()
            }
            // every sky is dark at the top, so over one the page is always in its dark colours;
            // glass takes the Mac's own, Light or Dark
            .preferredColorScheme(glass || scene == nil ? nil : .dark)
        }
        .task {
            // look again every couple of minutes; each refresh decides whether it is time to fetch
            while !Task.isCancelled {
                await weather.refresh()
                await homework.refresh()
                try? await Task.sleep(for: .seconds(120))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await weather.refresh() }
                Task { await homework.refresh() }
            }
        }
    }

    /* The top of the window. The day and the weather face each other across
       the sky, line for line — a large line and a small one under it: the
       date, then the weekday and the clock, at the left; the temperature,
       then the conditions, the high and low and the place, at the right —
       with whose timetable it is, a person on glass, between them in the
       middle, and the sun or the moon three quarters of the way across. On
       the phone the same pieces run down the left. */

    /* `gathered` is how far the header has given way to the boxes, from 0
       at rest to 1 gathered up. The large lines shrink a little and fade as
       it goes, and the one-line form fades in as they go: the date and the
       clock at the left, the temperature and the conditions at the right. */
    private func hero(profile: Profile, isDay: Bool, gathered: CGFloat) -> some View {
        // over the sky the words are white; under the glass, the page's own colours
        let onSky = !glass && weather.current != nil
        return ZStack(alignment: .top) {
            HStack(alignment: .top) {
                DayHero(onSky: onSky)
                Spacer(minLength: 24)
                if let current = weather.current {
                    WeatherHero(weather: current, isDay: isDay, onSky: onSky)
                }
            }
            .opacity(max(0, 1 - gathered * 1.8))
            .scaleEffect(1 - 0.15 * gathered, anchor: .top)
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                // the sun or moon goes at a window's right-hand end; this one ends three quarters of the
                // way across, clear of the person in the middle. Measured at rest: gathering up, the
                // header would carry the sun up with it
                guard gathered == 0 else { return }
                skyWindow = CGRect(x: frame.minX, y: frame.minY, width: frame.width * 0.72 + 64, height: frame.height)
            }
            HStack(alignment: .firstTextBaseline) {
                DayLine(onSky: onSky)
                Spacer(minLength: 24)
                if let current = weather.current {
                    WeatherLine(weather: current, isDay: isDay, onSky: onSky)
                }
            }
            // drawn in toward the middle as the header gathers, a centimetre a side on a laptop's screen
            .padding(.horizontal, Self.gatheredInset * gathered)
            .opacity(max(0, (gathered - 0.45) / 0.55))
            .allowsHitTesting(false)
        }
        // a halo of light round the words (光暈), over the sky and the glass alike: close and bright, then
        // wide and faint
        .shadow(color: .white.opacity(0.55), radius: 3)
        .shadow(color: .white.opacity(0.3), radius: 12)
        // whose timetable it is, between the day and the weather. Up in the title bar it was hard
        // against the window's top edge
        .overlay(alignment: .top) {
            PersonButton(profile: profile, size: 40 - 12 * gathered) { model.editing = true }
                .padding(.top, 8 - 12 * gathered)
        }
    }

    /// What is behind the page: the sky when the weather is known, and
    /// otherwise a wash of the colour of whatever is on. Under glass,
    /// nothing: the glass is behind the whole window, and the sky's frames
    /// stop.
    @ViewBuilder
    private func backdrop(_ scene: SkyScene?, tint: Color) -> some View {
        if glass {
            Color.clear
        } else if let scene {
            PixelSky(scene: scene, window: skyWindow)
        } else {
            LinearGradient(colors: [tint.opacity(0.28), .clear], startPoint: .top, endPoint: .center)
                .background(Color.plainBackground)
        }
    }
}

/// The left of the hero: the weekday in small capitals, the date large, and
/// the time to the second under it.
private struct DayHero: View {
    /// Over the sky every line is white: in grey, the small ones were lost
    /// against a pale cloud. Without a sky, the page's own colours.
    let onSky: Bool

    var body: some View {
        let ink = onSky ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)
        let small = onSky ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary)
        // from midnight, so each tick lands on the second
        TimelineView(.periodic(from: Timetable.calendar.startOfDay(for: .now), by: 1)) { context in
            VStack(alignment: .leading, spacing: 2) {
                Text(context.date.formatted(.dateTime.month(.wide).day()))
                    .font(.system(size: 46, weight: .bold))
                    .foregroundStyle(ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                // "Thursday · 15:49:46"
                Text(context.date.formatted(.dateTime.weekday(.wide)) + " · " + Timetable.clock(context.date))
                    .font(.title3.weight(.medium).monospacedDigit())
                    .foregroundStyle(small)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

/// The right of the hero, the day's mirror: the temperature large, and
/// under it the conditions, the high and low and the place.
private struct WeatherHero: View {
    let weather: Weather
    let isDay: Bool
    /// As for the day: white over the sky.
    let onSky: Bool

    var body: some View {
        let ink = onSky ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)
        let small = onSky ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary)
        let range = [weather.high.map { "H " + Weather.degrees($0) }, weather.low.map { "L " + Weather.degrees($0) }]
            .compactMap { $0 }.joined(separator: "  ")
        VStack(alignment: .trailing, spacing: 2) {
            Text(Weather.degrees(weather.temperature))
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(ink)
                .monospacedDigit()
            // "☁ Drizzle · H 25°C  L 22°C · Beitou District"
            let line = [weather.sky.label(isDay: isDay), range, weather.place].filter { !$0.isEmpty }.joined(separator: " · ")
            // the symbol in the one text with the words; joined on with `+` it came out as its own description
            Text("\(Image(systemName: weather.sky.symbol(isDay: isDay))) \(line)")
                .font(.title3.weight(.medium).monospacedDigit())
                .foregroundStyle(small)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The day gathered into one line, for the header once the boxes have
/// been scrolled up into it: "October 22  Thursday · 16:20:05".
private struct DayLine: View {
    let onSky: Bool

    var body: some View {
        let ink = onSky ? AnyShapeStyle(.white) : AnyShapeStyle(.primary)
        let small = onSky ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary)
        TimelineView(.periodic(from: Timetable.calendar.startOfDay(for: .now), by: 1)) { context in
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(context.date.formatted(.dateTime.month(.wide).day()))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(ink)
                Text(context.date.formatted(.dateTime.weekday(.wide)) + " · " + Timetable.clock(context.date))
                    .font(.callout.weight(.medium).monospacedDigit())
                    .foregroundStyle(small)
            }
            .lineLimit(1)
        }
    }
}

/// The weather gathered into one line, as the Weather app keeps it:
/// "24°C | Drizzle".
private struct WeatherLine: View {
    let weather: Weather
    let isDay: Bool
    let onSky: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(Weather.degrees(weather.temperature))
                .font(.title2.weight(.bold))
                .monospacedDigit()
            Text("|")
                .font(.callout.weight(.light))
            Text("\(Image(systemName: weather.sky.symbol(isDay: isDay))) \(weather.sky.label(isDay: isDay))")
                .font(.callout.weight(.medium))
        }
        .foregroundStyle(onSky ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
        .lineLimit(1)
    }
}

/* Whose timetable it is, as a person on glass that opens setup. Under the
   pointer it opens out into the name and the form: the glass stretches both
   ways from the middle, on a spring with a little give in it, as Apple's own
   glass moves, and the words come up through a blur as it goes. Out of its
   far end comes the gear for Settings, a drop of glass of its own that
   pulls away from it as water does (the two are in one
   `GlassEffectContainer`), while the person stays where it was. It opens as soon as the pointer comes, but is slow to let it go:
   a margin round it still counts as over it, and away from that it waits a
   moment before the gear runs back into it and it into a drop, so a pointer
   that overshoots on its way to the gear finds it still there. Under the
   pointer each drop swells a little: the person's all round, the gear
   making room for it, and the gear's away from the person, the gear
   turning once. The trackpad gives a tap each time the pointer comes onto
   either of them. */
private struct PersonButton: View {
    let profile: Profile
    /// Across, when it is a drop; the gear is as wide.
    let size: CGFloat
    let edit: () -> Void
    @Environment(\.openSettings) private var openSettings
    @Namespace private var glass
    @State private var open = false
    /// Closing it, once the pointer has been away for `grace`.
    @State private var leaving: Task<Void, Never>?
    @State private var overPerson = false
    /// One more each time the pointer comes onto the person, for the trackpad's tap.
    @State private var personVisits = 0
    @State private var overGear = false
    /// One more each time the pointer comes onto the gear, which turns it once.
    @State private var gearTurns = 0
    /// Between the person and the gear, and as far as the two drops reach
    /// for each other: they come apart, and then stand clear.
    private static let gap: CGFloat = 10
    /// Round it, once open, that still counts as over it.
    private static let margin: CGFloat = 11
    private static let grace = Duration.milliseconds(420)
    private static let spring = Animation.spring(duration: 0.45, bounce: 0.3)
    /// How much a drop grows under the pointer.
    private var swell: CGFloat { size * 0.12 }

    var body: some View {
        // wider by half the person's swell while it is swollen, so the gear keeps clear of it
        let spacing = Self.gap + (overPerson ? swell / 2 : 0)
        GlassEffectContainer(spacing: Self.gap) {
            HStack(spacing: spacing) {
                person
                if open {
                    gear
                }
            }
            // as much again on the other side, so the person stays in the middle of the header
            .padding(.leading, open ? size + spacing : 0)
            // the pointer crossing from the person to the gear is still over them, and so is the
            // margin round them, which is taken back off again so nothing moves
            .padding(open ? Self.margin : 0)
            .contentShape(.rect)
            .onHover { hovering in
                leaving?.cancel()
                leaving = nil
                if hovering {
                    withAnimation(Self.spring) { open = true }
                } else {
                    leaving = Task {
                        try? await Task.sleep(for: Self.grace)
                        guard !Task.isCancelled else { return }
                        withAnimation(Self.spring) {
                            open = false
                            // the gear goes before the pointer can be seen off it
                            overPerson = false
                            overGear = false
                        }
                    }
                }
            }
            .padding(open ? -Self.margin : 0)
        }
    }

    private var person: some View {
        Button(action: edit) {
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle")
                    .font(.system(size: size * 0.5, weight: .medium))
                if open {
                    Text(profile.name)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                        .fixedSize()
                        .transition(.blurReplace)
                    Text(profile.form)
                        .font(.footnote.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(.tint.opacity(0.4), in: .capsule)
                        .fixedSize()
                        .transition(.blurReplace)
                }
            }
            .foregroundStyle(.white)
            .padding(.horizontal, open ? 14 : 0)
            .frame(minWidth: size, minHeight: size)
            // swollen, the glass is really larger all round, the person and the words as they were
            .padding(overPerson ? swell / 2 : 0)
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .capsule)
        .glassEffectID("person", in: glass)
        // in the room it had, so the header doesn't move under it
        .padding(overPerson ? -swell / 2 : 0)
        .onHover { hovering in
            withAnimation(Self.spring) { overPerson = hovering }
            if hovering { personVisits += 1 }
        }
        // a tap on the trackpad each time the pointer comes onto it, opening it or coming back
        // from the gear; none as it goes
        .sensoryFeedback(.alignment, trigger: personVisits)
        .focusEffectDisabled()
        .accessibilityLabel("\(profile.name), \(profile.form)")
        .accessibilityHint("Changes your name, form and classes")
        // the gear is only there under the pointer
        .accessibilityAction(named: "Settings") { openSettings() }
    }

    private var gear: some View {
        // swollen, the drop is really larger, the gear in its middle: scaled instead, the glass,
        // drawn by its container, grew from its top left corner and left the gear off to one side
        let across = size + (overGear ? swell : 0)
        return Button {
            openSettings()
        } label: {
            Image(systemName: "gearshape")
                .font(.system(size: size * 0.45, weight: .medium))
                .symbolEffect(.rotate.clockwise, value: gearTurns)
                .foregroundStyle(.white)
                .frame(width: across, height: across)
                .contentShape(.circle)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular.interactive(), in: .circle)
        .glassEffectID("gear", in: glass)
        // in the room it had: it swells away from the person, and the two drops stay apart
        .frame(width: size, height: size, alignment: .leading)
        .onHover { hovering in
            withAnimation(Self.spring) { overGear = hovering }
            if hovering { gearTurns += 1 }
        }
        // a tap on the trackpad as the pointer comes onto it, as the person gives
        .sensoryFeedback(.alignment, trigger: gearTurns)
        .focusEffectDisabled()
        .help("Settings")
        .accessibilityLabel("Settings")
    }
}

/* Under glass the window keeps its look when another window is in front:
   with Settings open over it, the glass being set there should be seen as
   it will be. SwiftUI is told the window is in front, so the boxes and the
   picked day keep their colours; the glass over the whole window, which
   macOS itself drew darker behind another window, is gone (`GlassPane`).
   Over the sky, the window takes macOS's way. */
private struct LooksActive: ViewModifier {
    let always: Bool
    @Environment(\.appearsActive) private var active

    func body(content: Content) -> some View {
        content.environment(\.appearsActive, always || active)
    }
}

/* A box going up under the header is cut off at the top, as the Weather
   app's cards are, and not faded: its top edge stays where the header ends,
   rounded as it was, and the box grows shorter until it is gone. One that
   has a title keeps it at the top of what is left (`tucked`). */
private struct TucksUnder: ViewModifier {
    /// Where the header ends, in the scroll view's own space.
    let edge: CGFloat
    let radius: CGFloat
    /// The box's top, in the same space.
    @State private var top: CGFloat = 0

    func body(content: Content) -> some View {
        let tucked = max(0, edge - top)
        content
            .environment(\.tucked, tucked)
            .mask(alignment: .top) {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .padding(.top, tucked)
            }
            .onGeometryChange(for: CGFloat.self) { proxy in
                proxy.frame(in: .scrollView).minY
            } action: { minY in
                top = minY
            }
    }
}

private extension View {
    /// Tucked under the header as it scrolls, unless it is the copy being
    /// carried over the page, which is drawn whole.
    @ViewBuilder
    func tucksUnder(_ edge: CGFloat, radius: CGFloat, unless lifted: Bool) -> some View {
        if lifted {
            self
        } else {
            modifier(TucksUnder(edge: edge, radius: radius))
        }
    }
}
