import AppKit
import SwiftUI

/* The person in the header, come to life as the Mac's own login picture
   does when it is a Memoji. Apple draws that with a framework of its own
   that apps are not given, so this is the same manner in the person's own
   lines: the ring, the head and the shoulders of the symbol it was, with
   the Face ID symbol's face cut out of the head (two eyes, a nose that
   turns at its foot and a smile) for the glass to show through.

   - It looks at the pointer, wherever it is on the screen: the face most,
     the head after it, the shoulders hardly at all, so it seems to turn.
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
     doze, it gets up to something, a different thing each time (`Trick`):
     it ducks out of sight and peeks in round one side of the ring and then
     the other, one eye showing, before popping back up (探頭); it climbs out
     over the top of the ring, hands first, sits on it with its legs
     dangling, and jumps back in (爬出來); or it slips out of the bottom of the
     ring, falls with its arms up and its mouth open to the bottom of the
     window, bounces, and is hauled back up on a thread, legs dangling and
     swinging, as a spider goes back up its own (掉下來，被吊回去).

   The ring stays where it is, and the person is drawn on its own over a
   space three times as wide and as high, and on a fall as far down as the
   window goes, so that it can leave the ring. */
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
    /// Where it looks, from -1 to 1 each way, toward the pointer.
    @State private var look = CGVector.zero
    @State private var blinking = false
    /// Asleep until the window has been up a moment, as the login picture holds still at first.
    @State private var asleep = true
    @State private var motion = Motion()
    @State private var pose = Pose()
    @State private var activity = Activity()

    /// What a nod, a shake or a start does over its moment, on top of the face as it is.
    private struct Motion {
        var hop: CGFloat = 0
        var sway: CGFloat = 0
        var nod: CGFloat = 0
        var wide: CGFloat = 1
        var smile: CGFloat = 0
    }

    /// Where the person is, in its ring or out of it, and what its arms and legs are doing.
    private struct Pose {
        var x: CGFloat = 0
        var y: CGFloat = 0
        /// Degrees, clockwise.
        var tilt: CGFloat = 0
        /// 0 down by its sides, 1 up over its head.
        var arms: CGFloat = 0
        var legs: CGFloat = 0
        /// Its hands on the top of the ring, climbing out.
        var hands: CGFloat = 0
        var thread: CGFloat = 0
        /// Its mouth open, falling.
        var gasp: CGFloat = 0
        var out = AvatarFace.Out.no
        /// How much further down than the ring's own space it is drawn, falling.
        var drop: CGFloat = 0
    }

    /// When the pointer last moved or a key was last pressed, and what it has been up to since.
    /// Not watched: it changes far too often to draw the face again for each.
    fileprivate final class Activity {
        var last = Date()
        var handled = Date.distantPast
        /// Up to something now.
        var busy = false
        /// The drop is open, or the pointer on it.
        var open = false
        /// Has got up to something since the pointer last moved.
        var bored = false
        var boredAfter = TimeInterval.random(in: 15...30)
        /// What it is yet to get up to, in a shuffled turn, so each comes round before any again.
        var tricks: [Trick] = []
        weak var watcher: PointerWatch.Watcher?
    }

    private enum Cue { case hello, wake, nod, shake, grin }

    fileprivate enum Trick: CaseIterable { case peek, climb, fall }

    /// How long left alone before it dozes off.
    private static let idle: TimeInterval = 60
    private static let follow = Animation.spring(duration: 0.35, bounce: 0.1)

    var body: some View {
        Color.clear
            .frame(width: size, height: size)
            .overlay(alignment: .top) {
                AvatarFace(
                    lookX: look.dx,
                    lookY: asleep ? 0.7 : look.dy,
                    eyes: (blinking || asleep ? 0 : 1) * motion.wide,
                    smile: (asleep ? 0.15 : greeted ? 1 : 0.5) + motion.smile,
                    headX: motion.sway,
                    headY: motion.nod + (asleep ? size * 0.03 : 0),
                    x: pose.x, y: pose.y, tilt: pose.tilt,
                    arms: pose.arms, legs: pose.legs, hands: pose.hands,
                    thread: pose.thread, gasp: pose.gasp,
                    size: size, out: pose.out)
                    // the ring in the middle of a space it can get out into, up and to the sides
                    .frame(width: size * 3, height: size * 3 + pose.drop)
                    .offset(y: -size)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .topTrailing) {
                if asleep && !reduceMotion {
                    Dozing(size: size)
                        .transition(.opacity)
                }
            }
            .offset(y: motion.hop)
            .background(PointerWatch(activity: activity) { moved($0) } pressed: { woken() })
            .task { await blink() }
            .task { await idle() }
            .task {
                try? await Task.sleep(for: .milliseconds(700))
                wake(with: .hello)
            }
            .onChange(of: nods) { play(.nod) }
            .onChange(of: open || greeted, initial: true) { activity.open = $1 }
            .onChange(of: homework.status) { old, new in
                if new == .expired { play(.shake) } else if new == .signedIn, old != .signedIn { play(.grin) }
            }
            .onChange(of: homework.problem) { _, problem in
                if problem != nil { play(.shake) }
            }
            .accessibilityHidden(true)
    }

    /* The pointer, from the middle of the face, in points. The eyes go all
       the way round only when it is well away: close by, a little. Thirty
       times a second at most, and not for a move too small to be seen. */
    private func moved(_ offset: CGVector) {
        woken()
        guard !reduceMotion, Date().timeIntervalSince(activity.handled) > 1.0 / 30 else { return }
        activity.handled = Date()
        let distance = hypot(offset.dx, offset.dy)
        let reach = distance / (distance + size * 4)
        let wanted = distance < 1 ? .zero : CGVector(dx: offset.dx / distance * reach, dy: offset.dy / distance * reach)
        guard hypot(wanted.dx - look.dx, wanted.dy - look.dy) > 0.02 else { return }
        withAnimation(Self.follow) { look = wanted }
    }

    private func woken() {
        activity.last = Date()
        if activity.bored {
            activity.bored = false
            activity.boredAfter = .random(in: 15...30)
        }
        if asleep { wake(with: .wake) }
    }

    private func wake(with cue: Cue) {
        guard asleep else { return }
        withAnimation(.spring(duration: 0.3, bounce: 0.3)) { asleep = false }
        play(cue)
    }

    private func blink() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Double.random(in: 2.5...6)))
            guard !asleep else { continue }
            for _ in 0..<(Double.random(in: 0...1) < 0.15 ? 2 : 1) {
                withAnimation(.easeIn(duration: 0.06)) { blinking = true }
                try? await Task.sleep(for: .milliseconds(110))
                withAnimation(.easeOut(duration: 0.1)) { blinking = false }
                try? await Task.sleep(for: .milliseconds(160))
            }
        }
    }

    /// Bored after a while of nothing happening, once each while, and asleep after a minute.
    private func idle() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(1))
            guard !asleep, !activity.busy else { continue }
            let still = Date().timeIntervalSince(activity.last)
            if still > Self.idle {
                withAnimation(.easeInOut(duration: 1.6)) {
                    asleep = true
                    look = .zero
                }
            } else if still > activity.boredAfter, !activity.bored, !reduceMotion, !activity.open,
                      activity.watcher?.visible == true {
                activity.bored = true
                if activity.tricks.isEmpty { activity.tricks = Trick.allCases.shuffled() }
                await perform(activity.tricks.removeFirst())
            }
        }
    }

    /// Plays a moment's motion through, step by step.
    private func play(_ cue: Cue) {
        let steps: [(Motion, Animation, Duration)]
        let unit = size / 26
        switch cue {
        case .hello:
            steps = [(Motion(hop: -2.5 * unit, smile: 0.5), .spring(duration: 0.3, bounce: 0.4), .milliseconds(250)),
                     (Motion(smile: 0.5), .spring(duration: 0.4, bounce: 0.4), .milliseconds(900)),
                     (Motion(), .easeInOut(duration: 0.5), .zero)]
        case .wake:
            steps = [(Motion(hop: -3 * unit, wide: 1.45), .spring(duration: 0.18, bounce: 0.2), .milliseconds(320)),
                     (Motion(), .spring(duration: 0.45, bounce: 0.45), .zero)]
        case .nod:
            steps = [(Motion(nod: 2 * unit, smile: 0.5), .easeIn(duration: 0.14), .milliseconds(140)),
                     (Motion(nod: -0.6 * unit, smile: 0.5), .easeOut(duration: 0.16), .milliseconds(160)),
                     (Motion(smile: 0.5), .spring(duration: 0.3, bounce: 0.3), .milliseconds(600)),
                     (Motion(), .easeInOut(duration: 0.4), .zero)]
        case .shake:
            let sway: [CGFloat] = [-2.2, 2.2, -1.8, 1.4, -0.8]
            steps = sway.map { (Motion(sway: $0 * unit, smile: -1.4), .easeInOut(duration: 0.09), .milliseconds(90)) }
                + [(Motion(smile: -1.4), .spring(duration: 0.3, bounce: 0.3), .milliseconds(900)),
                   (Motion(), .easeInOut(duration: 0.4), .zero)]
        case .grin:
            steps = [(Motion(hop: -2 * unit, smile: 0.7), .spring(duration: 0.3, bounce: 0.4), .milliseconds(250)),
                     (Motion(smile: 0.7), .spring(duration: 0.4, bounce: 0.4), .milliseconds(1100)),
                     (Motion(), .easeInOut(duration: 0.5), .zero)]
        }
        Task { @MainActor in
            for (to, animation, hold) in steps {
                // with less motion, the face changes and the head stays where it is
                let to = reduceMotion ? Motion(wide: to.wide, smile: to.smile) : to
                withAnimation(animation) { motion = to }
                try? await Task.sleep(for: hold)
            }
        }
    }

    /* The tricks, step by step, in sizes of the ring across (`d`) from where
       the person sits in it. Out of sight it is moved without being seen to
       go; and it is only let out of the ring, or shut back into it, where
       the ring would show it the same either way, so it never jumps. */
    private func perform(_ trick: Trick) async {
        activity.busy = true
        defer { activity.busy = false }
        let d = size
        switch trick {
        case .peek:
            // down out of sight
            await set(.easeIn(duration: 0.25), hold: .milliseconds(800)) { $0.y = d * 0.95 }
            // round one side, leaning in, one eye showing; back; round the other
            await set(nil) { $0.x = -d * 0.85; $0.y = d * 0.1; $0.tilt = 22 }
            await set(.easeOut(duration: 0.35), hold: .milliseconds(900)) { $0.x = -d * 0.36 }
            await set(.easeIn(duration: 0.13), hold: .milliseconds(500)) { $0.x = -d * 0.85 }
            await set(nil) { $0.x = d * 0.85; $0.tilt = -22 }
            await set(.easeOut(duration: 0.3), hold: .milliseconds(800)) { $0.x = d * 0.36 }
            await set(.easeIn(duration: 0.13), hold: .milliseconds(450)) { $0.x = d * 0.85 }
            // and up from below, with a bounce
            await set(nil) { $0.x = 0; $0.y = d * 0.95; $0.tilt = 0 }
            await set(.spring(duration: 0.5, bounce: 0.5), hold: .milliseconds(200)) { $0.y = 0 }
            play(.grin)
        case .climb:
            // free over the top of the ring, the same as in it while it sits where it does
            await set(nil) { $0.out = .over }
            await set(.easeOut(duration: 0.2), hold: .milliseconds(250)) { $0.hands = 1; $0.y = -d * 0.12 }
            // up, slipping back a little, and up again
            await set(.easeInOut(duration: 0.35), hold: .milliseconds(150)) { $0.y = -d * 0.45 }
            await set(.easeInOut(duration: 0.15), hold: .milliseconds(120)) { $0.y = -d * 0.36 }
            await set(.easeOut(duration: 0.35), hold: .milliseconds(150)) { $0.y = -d * 0.75 }
            // sat on the ring, legs dangling, looking round at the pointer
            await set(.spring(duration: 0.4, bounce: 0.35), hold: .milliseconds(1600)) {
                $0.y = -d * 1.1
                $0.hands = 0
                $0.legs = 1
            }
            // a jump up, and down into the ring
            await set(.easeOut(duration: 0.18), hold: .milliseconds(180)) { $0.y = -d * 1.35; $0.legs = 0.5 }
            await set(.easeIn(duration: 0.3), hold: .milliseconds(300)) { $0.y = 0; $0.legs = 0 }
            await set(nil) { $0.out = .no }
            play(.wake)
        case .fall:
            guard let floor = activity.watcher?.floor else { return }
            // where it lands, below where it sits: just above the window's bottom edge
            let bottom = max(d * 2, floor - d * 0.95)
            // a start, and up out of its seat, where the ring shows it whole whichever way
            play(.wake)
            await set(.easeOut(duration: 0.16), hold: .milliseconds(160)) { $0.y = -d * 0.3 }
            await set(nil) { $0.out = .under; $0.drop = bottom + d }
            // down, as a thing falls: slowly at first, then faster and faster
            let fall = sqrt(2 * (bottom + d * 0.3) / 2600)
            await set(.timingCurve(0.33, 0, 0.67, 0.33, duration: fall), hold: .seconds(fall)) {
                $0.y = bottom
                $0.arms = 1
                $0.gasp = 1
            }
            // a bounce, and a moment lying there
            await set(.easeOut(duration: 0.14), hold: .milliseconds(140)) { $0.y = bottom - d * 0.6; $0.tilt = 14 }
            await set(.easeIn(duration: 0.14), hold: .milliseconds(600)) { $0.y = bottom; $0.tilt = 0; $0.arms = 0; $0.gasp = 0 }
            // the thread comes down to it, and it takes hold
            await set(.easeOut(duration: 0.35), hold: .milliseconds(450)) { $0.thread = 1; $0.arms = 1; $0.legs = 1 }
            // hauled up, swinging, to just under the ring
            withAnimation(.easeInOut(duration: 0.28).repeatCount(4, autoreverses: true)) { pose.tilt = 10 }
            await set(.easeInOut(duration: 1.2), hold: .milliseconds(1200)) { $0.y = d * 0.9 }
            // and in, letting go, to where the ring shows it the same either way
            await set(.easeOut(duration: 0.3), hold: .milliseconds(300)) {
                $0.y = -d * 0.3
                $0.tilt = 0
                $0.arms = 0
                $0.legs = 0
            }
            await set(nil) { $0.out = .no; $0.thread = 0; $0.drop = 0 }
            await set(.spring(duration: 0.45, bounce: 0.4)) { $0.y = 0 }
        }
    }

    /// Changes the pose, run through as `animation` or at once, and waits `hold`.
    private func set(_ animation: Animation?, hold: Duration = .zero, _ change: (inout Pose) -> Void) async {
        if let animation {
            withAnimation(animation) { change(&pose) }
        } else {
            var still = Transaction()
            still.disablesAnimations = true
            withTransaction(still) { change(&pose) }
        }
        if hold > .zero { try? await Task.sleep(for: hold) }
    }
}

