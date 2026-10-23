import AppKit

/* Draws the app's icon: a pixel owl, close in, cross-eyed and in a red bow
   tie, on white — shaded as if lit from the upper left, and lifted in
   layers — 1024 points square, for the phone app, the watch app and the Mac
   app alike.

       swift Tools/draw_icon.swift

   run from the top of the repository, writes it over both AppIcon.png files,
   and the Mac's ten sizes of it into the Mac's icon set (the Mac rounds the
   corners itself, as the phone does).
   The owl is a drawing of this project's own — a nod to the owl on the
   school's timetable app, and not a copy of it. It is made here rather than
   kept only as a picture so that it can be changed a square at a time: see
   `owl` for the drawing, `shade` for its light and `render` for its layers. */

// MARK: - plumbing

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 255) / 255, green: CGFloat((hex >> 8) & 255) / 255, blue: CGFloat(hex & 255) / 255, alpha: a)
}
/// A square bitmap `px` on a side, drawn in a 1024-point space with the origin top left.
func canvas(_ px: Int, smooth: Bool) -> CGContext {
    let c = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.translateBy(x: 0, y: CGFloat(px)); c.scaleBy(x: CGFloat(px) / 1024, y: -CGFloat(px) / 1024)
    c.setAllowsAntialiasing(smooth); c.setShouldAntialias(smooth)
    return c
}
func enlarged(_ image: CGImage, to px: Int = 1024) -> CGImage {
    let c = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .none
    c.draw(image, in: CGRect(x: 0, y: 0, width: px, height: px))
    return c.makeImage()!
}
func save(_ image: CGImage, _ name: String) {
    try! NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: name))
}


/// A picture made of squares, a part at a time, each with an edge one cell wide.
struct Sprite {
    let n: Int
    var cells: [[Character]]
    var dx = 0.0, dy = 0.0
    init(_ n: Int) { self.n = n; cells = Array(repeating: Array(repeating: ".", count: n), count: n) }
    mutating func part(_ ch: Character, edge: Bool = true, _ inside: (Double, Double) -> Bool) {
        var mask = Array(repeating: Array(repeating: false, count: n), count: n)
        for y in 0..<n { for x in 0..<n { mask[y][x] = inside(Double(x) + 0.5 - dx, Double(y) + 0.5 - dy) } }
        if edge {
            for y in 0..<n { for x in 0..<n where !mask[y][x] {
                let near = [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)].contains { $0.0 >= 0 && $0.0 < n && $0.1 >= 0 && $0.1 < n && mask[$0.1][$0.0] }
                if near { cells[y][x] = "N" }
            } }
        }
        for y in 0..<n { for x in 0..<n where mask[y][x] { cells[y][x] = ch } }
    }
    /// A part given cell by cell, with the same edge round it.
    mutating func block(_ ch: Character, _ at: [(Int, Int)]) {
        let set = at.map { ($0.0 + Int(dx), $0.1 + Int(dy)) }
        for (x, y) in set {
            for (ex, ey) in [(x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)]
            where ex >= 0 && ex < n && ey >= 0 && ey < n && !set.contains(where: { $0 == (ex, ey) }) {
                cells[ey][ex] = "N"
            }
        }
        for (x, y) in set where x >= 0 && x < n && y >= 0 && y < n { cells[y][x] = ch }
    }
    mutating func dots(_ ch: Character, _ at: [(Int, Int)]) {
        for (x, y) in at {
            let px = x + Int(dx), py = y + Int(dy)
            if px >= 0, px < n, py >= 0, py < n { cells[py][px] = ch }
        }
    }
}
func oval(_ cx: Double, _ cy: Double, _ rx: Double, _ ry: Double, turn: Double = 0) -> (Double, Double) -> Bool {
    let a = turn * .pi / 180
    return { x, y in
        let u = (x - cx) * cos(a) + (y - cy) * sin(a), v = -(x - cx) * sin(a) + (y - cy) * cos(a)
        return (u * u) / (rx * rx) + (v * v) / (ry * ry) <= 1
    }
}
func polygon(_ p: [(Double, Double)]) -> (Double, Double) -> Bool {
    { x, y in
        var inside = false
        var j = p.count - 1
        for i in 0..<p.count {
            if (p[i].1 > y) != (p[j].1 > y), x < (p[j].0 - p[i].0) * (y - p[i].1) / (p[j].1 - p[i].1) + p[i].0 { inside.toggle() }
            j = i
        }
        return inside
    }
}



// MARK: - the owl

/* The owl, on a grid of 32 with its middle on the line between the
   sixteenth cell and the seventeenth, so that its two halves match. The
   letters are colours: see `ink` below. */
