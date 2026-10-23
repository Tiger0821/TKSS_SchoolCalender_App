import SwiftUI

/* The sky behind the page, as pixel art, filling the background with the
   weather outside the way Weather does: sun or moon, stars, clouds on the
   wind, rain, snow, fog and lightning, over a line of hills. It is painted
   small — one pixel of it is about four and a half points across — into a
   frame of plain bytes fifteen times a second, then scaled up unsmoothed so
   every pixel stays square. Nothing here is an image file; each scene is
   worked out from the weather and the clock. */

/// What to paint.
struct SkyScene: Equatable {
    var sky: Sky
    var phase: DayPhase
    /// km/h: pushes the clouds along and leans the rain.
    var wind: Double
}

// MARK: - Pixels

/// One pixel, its bytes in the order the image reads them.
struct Pixel: Equatable {
    var r: UInt8
    var g: UInt8
    var b: UInt8
    var spare: UInt8 = 255

    init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(_ hex: UInt32) {
        self.init(r: UInt8(hex >> 16 & 0xFF), g: UInt8(hex >> 8 & 0xFF), b: UInt8(hex & 0xFF))
    }

    /// Part of the way towards another colour.
    func mixed(_ other: Pixel, _ amount: Double) -> Pixel {
        let t = min(1, max(0, amount))
        func mix(_ from: UInt8, _ to: UInt8) -> UInt8 { UInt8((Double(from) + (Double(to) - Double(from)) * t).rounded()) }
        return Pixel(r: mix(r, other.r), g: mix(g, other.g), b: mix(b, other.b))
    }
}

/* The frame the sky is painted into, in the sky's own pixels. Under each
   of those are two finer ones side by side, so that a cloud can stand half
   a pixel over and drift on in steps half as long (`blendHalf`): whole
   pixels, a step at a time, a slow cloud stood still and then hopped. Only
   across, as the clouds only move across; finer both ways was four times
   the pixels to hand the screen thirty times a second, for nothing anyone
   would see. Everything else is painted a whole pixel at a time, as before.
   Writes that land off its edges are dropped. */
struct PixelCanvas {
    let width: Int
    let height: Int
    /// Finer pixels to one of the sky's, side by side.
    static let fine = 2
    private let fineWidth: Int
    private var pixels: [Pixel]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        fineWidth = width * Self.fine
        pixels = Array(repeating: Pixel(0), count: fineWidth * height)
    }

    subscript(x: Int, y: Int) -> Pixel {
        get { pixels[y * fineWidth + x * Self.fine] }
        set {
            guard x >= 0, x < width, y >= 0, y < height else { return }
            for dx in 0..<Self.fine { pixels[y * fineWidth + x * Self.fine + dx] = newValue }
        }
    }

    /// Lay a colour over what is there, part way.
    mutating func blend(_ x: Int, _ y: Int, _ color: Pixel, _ amount: Double) {
        guard x >= 0, x < width else { return }
        blendHalf(x * Self.fine, y, color, amount)
    }

    /// The same over a whole pixel's worth of the finer grid from the finer
    /// column `fx`: half a pixel over, where that is odd.
    mutating func blendHalf(_ fx: Int, _ y: Int, _ color: Pixel, _ amount: Double) {
        guard y >= 0, y < height else { return }
        for dx in 0..<Self.fine {
            let x = fx + dx
            guard x >= 0, x < fineWidth else { continue }
            pixels[y * fineWidth + x] = amount >= 1 ? color : pixels[y * fineWidth + x].mixed(color, amount)
        }
    }

    /// Every finer pixel, to keep a painted sky and start the next frame from it.
    fileprivate var all: [Pixel] {
        get { pixels }
        set { if newValue.count == pixels.count { pixels = newValue } }
    }

    var image: CGImage? {
        let data = pixels.withUnsafeBytes { Data($0) }
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        return CGImage(width: fineWidth, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: fineWidth * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB)!,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }
}

/// A fixed scatter: the same number, from 0 up to 1, every time for the same
/// seed. It puts each star, cloud and raindrop where it was last frame.
private func scatter(_ seed: Int) -> Double {
    var x = UInt64(truncatingIfNeeded: seed) &* 0x9E37_79B9_7F4A_7C15
    x ^= x >> 31
    x &*= 0xBF58_476D_1CE4_E5B9
    x ^= x >> 29
    return Double(x >> 11) / Double(1 << 53)
}

/// The ordered-dither pattern: a threshold from 0 to 1 for each pixel, in a
/// four by four tile. Stippling one colour into the next against it is what
/// keeps the sky to a few flat colours.
private let ditherTile: [Double] = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5].map { ($0 + 0.5) / 16 }

private func threshold(_ x: Int, _ y: Int) -> Double {
    ditherTile[(y & 3) * 4 + (x & 3)]
}

// MARK: - Colours

private enum Mood {
    case fair, grey, wet, snow
}

private extension Sky {
    var mood: Mood {
        switch self {
        case .clear, .mostlyClear, .partlyCloudy: .fair
        case .overcast, .fog, .drizzle: .grey
        case .rain, .heavyRain, .thunderstorm: .wet
        case .snow: .snow
        }
    }
}

