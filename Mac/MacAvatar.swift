import AppKit
import SwiftUI

/* The person in the header, come to life as the Mac's own login picture
   does when it is a Memoji. Apple draws that with a framework of its own
   that apps are not given, so this is the same manner in the person's own
   lines: the ring, the head and the shoulders of the symbol it was, with
   the Face ID symbol's face cut out of the head (two eyes, a nose that
   turns at its foot and a smile) for the glass to show through.

   - It looks at the pointer while the pointer is on its window, and
     Timetable is the app in use: the face most, the head after it, the
     shoulders hardly at all, so it seems to turn. Anywhere else it leaves
     the pointer alone: following it across another app, or the screenshot
     tool's shading, it had the window drawn again a hundred and twenty
     times a second, and the shading dragged behind the pointer.
   - It blinks, every few seconds, now and then twice.
   - Left alone for a minute, it dozes off, head down and eyes shut, with z's
     rising off it; the pointer moving or a key pressed wakes it with a
     start, eyes wide and a hop.
   - It opens its eyes when the window first comes up, and smiles wider
     while the pointer is on it.
   - Clicked, it nods. As at the login window, where a wrong password gets a
     shake of the head and a right one a grin, ManageBac turning a look away
     gets a shake of the head and a frown, and signing in again a grin.
   - Bored, with the pointer still for a while but not yet long enough to
     doze, and Timetable the app in use, it gets up to something, a different thing each time (`Trick`):
     it ducks out of sight and peeks in round one side of the ring and then
     the other, one eye showing, before popping back up (探頭); it climbs out
     over the top of the ring, hands first, sits on it with its legs
     dangling, and jumps back in (爬出來); or it slips out of the bottom of the
     ring, falls with its arms up and its mouth open to the bottom of the
     window, bounces, and is hauled back up on a thread, legs dangling and
     swinging, as a spider goes back up its own (掉下來，被吊回去).

   It is drawn on layers of its own, by a clock of its own (`AvatarEngine`),
   and SwiftUI only tells it what the page knows: how big it is, whether the
   pointer is on it, a click, ManageBac. Drawn by SwiftUI, every frame of it
   moving had the page laid out again, every box and every pane of glass:
   sixty per cent of a core while the pointer moved, where the app sat at
   five, enough to make taking a screenshot stutter. The sky's frames did
   the same before they were put on a layer (`SkyLayer`). */
struct Avatar: View {
    /// Across.
    let size: CGFloat
    /// The pointer is on it.
    let greeted: Bool
    /// The drop it is in is open into a capsule, with the name: no tricks then.
    let open: Bool
    /// One more each time it is clicked.
    let nods: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable private var homework = Homework.shared
    @State private var engine = AvatarEngine()

    var body: some View {
        AvatarStage(engine: engine, size: size, greeted: greeted, open: open, reduceMotion: reduceMotion)
            .frame(width: size, height: size)
            .onChange(of: nods) { engine.play(.nod) }
            .onChange(of: homework.status) { old, new in
                if new == .expired { engine.play(.shake) } else if new == .signedIn, old != .signedIn { engine.play(.grin) }
            }
            .onChange(of: homework.problem) { _, problem in
                if problem != nil { engine.play(.shake) }
            }
            .accessibilityHidden(true)
    }
}

private struct AvatarStage: NSViewRepresentable {
    let engine: AvatarEngine
    let size: CGFloat
    let greeted: Bool
    let open: Bool
    let reduceMotion: Bool

    func makeNSView(context: Context) -> AvatarView {
        engine.view
    }

    func updateNSView(_ view: AvatarView, context: Context) {
        engine.update(size: size, greeted: greeted, open: open, reduceMotion: reduceMotion)
    }

    static func dismantleNSView(_ view: AvatarView, coordinator: ()) {
        view.engine?.detach()
    }
}

/// Where the person is drawn: never what a click lands on, which goes to the button it is in.
final class AvatarView: NSView {
    weak var engine: AvatarEngine?

    init(engine: AvatarEngine) {
        self.engine = engine
        super.init(frame: .zero)
        wantsLayer = true
        // the person gets out of the ring, and far out of this
        clipsToBounds = false
        layer?.masksToBounds = false
        setAccessibilityElement(false)
    }

    required init?(coder: NSCoder) { fatalError("made in code") }

    // from the top left, as the person is drawn
    override var isFlipped: Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { engine?.detach() } else { engine?.attach() }
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        engine?.rescale()
    }

    /// From its middle down to the bottom of the window, in points.
    var floor: CGFloat? {
        guard window != nil else { return nil }
        return convert(CGPoint(x: bounds.midX, y: bounds.midY), to: nil).y
    }
}

