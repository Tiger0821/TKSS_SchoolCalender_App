import ServiceManagement
import SwiftUI

/* Settings, as a Mac has them: a window of its own off the app menu (⌘,),
   or the gear that comes out of the person at the top of the timetable's
   window. What is behind the page, the sky or glass, and how frosted the
   glass is; whose timetable it is, ManageBac for the homework, the menu
   bar's class and opening at login, the reminders, how to put the widgets
   on the desktop, and where the timetable, the holidays and the weather
   come from. */
struct MacSettings: View {
    @Environment(MacModel.self) private var model
    @Environment(\.openWindow) private var openWindow
    @AppStorage(MenuBarClass.shownKey) private var inMenuBar = true
    @AppStorage("classReminders") private var reminders = true
    @AppStorage(MacBackdrop.key) private var backdrop = MacBackdrop.sky
    @AppStorage(MacBackdrop.clearKey) private var clear = MacBackdrop.clearDefault
    @AppStorage(MacBackdrop.blurKey) private var blur = MacBackdrop.blurDefault
    /// This window, to step out of the way while a glass slider is dragged,
    /// and the slider's lone copy that stays meanwhile.
    @State private var window: NSWindow?
    @State private var floating = FloatingSlider()
    /// Where each slider's end words are on screen, for the copy to go over it.
    @State private var clearEnds = (ScreenAnchor(), ScreenAnchor())
    @State private var blurEnds = (ScreenAnchor(), ScreenAnchor())
    /// Whether the system opens Timetable at login. It is the system's to
    /// say, and is read back from it after each change.
    @State private var opensAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section("Appearance") {
                BackdropChooser(selection: $backdrop)
                if backdrop == .glass {
                    // the window follows each as it is dragged, and Settings goes out of the way meanwhile
                    Slider(value: $clear, in: 0...1) {
                        Text("Transparency")
                    } minimumValueLabel: {
                        sliderEnd(GlassSlider.clear.low, .trailing, clearEnds.0)
                    } maximumValueLabel: {
                        sliderEnd(GlassSlider.clear.high, .leading, clearEnds.1)
                    } onEditingChanged: { stepAside($0, .clear) }
                    // a click left a focus ring round the end word
                    .focusEffectDisabled()
                    Slider(value: $blur, in: 0...1) {
                        Text("Blur")
                    } minimumValueLabel: {
                        sliderEnd(GlassSlider.blur.low, .trailing, blurEnds.0)
                    } maximumValueLabel: {
                        sliderEnd(GlassSlider.blur.high, .leading, blurEnds.1)
                    } onEditingChanged: { stepAside($0, .blur) }
                    .focusEffectDisabled()
                }
                Text(backdrop == .sky
                     ? "The weather outside as pixel art, the sun or the moon, the clouds and the rain, as on the iPhone."
                     : "The window becomes a pane of glass that the desktop and the windows behind it shine through. Transparency is how much of them comes through, and Blur how soft they are. With Reduce Transparency on in Accessibility, the glass stays solid.")
                    .settingsNote()
            }

            Section("You") {
                LabeledContent {
                    Button(model.profile == nil ? "Set Up…" : "Change…") {
                        if model.profile != nil { model.editing = true }
                        openWindow(id: MacPage.window)
                    }
                } label: {
                    if let profile = model.profile {
                        Text(profile.name.isEmpty ? "Your timetable" : profile.name)
                        Text("\(profile.form) · \(profile.subjects.count) classes")
                    } else {
                        Text("Not set up yet")
                    }
                }
                Text("Your form, your classes and your clubs. Clicking the person at the top of the timetable's window opens this too. The Mac keeps its own: what is picked on the iPhone or the Apple Watch does not come across.")
                    .settingsNote()
            }

            Section("ManageBac") {
                ManageBacSettings()
                Text("Click a class in the day's list to see its homework. Timetable reads what's set from your ManageBac, signed in as you.")
                    .settingsNote()
            }

            Section("Menu bar") {
                Toggle(isOn: $inMenuBar) {
                    Text("Show the class that's on")
                    Text("Its name and the minutes left, as the iPhone's Dynamic Island has them. Click it for the rest.")
                }
                Toggle(isOn: $opensAtLogin) {
                    Text("Open at login")
                    Text("So the menu bar and the reminders are there from the start of the day.")
                }
                .onChange(of: opensAtLogin) { _, on in
                    let service = SMAppService.mainApp
                    try? on ? service.register() : service.unregister()
                    // the system may want it allowed in System Settings first
                    let now = service.status == .enabled
                    if now != on { opensAtLogin = now }
                }
                Text("With the window closed, Timetable keeps going in the menu bar. Quit it from there.")
                    .settingsNote()
            }

            Section("Reminders") {
                Toggle(isOn: $reminders) {
                    Text("Before each class")
                    Text("15 minutes and 5 minutes ahead")
                }
                .onChange(of: reminders) { model.settle() }
                Text("The Mac lays its own down some four school days ahead, and tops them up each day Timetable is running. The iPhone and the Apple Watch send theirs as well.")
                    .settingsNote()
            }

            Section("Widgets") {
                Text("Right-click the desktop, choose Edit Widgets, and search for Timetable: Now & Next, Today, and Holiday Countdown.")
                    .settingsNote()
            }