/* The top of every sky is dark enough for the date to be read in white over
   it; the pale colours are kept to the horizon, behind the boxes. */
private struct SkyPalette {
    /// The top of the sky, the middle, and the horizon.
    let sky: [Pixel]
    /// A cloud's lit rim, its body, and its underside.
    let cloud: [Pixel]
    /// The far hills, the near ones, and the pines on them.
    let land: [Pixel]

    init(_ scene: SkyScene) {
        let hex: [UInt32] = switch (scene.sky.mood, scene.phase) {
        case (.fair, .day): [0x1B58A6, 0x3D84D6, 0x8FC6F2, 0xFFFFFF, 0xE6F0FA, 0xB4CBE4, 0x3E8E5C, 0x2E7049, 0x1F5236]
        case (.fair, .twilight): [0x2A2D72, 0xB0567C, 0xF6A65E, 0xFFE3C7, 0xF0B4A3, 0xB07397, 0x4A3B6B, 0x33284F, 0x231B39]
        case (.fair, .night): [0x060A22, 0x101843, 0x242D66, 0x55608F, 0x3A4472, 0x262E55, 0x141F3A, 0x0D1528, 0x080E1C]
        case (.grey, .day): [0x4A5A6E, 0x6F8196, 0xA9B7C4, 0xD5DCE4, 0xB4BECA, 0x8D99A8, 0x4F6B5C, 0x3C5548, 0x2B3F35]
        case (.grey, .twilight): [0x3A3550, 0x6D5A70, 0xB08A84, 0xC9B4B8, 0xA08C98, 0x74667A, 0x3D3550, 0x2B2640, 0x1D1A2E]
        case (.grey, .night): [0x0C1018, 0x1A212E, 0x2D3644, 0x3A4352, 0x2A3240, 0x1C222D, 0x121A22, 0x0C1218, 0x070B10]
        case (.wet, .day): [0x2F3B4D, 0x4A5A70, 0x74869B, 0x8A97A8, 0x6B788A, 0x4E596A, 0x3A5247, 0x2A3D34, 0x1D2B25]
        case (.wet, .twilight): [0x29283D, 0x47435C, 0x766A7A, 0x7A7388, 0x5A546A, 0x3F3B4E, 0x2C2A3E, 0x1F1D2E, 0x151420]
        case (.wet, .night): [0x070A12, 0x111722, 0x222B3A, 0x2C3442, 0x1F2632, 0x151A24, 0x0E141B, 0x090E13, 0x05080C]
        case (.snow, .day): [0x5C6F8A, 0x8CA0BA, 0xCBD8E6, 0xF4F7FB, 0xDCE4EE, 0xB6C2D2, 0xF1F5FA, 0xD5DFEA, 0x3A5247]
        case (.snow, .twilight): [0x3B3A5E, 0x7A6F8E, 0xC7A9A8, 0xE6D9DE, 0xC2B2C0, 0x8F829A, 0xE3DCE6, 0xC1B8CC, 0x3A3550]
        case (.snow, .night): [0x0E1424, 0x1E2A45, 0x3A4A6C, 0x4A5878, 0x36425F, 0x252E47, 0xAEBBD3, 0x8494B3, 0x1A2438]
        }
        let colors = hex.map { Pixel($0) }
        sky = Array(colors[0..<3])
        cloud = Array(colors[3..<6])
        land = Array(colors[6..<9])
    }
}

// MARK: - Clouds

/// A cloud as a small tile of tones: 0 for nothing, then 1 its sunlit top,
/// 2 where the light falls off, 3 its body and 4 its shaded underside.
private struct CloudSprite {
    let width: Int
    let height: Int
    let tones: [UInt8]
    /// 0 small, 1 middling, 2 big: which depth of the sky it belongs to.
    let size: Int

    /// Nine, three to a size, so no two clouds in a row look alike.
    static let all: [CloudSprite] = [(16, 7), (19, 8), (22, 9), (28, 11), (32, 12), (36, 14), (42, 16), (48, 18), (54, 20)]
        .enumerated().map { CloudSprite(width: $0.element.0, height: $0.element.1, seed: $0.offset + 1, size: $0.offset / 3) }