func owl(_ s: inout Sprite) {
    // wings, feet and ears first, so the body is laid over where they join it
    s.part("w", oval(6.4, 21.5, 2.3, 5.4, turn: 10))
    s.part("w", oval(25.6, 21.5, 2.3, 5.4, turn: -10))
    s.part("O") { x, y in y > 30 && y < 31 && ((x > 11 && x < 14) || (x > 18 && x < 21)) }
    s.part("W", polygon([(7.2, 14), (6.2, 6.4), (13, 10.6)]))
    s.part("W", polygon([(24.8, 14), (25.8, 6.4), (19, 10.6)]))
    s.part("W", oval(16, 20.2, 9.3, 9.9))
    // the sockets, set a little down the face to leave a brow, and the eyes in them
    s.part("P", oval(11, 16, 4.2, 4.2))
    s.part("P", oval(21, 16, 4.2, 4.2))
    s.part("W", edge: false, oval(11, 16, 2.7, 2.7))
    s.part("W", edge: false, oval(21, 16, 2.7, 2.7))
    // cross-eyed: both pupils hard over against the beak
    s.dots("N", [(12, 15), (13, 15), (12, 16), (13, 16), (18, 15), (19, 15), (18, 16), (19, 16)])
    // the beak, wide at the top and coming to a point
    s.dots("O", [(14, 20), (15, 20), (16, 20), (17, 20), (15, 21), (16, 21)])

    /* The bow tie, cut as a butterfly: each wing five cells tall at its
       outer end and one where it meets the knot, the knot darker and taller
       than where they meet it, and the whole of it edged in the owl's own
       navy. The first bow was two blocks and a bar with no edge to it, and
       was hard to tell from a plaster. */
    let row = 24
    var wings: [(Int, Int)] = []
    for (i, tall) in [5, 5, 3, 3, 1].enumerated() {
        for y in (row - tall / 2)...(row + tall / 2) { wings.append((10 + i, y)); wings.append((21 - i, y)) }
    }
    let knot = [-1, 0, 1].flatMap { [(15, row + $0), (16, row + $0)] }
    s.block("T", wings + knot)
    s.dots("K", knot)
    // a crease in each wing
    s.dots("S", [(12, row), (19, row)])
}

// MARK: - depth

/* Light from the upper left. Each part is given a lit side and a side in
   shade, a cell at a time, by where the cell lies in the part: the body and
   the sockets as round things, darker toward the lower right; the eyes with
   the brow's shadow across the top and a glint in each pupil; the beak and
   the bow lit along the top and dark along the bottom. */
func shade(_ s: inout Sprite, bowRow row: Int) {
    for py in 0..<s.n { for px in 0..<s.n {
        let x = Double(px) + 0.5 - s.dx, y = Double(py) + 0.5 - s.dy
        let iy = py - Int(s.dy)
        func near(_ cx: Double, _ cy: Double, _ r: Double) -> Bool { (x - cx) * (x - cx) + (y - cy) * (y - cy) <= r * r }
        switch s.cells[py][px] {
        case "W":
            if near(11, 16, 2.7) || near(21, 16, 2.7) {
                if y < 14 { s.cells[py][px] = "e" }
            } else if y < 13.6 && (x < 14 || x > 18) {
                // the ears: the right-hand side of each
                if (x < 16 && x > 9.6) || x > 23.4 { s.cells[py][px] = "a" }
            } else {
                let t = (x - 16) / 9.3 * 0.75 + (y - 20.2) / 9.9 * 0.65
                if t > 0.8 { s.cells[py][px] = "b" } else if t > 0.5 { s.cells[py][px] = "a" }
            }
        case "P":
            let cx: Double = x < 16 ? 11 : 21
            let d = ((x - cx) + (y - 16)) / 4.2 * 0.707
            if d > 0.42 { s.cells[py][px] = "c" } else if d < -0.5 { s.cells[py][px] = "d" }
        case "O":
            if iy == 20 { s.cells[py][px] = "f" } else if iy == 21 { s.cells[py][px] = "g" }
        case "T":
            let up = py > 0 ? s.cells[py - 1][px] : "N", down = py < s.n - 1 ? s.cells[py + 1][px] : "N"
            if up == "N" && down != "N" { s.cells[py][px] = "h" } else if down == "N" && up != "N" { s.cells[py][px] = "i" }
        case "K":
            if iy == row - 1 { s.cells[py][px] = "j" } else if iy == row + 1 { s.cells[py][px] = "k" }
        case "w":
            if x > 16 || y > 23.5 { s.cells[py][px] = "l" }
        default: break
        }
    } }
}

let ink: [Character: UInt32] = [
    "N": 0x1B2A5E, "W": 0xFFFFFF, "P": 0xDDE7FF, "w": 0xC9D8FF, "O": 0xFFAA1E, "T": 0xDD2B3B, "K": 0x9C1A2A, "S": 0xBE2232,
    "a": 0xDDE5F7, "b": 0xC6D3EE, "c": 0xBCCDF7, "d": 0xEFF4FF, "e": 0xDFE7FA, "f": 0xFFC752, "g": 0xE58800,
    "h": 0xF4606C, "i": 0xB01D2C, "j": 0xB5243A, "k": 0x7C1220, "l": 0xA9BEF5,
]


/* The picture from its cells, in layers: the owl lifted off the page, and
   the sockets, the beak and the bow lifted off the owl, each with a soft
   shadow under it, as cut paper laid in layers would have. The shadows are
   the one thing here that is not squares. A glint goes in each pupil. */
