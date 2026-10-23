import AppKit
import SwiftUI

/* The Mac's boxes, which can be moved about as the phone's can: press and
   hold one and it lifts off the page with a tap on the trackpad, follows the
   pointer, and the others slide out of its way; let go and it settles into
   the gap. Two columns while the window is wide, and a box can go from one
   to the other; one column while it is narrow, the left's boxes over the
   right's. The order is kept (`MacLayout`).

   As on the phone, what moves under the pointer is a copy drawn over the
   page, and the real box stays where it is, unseen, holding its gap open,
   so the page reflows by ordinary layout. The columns are one layout of
   all five boxes (`BoxColumns`) rather than a stack each, so a box keeps
   itself when it crosses from one column to the other and glides there
   instead of going out of one and coming into the other. */
enum MacBox: String, CaseIterable, Identifiable {
    case now, holiday, homework, days, timetable

    var id: Self { self }
}

/// Which boxes are in which column, top to bottom, as kept in the
/// defaults: "now,holiday,homework|days,timetable".
struct MacLayout: RawRepresentable, Equatable {
    var columns: [[MacBox]]

    static let standard = MacLayout(columns: [[.now, .holiday, .homework], [.days, .timetable]])
    static let key = "macBoxes"

    init(columns: [[MacBox]]) {
        self.columns = columns
    }

    init?(rawValue: String) {
        let saved = rawValue.split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.split(separator: ",").compactMap { MacBox(rawValue: String($0)) } }
        guard saved.count == 2 else { return nil }
        var seen = Set<MacBox>()
        var columns = saved.map { $0.filter { seen.insert($0).inserted } }
        // a box new since the order was kept goes at the end of the column it starts in
        for box in MacBox.allCases where !seen.contains(box) {
            columns[Self.standard.column(of: box) ?? 0].append(box)
        }
        self.columns = columns
    }

    var rawValue: String {
        columns.map { $0.map(\.rawValue).joined(separator: ",") }.joined(separator: "|")
    }

    func column(of box: MacBox) -> Int? {
        columns.firstIndex { $0.contains(box) }
    }
}

struct BoxBoard<Box: View>: View {
    @Binding var layout: MacLayout
    let twoColumns: Bool
    let leftWidth: CGFloat
    let spacing: CGFloat
    /// A box as it sits on the page; and, `lifted`, as it is carried.
    @ViewBuilder let box: (MacBox, _ lifted: Bool) -> Box

    /// Where each box sits, in the board's own coordinates.
    @State private var frames: [MacBox: CGRect] = [:]
    @State private var lift: Lift?
    @State private var raised = false

    private struct Lift {
        let id: MacBox
        /// The box's frame when it was picked up, and how far the pointer
        /// has carried it since.
        let frame: CGRect
        var moved = CGSize.zero
        /// Set on letting go: the gap the copy goes back to.
        var landing: CGRect?

        var carried: CGRect { frame.offsetBy(dx: moved.width, dy: moved.height) }
    }

    private let space = "box-board"

    private struct Placed: Identifiable {
        let box: MacBox
        let column: Int
        var id: MacBox { box }
    }