            Section("Sources") {
                Link(destination: Timetable.source) {
                    Label("Prime Timetable", systemImage: "arrow.up.right.square")
                }
                Text("Read from the school's published timetable on \(TimetableData.readOn) (\(TimetableData.edition)). Week 2 is the week of Mon 7 Sep; the rest alternate.")
                    .settingsNote()
                Text("Holidays are Taiwan's national holidays from the government office calendars for 2026 and 2027.")
                    .settingsNote()
                Link(destination: URL(string: "https://open-meteo.com/")!) {
                    Label("Weather data by Open-Meteo.com", systemImage: "arrow.up.right.square")
                }
                Text("The sky behind the page is the weather near where the Mac is, looked up again every ten minutes while the window is open.")
                    .settingsNote()
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .frame(minHeight: 520, idealHeight: 720)
        .onAppear { opensAtLogin = SMAppService.mainApp.status == .enabled }
        .background(WindowReader { window = $0 })
        // ManageBac's sign-in page comes up over the timetable's window
        .onChange(of: Homework.shared.signingIn) { _, signingIn in
            if signingIn { openWindow(id: MacPage.window) }
        }
    }
}

extension MacSettings {
    /* While a glass slider is being dragged, Settings fades out of the way,
       so the timetable's window behind it can be seen as the glass changes,
       and the slider alone stays where it was: a copy of it, on glass of its
       own, moving as the drag moves the setting. The drag itself carries on
       in the faded window, the pointer still on the slider. Let go, and the
       copy goes and Settings comes back. */
    private func stepAside(_ dragging: Bool, _ slider: GlassSlider) {
        if dragging {
            let ends = slider == .clear ? clearEnds : blurEnds
            floating.show(slider, over: ends.0, to: ends.1)
        } else {
            floating.hide()
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = dragging ? 0.18 : 0.25
            window?.animator().alphaValue = dragging ? 0 : 1
        }
    }
}

/// The two glass sliders: what each sets, and the words at its ends.
private enum GlassSlider {
    case clear, blur

    var key: String { self == .clear ? MacBackdrop.clearKey : MacBackdrop.blurKey }
    var initial: Double { self == .clear ? MacBackdrop.clearDefault : MacBackdrop.blurDefault }
    var low: String { self == .clear ? "Solid" : "Sharp" }
    var high: String { self == .clear ? "Clear" : "Soft" }
}

/* The slider that stays while Settings is out of the way: a window of its
   own over everything, clear but for the slider on a capsule of glass,
   which the pointer goes through to the real slider under it. It is laid
   from the real one's end words to each other, the same words at the same
   width, so its track and its knob sit where the real ones are. */
@MainActor
private final class FloatingSlider {
    private var panel: NSPanel?
    private var shown = false
    private static let pad = NSSize(width: 18, height: 12)

    func show(_ slider: GlassSlider, over low: ScreenAnchor, to high: ScreenAnchor) {
        guard let from = low.frame, let to = high.frame else { return }
        let span = from.union(to)
        let panel = self.panel ?? Self.makePanel()
        self.panel = panel
        panel.contentView = NSHostingView(rootView: LoneSlider(slider: slider, width: span.width, pad: Self.pad))
        panel.setFrame(span.insetBy(dx: -Self.pad.width, dy: -Self.pad.height), display: false)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        shown = true
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard let panel else { return }
        shown = false
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        } completionHandler: {
            // unless a slider has been picked up again in the meantime
            MainActor.assumeIsolated {
                if !self.shown { panel.orderOut(nil) }
            }
        }
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        return panel
    }
}

/// The copy itself, following the setting as the real slider changes it.
private struct LoneSlider: View {
    let slider: GlassSlider
    let width: CGFloat
    let pad: NSSize
    @AppStorage private var value: Double

    init(slider: GlassSlider, width: CGFloat, pad: NSSize) {
        self.slider = slider
        self.width = width
        self.pad = pad
        _value = AppStorage(wrappedValue: slider.initial, slider.key)
    }

    var body: some View {
        Slider(value: $value, in: 0...1) {
            EmptyView()
        } minimumValueLabel: {
            sliderEnd(slider.low, .trailing)
        } maximumValueLabel: {
            sliderEnd(slider.high, .leading)
        }
        .labelsHidden()
        .focusEffectDisabled()
        .frame(width: width)
        .padding(.horizontal, pad.width)
        .padding(.vertical, pad.height)
        .glassEffect(.regular, in: .capsule)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Where a view is on screen, read when it is wanted.
@MainActor
final class ScreenAnchor {
    fileprivate weak var view: NSView?

    var frame: NSRect? {
        guard let view, let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }
}

private struct AnchorView: NSViewRepresentable {
    let anchor: ScreenAnchor

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        anchor.view = view
    }
}

/// Hands over the window a view is in, once it is in one.
private struct WindowReader: NSViewRepresentable {
    let found: (NSWindow) -> Void

    func makeNSView(context: Context) -> Reader { Reader(found: found) }

    func updateNSView(_ view: Reader, context: Context) {}

    final class Reader: NSView {
        let found: (NSWindow) -> Void

        init(found: @escaping (NSWindow) -> Void) {
            self.found = found
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { fatalError("made in code") }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            if let window { found(window) }
        }
    }
}

/// A slider's end word, as wide as the others, so the two sliders' tracks
/// start and end level; and marked, for the floating copy to find.
@ViewBuilder
private func sliderEnd(_ word: String, _ alignment: Alignment, _ anchor: ScreenAnchor? = nil) -> some View {
    let end = Text(word).frame(width: 40, alignment: alignment)
    if let anchor {
        end.background(AnchorView(anchor: anchor))
    } else {
        end
    }
}

private extension View {
    /// The small grey print under a setting.
    func settingsNote() -> some View {
        font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