func render(_ s: Sprite) -> CGImage {
    let c = canvas(1024, smooth: false)
    c.setFillColor(rgb(0xFFFFFF)); c.fill(CGRect(x: 0, y: 0, width: 1024, height: 1024))
    func edge(_ i: Int) -> CGFloat { (CGFloat(i) * 1024 / CGFloat(s.n)).rounded() }
    func frame(_ x: Int, _ y: Int) -> CGRect { CGRect(x: edge(x), y: edge(y), width: edge(x + 1) - edge(x), height: edge(y + 1) - edge(y)) }
    func cell(_ x: Int, _ y: Int) {
        guard let color = ink[s.cells[y][x]] else { return }
        let r = frame(x, y)
        c.setFillColor(rgb(color)); c.fill(r)
    }
    func layer(shadow: (CGSize, CGFloat, CGFloat)?, _ member: (Int, Int) -> Bool) {
        c.saveGState()
        if let shadow { c.setShadow(offset: shadow.0, blur: shadow.1, color: rgb(0x0B1640, shadow.2)) }
        c.beginTransparencyLayer(auxiliaryInfo: nil)
        for y in 0..<s.n { for x in 0..<s.n where s.cells[y][x] != "." && member(x, y) { cell(x, y) } }
        c.endTransparencyLayer()
        c.restoreGState()
    }
    func at(_ x: Int, _ y: Int) -> Character { x >= 0 && x < s.n && y >= 0 && y < s.n ? s.cells[y][x] : "." }
    let bowInk: Set<Character> = ["T", "K", "S", "h", "i", "j", "k"]
    layer(shadow: (CGSize(width: 0, height: -12), 30, 0.30)) { _, _ in true }
    do {
        // the sockets, with their rims
        func inSocket(_ px: Int, _ py: Int) -> Bool {
            let x: Double = Double(px) + 0.5 - s.dx, y: Double = Double(py) + 0.5 - s.dy
            let up: Double = (y - 16) * (y - 16), limit: Double = 4.2 * 4.2
            let left: Double = (x - 11) * (x - 11) + up, right: Double = (x - 21) * (x - 21) + up
            return left <= limit || right <= limit
        }
        layer(shadow: (CGSize(width: 5, height: -9), 16, 0.38)) { x, y in
            if inSocket(x, y) { return true }
            guard at(x, y) == "N" else { return false }
            return inSocket(x - 1, y) || inSocket(x + 1, y) || inSocket(x, y - 1) || inSocket(x, y + 1)
        }
        // the beak
        let beakInk: Set<Character> = ["O", "f", "g"]
        layer(shadow: (CGSize(width: 4, height: -8), 12, 0.40)) { x, y in beakInk.contains(at(x, y)) }
        // the bow, with its edge
        layer(shadow: (CGSize(width: 5, height: -10), 16, 0.40)) { x, y in
            let here: Character = at(x, y)
            if bowInk.contains(here) { return true }
            guard here == "N" else { return false }
            let around: [Character] = [at(x - 1, y), at(x + 1, y), at(x, y - 1), at(x, y + 1)]
            return around.contains { bowInk.contains($0) }
        }
    }
    // a glint in each pupil
    for (gx, gy) in [(12, 15), (18, 15)] {
        let r = frame(gx + Int(s.dx), gy + Int(s.dy))
        c.setFillColor(rgb(0xFFFFFF))
        c.fill(CGRect(x: r.minX + r.width * 0.16, y: r.minY + r.height * 0.16, width: r.width * 0.42, height: r.height * 0.42))
    }
    return c.makeImage()!
}

// MARK: - the icon

/* Close in: on a grid of 24 the owl, drawn for 32, runs off the sides and
   the bottom — the wings are cut by the icon's edges, and it is the face
   that fills it. The bow sits where its lower edge is the last row in view. */
func icon() -> CGImage {
    var s = Sprite(24)
    s.dx = -4; s.dy = -4
    owl(&s)
    shade(&s, bowRow: 24)
    return render(s)
}

/// The icon drawn down to `px` on a side, smoothly, for the Mac's smaller sizes.
func reduced(_ image: CGImage, to px: Int) -> CGImage {
    let c = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.interpolationQuality = .high
    c.draw(image, in: CGRect(x: 0, y: 0, width: px, height: px))
    return c.makeImage()!
}

/* A target is a PNG to write the icon to, or an icon set (the Mac's), which
   is given the 16, 32, 128, 256 and 512 point sizes at 1x and 2x, named as
   its Contents.json names them. */
let targets = CommandLine.arguments.count > 1 ? Array(CommandLine.arguments.dropFirst())
    : ["App/Assets.xcassets/AppIcon.appiconset/AppIcon.png", "Watch/Assets.xcassets/AppIcon.appiconset/AppIcon.png",
       "Mac/Assets.xcassets/AppIcon.appiconset"]
let drawn = icon()
for target in targets {
    if target.hasSuffix(".appiconset") {
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                save(reduced(drawn, to: points * scale), "\(target)/icon_\(points)x\(points)\(scale == 2 ? "@2x" : "").png")
            }
        }
    } else {
        save(drawn, target)
    }
}