    /* Built the way a cumulus is: a flat base with a row of small puffs
       along it, and bigger ones heaped on top somewhere off the middle. Then
       lit like cotton, from the upper left as the app's icon is: each pixel
       takes the light of the puff it is deepest inside, as if that puff were
       a ball, a little less where two puffs meet, and less again towards the
       base. The light is cut into four tones, stippled where one gives way to
       the next, as the sky's own bands are. */
    init(width: Int, height: Int, seed: Int, size: Int) {
        let w = Double(width), h = Double(height)
        let base = h
        var puffs: [(x: Double, y: Double, r: Double)] = []
        let along = max(3, width / 5)
        for i in 0..<along {
            let r = h * (0.22 + 0.16 * scatter(seed * 97 + i))
            let x = min(max((Double(i) + 0.5) / Double(along) * w, r), w - r)
            puffs.append((x: x, y: base - r * 0.55, r: r))
        }
        let heaps = 1 + Int(scatter(seed * 31) * 2.99)
        let middle = 0.35 + 0.3 * scatter(seed * 37)
        for j in 0..<heaps {
            let r = h * (0.46 + 0.16 * scatter(seed * 41 + j))
            let x = min(max((middle + (Double(j) - Double(heaps - 1) / 2) * 0.24) * w, r), w - r)
            let y = max(r + 0.2, base - r * (1.0 + 0.25 * scatter(seed * 43 + j)))
            puffs.append((x: x, y: y, r: r))
        }
        // the underside, flat from the first small puff to the last
        let slab = (from: puffs[0].x, to: puffs[along - 1].x, rows: max(2, height / 5))

        /// How far inside each puff a point is, 0 at its edge and 1 at its middle.
        func depths(_ cx: Double, _ cy: Double) -> [Double] {
            puffs.map { puff in
                let dx = cx - puff.x, dy = cy - puff.y
                return 1 - (dx * dx + dy * dy).squareRoot() / puff.r
            }
        }
        func inside(_ x: Int, _ y: Int) -> Bool {
            guard x >= 0, x < width, y >= 0, y < height else { return false }
            if y >= height - slab.rows, Double(x) + 0.5 >= slab.from, Double(x) + 0.5 <= slab.to { return true }
            return depths(Double(x) + 0.5, Double(y) + 0.5).contains { $0 >= 0 }
        }

        // the light: from the upper left, and towards whoever is looking
        let light = (x: -0.55, y: -0.75, z: 0.55)
        let length = (light.x * light.x + light.y * light.y + light.z * light.z).squareRoot()
        var tones = [UInt8](repeating: 0, count: width * height)
        for y in 0..<height {
            for x in 0..<width where inside(x, y) {
                let cx = Double(x) + 0.5, cy = Double(y) + 0.5
                let all = depths(cx, cy)
                let owner = all.indices.max { all[$0] < all[$1] }!
                let puff = puffs[owner]
                let nx = (cx - puff.x) / puff.r, ny = (cy - puff.y) / puff.r
                let nz = max(0, 1 - nx * nx - ny * ny).squareRoot()
                let lambert = max(0, (nx * light.x + ny * light.y + nz * light.z) / length)
                // the puff's own roundness, and the whole cloud's: lit at the top, shaded at the base
                var lit = 0.12 + 0.48 * lambert + 0.42 * (1 - cy / h)
                // the creases, where one puff gives way to another
                let rest = all.enumerated().filter { $0.offset != owner }.map(\.element).max() ?? -1
                if rest > -0.05, all[owner] < 0.25 { lit -= 0.08 }
                let stippled = lit + (threshold(x, y) - 0.5) * 0.16
                var tone: UInt8 = stippled > 0.74 ? 1 : stippled > 0.52 ? 2 : stippled > 0.3 ? 3 : 4
                // the bottom row is always in shade, and nothing above it is lit
                if y == height - 1 || !inside(x, y + 1) { tone = 4 }
                tones[y * width + x] = tone
            }
        }
        self.width = width
        self.height = height
        self.tones = tones
        self.size = size
    }
}

// MARK: - The painter

struct SkyPainter {
    let scene: SkyScene
    let width: Int
    let height: Int
    /// The middle of the sun or moon.
    let bodyX: Int
    let bodyY: Int
    /// The first row the clouds may use, so they stay out from behind the date.
    let cloudTop: Int
    /// Painted once and left as it is: no lightning.
    var still = false

    /// The sky's bands as last painted, and what for: they are the same from
    /// one frame to the next, and painting them was most of a frame's work.
    @MainActor private static var bands: (key: String, pixels: [Pixel])?

    @MainActor
    func paint(at time: Double) -> PixelCanvas {
        let palette = SkyPalette(scene)
        var canvas = PixelCanvas(width: width, height: height)
        let key = "\(scene.sky.rawValue) \(scene.phase.rawValue) \(width)x\(height)"
        if let bands = Self.bands, bands.key == key {
            canvas.all = bands.pixels
        } else {
            paintSky(&canvas, palette)
            Self.bands = (key, canvas.all)
        }
        if scene.sky.mood == .fair {
            if scene.phase == .night {
                paintStars(&canvas, time)
                paintMoon(&canvas)
            } else {
                paintSun(&canvas, time)
            }
        }
        paintClouds(&canvas, palette, time)
        paintHills(&canvas, palette)
        switch scene.sky {
        case .fog:
            paintFog(&canvas, time)
        case .drizzle, .rain, .heavyRain:
            paintRain(&canvas, time)
        case .thunderstorm:
            paintRain(&canvas, time)
            if !still { paintLightning(&canvas, time) }
        case .snow:
            paintSnow(&canvas, time)
        default:
            break
        }
        return canvas
    }

