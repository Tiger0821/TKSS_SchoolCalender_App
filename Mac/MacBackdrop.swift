import AppKit
import SwiftUI

/* What is behind the Mac's page, picked in Settings: the weather outside as
   pixel art, as on the phone, or Liquid Glass — the window itself a pane of
   glass that the desktop and the windows behind it show through, with the
   boxes on it Liquid Glass.

   The glass has two sliders, as the person asked: how see-through it is,
   and how blurred what is behind it is. Apple's glass comes only clear or
   frosted, and fading one into the other left a sharp ghost of the desktop
   under a blurred one; so the blur is the system's own behind-window blur,
   its strength set by hand (`BackdropBlur`), and the window's own colour is
   laid over it as solid as the first slider says. Clear Liquid Glass over
   the lot, for the bend at the window's edges, is gone: macOS draws glass
   brighter in the window in front and darker in one behind, so with
   Settings open over the window the glass being set there was only ever
   seen darker than it would be. The header is on the same glass
   as the rest: a band of blur and colour of its own behind it dimmed the top
   of the window, and the person would rather set the glass with the two
   sliders alone. With Reduce Transparency on, the glass is solid. */
enum MacBackdrop: String, CaseIterable, Identifiable {
    case sky, glass

    var id: Self { self }

    var title: String {
        switch self {
        case .sky: "Weather Sky"
        case .glass: "Liquid Glass"
        }
    }

    static let key = "macBackdrop"
    /// How see-through the glass is, from 0, solid, to 1, clear.
    static let clearKey = "macGlassClear"
    static let clearDefault = 0.5
    /// How blurred what is behind it is, from 0, sharp, to 1, soft.
    static let blurKey = "macGlassBlur"
    static let blurDefault = 0.7

    /* The blur's radius in points for the slider's 0 to 1, so that the
       slider's steps look even. Measured over a desktop-like picture —
       small text over big blocks of colour — at 22 radii: how much fine
       detail and how much of the big shapes came through, each on a log
       scale as the eye takes it, and the two averaged. Each tenth of the
       slider takes away a tenth of that. Measured over text alone, as it
       was at first, the curve had the text gone by four fifths of the way
       and left the big shapes, most of what a desktop is, to change all at
       once in the last fifth. */
    private static let blurSteps: [CGFloat] = [0, 1.6, 4.1, 5.9, 9.9, 13.6, 17.7, 23.5, 34, 53, 72]

    static func blurRadius(_ blur: Double) -> CGFloat {
        let at = CGFloat(min(1, max(0, blur))) * CGFloat(blurSteps.count - 1)
        let below = Int(at.rounded(.down)), above = min(below + 1, blurSteps.count - 1)
        return blurSteps[below] + (blurSteps[above] - blurSteps[below]) * (at - CGFloat(below))
    }
}

/// The window as one pane of glass, its corners the window's own.
struct GlassPane: View {
    let clear: Double
    let blur: Double
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        let clear = reduceTransparency ? 0 : min(1, max(0, clear))
        let radius = MacBackdrop.blurRadius(blur)
        ZStack {
            // at no blur, none at all: what is behind comes through crisp
            if radius >= 0.5 {
                BackdropBlur(radius: radius)
            }
            // toward solid, the window's own colour: dark in Dark Mode, light in Light
            Color(nsColor: .windowBackgroundColor)
                .opacity(1 - clear)
        }
        .clipShape(ConcentricRectangle())
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/* The system's own behind-window blur, the one under a HUD, with its
   strength set here. AppKit gives it no strength to set: the blur is a
   gaussian filter on a backdrop layer the view keeps, and the strength is
   that filter's radius, set again whenever the view may have built its
   layers anew. The layer takes in what is behind the window at an eighth of
   its size, which is plenty for a heavy blur but smeared a light one into a
   grey haze; so the lighter the blur, the finer it is taken in, up to full
   size. Spread over only three of the pixels taken in, the blur showed
   their blocks, a mosaic that shimmered over a video behind the window;
   over eight it is smeared evenly, as frosted glass is. And the layer's
   scale counts what it takes in to a point, not to a pixel: at 1, its
   "whole", it took in half of what a Retina screen shows, and a light blur
   turned fine lines into stairs of two-pixel blocks. So the finest is the
   screen's own (2 on a Retina screen), and the blur spreads over at least
   sixteen of what is taken in. The blur is also
   set finer than the system's own (high quality, dithered, in linear
   light), and the system's colour boost after it, half again as strong,
   taken off: side by side, these blurred evenly where the system's own
   left soft blotches, in colours that looked daubed on. The view's own fill and tone are hidden, as the page lays its own
   colour over it. Were a later macOS to name these differently,
   the blur would keep the system's own strength and tint. */
struct BackdropBlur: NSViewRepresentable {
    let radius: CGFloat

