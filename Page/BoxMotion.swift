import SwiftUI

/* How the boxes move while one is carried, on the phone and the Mac alike
   (`ReorderableStack`, `BoxBoard`), after the Home Screen's own editing.
   The one picked up grows a little and takes a shadow, holds still, and
   goes wherever the hand does. The rest wobble where they are (`Jiggle`),
   and slide smoothly out of its way, with hardly any give, as the Home
   Screen's icons make room. Let go, it glides into its gap and settles
   back to its size, and the others stand still again.

   Apple's numbers are not published, and the simulator's Home Screen does
   not draw its wobble to be measured; the wobble is the one worked out by
   watching it, as Kirupa's study of it has it: a turn of about a degree
   one way and a degree and a half the other, a beat of a quarter to a
   third of a second, about a point near the top, every icon a little out
   of step with the next. */
enum BoxMotion {
    /// The others sliding out of the way.
    static let slide = Animation.spring(duration: 0.4, bounce: 0.1)
    /// The one let go, into its gap.
    static let land = Animation.spring(duration: 0.35, bounce: 0.15)
    /// The one picked up growing and taking its shadow.
    static let lift = Animation.spring(duration: 0.25, bounce: 0.2)
    /// How much bigger the one carried is.
    static let lifted: CGFloat = 1.04
}

/// A box wobbling where it is. An icon turns about a degree and a half;
/// a box many times its size would swing a long way at its far corners
/// at that, so each turns as far as moves its farthest corner as far as an
/// icon's goes, about a point and a half.
struct Jiggle: ViewModifier {
    let active: Bool
    /// Which box: each beats a little differently, about a point of its own,
    /// and every other one starts the other way.
    let seed: Int
    @State private var size = CGSize.zero

    func body(content: Content) -> some View {
        let odd = !seed.isMultiple(of: 2)
        // turned about a point near the top, so it swings below as if hung there
        let pivot = odd ? UnitPoint(x: 0.3, y: 0.05) : UnitPoint(x: 0.5, y: 0.1)
        let reach = max(1, hypot(size.width * max(pivot.x, 1 - pivot.x), size.height * (1 - pivot.y)))
        let degree = asin(min(1, 1.5 / reach)) * 180 / .pi / 1.5
        // a beat of a quarter to a third of a second
        let beat = 0.22 + 0.11 * Double((seed * 7) % 11) / 10
        let way: Double = odd ? -1 : 1
        content
            .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
            .keyframeAnimator(initialValue: 0.0, repeating: active) { view, turn in
                // stopped, it stands straight: the keyframes stop where they are
                view.rotationEffect(.degrees(active ? turn * degree : 0), anchor: pivot)
            } keyframes: { _ in
                KeyframeTrack {
                    CubicKeyframe(way * 1.5, duration: beat * 0.25)
                    CubicKeyframe(-way, duration: beat * 0.5)
                    CubicKeyframe(0, duration: beat * 0.25)
                }
            }
    }
}
