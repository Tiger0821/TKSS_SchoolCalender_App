import SwiftUI

/* How each block looks, shared by the app and the widgets so a subject is the
   same colour everywhere. */

/* One colour of the palette: a tone for light backgrounds and a tone for
   dark ones, each as 0xRRGGBB.

   The subjects were in the system's own colours once, and on the dark page
   those came out neon — and its green, teal, mint and cyan, three of which
   one person has on the same day, near enough the same. These are picked for
   the job instead, the way the timetable apps and the palettes that are good
   at it go about it: a named tone to a subject, all kept to much the same
   lightness and strength so none shouts, spaced round the wheel so that no
   two which meet are neighbours, and each with a deeper tone of its own for
   light backgrounds, where a pastel does not read as text. */
struct Tone: Sendable {
    let light: UInt32
    let dark: UInt32

    static let vermilion = Tone(light: 0xC34517, dark: 0xF58967)
    static let amber = Tone(light: 0xA76C01, dark: 0xFDBD69)
    static let lime = Tone(light: 0x6B8316, dark: 0xC7E18A)
    static let leaf = Tone(light: 0x0A7E3A, dark: 0x7CCD8E)
    static let jade = Tone(light: 0x098777, dark: 0x8CE5D3)
    static let lagoon = Tone(light: 0x00707D, dark: 0x58C3D2)
    static let powder = Tone(light: 0x2368BD, dark: 0xA9CDFF)
    static let iris = Tone(light: 0x5550C0, dark: 0x989EF8)
    static let orchid = Tone(light: 0x8C399E, dark: 0xDDA1EA)
    static let rose = Tone(light: 0xC33E77, dark: 0xFAA9C4)
    /// The two that are hardly colours: Guidance, and IB Core and the breaks.
    static let sand = Tone(light: 0x795D3C, dark: 0xD5B898)
    static let slate = Tone(light: 0x616A75, dark: 0xAAB2BD)
    /// Lunch.
    static let butter = Tone(light: 0x93770E, dark: 0xF6DD90)

    /// The tone for whichever background is up.
    var color: Color {
        #if canImport(UIKit) && !os(watchOS)
        Color(uiColor: UIColor { [light, dark] traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: Self.part(hex, 16), green: Self.part(hex, 8), blue: Self.part(hex, 0), alpha: 1)
        })
        #elseif os(macOS)
        Color(nsColor: NSColor(name: nil) { [light, dark] appearance in
            let hex = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? dark : light
            return NSColor(srgbRed: Self.part(hex, 16), green: Self.part(hex, 8), blue: Self.part(hex, 0), alpha: 1)
        })
        #else
        // the watch is always dark
        onDark
        #endif
    }

    /// The tone for a dark background whatever the phone is set to, for what
    /// is drawn on black regardless: the Lock Screen's day and the island.
    var onDark: Color {
        Color(.sRGB, red: Self.part(dark, 16), green: Self.part(dark, 8), blue: Self.part(dark, 0))
    }

    private static func part(_ hex: UInt32, _ shift: UInt32) -> Double {
        Double((hex >> shift) & 0xFF) / 255
    }
}

extension Timetable {
    /* Classes that are alternatives to each other share a colour, since
       nobody has two of them; classes one person can have together don't. */
    static func tone(for subject: String) -> Tone {
        func any(_ prefixes: String...) -> Bool { prefixes.contains { subject.hasPrefix($0) } }
        return switch subject {
        case _ where any("DP Chi"): .vermilion
        case _ where any("DP Eng"): .powder
        case "Eng Lit": .iris
        case _ where any("DP MA"): .amber
        case _ where any("DP Comp. Sc.", "DP ESS"): .lagoon
        case _ where any("DP Chem"): .lime
        case _ where any("DP Econ", "DP History", "DP Psych"): .leaf
        case _ where any("DP Bus Man", "DP Bio", "DP Physics", "DP V. Arts"): .jade
        case _ where any("DP TOK"): .orchid
        case core: .slate
        case let s where s.hasPrefix("G:") || s == "Guidance": .sand
        default: .rose   // the clubs
        }
    }

    static func tint(for subject: String) -> Color {
        tone(for: subject).color
    }

    /// A name for tight spaces: "G: Weekly Alignment" is "Weekly Alignment".
    static func shortName(_ subject: String) -> String {
        var s = displayName(subject)
        if s.hasPrefix("G: ") { s = String(s.dropFirst(3)) }
        if let bracket = s.firstIndex(of: "[") { s = String(s[..<bracket]).trimmingCharacters(in: .whitespaces) }
        return s
    }
}

extension Segment {
    var tint: Color {
        switch kind {
        case .lessons(let items): Timetable.tint(for: items[0].subject)
        case .gap(let label): (label == "Lunch" ? Tone.butter : .slate).color
        }
    }

    var shortTitle: String {
        switch kind {
        case .lessons(let items): items.map { Timetable.shortName($0.subject) }.joined(separator: " or ")
        case .gap(let label): label
        }
    }

    var symbol: String {
        switch kind {
        case .lessons(let items) where items[0].subject == Timetable.core: "graduationcap"
        case .lessons: "book.closed"
        case .gap("Lunch"): "fork.knife"
        case .gap("Break"): "cup.and.saucer"
        case .gap: "leaf"
        }
    }
}

extension Segment {
    /* Four letters or so, for the middle of a circular widget and the
       Dynamic Island. A subject whose name cuts down well is cut down — the
       first word of it, to four letters: Chem, Bio, Phys, Hist, Econ — and
       the rest are given here. It was once a list of one person's subjects
       with "Club" for anything else, so Chemistry was "Club" in the island.

       The Live Activity goes by these in telling a double period from two
       classes in a row, so classes one person can take together must not
       share one. A revision class does share its subject's. */
    var abbreviation: String {
        guard let subject = lessons.first?.subject else { return title }
        switch subject {
        case let s where s.hasPrefix("DP Chi"): return "Chi"
        case let s where s.hasPrefix("DP Eng A"): return "EngA"
        case let s where s.hasPrefix("DP Eng B"): return "EngB"
        case "Eng Lit": return "Lit"
        case let s where s.hasPrefix("DP MA"): return "Math"
        case "DP Comp. Sc.": return "CS"
        case "DP Bus Man": return "BM"
        case let s where s.hasPrefix("DP V. Arts"): return "Art"
        case let s where s.hasPrefix("DP Psych"): return "Psy"
        case let s where s.hasPrefix("DP TOK"): return "TOK"
        case Timetable.core: return "Core"
        case let s where s.hasPrefix("G:") || s == "Guidance": return "G"
        case let s where s.hasSuffix("Clubs"): return "Club"
        default: return String(Timetable.shortName(subject).prefix { $0 != " " }.prefix(4))
        }
    }
}