    func makeNSView(context: Context) -> BlurView { BlurView() }

    func updateNSView(_ view: BlurView, context: Context) { view.radius = radius }

    final class BlurView: NSVisualEffectView {
        var radius: CGFloat = 0 {
            didSet { if radius != oldValue { tune() } }
        }

        init() {
            super.init(frame: .zero)
            blendingMode = .behindWindow
            material = .hudWindow
            // the same whether the window is in front or not
            state = .active
        }

        required init?(coder: NSCoder) { fatalError("made in code") }

        override func layout() {
            super.layout()
            tune()
        }

        override func updateLayer() {
            super.updateLayer()
            tune()
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            tune()
            // the view finishes its layers after it is in the window
            DispatchQueue.main.async { self.tune() }
        }

        override func viewDidChangeEffectiveAppearance() {
            super.viewDidChangeEffectiveAppearance()
            DispatchQueue.main.async { self.tune() }
        }

        // moved to a screen of another resolution
        override func viewDidChangeBackingProperties() {
            super.viewDidChangeBackingProperties()
            tune()
        }

        private func tune() {
            guard let layer else { return }
            tune(layer)
        }

        private func tune(_ layer: CALayer) {
            if String(describing: type(of: layer)) == "CABackdropLayer" {
                /* Set inside the filters the layer already has, by key path, and never by handing it
                   a new set: handed new filters, the layer kept them, but the screen went on showing
                   the blur it had until the changes stopped for a while — a slider being dragged
                   never showed, and the window opened on the system's own blur for half a minute. */
                let names = Set((layer.filters ?? []).compactMap { ($0 as AnyObject).value(forKey: "name") as? String })
                if names.contains("gaussianBlur") {
                    layer.setValue(radius, forKeyPath: "filters.gaussianBlur.inputRadius")
                    // finer than the system's own, with the steps of a soft fade dithered away, and the
                    // colours mixed in linear light, as frosted glass mixes them
                    layer.setValue("high", forKeyPath: "filters.gaussianBlur.inputQuality")
                    layer.setValue(true, forKeyPath: "filters.gaussianBlur.inputDither")
                    layer.setValue(true, forKeyPath: "filters.gaussianBlur.inputLinear")
                }
                if names.contains("colorSaturate") {
                    // the colours as they are: the system's half again more made the blur look daubed on
                    layer.setValue(1.0, forKeyPath: "filters.colorSaturate.inputAmount")
                }
                // taken in at the screen's own resolution for a light blur — two to a point on a Retina
                // screen — and more coarsely for a heavier one, always at least sixteen to the blur's
                // radius; in halvings only, so a drag doesn't have the layer start afresh at every step
                let finest = window?.backingScaleFactor ?? 2
                let wanted = min(finest, max(0.125, 16 / max(radius, 0.5)))
                let scale = wanted >= finest ? finest : max(0.125, pow(2, log2(wanted).rounded(.down)))
                if (layer.value(forKey: "scale") as? CGFloat) != scale {
                    layer.setValue(scale, forKey: "scale")
                }
            }
            if ["fill", "tone", "desktop tint"].contains(layer.name ?? "") {
                layer.isHidden = true
            }
            layer.sublayers?.forEach(tune)
        }
    }
}

/* Makes the window see-through, for the glass to show what is behind it,
   and opaque again for the sky. A window's own background is drawn under
   everything SwiftUI puts in it, so it is the window that has to be told. */
struct SeeThroughWindow: NSViewRepresentable {
    let isOn: Bool