    /* Sixteen flat bands from the top colour through the middle to the
       horizon, each stippled into the next. Not in straight rows, nor by the
       dither's pattern, which laid the stipple out as neat as a chequered
       cloth: the edge between two bands wanders up and down across the sky
       in a slow wave, and each pixel's turn from one shade to the next is
       left to chance. */
    private func paintSky(_ canvas: inout PixelCanvas, _ palette: SkyPalette) {
        let bands = 16
        let shades = (0..<bands).map { band -> Pixel in
            let t = Double(band) / Double(bands - 1)
            return t < 0.5 ? palette.sky[0].mixed(palette.sky[1], t * 2) : palette.sky[1].mixed(palette.sky[2], t * 2 - 1)
        }
        for y in 0..<height {
            for x in 0..<width {
                let wave = 1.8 * sin(Double(x) * 0.07 + Double(y) * 0.05) + 1.1 * sin(Double(x) * 0.19 + 2.1)
                    + 0.6 * sin(Double(x) * 0.41 + Double(y) * 0.13 + 0.7)
                let along = min(max(0, (Double(y) + wave) / Double(max(1, height - 1)) * Double(bands - 1)), Double(bands - 1))
                let band = min(Int(along), bands - 2)
                let into = along - Double(band)
                let chance = scatter(x &* 73_856_093 ^ y &* 19_349_663 ^ 0x5bd1e995)
                canvas[x, y] = shades[into > chance ? band + 1 : band]
            }
        }
    }

    private func paintStars(_ canvas: inout PixelCanvas, _ time: Double) {
        let star = Pixel(0xE8ECFF)
        let thinning = scene.sky == .partlyCloudy ? 300 : 150
        for i in 0..<(width * height / thinning) {
            let x = Int(scatter(i * 4 + 1) * Double(width))
            let y = Int(scatter(i * 4 + 2) * Double(height) * 0.75)
            let twinkle = sin(time * (0.5 + 1.5 * scatter(i * 4 + 3)) + scatter(i * 4 + 4) * 2 * .pi)
            if twinkle < -0.6 { continue }   // winks out for a moment
            let big = i % 9 == 0
            canvas.blend(x, y, star, big ? 1 : 0.5 + 0.3 * twinkle)
            if big && twinkle > 0.3 {
                for (dx, dy) in [(-1, 0), (1, 0), (0, -1), (0, 1)] { canvas.blend(x + dx, y + dy, star, 0.35) }
            }
        }
    }

    /// A disc in three tones with a stippled glow, and by day eight rays, the
    /// long ones and the short ones swapping places. At twilight it is low and
    /// orange and has none.
    private func paintSun(_ canvas: inout PixelCanvas, _ time: Double) {
        let low = scene.phase == .twilight
        let core = Pixel(low ? 0xFFD9A0 : 0xFFF6C2), body = Pixel(low ? 0xFF9A4A : 0xFFD94A)
        // the glow is the sky's own colour lifted, since yellow stippled over blue only goes grey
        let rim = Pixel(low ? 0xF2673A : 0xFFB52E), glow = Pixel(low ? 0xFFC08A : 0xBFE1FF)
        let r = 7, reach = 15
        for dy in -reach...reach {
            for dx in -reach...reach {
                let x = bodyX + dx, y = bodyY + dy
                let d2 = dx * dx + dy * dy
                if d2 <= r * r + r {
                    // the highlight sits up and to the left
                    let lit = (dx + 2) * (dx + 2) + (dy + 2) * (dy + 2)
                    canvas[x, y] = lit <= 10 ? core : d2 <= (r - 1) * (r - 1) ? body : rim
                } else {
                    let fade = 1 - (Double(d2).squareRoot() - Double(r)) / Double(reach - r)
                    if fade > threshold(x, y) { canvas.blend(x, y, glow, 0.3) }
                }
            }
        }
        guard !low else { return }
        let beat = Int(time / 0.8) % 2
        let ray = Pixel(0xFFE27A)
        for k in 0..<8 {
            let angle = Double(k) * .pi / 4
            for step in (r + 3)..<(r + (k % 2 == beat ? 7 : 5)) {
                canvas[bodyX + Int((cos(angle) * Double(step)).rounded()), bodyY + Int((sin(angle) * Double(step)).rounded())] = ray
            }
        }
    }

    /// A crescent: a disc with a second one, up and to the right, bitten out of it.
    private func paintMoon(_ canvas: inout PixelCanvas) {
        let body = Pixel(0xF2EFD8), shade = Pixel(0xCFCBB0), glow = Pixel(0xAEB9E8)
        let r = 6, reach = 14
        for dy in -reach...reach {
            for dx in -reach...reach {
                let x = bodyX + dx, y = bodyY + dy
                let d2 = dx * dx + dy * dy
                let bite = (dx - 4) * (dx - 4) + (dy + 3) * (dy + 3)
                if d2 <= r * r + r {
                    if bite > 30 { canvas[x, y] = bite < 46 ? shade : body }
                } else {
                    let fade = 1 - (Double(d2).squareRoot() - Double(r)) / Double(reach - r)
                    if fade * 0.7 > threshold(x, y) { canvas.blend(x, y, glow, 0.22) }
                }
            }
        }
    }