/// How a number of the drawing goes to where it is sent: on a spring, as
/// SwiftUI's own are measured, or along a curve.
enum Curve {
    case spring(Double, bounce: Double)
    case easeIn(Double)
    case easeOut(Double)
    case easeInOut(Double)
    /// A cubic Bézier through (0, 0), the two points given and (1, 1), over a duration.
    case curve(Double, Double, Double, Double, duration: Double)
}

/* One number of the drawing, and how it is moving. On a spring it keeps
   its speed when it is sent somewhere new, so following the pointer, sent
   on thirty times a second, it never stops and starts; along a curve it
   goes from where it is to where it is sent in the time given. */
@MainActor
private final class Value {
    private(set) var now: CGFloat
    private var target: CGFloat
    private var speed: CGFloat = 0
    private var spring: (stiffness: CGFloat, damping: CGFloat)?
    private var tween: (from: CGFloat, start: CFTimeInterval, duration: CFTimeInterval, ease: (CGFloat) -> CGFloat)?
    /// Near enough to stop at.
    private let precision: CGFloat

    init(_ value: CGFloat, precision: CGFloat = 0.001) {
        now = value
        target = value
        self.precision = precision
    }

    var moving: Bool { spring != nil || tween != nil }

    func go(to value: CGFloat, _ curve: Curve?, at time: CFTimeInterval) {
        target = value
        spring = nil
        tween = nil
        switch curve {
        case nil:
            now = value
            speed = 0
        case .spring(let duration, let bounce)?:
            // as SwiftUI's: a mass of one
            spring = (pow(2 * .pi / duration, 2), 4 * .pi * (1 - bounce) / duration)
        case .easeIn(let duration)?:
            tween = (now, time, duration, Self.bezier(0.42, 0, 1, 1))
        case .easeOut(let duration)?:
            tween = (now, time, duration, Self.bezier(0, 0, 0.58, 1))
        case .easeInOut(let duration)?:
            tween = (now, time, duration, Self.bezier(0.42, 0, 0.58, 1))
        case .curve(let x1, let y1, let x2, let y2, let duration)?:
            tween = (now, time, duration, Self.bezier(x1, y1, x2, y2))
        }
    }

    /// Moves on to `time`, `step` after the last; whether it moved.
    func advance(to time: CFTimeInterval, by step: CFTimeInterval) -> Bool {
        let before = now
        if let tween {
            let done = tween.duration > 0 ? min(1, max(0, (time - tween.start) / tween.duration)) : 1
            now = tween.from + (target - tween.from) * tween.ease(done)
            speed = step > 0 ? (now - before) / step : 0
            if done >= 1 {
                now = target
                self.tween = nil
            }
        } else if let spring {
            var left = step
            while left > 0 {
                let part = min(left, 1.0 / 240)
                speed += (-spring.stiffness * (now - target) - spring.damping * speed) * part
                now += speed * part
                left -= part
            }
            if abs(now - target) < precision, abs(speed) < precision * 10 {
                now = target
                speed = 0
                self.spring = nil
            }
        }
        return now != before
    }

    /// How far along a cubic Bézier timing curve is, a part of the way through its time.
    private static func bezier(_ x1: Double, _ y1: Double, _ x2: Double, _ y2: Double) -> (CGFloat) -> CGFloat {
        func along(_ s: Double, _ a: Double, _ b: Double) -> Double {
            3 * (1 - s) * (1 - s) * s * a + 3 * (1 - s) * s * s * b + s * s * s
        }
        return { t in
            let t = Double(t)
            // the point on the curve whose x is t, halved in on
            var low = 0.0, high = 1.0, s = t
            for _ in 0..<24 {
                if along(s, x1, x2) < t { low = s } else { high = s }
                s = (low + high) / 2
            }
            return CGFloat(along(s, y1, y2))
        }
    }
}

/* The person: its numbers, the layers it is drawn on, its clock, and what
   it gets up to. The clock is the screen's own (`CADisplayLink`), running
   only while a number is moving; each frame the person's picture, a few
   dozen points across, is painted again and put on its layer, and where it
   is and how it leans are set on the layer, and SwiftUI is not told. */
@MainActor
final class AvatarEngine: NSObject {
    enum Cue { case hello, wake, nod, shake, grin }

    private enum Trick: CaseIterable { case peek, climb, fall }

    /// Whether the person can be seen outside the ring, and where.
    private enum Out { case no, over, under }

    private(set) lazy var view = AvatarView(engine: self)

    private var size: CGFloat = 0
    private var greeted = false
    private var open = false
    private var reduceMotion = false

