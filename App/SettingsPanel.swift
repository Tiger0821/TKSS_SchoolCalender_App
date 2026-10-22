import SwiftUI

/* Settings: everything that isn't the day itself — the Lock Screen switch,
   whose timetable this is, how the page and the widgets work, and where the
   timetable, the holidays and the weather come from.

   It is a page of its own, kept off the right-hand edge of the screen so the
   day's page has nothing on it but the day. Swipe in from that edge, or tap
   the gear, and it slides across; swipe back from the left edge, or tap the
   arrow, and it goes. ContentView does the sliding. */
struct SettingsPanel: View {
    let profile: Profile
    /// Open setup again, to change the name, the form or the classes.
    let edit: () -> Void
    let close: () -> Void
    @AppStorage("boxOrder") private var savedOrder = ""
    @AppStorage("classReminders") private var reminders = true

    var body: some View {
        // its own clock, for the Lock Screen switch's status
        TimelineView(.everyMinute) { context in
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    HStack(spacing: 14) {
                        Button(action: close) {
                            Image(systemName: "chevron.left")
                                .font(.body.weight(.semibold))
                                .frame(width: 44, height: 44)
                                .background(Color(.secondarySystemGroupedBackground), in: .circle)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Back to the timetable")
                        Text("Settings")
                            .font(.largeTitle.weight(.bold))
                    }

                    SettingsSection("Lock Screen", symbol: "lock.iphone") {
                        LockScreenSettings(now: context.date)
                    }

                    SettingsSection("Reminders", symbol: "bell.badge") {
                        Toggle(isOn: $reminders) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Before each class")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("15 minutes and 5 minutes ahead")
                            }
                        }
                        .onChange(of: reminders) { TimetableApp.remind() }
                        Text("With Timetable open once on a paired Apple Watch, the watch sends them and taps your wrist. Otherwise the phone does, and passes them to the watch while it is locked.")
                    }

                    SettingsSection("ManageBac", symbol: "checklist") {
                        ManageBacSettings()
                        Text("Tap a class in the day's list to see its homework. Timetable reads what's set from your ManageBac, signed in as you.")
                    }

                    SettingsSection("You", symbol: "person.crop.circle") {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.name.isEmpty ? "Your timetable" : profile.name)
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.primary)
                                Text("\(profile.form) · \(profile.subjects.count) classes")
                            }
                            Spacer()
                            Button("Change", action: edit)
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.tint)
                        }
                        Text("Your form, your classes and your clubs. Tapping your name under the clock opens this too.")
                    }

                    SettingsSection("The page", symbol: "rectangle.3.group") {
                        Text("Touch and hold a box to move it; the others make room, and the order is kept. Hold it at the top or bottom of the screen to scroll.")
                        if Box.order(from: savedOrder) != Box.allCases {
                            Divider()
                            Button("Put the boxes back as they came") {
                                withAnimation(.snappy) { savedOrder = "" }
                            }
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.tint)
                        }
                    }

                    SettingsSection("Widgets", symbol: "square.grid.2x2") {
                        Text("Touch and hold the Home Screen or Lock Screen, tap Edit, then Add Widget, and search for Timetable.")
                    }

                    SettingsSection("Sources", symbol: "book.closed") {
                        Link(destination: Timetable.source) {
                            Label("Prime Timetable", systemImage: "arrow.up.right.square")
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        Text("Read from the school's published timetable on \(TimetableData.readOn) (\(TimetableData.edition)). Week 2 is the week of Mon 7 Sep; the rest alternate.")
                        Divider()
                        Text("Holidays are Taiwan's national holidays from the government office calendars for 2026 and 2027.")
                        Divider()
                        Link(destination: URL(string: "https://open-meteo.com/")!) {
                            Label("Weather data by Open-Meteo.com", systemImage: "arrow.up.right.square")
                        }
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.tint)
                        Text("The sky behind the page is the weather near where the phone is, looked up again every ten minutes.")
                    }
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }
}

/// A titled box of settings.
struct SettingsSection<Content: View>: View {
    let title: String
    let symbol: String
    @ViewBuilder var content: Content

    init(_ title: String, symbol: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.symbol = symbol
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.footnote.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
            VStack(alignment: .leading, spacing: 12) {
                content
            }
            // the explanations are the small grey print; titles, switches
            // and buttons say so themselves
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        }
    }
}

/* A swipe in from one edge of the screen, reporting how far the finger has
   come and how fast it is going. It is UIKit's own edge recogniser, the one
   behind the swipe back in every navigation stack: it only answers to a
   touch that starts at the edge, so scrolling the page, and holding a box to
   move it, are left alone. */
struct EdgeSwipe: UIGestureRecognizerRepresentable {
    let edge: UIRectEdge
    /// The state, then the distance and the speed across the screen, in
    /// points and points a second, to the right being positive.
    let action: (UIGestureRecognizer.State, CGFloat, CGFloat) -> Void

    func makeUIGestureRecognizer(context: Context) -> UIScreenEdgePanGestureRecognizer {
        let recognizer = UIScreenEdgePanGestureRecognizer()
        recognizer.edges = edge
        return recognizer
    }

    func handleUIGestureRecognizerAction(_ recognizer: UIScreenEdgePanGestureRecognizer, context: Context) {
        action(recognizer.state, recognizer.translation(in: recognizer.view).x, recognizer.velocity(in: recognizer.view).x)
    }
}