    /* The clouds, at three depths: far ones small, slow and a little hazy,
       near ones big and quicker; all of them solid, as see-through clouds
       looked like ghosts. The far ones are painted first, so the near ones
       pass in front. */
    private func paintClouds(_ canvas: inout PixelCanvas, _ palette: SkyPalette, _ time: Double) {
        let count: Int
        switch scene.sky {
        case .clear: count = 0
        case .mostlyClear: count = 3
        case .partlyCloudy, .fog: count = 7
        case .drizzle, .rain, .snow: count = 13
        case .overcast, .heavyRain, .thunderstorm: count = 17
        }
        let colors = [palette.cloud[0], palette.cloud[0].mixed(palette.cloud[1], 0.5), palette.cloud[1], palette.cloud[2]]
        // a narrow sky, the watch's, keeps to clouds that fit it
        let sprites = CloudSprite.all.filter { $0.width <= max(18, width / 2) }
        // the rows the clouds ride in, counted down from the first they may use: two
        // in the strip of open sky under the date, the rest behind the boxes
        let lanes = [1, 12, 27, 42, 58, 76]
        let push = min(4, 0.6 + scene.wind / 15)
        // far and near drift at further apart speeds, so they overtake each other
        let depthSpeed = [0.4, 0.72, 1.1]
        // every cloud solid: a far one is only a little hazier, the sky's colour mixed into its own
        let haze = [0.2, 0.08, 0.0]
        let tinted = haze.map { amount in colors.map { $0.mixed(palette.sky[1], amount) } }
        for i in (0..<count).sorted(by: { $0 % 3 < $1 % 3 }) {
            let depth = i % 3
            let fitting = sprites.filter { $0.size == depth }
            let choices = fitting.isEmpty ? sprites : fitting
            let sprite = choices[min(choices.count - 1, Int(scatter(i * 5 + 4) * Double(choices.count)))]
            let top = cloudTop + lanes[i % lanes.count] + Int(scatter(i * 5 + 1) * 4) - sprite.height / 3
            // and each its own pace within that, some nearly four times another's
            let speed = (0.4 + 1.2 * scatter(i * 5 + 2)) * push * depthSpeed[depth]
            // off the right edge, round again from the left
            let span = Double(width + sprite.width + 12)
            let along = (scatter(i * 5 + 3) * span + time * speed).truncatingRemainder(dividingBy: span) - Double(sprite.width)
            // where it is to the half pixel: it moves on in steps half as long as the sky's pixels
            let fine = PixelCanvas.fine
            let left = Int((along * Double(fine)).rounded(.down))
            for row in 0..<sprite.height {
                for col in 0..<sprite.width {
                    let tone = sprite.tones[row * sprite.width + col]
                    if tone > 0 { canvas.blendHalf(left + col * fine, top + row, tinted[depth][Int(tone) - 1], 1) }
                }
            }
        }
    }

    /// Two ridges along the bottom, and a few pines on the nearer one.
    private func paintHills(_ canvas: inout PixelCanvas, _ palette: SkyPalette) {
        let tall = Double(height)
        func far(_ x: Int) -> Int { max(0, Int(0.075 * tall + 3.5 * sin(Double(x) * 0.07 + 1.3) + 2 * sin(Double(x) * 0.19 + 0.4))) }
        func near(_ x: Int) -> Int { max(0, Int(0.045 * tall + 2.5 * sin(Double(x) * 0.11 + 4) + 1.5 * sin(Double(x) * 0.27))) }
        for x in 0..<width {
            for y in (height - far(x))..<height { canvas[x, y] = palette.land[0] }
            for y in (height - near(x))..<height { canvas[x, y] = palette.land[1] }
        }
        for i in 0..<(width / 12) {
            let x = Int(scatter(i * 3 + 700) * Double(width))
            let foot = height - near(x)
            for row in 0..<6 {
                for dx in -(row / 2)...(row / 2) { canvas[x + dx, foot - 6 + row] = palette.land[2] }
            }
        }
    }

    /// Streaks leaning with the wind: few, short and slow for drizzle; many,
    /// long and fast for a downpour.
    private func paintRain(_ canvas: inout PixelCanvas, _ time: Double) {
        let drop = Pixel(scene.phase == .night ? 0x9DB4D2 : 0xCFE0F2)
        let (thinning, length, fall): (Int, Int, Double) = switch scene.sky {
        case .drizzle: (420, 2, 55)
        case .rain: (200, 3, 95)
        default: (110, 4, 120)
        }
        let lean = min(0.7, 0.12 + scene.wind / 70)
        let drift = Double(height) * lean
        let run = Double(height + 2 * length)
        for i in 0..<(width * height / thinning) {
            let speed = fall * (0.8 + 0.5 * scatter(i * 3 + 1))
            let y = (scatter(i * 3 + 2) * run + time * speed).truncatingRemainder(dividingBy: run) - Double(length)
            // starting far enough left that the lean still reaches the left edge at the bottom
            let x = scatter(i * 3 + 3) * (Double(width) + drift) - drift + y * lean
            for k in 0..<length {
                canvas.blend(Int((x - Double(k) * lean).rounded(.down)), Int(y.rounded(.down)) - k, drop, 0.7 - 0.15 * Double(k))
            }
        }
    }

