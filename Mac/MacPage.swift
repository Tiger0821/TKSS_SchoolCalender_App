import SwiftUI

/* The page, in a window: the date and the time, whose timetable it is with
   the weather beside it, and under them the boxes — the class that is on,
   the next holiday, the ten-day picker and the day picked. They are the
   phone's own boxes (Page/), laid out for a window: in one column, as on the
   phone, while the window is narrow, and in two once there is room for them,
   the class and the holiday on the left and the day on the right. The date
   and the sky stay where they are, and the boxes scroll up under them.

   Behind it all is the sky as it is outside, when the weather is known. The
   name under the clock opens setup again, and the gear opens Settings. */
struct MacPage: View {
    /// The window's id, for opening it from the menu bar and from Settings.
    static let window = "timetable"

    @Environment(MacModel.self) private var model
    @Environment(\.openSettings) private var openSettings
    @Environment(\.scenePhase) private var scenePhase
    /// A cycle day (0-9) picked by hand; nil follows the clock.
    @State private var picked: Int?
    @State private var weather = WeatherModel()
    /// The strip of open sky under the date, in the window: it places the sun.
    @State private var skyWindow = CGRect.zero

    /// From this width there is room for the boxes in two columns.
    private static let twoColumns: CGFloat = 820
    /// Wider than this and the page stays this wide, in the middle.
    private static let widest: CGFloat = 1240
    private static let margin: CGFloat = 24
    private static let spacing: CGFloat = 18

    var body: some View {
        @Bindable var model = model
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
        .sheet(isPresented: $model.editing) {
            SetupView(existing: model.profile) { new in
                model.use(new)
                model.editing = false
            } cancel: {
                model.editing = false
            }
            .frame(width: 520, height: 680)
        }
    }

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
                let nowCard = NowCard(snapshot: snapshot, now: now)
                let holidayCard = HolidayCard(now: now)
                let picker = DayPicker(picked: $picked, shown: shown, today: today,
                                       followed: snapshot.followedDay, daysOff: daysOff)
                let dayCard = DayCard(day: shown, today: today, snapshot: snapshot, now: now,
                                      dayOff: daysOff[shown], picked: $picked)
                VStack(alignment: .leading, spacing: 0) {
                    header(profile: profile, isDay: phase != .night)
                        .padding(.horizontal, Self.margin)
                    ScrollView {
                        Group {
                            if window.size.width >= Self.twoColumns {
                                HStack(alignment: .top, spacing: Self.spacing) {
                                    VStack(spacing: Self.spacing) {
                                        nowCard
                                        holidayCard
                                    }
                                    .frame(width: min(460, (content - Self.spacing) * 0.45))
                                    VStack(spacing: Self.spacing) {
                                        picker
                                        dayCard
                                    }
                                }
                            } else {
                                VStack(spacing: Self.spacing) {
                                    nowCard
                                    holidayCard
                                    picker
                                    dayCard
                                }
                            }
                        }
                        .padding(.horizontal, Self.margin)
                        .padding(.top, Self.spacing)
                        .padding(.bottom, 28)
                    }
                    // the boxes thin out as they go up under the sky strip, the way
                    // the phone's page fades away under the clock
                    .mask {
                        VStack(spacing: 0) {
                            LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                                .frame(height: Self.spacing)
                            Rectangle()
                        }
                    }
                }
                .frame(maxWidth: Self.widest)
                .frame(maxWidth: .infinity)
            }
            .background {
                backdrop(scene, tint: snapshot.focus?.segment.tint ?? .accentColor)
                    .ignoresSafeArea()
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

    /// The date and the clock with the gear beside them, and under them the
    /// name and the weather on the strip of open sky.
    private func header(profile: Profile, isDay: Bool) -> some View {
        VStack(alignment: .leading, spacing: Self.spacing) {
            DateHeader()
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .bottomTrailing) {
                    Button {
                        openSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.body.weight(.medium))
                            .frame(width: 38, height: 38)
                            .contentShape(.circle)
                    }
                    .buttonStyle(.plain)
                    .glassEffect(.regular.interactive(), in: .circle)
                    .offset(y: 6)
                    .help("Settings")
                    .accessibilityLabel("Settings")
                }
            SkyStrip(profile: profile, weather: weather.current, isDay: isDay) {
                model.editing = true
            }
            .onGeometryChange(for: CGRect.self) { proxy in
                proxy.frame(in: .global)
            } action: { frame in
                skyWindow = frame
            }
        }
    }

    /// What is behind the page: the sky when the weather is known, and
    /// otherwise a wash of the colour of whatever is on.
    @ViewBuilder
    private func backdrop(_ scene: SkyScene?, tint: Color) -> some View {
        if let scene {
            PixelSky(scene: scene, window: skyWindow)
        } else {
            LinearGradient(colors: [tint.opacity(0.28), .clear], startPoint: .top, endPoint: .center)
                .background(Color.plainBackground)
        }
    }
}