    var body: some View {
        let order = twoColumns ? layout.columns : [layout.columns.flatMap { $0 }]
        // one list of all the boxes, each told its column: in a list of its own for each column,
        // a box would be a new one in the column it went to
        let placed = order.enumerated().flatMap { column, boxes in boxes.map { Placed(box: $0, column: column) } }
        BoxColumns(twoColumns: twoColumns, leftWidth: leftWidth, spacing: spacing) {
            ForEach(placed) { placed in
                let id = placed.box
                box(id, false)
                    .opacity(lift?.id == id ? 0 : 1)
                    .overlay {
                        if lift?.id == id {
                            RoundedRectangle(cornerRadius: 26)
                                .strokeBorder(.tertiary, style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                        }
                    }
                    .onGeometryChange(for: CGRect.self) { proxy in
                        proxy.frame(in: .named(space))
                    } action: { frame in
                        frames[id] = frame
                    }
                    // the whole box takes the press, not only what is drawn in it
                    .contentShape(.rect(cornerRadius: 26))
                    .simultaneousGesture(holdAndDrag(id))
                    .layoutValue(key: BoxColumn.self, value: placed.column)
            }
        }
        .overlay(alignment: .topLeading) {
            if let lift {
                let shown = lift.landing ?? lift.carried
                box(lift.id, true)
                    .frame(width: shown.width)
                    .fixedSize(horizontal: false, vertical: true)
                    .scaleEffect(raised ? 1.03 : 1)
                    .shadow(color: .black.opacity(raised ? 0.25 : 0), radius: 24, y: 12)
                    .offset(x: shown.minX, y: shown.minY)
                    .allowsHitTesting(false)
                    .onAppear {
                        withAnimation(.snappy(duration: 0.2)) { raised = true }
                    }
            }
        }
        .coordinateSpace(.named(space))
        // a tap on the trackpad as a box lifts, and a lighter one each time the others make way
        .sensoryFeedback(.levelChange, trigger: lift?.id) { _, lifted in lifted != nil }
        .sensoryFeedback(.alignment, trigger: layout)
    }

    /* Held still for a moment, a box lifts; then it goes where the pointer
       does. Alongside whatever is in the box, not instead of it, so a click
       on a class or a day is still a click. */
    private func holdAndDrag(_ id: MacBox) -> some Gesture {
        LongPressGesture(minimumDuration: 0.3, maximumDistance: 8)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(space)))
            .onChanged { value in
                guard case .second(true, let drag) = value else { return }
                if lift == nil, let frame = frames[id] { pick(id, frame) }
                guard lift?.id == id, lift?.landing == nil, let drag else { return }
                lift?.moved = drag.translation
                makeWay()
            }
            .onEnded { _ in
                if lift?.id == id, lift?.landing == nil { drop() }
            }
    }

    private func pick(_ id: MacBox, _ frame: CGRect) {
        raised = false
        lift = Lift(id: id, frame: frame)
        NSCursor.closedHand.push()
    }

    /* Moves the gap to where the carried box now belongs. Across the
       middle of the page it goes into the other column, where the boxes
       above its top edge stay above it. In its own column it goes up past
       every box whose middle its top edge has crossed, or down past every
       box whose middle its bottom edge has: the boxes are very different
       heights, and middle past middle had the day's card needing to be
       carried half its length before the picker made way. */
    private func makeWay() {
        guard let lift, let from = layout.column(of: lift.id) else { return }
        let carried = lift.carried
        let to = twoColumns ? (carried.midX < leftWidth + spacing / 2 ? 0 : 1) : from
        var next = layout
        if to == from {
            var boxes = next.columns[from]
            // one column shows both, the left's boxes over the right's: work in that order
            if !twoColumns { boxes = next.columns.flatMap { $0 } }
            guard let at = boxes.firstIndex(of: lift.id) else { return }
            var index = at
            while index > 0, let above = frames[boxes[index - 1]], carried.minY < above.midY { index -= 1 }
            if index == at {
                while index < boxes.count - 1, let below = frames[boxes[index + 1]], carried.maxY > below.midY { index += 1 }
            }
            guard index != at else { return }
            boxes.move(fromOffsets: IndexSet(integer: at), toOffset: index > at ? index + 1 : index)
            if twoColumns {
                next.columns[from] = boxes
            } else {
                // back into the two columns, each keeping as many boxes as it had
                let split = next.columns[0].count
                next.columns = [Array(boxes.prefix(split)), Array(boxes.dropFirst(split))]
            }
        } else {
            next.columns[from].removeAll { $0 == lift.id }
            let index = next.columns[to].filter { (frames[$0]?.midY ?? .infinity) < carried.minY }.count
            next.columns[to].insert(lift.id, at: index)
        }
        withAnimation(.snappy(duration: 0.3)) { layout = next }
    }

    /// The copy goes to the gap, and only then gives way to the real box.
    private func drop() {
        guard let id = lift?.id else { return }
        NSCursor.pop()
        withAnimation(.snappy(duration: 0.28)) {
            lift?.landing = frames[id] ?? lift?.frame
            raised = false
        } completion: {
            // a box picked up again in the meantime has no landing yet
            if lift?.landing != nil { lift = nil }
        }
    }
}

/// Which column a box is in: 0, the left, or 1, the right.
private struct BoxColumn: LayoutValueKey {
    static let defaultValue = 0
}

/// The boxes in one column, or in two side by side, each column's boxes
/// stacked in the order they come.
private struct BoxColumns: Layout {
    let twoColumns: Bool
    let leftWidth: CGFloat
    let spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? leftWidth * 2 + spacing
        return CGSize(width: width, height: frames(width: width, subviews: subviews).height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placed = frames(width: bounds.width, subviews: subviews)
        for (subview, frame) in zip(subviews, placed.frames) {
            subview.place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                          proposal: ProposedViewSize(width: frame.width, height: frame.height))
        }
    }

    private func frames(width: CGFloat, subviews: Subviews) -> (frames: [CGRect], height: CGFloat) {
        var bottom: [CGFloat?] = [nil, nil]
        var frames: [CGRect] = []
        for subview in subviews {
            let column = twoColumns ? min(1, max(0, subview[BoxColumn.self])) : 0
            let x = column == 0 ? 0 : leftWidth + spacing
            let w = twoColumns ? (column == 0 ? leftWidth : width - leftWidth - spacing) : width
            let h = subview.sizeThatFits(ProposedViewSize(width: w, height: nil)).height
            let top = bottom[column].map { $0 + spacing } ?? 0
            frames.append(CGRect(x: x, y: top, width: w, height: h))
            bottom[column] = top + h
        }
        return (frames, max(bottom[0] ?? 0, bottom[1] ?? 0))
    }
}