/* The ring, and the person, drawn: every part given as a number so that
   SwiftUI can run each from where it is to where it is going. The ring in
   the middle; the person in it, white, the head apart from the shoulders
   by a gap, and the Face ID face cut out of the head in lines, so that what
   is behind shows through. In the ring the person is cut off by its inside,
   as the symbol is; out of it, over the top or under the bottom, it is
   drawn whole, with arms and legs. */
@Animatable
private struct AvatarFace: View {
    var lookX: CGFloat
    var lookY: CGFloat
    /// 1 open, 0 shut, more than 1 wide.
    var eyes: CGFloat
    /// 1 a smile, 0 a straight line, below it a frown.
    var smile: CGFloat
    var headX: CGFloat
    var headY: CGFloat
    var x: CGFloat
    var y: CGFloat
    var tilt: CGFloat
    var arms: CGFloat
    var legs: CGFloat
    var hands: CGFloat
    var thread: CGFloat
    var gasp: CGFloat
    @AnimatableIgnored var size: CGFloat
    @AnimatableIgnored var out: Out

    /// Whether the person can be seen outside the ring, and where.
    enum Out { case no, over, under }

    var body: some View {
        Canvas { context, canvas in
            let d = size
            let middle = CGPoint(x: canvas.width / 2, y: d * 1.5)
            let line = d * 0.075
            context.stroke(circle(middle, d / 2 - line / 2), with: .foreground, lineWidth: line)

            let room = d / 2 - line - d * 0.05
            var seen = circle(middle, room)
            switch out {
            case .no: break
            case .over: seen = seen.union(Path(CGRect(x: 0, y: 0, width: canvas.width, height: middle.y)))
            case .under: seen = seen.union(Path(CGRect(x: 0, y: middle.y, width: canvas.width, height: canvas.height - middle.y)))
            }
            let limb = StrokeStyle(lineWidth: d * 0.075, lineCap: .round)

            // the thread, from the bottom of the ring down to its hands
            let held = CGPoint(x: middle.x + x, y: middle.y + y - d * 0.36)
            if thread > 0, held.y > middle.y + room {
                var string = context
                string.opacity = min(1, thread)
                var path = Path()
                path.move(to: CGPoint(x: middle.x, y: middle.y + room))
                path.addLine(to: held)
                string.stroke(path, with: .foreground, style: StrokeStyle(lineWidth: d * 0.035, lineCap: .round))
            }

            var person = context
            person.clip(to: seen)
            // climbing out, its hands on the top of the ring and its arms up to them
            if hands > 0 {
                var grip = person
                grip.opacity = min(1, hands)
                let top = middle.y - d / 2 + line / 2
                for side in [-1.0, 1.0] {
                    let hand = CGPoint(x: middle.x + side * d * 0.17, y: top)
                    var arm = Path()
                    arm.move(to: CGPoint(x: middle.x + x + side * d * 0.24, y: middle.y + y + d * 0.24))
                    arm.addLine(to: hand)
                    grip.stroke(arm, with: .foreground, style: limb)
                    grip.fill(circle(hand, d * 0.065), with: .foreground)
                }
            }

            // the person turns about its middle
            person.translateBy(x: middle.x + x, y: middle.y + y + d * 0.2)
            person.rotate(by: .degrees(tilt))
            person.translateBy(x: 0, y: -d * 0.2)

            if legs > 0 {
                var dangling = person
                dangling.opacity = min(1, legs * 3)
                for side in [-1.0, 1.0] {
                    var leg = Path()
                    leg.move(to: CGPoint(x: side * d * 0.11, y: d * 0.56))
                    leg.addLine(to: CGPoint(x: side * d * 0.13, y: d * 0.56 + d * 0.3 * legs))
                    dangling.stroke(leg, with: .foreground, style: limb)
                }
            }
            person.fill(Ellipse().path(in: CGRect(x: lookX * d * 0.015 - d * 0.32, y: d * 0.16, width: d * 0.64, height: d * 0.48)),
                        with: .foreground)
            if arms > 0 {
                var raised = person
                raised.opacity = min(1, arms * 3)
                for side in [-1.0, 1.0] {
                    var arm = Path()
                    arm.move(to: CGPoint(x: side * d * 0.26, y: d * 0.32))
                    arm.addLine(to: CGPoint(x: side * (d * 0.36 - d * 0.24 * arms), y: d * 0.5 - d * 0.86 * arms))
                    raised.stroke(arm, with: .foreground, style: limb)
                }
            }

            // the shoulders turn least, the head more, the face most
            let head = CGPoint(x: lookX * d * 0.04 + headX, y: -d * 0.07 + lookY * d * 0.03 + headY)
            let radius = d * 0.2
            person.blendMode = .destinationOut
            person.fill(circle(head, radius + d * 0.045), with: .color(.black))
            person.blendMode = .normal
            person.fill(circle(head, radius), with: .foreground)

            // the face, as the Face ID symbol draws it, cut out of the head
            person.blendMode = .destinationOut
            let face = CGPoint(x: head.x + lookX * d * 0.06, y: head.y + lookY * d * 0.045)
            let pen = StrokeStyle(lineWidth: d * 0.032, lineCap: .round, lineJoin: .round)
            var features = Path()
            for side in [-1.0, 1.0] {
                let eye = CGPoint(x: face.x + side * d * 0.078, y: face.y - d * 0.04)
                if eyes < 0.2 {
                    // shut: a line curved down at its ends
                    features.move(to: CGPoint(x: eye.x - d * 0.035, y: eye.y))
                    features.addQuadCurve(to: CGPoint(x: eye.x + d * 0.035, y: eye.y), control: CGPoint(x: eye.x, y: eye.y + d * 0.03))
                } else {
                    let tall = d * 0.03 * eyes
                    features.move(to: CGPoint(x: eye.x, y: eye.y - tall))
                    features.addLine(to: CGPoint(x: eye.x, y: eye.y + tall))
                }
            }
            // the nose turns furthest, and its foot points the other way
            let nose = CGPoint(x: face.x + lookX * d * 0.015 + d * 0.012, y: face.y)
            features.move(to: CGPoint(x: nose.x, y: nose.y - d * 0.065))
            features.addLine(to: CGPoint(x: nose.x, y: nose.y + d * 0.008))
            features.addQuadCurve(to: CGPoint(x: nose.x - d * 0.035, y: nose.y + d * 0.03),
                                  control: CGPoint(x: nose.x, y: nose.y + d * 0.03))
            let lips = face.y + d * 0.08
            if gasp > 0.5 {
                // an O, falling
                let open = d * 0.07 * gasp
                person.fill(Ellipse().path(in: CGRect(x: face.x - d * 0.032, y: lips - open / 3, width: d * 0.064, height: open)),
                            with: .color(.black))
            } else {
                features.move(to: CGPoint(x: face.x - d * 0.075, y: lips))
                features.addQuadCurve(to: CGPoint(x: face.x + d * 0.075, y: lips),
                                      control: CGPoint(x: face.x, y: lips + smile * d * 0.09))
            }
            person.stroke(features, with: .color(.black), style: pen)
        }
    }