    /// Flakes swaying on their way down, the near ones bigger and quicker.
    private func paintSnow(_ canvas: inout PixelCanvas, _ time: Double) {
        let flake = Pixel(0xFFFFFF)
        let run = Double(height + 4)
        for i in 0..<(width * height / 240) {
            let near = i % 4 == 0
            let speed = (near ? 15 : 8) * (0.8 + 0.4 * scatter(i * 4 + 1))
            let y = Int((scatter(i * 4 + 2) * run + time * speed).truncatingRemainder(dividingBy: run)) - 2
            let sway = sin(time * (0.4 + 0.6 * scatter(i * 4 + 3)) + Double(i)) * (near ? 3 : 1.5)
            let across = scatter(i * 4 + 4) * Double(width) + sway + time * scene.wind / 12
            let x = Int(across.truncatingRemainder(dividingBy: Double(width)))
            canvas.blend(x, y, flake, near ? 1 : 0.7)
            if near {
                canvas.blend(x + 1, y, flake, 1)
                canvas.blend(x, y + 1, flake, 1)
                canvas.blend(x + 1, y + 1, flake, 1)
            }
        }
    }

    /// Long banks of mist, thickest along the middle and thinner at the
    /// edges, drifting below the date.
    private func paintFog(_ canvas: inout PixelCanvas, _ time: Double) {
        let mist = Pixel(scene.phase == .night ? 0x5A6677 : 0xE3E9EE)
        for i in 0..<(height / 12) {
            let wide = 34 + Int(scatter(i * 5 + 1) * 44)
            let deep = 5 + Int(scatter(i * 5 + 2) * 4)
            let top = cloudTop + Int(scatter(i * 5 + 3) * Double(height - cloudTop))
            let span = Double(width + wide)
            let left = Int((scatter(i * 5 + 4) * span + time * (0.5 + scatter(i * 5 + 5))).truncatingRemainder(dividingBy: span)) - wide
            for row in 0..<deep {
                // each row is shorter the further it is from the middle one
                let off = abs(Double(row) - Double(deep - 1) / 2) / (Double(deep) / 2)
                let inset = Int(off * off * Double(wide) * 0.3)
                for col in inset..<(wide - inset) {
                    let edge = row == 0 || row == deep - 1 || col < inset + 2 || col >= wide - inset - 2
                    canvas.blend(left + col, top + row, mist, edge ? 0.16 : 0.32)
                }
            }
        }
    }

    /// A bolt every seven seconds or so: two quick flickers of the same
    /// zigzag, and the whole sky lifting a little with the first.
    private func paintLightning(_ canvas: inout PixelCanvas, _ time: Double) {
        let gap = 7.0
        let strike = Int(time / gap)
        let since = time - Double(strike) * gap - scatter(strike * 7 + 1) * (gap - 1)
        guard (0..<0.12).contains(since) || (0.2..<0.32).contains(since) else { return }
        let bolt = Pixel(0xFFF7C2)
        var x = 12 + Int(scatter(strike * 7 + 2) * Double(max(1, width - 24)))
        var y = cloudTop + 10
        let foot = y + 45 + Int(scatter(strike * 7 + 3) * 45)
        var side = scatter(strike * 7 + 4) > 0.5 ? 1 : -1
        var leg = 0
        while y < foot {
            canvas[x, y] = bolt
            canvas[x + 1, y] = bolt
            y += 1
            leg += 1
            x += side * (leg % 2)   // down two for every one across
            if leg >= 6 + Int(scatter(strike * 31 + y) * 5) {
                side = -side
                leg = 0
            }
        }
        if since < 0.08 {
            let white = Pixel(0xFFFFFF)
            for row in 0..<height {
                for col in 0..<width { canvas.blend(col, row, white, 0.14) }
            }
        }
    }
}

// MARK: - The view

struct PixelSky: View {
    let scene: SkyScene
    /// The strip of open sky under the date, in points from the top left of
    /// the screen: the sun or moon goes at its right-hand end, and the clouds
    /// start at its top.
    let window: CGRect

    @Environment(\.displayScale) private var displayScale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    #if os(macOS)
    /* Whether Timetable is the app in use: behind another app, the sky goes
       on at a few frames a second, as nobody is watching it closely. The
       app and not the window, as the window's own state counted a sheet
       over it — setup — as being elsewhere, and the sky under it slowed.
       Mission Control counts as another app, the Dock's, though the window
       is there to be looked at; so there the sky goes at its full rate
       whatever this says (`SkyView`). */
    @State private var appActive = NSApplication.shared.isActive
    #endif

    /// Frames a second while the sky is being looked at.
    private static let fullRate: Double = 15

    private var frameRate: Double {
        #if os(macOS)
        if !appActive { return 4 }
        #endif
        return Self.fullRate
    }

