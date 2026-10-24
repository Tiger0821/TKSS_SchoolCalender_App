import SwiftUI

/* When before a class to be reminded, on the phone and the Mac: up to
   three times, each on a wheel of its own side by side, as the Clock app's
   timer sets its hours, minutes and seconds. Each turns from Off through a
   minute to an hour. What the wheels are set to is kept as soon as one
   stops, latest first and each only once (`ClassReminders`), and `changed`
   lays the reminders down again. */
struct ReminderTimes: View {
    let changed: () -> Void
    @AppStorage(ClassReminders.leadsKey) private var saved = ClassReminders.standard
    /// The three wheels, 0 for Off.
    @State private var wheels = [Int](repeating: 0, count: ClassReminders.choices)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(wheels.indices, id: \.self) { index in
                MinuteWheel(minutes: Binding {
                    wheels[index]
                } set: { minutes in
                    wheels[index] = minutes
                    keep()
                })
            }
        }
        .onAppear {
            let kept = ClassReminders.parse(saved)
            wheels = kept + [Int](repeating: 0, count: ClassReminders.choices - kept.count)
        }
    }

    private func keep() {
        let text = ClassReminders.parse(wheels.map(String.init).joined(separator: ",")).map(String.init).joined(separator: ",")
        guard text != saved else { return }
        saved = text
        changed()
    }
}

#if os(iOS)
/// One of the wheels: the phone's own, as the Clock app has it.
private struct MinuteWheel: View {
    @Binding var minutes: Int

    var body: some View {
        Picker("Minutes before", selection: $minutes) {
            Text("Off").tag(0)
            ForEach(1...60, id: \.self) { minute in
                Text("\(minute) min").tag(minute)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxWidth: .infinity)
        .frame(height: 150)
        // side by side, each wheel keeps to its own third: left to itself it takes touches
        // across the others'
        .compositingGroup()
        .clipped()
        .contentShape(.rect)
    }
}
#else
/* One of the wheels, drawn on the Mac, which has none of its own: the
   phone's, as near as can be. Five rows show; the one in the middle, on a
   band, is what is picked, and the rows above and below it lean away and
   fade, as if round a drum. Scrolled, it comes to rest on a row; a row
   clicked turns to the middle. */
private struct MinuteWheel: View {
    @Binding var minutes: Int
    @State private var centred: Int?

    private static let row: CGFloat = 30
    private static let values = [0] + Array(1...60)

    var body: some View {
        ScrollView(.vertical) {
            LazyVStack(spacing: 0) {
                ForEach(Self.values, id: \.self) { value in
                    Text(value == 0 ? "Off" : "\(value) min")
                        .font(.title3.monospacedDigit())
                        .frame(maxWidth: .infinity, minHeight: Self.row, maxHeight: Self.row)
                        .contentShape(.rect)
                        .onTapGesture { withAnimation(.snappy) { centred = value } }
                        // round the drum: the further from the middle, the more it leans away and fades
                        .visualEffect { content, proxy in
                            // the row's place in what shows of the wheel, which starts at its top; the
                            // wheel's own bounds start where it has been scrolled to, and measured from
                            // them the rows turned right over
                            let height = proxy.bounds(of: .scrollView)?.height ?? 0
                            let frame = proxy.frame(in: .scrollView)
                            let off = height > 0 ? max(-1, min(1, (frame.midY - height / 2) / (height / 2))) : 0
                            let away = abs(off)
                            return content
                                .rotation3DEffect(.degrees(Double(-off) * 40), axis: (x: 1, y: 0, z: 0), perspective: 0.4)
                                .scaleEffect(1 - away * 0.05)
                                .opacity(1 - away * 0.6)
                        }
                        .id(value)
                }
            }
            .scrollTargetLayout()
        }
        // room above the first row and below the last, so either can come to the middle
        .contentMargins(.vertical, Self.row * 2, for: .scrollContent)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $centred, anchor: .center)
        .scrollIndicators(.never)
        .frame(height: Self.row * 5)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(.quaternary)
                .frame(height: Self.row)
        }
        .onAppear { centred = minutes }
        .onChange(of: centred) { _, value in
            if let value, value != minutes { minutes = value }
        }
        .onChange(of: minutes) { _, value in
            if centred != value { centred = value }
        }
    }
}
#endif
