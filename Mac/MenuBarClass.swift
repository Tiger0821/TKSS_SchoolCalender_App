import SwiftUI

/* The class that is on, in the menu bar: what the phone's Dynamic Island
   says, said on the Mac. In a class it is the class's name and the minutes
   left of it ("Econ 14 min"), to the end of a double period where it is one.
   The name is the short one the page uses, not the island's few letters:
   there is room for it here, and the island's run out at the subjects it
   was made for.
   In a short break it names the class to come and the time it starts, and
   so it does before the first bell. Out of school hours it is only its mark.

   Clicked, it opens a panel with the phone's Now box in it, and the ways to
   the window, to Settings, and out. */
enum MenuBarClass {
    /// Whether it is in the menu bar; a switch in Settings.
    static let shownKey = "menuBarClass"

    /// What the menu bar says at `now`: a symbol, and the words after it,
    /// if there are any.
    static func title(at now: Date) -> (symbol: String, text: String?) {
        let day = Timetable.day(of: now)
        guard Timetable.profile != nil, let first = day.first, let last = day.last, now < last.end else {
            return ("graduationcap", nil)
        }
        guard let index = day.firstIndex(where: { $0.contains(now) }) else {
            // before the first bell: the first class and when it starts
            let lesson = day.first(where: \.segment.isLesson) ?? first
            return ("sunrise", "\(lesson.segment.shortTitle) \(Timetable.hhmm(lesson.start))")
        }
        let block = day[index]
        if !block.segment.isLesson, block.end.timeIntervalSince(block.start) <= 15 * 60,
           let next = day.dropFirst(index + 1).first(where: \.segment.isLesson) {
            return (block.segment.symbol, "\(next.segment.shortTitle) \(Timetable.hhmm(next.start))")
        }
        // a double period is one class: the count runs to the end of its second half
        var end = block.end
        for later in day.dropFirst(index + 1) {
            guard later.start == end, later.segment.isLesson == block.segment.isLesson,
                  later.segment.title == block.segment.title else { break }
            end = later.end
        }
        let minutes = max(1, Int((end.timeIntervalSince(now) / 60).rounded(.up)))
        return (block.segment.symbol, "\(block.segment.shortTitle) \(minutes) min")
    }
}

/// The menu bar's few words. It goes by the model's minute, which turns over
/// with the bells.
struct MenuBarLabel: View {
    let model: MacModel

    var body: some View {
        let title = MenuBarClass.title(at: model.now)
        // the profile is read so that setup finishing redraws it
        let _ = model.profile
        HStack(spacing: 4) {
            Image(systemName: title.symbol)
            if let text = title.text {
                Text(text)
                    .monospacedDigit()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(title.text ?? "Timetable")
    }
}

/// What opens under it: the class that is on, as the page's Now box has it,
/// and the ways on.
struct MenuBarPanel: View {
    @Environment(MacModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.profile != nil {
                NowCard(snapshot: Timetable.snapshot(at: model.now), now: model.now)
            } else {
                Label("Open Timetable to say which classes are yours.", systemImage: "person.crop.circle.badge.questionmark")
                    .font(.callout)
                    .padding(8)
            }
            HStack(spacing: 8) {
                Button("Open Timetable") {
                    openWindow(id: MacPage.window)
                    NSApp.activate()
                }
                Spacer()
                Button {
                    NSApp.activate()
                    openSettings()
                } label: {
                    Image(systemName: "gearshape")
                }
                .help("Settings")
                .accessibilityLabel("Settings")
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                }
                .help("Quit Timetable")
                .accessibilityLabel("Quit Timetable")
            }
            .buttonStyle(.glass)
            .controlSize(.large)
        }
        .padding(12)
        .frame(width: 340)
    }
}