    func makeNSView(context: Context) -> Watcher { Watcher() }

    func updateNSView(_ view: Watcher, context: Context) {
        view.isOn = isOn
        view.apply()
    }

    final class Watcher: NSView {
        var isOn = false

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        func apply() {
            guard let window, window.isOpaque == isOn else { return }
            window.isOpaque = !isOn
            window.backgroundColor = isOn ? .clear : .windowBackgroundColor
            // the shadow follows what is drawn, which has just changed
            window.invalidateShadow()
        }
    }
}

/* The choice in Settings, as System Settings shows Light and Dark: a small
   picture of each, ringed in the accent colour when it is the one, and its
   name under it. The sky's is painted by the sky's own painter; the glass's
   is real glass over a wash of colour. */
struct BackdropChooser: View {
    @Binding var selection: MacBackdrop

    var body: some View {
        HStack(spacing: 18) {
            ForEach(MacBackdrop.allCases) { backdrop in
                let chosen = backdrop == selection
                Button {
                    withAnimation(.snappy) { selection = backdrop }
                } label: {
                    VStack(spacing: 7) {
                        BackdropPreview(backdrop: backdrop)
                            .frame(width: 118, height: 76)
                            .clipShape(.rect(cornerRadius: 10))
                            .overlay {
                                RoundedRectangle(cornerRadius: 10)
                                    .strokeBorder(.primary.opacity(0.12), lineWidth: 1)
                            }
                            .padding(3)
                            .overlay {
                                RoundedRectangle(cornerRadius: 13)
                                    .strokeBorder(Color.accentColor, lineWidth: 3)
                                    .opacity(chosen ? 1 : 0)
                            }
                        Text(backdrop.title)
                            .font(.callout.weight(chosen ? .semibold : .regular))
                            .foregroundStyle(chosen ? .primary : .secondary)
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .focusEffectDisabled()
                .accessibilityLabel(backdrop.title)
                .accessibilityAddTraits(chosen ? .isSelected : [])
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

private struct BackdropPreview: View {
    let backdrop: MacBackdrop
    /// A partly cloudy afternoon, painted once.
    @State private var sky: CGImage?

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch backdrop {
            case .sky:
                if let sky {
                    Image(decorative: sky, scale: 1)
                        .interpolation(.none)
                        .resizable()
                } else {
                    Color(red: 0.36, green: 0.6, blue: 0.86)
                }
            case .glass:
                // a desktop's wash of colour, and the window over it as a pane of glass
                LinearGradient(colors: [Color(red: 0.98, green: 0.62, blue: 0.38), Color(red: 0.86, green: 0.36, blue: 0.62),
                                        Color(red: 0.36, green: 0.42, blue: 0.9)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RoundedRectangle(cornerRadius: 8)
                    .fill(.clear)
                    .glassEffect(.regular, in: .rect(cornerRadius: 8))
                    .padding(9)
            }
            page
        }
        .task {
            guard backdrop == .sky, sky == nil else { return }
            sky = SkyPainter(scene: SkyScene(sky: .partlyCloudy, phase: .day, wind: 12),
                             width: 59, height: 38, bodyX: 47, bodyY: 9, cloudTop: 6, still: true)
                .paint(at: 120).image
        }
    }

    /// The page in miniature: the date, and two boxes under it.
    private var page: some View {
        let ink: Color = backdrop == .sky ? .white : .white.opacity(0.9)
        return VStack(alignment: .leading, spacing: 4) {
            Capsule().fill(ink).frame(width: 30, height: 5)
            Capsule().fill(ink.opacity(0.6)).frame(width: 20, height: 3)
            HStack(alignment: .top, spacing: 4) {
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.28)).frame(height: 30)
                RoundedRectangle(cornerRadius: 4).fill(.white.opacity(0.28)).frame(height: 40)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, backdrop == .glass ? 16 : 9)
        .padding(.top, backdrop == .glass ? 15 : 9)
    }
}