    // where it looks, from -1 to 1 each way, toward the pointer
    private let lookX = Value(0)
    private let lookY = Value(0)
    private let blink = Value(0)
    /// 1 asleep: eyes shut, head down, looking down. Asleep until the
    /// window has been up a moment, as the login picture holds still at first.
    private let sleepy = Value(1)
    /// 1 while the pointer is on it: a wider smile.
    private let greet = Value(0)
    // a nod, a shake or a start, on top of the face as it is
    private let hop = Value(0, precision: 0.01)
    private let sway = Value(0, precision: 0.01)
    private let nod = Value(0, precision: 0.01)
    private let wide = Value(1)
    private let smile = Value(0)
    // where the person is, in its ring or out of it, and what its arms and legs are doing
    private let x = Value(0, precision: 0.05)
    private let y = Value(0, precision: 0.05)
    /// Degrees, clockwise.
    private let tilt = Value(0, precision: 0.05)
    /// 0 down by its sides, 1 up over its head.
    private let arms = Value(0)
    private let legs = Value(0)
    /// Its hands on the top of the ring, climbing out.
    private let hands = Value(0)
    private let thread = Value(0)
    /// Its mouth open, falling.
    private let gasp = Value(0)
    private lazy var values = [lookX, lookY, blink, sleepy, greet, hop, sway, nod, wide, smile,
                               x, y, tilt, arms, legs, hands, thread, gasp]
    private var out = Out.no
    /// Swinging on its thread, from and until.
    private var swing: (from: CFTimeInterval, until: CFTimeInterval)?
    /// How much further down than its own space the person can be seen, falling.
    private var drop: CGFloat = 0

    private var asleep = true
    /// When the pointer last moved or a key was last pressed.
    private var last = Date()
    private var handled = Date.distantPast
    /// Up to something now.
    private var busy = false
    /// Has got up to something since the pointer last moved.
    private var bored = false
    private var boredAfter = TimeInterval.random(in: 15...30)
    /// What it is yet to get up to, in a shuffled turn, so each comes round before any again.
    private var tricks: [Trick] = []

    private var tasks: [Task<Void, Never>] = []
    private var monitors: [Any] = []
    private var observers: [NSObjectProtocol] = []
    private var link: CADisplayLink?
    private var lastTick: CFTimeInterval?

    private let stage = CALayer()
    private let ring = CAShapeLayer()
    /// The space the person can be seen in, cut to the ring's inside but where it is out (`seen`).
    private let room = CALayer()
    private let seen = CAShapeLayer()
    private let figure = CALayer()
    private let grip = CALayer()
    private let string = CALayer()
    private var zs: [CATextLayer] = []
    private var built = false

    /// How long left alone before it dozes off.
    private static let idle: TimeInterval = 60
    private static let white = CGColor(gray: 1, alpha: 1)

    // MARK: from the page

    func update(size: CGFloat, greeted: Bool, open: Bool, reduceMotion: Bool) {
        self.open = open || greeted
        self.reduceMotion = reduceMotion
        if greeted != self.greeted {
            self.greeted = greeted
            go(greet, to: greeted ? 1 : 0, .spring(0.45, bounce: 0.3))
        }
        if size != self.size, size > 0 {
            self.size = size
            layOut()
            render()
        }
    }