    var body: some View {
        GeometryReader { proxy in
            // one pixel of the scene is a whole number of the screen's own
            let pixel = (4.5 * displayScale).rounded() / displayScale
            let strip = window.isEmpty ? CGRect(x: 0, y: 150, width: proxy.size.width, height: 112) : window
            let painter = SkyPainter(scene: scene,
                                     width: max(8, Int((proxy.size.width / pixel).rounded(.up))),
                                     height: max(8, Int((proxy.size.height / pixel).rounded(.up))),
                                     bodyX: Int((strip.maxX - 64) / pixel), bodyY: Int((strip.midY - 6) / pixel),
                                     cloudTop: Int((strip.minY / pixel).rounded(.up)), still: reduceMotion)
            // with Reduce Motion on, one frame is painted and left
            let still = reduceMotion || scenePhase != .active
            #if os(watchOS)
            // fifteen frames a second: the clouds' smoothness is in their half-pixel steps (PixelCanvas),
            // as even the quickest moves a few pixels a second; thirty only doubled the work
            TimelineView(SkyFrames(paused: still, rate: frameRate)) { context in
                if let image = painter.paint(at: context.date.timeIntervalSinceReferenceDate).image {
                    Image(decorative: image, scale: 1)
                        .interpolation(.none)
                        .resizable()
                        .frame(width: CGFloat(painter.width) * pixel, height: CGFloat(painter.height) * pixel)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
            #else
            SkyLayer(painter: painter, pixel: pixel, rate: still ? 0 : frameRate, fullRate: still ? 0 : Self.fullRate)
                .frame(width: proxy.size.width, height: proxy.size.height)
            #endif
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
        #if os(macOS)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            appActive = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            appActive = false
        }
        #endif
    }
}

#if !os(watchOS)
#if os(macOS)
typealias PlatformView = NSView
typealias PlatformRepresentable = NSViewRepresentable
#else
typealias PlatformView = UIView
typealias PlatformRepresentable = UIViewRepresentable
#endif

/* The sky's frames put straight onto a layer of their own, by a timer of
   their own. Shown through SwiftUI, each new frame was a new image in the
   page, and the whole window — every box, every pane of glass — was worked
   out again with it: a third of one of a Mac's cores, where a sky held
   still left the app at one per cent. On a layer, SwiftUI is not told. */
struct SkyLayer: PlatformRepresentable {
    let painter: SkyPainter
    /// Points to one of the sky's pixels.
    let pixel: CGFloat
    /// Frames a second; nought for one frame, left still.
    let rate: Double
    /// Frames a second when it is looked at whatever app is in use: under
    /// Mission Control.
    let fullRate: Double

    #if os(macOS)
    func makeNSView(context: Context) -> SkyView { SkyView() }
    func updateNSView(_ view: SkyView, context: Context) { view.show(painter, pixel: pixel, rate: rate, fullRate: fullRate) }
    static func dismantleNSView(_ view: SkyView, coordinator: ()) { view.stop() }
    #else
    func makeUIView(context: Context) -> SkyView { SkyView() }
    func updateUIView(_ view: SkyView, context: Context) { view.show(painter, pixel: pixel, rate: rate, fullRate: fullRate) }
    static func dismantleUIView(_ view: SkyView, coordinator: ()) { view.stop() }
    #endif
}

final class SkyView: PlatformView {
    /// The painted frame, scaled up unsmoothed so every pixel stays square.
    private let picture = CALayer()
    private var painter: SkyPainter?
    /// Frames a second as asked for, and as the timer goes: nought while
    /// the sky is held still.
    private var rate = 0.0
    private var fullRate = 0.0
    private var running = 0.0
    private var timer: Timer?
    /// The sky's own clock: the time, less however long it has been held
    /// still, so it goes on from where it stopped rather than jumping ahead.
    private var held: TimeInterval = 0
    private var heldSince: Date?
    #if os(macOS)
    /// Looks every so often for Mission Control over the window (`look`).
    private var lookout: Timer?
    private var dock: NSRunningApplication?
    /// How wide the window is drawn under Mission Control, at its smallest,
    /// and whether it has grown back from that: Mission Control is going.
    private var shrunk: CGFloat?
    private var leaving = false
    /// Since when Mission Control has been up over the window.
    private var coveredSince: Date?
    #endif

    init() {
        super.init(frame: .zero)
        #if os(macOS)
        wantsLayer = true
        layer?.masksToBounds = true
        layer?.addSublayer(picture)
        #else
        isUserInteractionEnabled = false
        layer.masksToBounds = true
        layer.addSublayer(picture)
        #endif
        picture.anchorPoint = .zero
        picture.contentsGravity = .resize
        picture.magnificationFilter = .nearest
    }

    required init?(coder: NSCoder) { fatalError("made in code") }

    #if os(macOS)
    // from the top left, as the frame is painted; and nothing here is to be clicked
    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        keepLookout()
    }
    #endif

    func show(_ painter: SkyPainter, pixel: CGFloat, rate: Double, fullRate: Double) {
        self.painter = painter
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        picture.frame = CGRect(x: 0, y: 0, width: CGFloat(painter.width) * pixel, height: CGFloat(painter.height) * pixel)
        CATransaction.commit()
        self.rate = rate
        self.fullRate = fullRate
        #if os(macOS)
        keepLookout()
        #endif
        keepTime()
        paint()
    }

    /// Sets the timer going at the rate asked for, or stops it while the
    /// sky is held still.
    private func keepTime() {
        var wanted = rate
        #if os(macOS)
        // shown under Mission Control, it is being looked at, though the Dock is the app in use
        if coveredSince != nil, rate > 0 { wanted = max(rate, fullRate) }
        #endif
        if heldSince != nil { wanted = 0 }
        guard wanted != running || (wanted > 0 && timer == nil) else { return }
        timer?.invalidate()
        timer = nil
        running = wanted
        guard wanted > 0 else { return }
        let timer = Timer(timeInterval: 1 / wanted, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.paint() }
        }
        timer.tolerance = 0.2 / wanted
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func hold(_ still: Bool) {
        guard still != (heldSince != nil) else { return }
        if let heldSince {
            held += Date.now.timeIntervalSince(heldSince)
            self.heldSince = nil
        } else {
            heldSince = .now
        }
        keepTime()
    }

    private func paint() {
        let time = (heldSince ?? .now).timeIntervalSinceReferenceDate - held
        guard let image = painter?.paint(at: time).image else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        picture.contents = image
        CATransaction.commit()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        #if os(macOS)
        lookout?.invalidate()
        lookout = nil
        #endif
    }

    #if os(macOS)
    /* Under Mission Control and App Exposé the window is one small picture
       among the others. Its sky goes on there as it does anywhere — the
       person wanted to see it moving in the picture — but left there three
       minutes it is held still, and goes on from where it stopped once the
       window is back. Nothing tells a window they have come up: what shows
       it is the Dock's own window, put up over the whole screen and so over
       this one (Launchpad's is the same). So while the sky is going, the
       windows in front of this one are looked through for the Dock's —
       about a seventh of a millisecond, where all the screen's windows took
       twenty times as long — four times a second, and twenty while the sky
       is held. It is let go as soon as the window starts to grow back to
       its own size: the Dock's window stays on to the end, and waiting for
       it, the sky came back still for half a second. */
    private static let watching: TimeInterval = 0.25
    private static let closely: TimeInterval = 0.05
    /// How long under Mission Control before the sky is held.
    private static let patience: TimeInterval = 180

    private func keepLookout() {
        let wanted = window != nil && rate > 0
        guard wanted != (lookout != nil) else { return }
        settle(covered: false)
        look(every: wanted ? Self.watching : nil)
    }

    private func look(every interval: TimeInterval?) {
        lookout?.invalidate()
        lookout = nil
        guard let interval else { return }
        let lookout = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.look() }
        }
        lookout.tolerance = interval / 5
        RunLoop.main.add(lookout, forMode: .common)
        self.lookout = lookout
    }

    private func look() {
        guard let window, window.windowNumber > 0, let main = NSScreen.screens.first else { return }
        if dock?.isTerminated ?? true {
            dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first
        }
        guard let dock = dock?.processIdentifier else { return }
        let id = CGWindowID(window.windowNumber)
        // the window's middle, from the top left of the main screen, as the window server counts
        let middle = CGPoint(x: window.frame.midX, y: main.frame.height - window.frame.midY)
        let over = CGWindowListCopyWindowInfo([.optionOnScreenAboveWindow, .excludeDesktopElements], id) as? [[String: Any]] ?? []
        let covered = over.contains { info in
            (info[kCGWindowOwnerPID as String] as? NSNumber)?.int32Value == dock
                && Self.bounds(of: info)?.contains(middle) == true
        }
        if covered, let drawn = (CGWindowListCopyWindowInfo(.optionIncludingWindow, id) as? [[String: Any]])?.first
            .flatMap(Self.bounds(of:))?.width {
            // a tenth wider than it was at its smallest: on its way back
            if let shrunk, drawn > shrunk * 1.1 { leaving = true }
            shrunk = min(shrunk ?? drawn, drawn)
        }
        settle(covered: covered)
    }

    private func settle(covered: Bool) {
        if covered {
            if coveredSince == nil { coveredSince = .now }
        } else {
            coveredSince = nil
            shrunk = nil
            leaving = false
        }
        let waited = coveredSince.map { Date.now.timeIntervalSince($0) >= Self.patience } ?? false
        hold(covered && waited && !leaving)
        // up to the full rate as Mission Control comes, and back as it goes
        keepTime()
        // closely only while it is held, to let it go the moment Mission Control goes
        let interval = heldSince != nil ? Self.closely : Self.watching
        if let lookout, lookout.timeInterval != interval { look(every: interval) }
    }

    private static func bounds(of info: [String: Any]) -> CGRect? {
        (info[kCGWindowBounds as String] as? NSDictionary).flatMap { CGRect(dictionaryRepresentation: $0) }
    }
    #endif
}
#endif

/* The sky's frames on the watch, where there is no layer to hand them to:
   fifteen a second, by the clock, or none at all while it is to keep still. An animation schedule asked for at fifteen still woke
   the window at every refresh of the screen — a hundred and twenty times a
   second on a Mac's — to see whether a frame was due, and that came to more
   than painting the frames did. */
struct SkyFrames: TimelineSchedule {
    var paused: Bool
    /// Frames a second.
    var rate: Double

    func entries(from start: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var next = start
        let paused = paused, step = 1 / rate
        return AnyIterator {
            guard !paused else { return nil }
            defer { next = next.addingTimeInterval(step) }
            return next
        }
    }
}

#Preview("Thunderstorm at night") {
    PixelSky(scene: SkyScene(sky: .thunderstorm, phase: .night, wind: 40), window: .zero)
}

#Preview("Partly cloudy day") {
    PixelSky(scene: SkyScene(sky: .partlyCloudy, phase: .day, wind: 9), window: .zero)
}
