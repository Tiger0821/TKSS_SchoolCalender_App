import SwiftUI
import WidgetKit

/// The boxes that can be moved around, in the order they come in.
enum Box: String, CaseIterable {
    case now, holiday, days, timetable

    /// A saved order, with anything missing from it put back at the end.
    static func order(from saved: String) -> [Box] {
        var boxes: [Box] = []
        for name in saved.split(separator: ",") {
            if let box = Box(rawValue: String(name)), !boxes.contains(box) { boxes.append(box) }
        }
        return boxes + allCases.filter { !boxes.contains($0) }
    }
}

/* The dock, as an app: today's date and the time, what's on now, the next
   national holiday, a picker for any of the ten days in the cycle, and the
   picked day underneath. It follows the clock until a day is picked by hand;
   Today brings it back. The four boxes can be put in any order — touch and
   hold one to move it — and the order is kept. Behind it all is the sky as it
   is outside, when the weather is known.

   Nothing else is on the page. The settings, and where everything comes
   from, are a page of their own off the right-hand edge: a swipe in from
   that edge, or the gear by the clock, slides it across. */
struct ContentView: View {
    /// A cycle day (0-9) picked by hand; nil follows the clock.
    @State private var picked: Int?
    @AppStorage("boxOrder") private var savedOrder = ""
    /// The page's scroll position, so a box held at the edge can scroll it.
    @State private var scrollPosition = ScrollPosition()
    @State private var scroller = Scroller()
    @State private var weather = WeatherModel()
    /// The strip of open sky under the date, measured on the page, and where
    /// the page starts on the screen: together they place the sun.
    @State private var skyWindow = CGRect.zero
    @State private var pageOrigin = CGPoint.zero
    @Environment(\.scenePhase) private var scenePhase
    /// Whose timetable it is; nil until setup has been done.
    @State private var profile = Timetable.profile
    /// Setup again, to change the name, the form or the classes.
    @State private var editing = false
    /// Whether the settings page is across the screen.
    @State private var settingsOpen = false
    /// While a finger is pulling it: how far across it is, 0 (away) to 1.
    @State private var pull: CGFloat?

    private var boxOrder: Binding<[Box]> {
        Binding {
            Box.order(from: savedOrder)
        } set: { boxes in
            savedOrder = boxes.map(\.rawValue).joined(separator: ",")
        }
    }

    var body: some View {
        Group {
            if let profile {
                GeometryReader { geo in
                    let span = geo.size.width + geo.safeAreaInsets.leading + geo.safeAreaInsets.trailing
                    let across = pull ?? (settingsOpen ? 1 : 0)
                    ZStack {
                        // the day's rows are laid out from the profile without being handed it,
                        // so a changed profile gets a page of its own rather than a stale one
                        page(for: profile)
                            .id(profile)
                            // it gives way as settings comes over it, a little, and dims
                            .offset(x: -across * span * 0.3)
                            .overlay {
                                Color.black.opacity(0.35 * across)
                                    .ignoresSafeArea()
                                    .allowsHitTesting(false)
                            }
                            .allowsHitTesting(across == 0)
                            .accessibilityHidden(settingsOpen)
                            .gesture(EdgeSwipe(edge: .right) { state, distance, speed in
                                pulled(state, fraction: -distance / span, speed: -speed, opening: true)
                            })
                        SettingsPanel(profile: profile) {
                            editing = true
                        } close: {
                            withAnimation(.snappy(duration: 0.3)) { settingsOpen = false }
                        }
                        .offset(x: (1 - across) * span)
                        .accessibilityHidden(!settingsOpen)
                        .gesture(EdgeSwipe(edge: .left) { state, distance, speed in
                            pulled(state, fraction: distance / span, speed: speed, opening: false)
                        })
                    }
                }
                // a knock as it opens, and a lighter one as it goes
                .sensoryFeedback(trigger: settingsOpen) { _, open in
                    open ? .impact(weight: .medium) : .impact(weight: .light)
                }
            } else {
                SetupView(existing: nil) { use($0) }
            }
        }
        .sheet(isPresented: $editing) {
            SetupView(existing: profile) {
                use($0)
                editing = false
            } cancel: {
                editing = false
            }
        }
    }

    /* A finger pulling the settings page in from the right edge, or pushing
       it back from the left. `fraction` is how far across the screen it has
       come and `speed` how fast, both in the direction of the swipe. The page
       follows the finger; let go and it carries on if it was past a third of
       the way or moving quickly, and goes back otherwise. */
    private func pulled(_ state: UIGestureRecognizer.State, fraction: CGFloat, speed: CGFloat, opening: Bool) {
        let fraction = min(1, max(0, fraction))
        switch state {
        case .began, .changed:
            pull = opening ? fraction : 1 - fraction
        case .ended:
            let carriesOn = fraction > 0.35 || speed > 600
            withAnimation(.snappy(duration: 0.3)) {
                settingsOpen = opening ? carriesOn : !carriesOn
                pull = nil
            }
        default:
            withAnimation(.snappy(duration: 0.3)) { pull = nil }
        }
    }