    private func circle(_ middle: CGPoint, _ radius: CGFloat) -> Path {
        Circle().path(in: CGRect(x: middle.x - radius, y: middle.y - radius, width: radius * 2, height: radius * 2))
    }
}

/// Three z's, rising off it up and to one side and fading, one after another.
private struct Dozing: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                PhaseAnimator([false, true]) { risen in
                    Text("z")
                        .font(.system(size: size * (0.26 + 0.06 * CGFloat(index)), weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 1.5)
                        // from just off the ring, clear of it
                        .offset(x: risen ? size * 0.75 : size * 0.22, y: risen ? -size * 0.8 : -size * 0.08)
                        .opacity(risen ? 0 : 1)
                        .scaleEffect(risen ? 1.2 : 0.6)
                } animation: { risen in
                    // up slowly, and back down at once, unseen
                    risen ? .easeOut(duration: 2.4).delay(Double(index) * 0.8) : nil
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/* Where the pointer is, wherever it is, and whether a key is pressed in
   the app. The pointer's moves come both when the app is in front and when
   another is; keys only when it is in front, for which no permission is
   asked. Nothing while the window can't be seen. It also tells the person
   how far it is to the bottom of the window, and whether the window can be
   seen at all. */
private struct PointerWatch: NSViewRepresentable {
    let activity: Avatar.Activity
    let moved: (CGVector) -> Void
    let pressed: () -> Void

    func makeNSView(context: Context) -> Watcher {
        Watcher()
    }

    func updateNSView(_ view: Watcher, context: Context) {
        view.moved = moved
        view.pressed = pressed
        activity.watcher = view
    }

    final class Watcher: NSView {
        var moved: ((CGVector) -> Void)?
        var pressed: (() -> Void)?
        private var monitors: [Any] = []

        /// From its middle down to the bottom of the window, in points.
        var floor: CGFloat? {
            guard window != nil else { return nil }
            return convert(CGPoint(x: bounds.midX, y: bounds.midY), to: nil).y
        }

        var visible: Bool {
            window?.occlusionState.contains(.visible) == true
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            monitors.forEach(NSEvent.removeMonitor)
            monitors = []
            guard let window else { return }
            // or the window hears the pointer only over what tracks it
            window.acceptsMouseMovedEvents = true
            let moves: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged]
            if let local = NSEvent.addLocalMonitorForEvents(matching: moves.union([.keyDown, .scrollWheel]), handler: { [weak self] event in
                self?.seen(event)
                return event
            }) {
                monitors.append(local)
            }
            if let global = NSEvent.addGlobalMonitorForEvents(matching: moves, handler: { [weak self] event in
                self?.seen(event)
            }) {
                monitors.append(global)
            }
        }

        override func removeFromSuperview() {
            monitors.forEach(NSEvent.removeMonitor)
            monitors = []
            super.removeFromSuperview()
        }

        private func seen(_ event: NSEvent) {
            guard let window, visible else { return }
            if event.type == .keyDown || event.type == .scrollWheel {
                pressed?()
                return
            }
            let pointer = NSEvent.mouseLocation
            let middle = window.convertPoint(toScreen: convert(CGPoint(x: bounds.midX, y: bounds.midY), to: nil))
            // the screen's y goes up, the face's down
            moved?(CGVector(dx: pointer.x - middle.x, dy: middle.y - pointer.y))
        }
    }
}