    func attach() {
        guard tasks.isEmpty, let window = view.window else { return }
        if !built { build() }
        rescale()
        // or the window hears the pointer only over what tracks it
        window.acceptsMouseMovedEvents = true
        let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
        // the app's own events only: what goes to other apps is theirs (as above)
        if let local = NSEvent.addLocalMonitorForEvents(matching: moves.union([.keyDown, .scrollWheel]), handler: { [weak self] event in
            self?.seen(event)
            return event
        }) {
            monitors.append(local)
        }
        // the z's only while it is looked at closely: behind another app they would have the
        // window drawn again all the time, as the sky slows there
        let center = NotificationCenter.default
        observers = [
            center.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { if self?.asleep == true { self?.showZs() } }
            },
            center.addObserver(forName: NSApplication.didResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.hideZs() }
            },
        ]
        let link = view.displayLink(target: self, selector: #selector(tick(_:)))
        // as many frames as the screen shows: a hundred and twenty a second on a ProMotion screen
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        link.isPaused = true
        self.link = link
        tasks = [
            Task { await self.hello() },
            Task { await self.blinking() },
            Task { await self.idling() },
        ]
        if asleep { showZs() }
    }

    func detach() {
        tasks.forEach { $0.cancel() }
        tasks = []
        monitors.forEach(NSEvent.removeMonitor)
        monitors = []
        observers.forEach(NotificationCenter.default.removeObserver)
        observers = []
        link?.invalidate()
        link = nil
    }

    func rescale() {
        let scale = view.window?.backingScaleFactor ?? 2
        for layer in [ring, figure, grip] + zs { layer.contentsScale = scale }
        render()
    }

    func play(_ cue: Cue) {
        struct Motion {
            var hop: CGFloat = 0
            var sway: CGFloat = 0
            var nod: CGFloat = 0
            var wide: CGFloat = 1
            var smile: CGFloat = 0
        }
        let steps: [(Motion, Curve, Duration)]
        let unit = size / 26
        switch cue {
        case .hello:
            steps = [(Motion(hop: -2.5 * unit, smile: 0.5), .spring(0.3, bounce: 0.4), .milliseconds(250)),
                     (Motion(smile: 0.5), .spring(0.4, bounce: 0.4), .milliseconds(900)),
                     (Motion(), .easeInOut(0.5), .zero)]
        case .wake:
            steps = [(Motion(hop: -3 * unit, wide: 1.45), .spring(0.18, bounce: 0.2), .milliseconds(320)),
                     (Motion(), .spring(0.45, bounce: 0.45), .zero)]
        case .nod:
            steps = [(Motion(nod: 2 * unit, smile: 0.5), .easeIn(0.14), .milliseconds(140)),
                     (Motion(nod: -0.6 * unit, smile: 0.5), .easeOut(0.16), .milliseconds(160)),
                     (Motion(smile: 0.5), .spring(0.3, bounce: 0.3), .milliseconds(600)),
                     (Motion(), .easeInOut(0.4), .zero)]
        case .shake:
            let sway: [CGFloat] = [-2.2, 2.2, -1.8, 1.4, -0.8]
            steps = sway.map { (Motion(sway: $0 * unit, smile: -1.4), .easeInOut(0.09), .milliseconds(90)) }
                + [(Motion(smile: -1.4), .spring(0.3, bounce: 0.3), .milliseconds(900)),
                   (Motion(), .easeInOut(0.4), .zero)]
        case .grin:
            steps = [(Motion(hop: -2 * unit, smile: 0.7), .spring(0.3, bounce: 0.4), .milliseconds(250)),
                     (Motion(smile: 0.7), .spring(0.4, bounce: 0.4), .milliseconds(1100)),
                     (Motion(), .easeInOut(0.5), .zero)]
        }
        Task {
            for (to, curve, hold) in steps {
                // with less motion, the face changes and the head stays where it is
                if !reduceMotion {
                    go(hop, to: to.hop, curve)
                    go(sway, to: to.sway, curve)
                    go(nod, to: to.nod, curve)
                }
                go(wide, to: to.wide, curve)
                go(smile, to: to.smile, curve)
                try? await Task.sleep(for: hold)
            }
        }
    }

    // MARK: the clock

    /// Sends a number on, and the clock going if it was still.
    private func go(_ value: Value, to target: CGFloat, _ curve: Curve?) {
        guard let link else {
            value.go(to: target, nil, at: 0)
            render()
            return
        }
        value.go(to: target, curve, at: CACurrentMediaTime())
        if curve == nil { render() }
        if link.isPaused {
            lastTick = nil
            link.isPaused = false
        }
    }

    @objc private func tick(_ link: CADisplayLink) {
        let time = link.targetTimestamp
        // after a pause, or a long frame, as if a usual one had passed
        let step = min(1.0 / 30, lastTick.map { time - $0 } ?? 1.0 / 120)
        lastTick = time
        var moved = false
        for value in values {
            if value.advance(to: time, by: step) { moved = true }
        }
        let swinging = swing.map { time < $0.until } ?? false
        if moved || swinging { render(at: time) }
        if !swinging { swing = nil }
        if swing == nil, !values.contains(where: \.moving) {
            link.isPaused = true
            lastTick = nil
        }
    }

    // MARK: drawing

    private func build() {
        built = true
        guard let host = view.layer else { return }
        host.addSublayer(stage)
        ring.fillColor = nil
        ring.strokeColor = Self.white
        stage.addSublayer(ring)
        room.mask = seen
        stage.addSublayer(room)
        string.backgroundColor = Self.white
        for layer in [string, grip, figure] { room.addSublayer(layer) }
        for index in 0..<3 {
            let z = CATextLayer()
            z.string = "z"
            z.foregroundColor = Self.white
            z.alignmentMode = .center
            z.opacity = 0
            z.shadowColor = CGColor(gray: 0, alpha: 1)
            z.shadowOpacity = 0.25
            z.shadowRadius = 1.5
            z.shadowOffset = .zero
            z.name = String(index)
            zs.append(z)
        }
        layOut()
    }

    /// Where the ring's middle is in `room`, which reaches from a ring and a
    /// half to either side of it and two rings above it to two below, and on
    /// a fall as far down as the window goes.
    private var middle: CGPoint { CGPoint(x: size * 1.6, y: size * 2) }
    /// Half the ring's inside, across.
    private var inside: CGFloat { size / 2 - size * 0.075 - size * 0.05 }

    private func layOut() {
        guard built, size > 0 else { return }
        let d = size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        stage.frame = CGRect(x: 0, y: 0, width: d, height: d)
        let line = d * 0.075
        ring.frame = stage.bounds
        ring.lineWidth = line
        ring.path = CGPath(ellipseIn: stage.bounds.insetBy(dx: line / 2, dy: line / 2), transform: nil)
        room.frame = CGRect(x: d / 2 - middle.x, y: d / 2 - middle.y, width: d * 3.2, height: d * 4 + drop)
        seen.frame = room.bounds
        seen.path = seenPath()
        figure.bounds = CGRect(x: 0, y: 0, width: d * 1.2, height: d * 1.75)
        // it turns about a point a fifth of the ring down from the ring's middle
        figure.anchorPoint = CGPoint(x: 0.5, y: 0.95 / 1.75)
        grip.frame = CGRect(x: middle.x - d * 0.6, y: middle.y - d * 0.7, width: d * 1.2, height: d * 1.3)
        for (index, z) in zs.enumerated() {
            let font = NSFont.systemFont(ofSize: d * (0.26 + 0.06 * CGFloat(index)), weight: .heavy)
            z.font = font.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: font.pointSize) } ?? font
            z.fontSize = font.pointSize
            z.bounds = CGRect(x: 0, y: 0, width: font.pointSize, height: font.pointSize * 1.3)
            z.position = CGPoint(x: d * 1.05, y: d * 0.05)
        }
        CATransaction.commit()
        if asleep, link != nil { showZs() }
    }

    private func seenPath() -> CGPath {
        let circle = CGPath(ellipseIn: CGRect(x: middle.x - inside, y: middle.y - inside, width: inside * 2, height: inside * 2), transform: nil)
        let width = room.bounds.width, height = room.bounds.height
        switch out {
        case .no: return circle
        case .over: return circle.union(CGPath(rect: CGRect(x: 0, y: 0, width: width, height: middle.y), transform: nil))
        case .under: return circle.union(CGPath(rect: CGRect(x: 0, y: middle.y, width: width, height: height - middle.y), transform: nil))
        }
    }

    private func render(at time: CFTimeInterval = CACurrentMediaTime()) {
        guard built, size > 0 else { return }
        let d = size
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        stage.setAffineTransform(CGAffineTransform(translationX: 0, y: hop.now))
        var swung: CGFloat = 0
        if let swing {
            let gone = time - swing.from
            swung = 10 * sin(2 * .pi * gone / 0.56) * max(0, 1 - gone / (swing.until - swing.from))
        }
        figure.contents = paintFigure()
        figure.position = CGPoint(x: middle.x + x.now, y: middle.y + y.now + d * 0.2)
        figure.setAffineTransform(CGAffineTransform(rotationAngle: (tilt.now + swung) * .pi / 180))
        if hands.now > 0.001 {
            grip.isHidden = false
            grip.opacity = Float(min(1, hands.now))
            grip.contents = paintGrip()
        } else {
            grip.isHidden = true
        }
        // the thread, from the bottom of the ring's inside down to its hands
        let from = middle.y + inside
        let held = middle.y + y.now - d * 0.36
        if thread.now > 0.001, held > from {
            let width = d * 0.035
            string.isHidden = false
            string.opacity = Float(min(1, thread.now))
            string.frame = CGRect(x: middle.x - width / 2, y: from, width: width, height: held - from)
            string.cornerRadius = width / 2
        } else {
            string.isHidden = true
        }
        CATransaction.commit()
    }

    /// A context a box of points across, drawn into from the top left at
    /// the screen's own scale, with `origin` where the person's own middle is.
    private func canvas(_ box: CGSize, origin: CGPoint) -> CGContext? {
        let scale = view.window?.backingScaleFactor ?? 2
        guard let context = CGContext(data: nil, width: Int((box.width * scale).rounded(.up)), height: Int((box.height * scale).rounded(.up)),
                                      bitsPerComponent: 8, bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.translateBy(x: 0, y: CGFloat(context.height))
        context.scaleBy(x: scale, y: -scale)
        context.translateBy(x: origin.x, y: origin.y)
        context.setFillColor(Self.white)
        context.setStrokeColor(Self.white)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        return context
    }

    /* The person, white, the head apart from the shoulders by a gap, and
       the face cut out of the head in lines, so that what is behind shows
       through; arms and legs when it is out. In the ring it is cut off by
       the ring's inside, as the symbol is (`seen`). */
    private func paintFigure() -> CGImage? {
        let d = size
        guard let context = canvas(CGSize(width: d * 1.2, height: d * 1.75), origin: CGPoint(x: d * 0.6, y: d * 0.75)) else { return nil }
        let asleep = sleepy.now
        let lookAcross = lookX.now
        let lookDown = lookY.now * (1 - asleep) + 0.7 * asleep
        let eyes = max(0, 1 - max(blink.now, asleep)) * wide.now
        let smiling = 0.5 + 0.5 * greet.now - 0.35 * asleep + smile.now
        context.setLineWidth(d * 0.075)

        if legs.now > 0.001 {
            context.saveGState()
            context.setAlpha(min(1, legs.now * 3))
            for side in [-1.0, 1.0] {
                context.move(to: CGPoint(x: side * d * 0.11, y: d * 0.56))
                context.addLine(to: CGPoint(x: side * d * 0.13, y: d * 0.56 + d * 0.3 * legs.now))
            }
            context.strokePath()
            context.restoreGState()
        }
        context.fillEllipse(in: CGRect(x: lookAcross * d * 0.015 - d * 0.32, y: d * 0.16, width: d * 0.64, height: d * 0.48))
        if arms.now > 0.001 {
            context.saveGState()
            context.setAlpha(min(1, arms.now * 3))
            for side in [-1.0, 1.0] {
                context.move(to: CGPoint(x: side * d * 0.26, y: d * 0.32))
                context.addLine(to: CGPoint(x: side * (d * 0.36 - d * 0.24 * arms.now), y: d * 0.5 - d * 0.86 * arms.now))
            }
            context.strokePath()
            context.restoreGState()
        }

        // the shoulders turn least, the head more, the face most
        let head = CGPoint(x: lookAcross * d * 0.04 + sway.now, y: -d * 0.07 + lookDown * d * 0.03 + nod.now + asleep * d * 0.03)
        let radius = d * 0.2
        context.setBlendMode(.clear)
        context.fillEllipse(in: CGRect(x: head.x - radius - d * 0.045, y: head.y - radius - d * 0.045,
                                       width: (radius + d * 0.045) * 2, height: (radius + d * 0.045) * 2))
        context.setBlendMode(.normal)
        context.fillEllipse(in: CGRect(x: head.x - radius, y: head.y - radius, width: radius * 2, height: radius * 2))

        // the face, as the Face ID symbol draws it, cut out of the head
        context.setBlendMode(.clear)
        context.setLineWidth(d * 0.032)
        let face = CGPoint(x: head.x + lookAcross * d * 0.06, y: head.y + lookDown * d * 0.045)
        for side in [-1.0, 1.0] {
            let eye = CGPoint(x: face.x + side * d * 0.078, y: face.y - d * 0.04)
            if eyes < 0.2 {
                // shut: a line curved down at its ends
                context.move(to: CGPoint(x: eye.x - d * 0.035, y: eye.y))
                context.addQuadCurve(to: CGPoint(x: eye.x + d * 0.035, y: eye.y), control: CGPoint(x: eye.x, y: eye.y + d * 0.03))
            } else {
                let tall = d * 0.03 * eyes
                context.move(to: CGPoint(x: eye.x, y: eye.y - tall))
                context.addLine(to: CGPoint(x: eye.x, y: eye.y + tall))
            }
        }
        // the nose turns furthest, and its foot points the other way
        let nose = CGPoint(x: face.x + lookAcross * d * 0.015 + d * 0.012, y: face.y)
        context.move(to: CGPoint(x: nose.x, y: nose.y - d * 0.065))
        context.addLine(to: CGPoint(x: nose.x, y: nose.y + d * 0.008))
        context.addQuadCurve(to: CGPoint(x: nose.x - d * 0.035, y: nose.y + d * 0.03), control: CGPoint(x: nose.x, y: nose.y + d * 0.03))
        let lips = face.y + d * 0.08
        if gasp.now > 0.5 {
            context.strokePath()
            // an O, falling
            let open = d * 0.07 * gasp.now
            context.fillEllipse(in: CGRect(x: face.x - d * 0.032, y: lips - open / 3, width: d * 0.064, height: open))
        } else {
            context.move(to: CGPoint(x: face.x - d * 0.075, y: lips))
            context.addQuadCurve(to: CGPoint(x: face.x + d * 0.075, y: lips), control: CGPoint(x: face.x, y: lips + smiling * d * 0.09))
            context.strokePath()
        }
        return context.makeImage()
    }

    /// Climbing out: its hands on the top of the ring, and its arms up to them from its shoulders.
    private func paintGrip() -> CGImage? {
        let d = size
        // drawn about the ring's middle
        guard let context = canvas(grip.bounds.size, origin: CGPoint(x: d * 0.6, y: d * 0.7)) else { return nil }
        context.setLineWidth(d * 0.075)
        let top = -d / 2 + d * 0.075 / 2
        for side in [-1.0, 1.0] {
            let hand = CGPoint(x: side * d * 0.17, y: top)
            context.move(to: CGPoint(x: x.now + side * d * 0.24, y: y.now + d * 0.24))
            context.addLine(to: hand)
            context.strokePath()
            context.fillEllipse(in: CGRect(x: hand.x - d * 0.065, y: hand.y - d * 0.065, width: d * 0.13, height: d * 0.13))
        }
        return context.makeImage()
    }

    /// Three z's, rising off it up and to one side and fading, one after another, by Core
    /// Animation alone.
    private func showZs() {
        guard !reduceMotion, built, NSApp.isActive else { return }
        let d = size
        let start = CACurrentMediaTime()
        for (index, z) in zs.enumerated() {
            if z.superlayer == nil { stage.addSublayer(z) }
            let rise = CABasicAnimation(keyPath: "position")
            rise.fromValue = CGPoint(x: d * 1.05, y: d * 0.05)
            rise.toValue = CGPoint(x: d * 1.6, y: -d * 0.75)
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1
            fade.toValue = 0
            let grow = CABasicAnimation(keyPath: "transform.scale")
            grow.fromValue = 0.6
            grow.toValue = 1.2
            let group = CAAnimationGroup()
            group.animations = [rise, fade, grow]
            group.duration = 2.4
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            group.repeatCount = .infinity
            group.beginTime = start + Double(index) * 0.8
            // drifting, they are smooth enough at thirty a second, a quarter of the work of a hundred
            // and twenty
            group.preferredFrameRateRange = CAFrameRateRange(minimum: 10, maximum: 30, preferred: 30)
            z.add(group, forKey: "doze")
        }
    }

    private func hideZs() {
        for z in zs {
            z.removeAllAnimations()
            z.removeFromSuperlayer()
        }
    }

    // MARK: what it does

    /* The pointer, from the middle of the face, in points. The eyes go all
       the way round only when it is well away: close by, a little. Thirty
       times a second at most, and not for a move too small to be seen. */
    private func seen(_ event: NSEvent) {
        guard let window = view.window, window.occlusionState.contains(.visible) else { return }
        if event.type == .keyDown || event.type == .scrollWheel {
            woken()
            return
        }
        woken()
        guard !reduceMotion, Date().timeIntervalSince(handled) > 1.0 / 30 else { return }
        handled = Date()
        let pointer = NSEvent.mouseLocation
        /* Only while this window is the one under the pointer. The
           screenshot tool's shading is a window over the whole screen, and
           the app still hears the pointer under it: following it there, the
           face had the window drawn again a hundred and twenty times a
           second while the tool drew the shading, and the shading dragged
           behind the pointer. */
        guard NSWindow.windowNumber(at: pointer, belowWindowWithWindowNumber: 0) == window.windowNumber else { return }
        let middle = window.convertPoint(toScreen: view.convert(CGPoint(x: view.bounds.midX, y: view.bounds.midY), to: nil))
        // the screen's y goes up, the face's down
        follow(CGVector(dx: pointer.x - middle.x, dy: middle.y - pointer.y))
    }

    private func follow(_ offset: CGVector) {
        let distance = hypot(offset.dx, offset.dy)
        let reach = distance / (distance + size * 4)
        let wanted = distance < 1 ? .zero : CGVector(dx: offset.dx / distance * reach, dy: offset.dy / distance * reach)
        guard hypot(wanted.dx - lookX.now, wanted.dy - lookY.now) > 0.02 else { return }
        go(lookX, to: wanted.dx, .spring(0.35, bounce: 0.1))
        go(lookY, to: wanted.dy, .spring(0.35, bounce: 0.1))
    }

    private func woken() {
        last = Date()
        if bored {
            bored = false
            boredAfter = .random(in: 15...30)
        }
        if asleep { wake(with: .wake) }
    }

    private func wake(with cue: Cue) {
        guard asleep else { return }
        asleep = false
        hideZs()
        go(sleepy, to: 0, .spring(0.3, bounce: 0.3))
        play(cue)
    }

    private func hello() async {
        try? await Task.sleep(for: .milliseconds(700))
        guard !Task.isCancelled else { return }
        wake(with: .hello)
    }

    private func blinking() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.5...6)))
            guard !asleep, !Task.isCancelled else { continue }
            for _ in 0..<(Double.random(in: 0...1) < 0.15 ? 2 : 1) {
                go(blink, to: 1, .easeIn(0.06))
                try? await Task.sleep(for: .milliseconds(110))
                go(blink, to: 0, .easeOut(0.1))
                try? await Task.sleep(for: .milliseconds(160))
            }
        }
    }

    /// Bored after a while of nothing happening, once each while, and asleep after a minute.
    private func idling() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !asleep, !busy else { continue }
            let still = Date().timeIntervalSince(last)
            if still > Self.idle {
                asleep = true
                go(sleepy, to: 1, .easeInOut(1.6))
                go(lookX, to: 0, .easeInOut(1.6))
                go(lookY, to: 0, .easeInOut(1.6))
                showZs()
            } else if still > boredAfter, !bored, !reduceMotion, !open, NSApp.isActive,
                      view.window?.occlusionState.contains(.visible) == true {
                bored = true
                if tricks.isEmpty { tricks = Trick.allCases.shuffled() }
                await perform(tricks.removeFirst())
            }
        }
    }

    /// Sends some of the pose's numbers on, and waits.
    private func move(_ curve: Curve?, hold: Duration = .zero, _ changes: (Value, CGFloat)...) async {
        for (value, target) in changes { go(value, to: target, curve) }
        if hold > .zero { try? await Task.sleep(for: hold) }
    }

    private func letOut(_ out: Out, drop: CGFloat = 0) {
        self.out = out
        self.drop = drop
        layOut()
    }

    /* The tricks, step by step, in sizes of the ring across (`d`) from where
       the person sits in it. Out of sight it is moved without being seen to
       go; and it is only let out of the ring, or shut back into it, where
       the ring would show it the same either way, so it never jumps. */
    private func perform(_ trick: Trick) async {
        busy = true
        defer { busy = false }
        let d = size
        switch trick {
        case .peek:
            // down out of sight
            await move(.easeIn(0.25), hold: .milliseconds(800), (y, d * 0.95))
            // round one side, leaning in, one eye showing; back; round the other
            await move(nil, (x, -d * 0.85), (y, d * 0.1), (tilt, 22))
            await move(.easeOut(0.35), hold: .milliseconds(900), (x, -d * 0.36))
            await move(.easeIn(0.13), hold: .milliseconds(500), (x, -d * 0.85))
            await move(nil, (x, d * 0.85), (tilt, -22))
            await move(.easeOut(0.3), hold: .milliseconds(800), (x, d * 0.36))
            await move(.easeIn(0.13), hold: .milliseconds(450), (x, d * 0.85))
            // and up from below, with a bounce
            await move(nil, (x, 0), (y, d * 0.95), (tilt, 0))
            await move(.spring(0.5, bounce: 0.5), hold: .milliseconds(200), (y, 0))
            play(.grin)
        case .climb:
            // free over the top of the ring, the same as in it while it sits where it does
            letOut(.over)
            await move(.easeOut(0.2), hold: .milliseconds(250), (hands, 1), (y, -d * 0.12))
            // up, slipping back a little, and up again
            await move(.easeInOut(0.35), hold: .milliseconds(150), (y, -d * 0.45))
            await move(.easeInOut(0.15), hold: .milliseconds(120), (y, -d * 0.36))
            await move(.easeOut(0.35), hold: .milliseconds(150), (y, -d * 0.75))
            // sat on the ring, legs dangling, looking round at the pointer
            await move(.spring(0.4, bounce: 0.35), hold: .milliseconds(1600), (y, -d * 1.1), (hands, 0), (legs, 1))
            // a jump up, and down into the ring
            await move(.easeOut(0.18), hold: .milliseconds(180), (y, -d * 1.35), (legs, 0.5))
            await move(.easeIn(0.3), hold: .milliseconds(300), (y, 0), (legs, 0))
            letOut(.no)
            play(.wake)
        case .fall:
            guard let floor = view.floor else { return }
            // where it lands, below where it sits: just above the window's bottom edge
            let bottom = max(d * 2, floor - d * 0.95)
            // a start, and up out of its seat, where the ring shows it whole whichever way
            play(.wake)
            await move(.easeOut(0.16), hold: .milliseconds(160), (y, -d * 0.3))
            letOut(.under, drop: bottom)
            // down, as a thing falls: slowly at first, then faster and faster
            let fall = sqrt(2 * (bottom + d * 0.3) / 2600)
            await move(.curve(0.33, 0, 0.67, 0.33, duration: fall), hold: .seconds(fall), (y, bottom), (arms, 1), (gasp, 1))
            // a bounce, and a moment lying there
            await move(.easeOut(0.14), hold: .milliseconds(140), (y, bottom - d * 0.6), (tilt, 14))
            await move(.easeIn(0.14), hold: .milliseconds(600), (y, bottom), (tilt, 0), (arms, 0), (gasp, 0))
            // the thread comes down to it, and it takes hold
            await move(.easeOut(0.35), hold: .milliseconds(450), (thread, 1), (arms, 1), (legs, 1))
            // hauled up, swinging, to just under the ring
            let now = CACurrentMediaTime()
            swing = (now, now + 1.2)
            await move(.easeInOut(1.2), hold: .milliseconds(1200), (y, d * 0.9))
            // and in, letting go, to where the ring shows it the same either way
            await move(.easeOut(0.3), hold: .milliseconds(300), (y, -d * 0.3), (tilt, 0), (arms, 0), (legs, 0))
            await move(nil, (thread, 0))
            letOut(.no)
            await move(.spring(0.45, bounce: 0.4), (y, 0))
        }
    }
}