    /// Take up a profile from setup: keep it, lay the fortnight out for it,
    /// and have the widgets do the same.
    private func use(_ new: Profile) {
        new.save()
        Timetable.profile = new
        withAnimation(.snappy) {
            profile = new
            picked = nil
        }
        WidgetCenter.shared.reloadAllTimelines()
        // the watch lays out the same profile, and the reminders name its classes
        TimetableApp.remind()
        // a day already on the Lock Screen was laid out for the old profile
        Task { await ClassActivityManager.refresh(reset: .everything) }
    }

    private func page(for profile: Profile) -> some View {
        TimelineView(.everyMinute) { context in
            let now = context.date
            let snapshot = Timetable.snapshot(at: now)
            let today = Timetable.cycleDay(of: now)
            let followed = snapshot.followedDay
            let shown = picked ?? followed ?? 0
            let daysOff = snapshot.cycleDaysOff
            let phase = weather.current?.phase(at: now)
            let scene = weather.current.map { SkyScene(sky: $0.sky, phase: phase ?? .day, wind: $0.wind) }

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    DateHeader()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        // beside the clock, where the date above it has the full width
                        .overlay(alignment: .bottomTrailing) {
                            Button {
                                withAnimation(.snappy(duration: 0.3)) { settingsOpen = true }
                            } label: {
                                Image(systemName: "gearshape")
                                    .font(.body.weight(.medium))
                                    .frame(width: 38, height: 38)
                            }
                            .buttonStyle(.plain)
                            .glassEffect(.regular.interactive(), in: .circle)
                            .offset(y: 6)
                            .accessibilityLabel("Settings")
                        }
                    SkyStrip(profile: profile, weather: weather.current, isDay: phase != .night) {
                        editing = true
                    }
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named("page"))
                    } action: { frame in
                        skyWindow = frame
                    }
                    ReorderableStack(order: boxOrder, scroller: scroller) { box in
                        switch box {
                        case .now: NowCard(snapshot: snapshot, now: now)
                        case .holiday: HolidayCard(now: now)
                        case .days: DayPicker(picked: $picked, shown: shown, today: today,
                                               followed: followed, daysOff: daysOff)
                        case .timetable:
                            DayCard(day: shown, today: today, snapshot: snapshot, now: now,
                                    dayOff: daysOff[shown], picked: $picked)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 40)
                .coordinateSpace(.named("page"))
            }
            .scrollPosition($scrollPosition)
            // keep the Lock Screen's day going: today's up, the next one booked
            .task(id: now) { await ClassActivityManager.refresh() }
            .onScrollGeometryChange(for: ScrollExtent.self) { geometry in
                let top = -geometry.contentInsets.top
                return ScrollExtent(offset: geometry.contentOffset.y, top: top,
                                    bottom: max(top, geometry.contentSize.height + geometry.contentInsets.bottom
                                                - geometry.containerSize.height),
                                    leading: geometry.contentInsets.leading)
            } action: { _, extent in
                scroller.offset = extent.offset
                scroller.range = extent.top...extent.bottom
                let origin = CGPoint(x: extent.leading, y: -extent.top)
                if origin != pageOrigin { pageOrigin = origin }
            }
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                scroller.frame = frame
            }
            .onAppear {
                let position = $scrollPosition
                scroller.scrollTo = { position.wrappedValue.scrollTo(y: $0) }
            }
            .background {
                backdrop(scene, tint: snapshot.focus?.segment.tint ?? .accentColor)
                    .ignoresSafeArea()
            }
            // the backdrop again over the top of the screen, thinning out just below the
            // status bar, so the page fades away as it slides up under the clock
            .overlay {
                backdrop(scene, tint: snapshot.focus?.segment.tint ?? .accentColor)
                    .mask(alignment: .top) {
                        LinearGradient(stops: [.init(color: .black, location: 0.6), .init(color: .clear, location: 1)],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: pageOrigin.y + 8)
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            // every sky is dark at the top, so over one the page is always in its dark colours
            .preferredColorScheme(scene == nil ? nil : .dark)
        }
        .task {
            // look again every couple of minutes; refresh decides whether it is time to fetch
            while !Task.isCancelled {
                await weather.refresh()
                try? await Task.sleep(for: .seconds(120))
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { Task { await weather.refresh() } }
        }
    }

    /// What is behind the page: the sky when the weather is known, and
    /// otherwise a wash of the colour of whatever is on.
    @ViewBuilder
    private func backdrop(_ scene: SkyScene?, tint: Color) -> some View {
        if let scene {
            PixelSky(scene: scene, window: skyWindow.offsetBy(dx: pageOrigin.x, dy: pageOrigin.y))
        } else {
            LinearGradient(colors: [tint.opacity(0.28), .clear], startPoint: .top, endPoint: .center)
                .background(Color(.systemBackground))
        }
    }
}

/// How far the page is scrolled, how far it can go either way, and how far
/// in from the left edge of the screen it starts.
private struct ScrollExtent: Equatable {
    var offset: CGFloat
    var top: CGFloat
    var bottom: CGFloat
    var leading: CGFloat
}

#Preview {
    ContentView()
}
