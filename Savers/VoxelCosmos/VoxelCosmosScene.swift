import AppKit
import QuartzCore

/// Small, deterministic voxel sculptures, painted once per camera angle. Animation
/// composites cached sprites at a bounded pixel resolution; no assets or network.
final class VoxelCosmosScene: SaverScene {
    private var settings = CosmosSettings()
    private var motion = MotionClock()
    private var tour = MotionClock()
    private var running = false
    private var sprites: [String: CGImage] = [:]
    private var sky: CGImage?
    private var skySize = CGSize.zero
    private var buffer: CGContext?
    private var bufferSize = CGSize.zero
    private var currentImage: CGImage?
    private var outgoing: CGImage?
    private var transitionStart = 0.0
    private var shotIndex = 0
    private var renderedShot = -1
    private var caption = CALayer()
    private var captionKey = ""
    private let picture = CALayer()
    private let dissolve = CALayer()
    private(set) var activeView = CosmosView.solarSystem
    static let planetNames = ["Mercury", "Venus", "Earth", "Mars", "Jupiter", "Saturn", "Uranus", "Neptune"]

    func start() { guard !running else { return }; running = true; motion.pause(); tour.pause() }
    func stop() { running = false; motion.pause(); tour.pause(); outgoing = nil; dissolve.contents = nil }
    func apply(_ value: SaverSettings) {
        let next = value.cosmos.sanitized()
        if next.background != settings.background || next.starDensity != settings.starDensity { sky = nil }
        if next.angle != settings.angle || next.glow != settings.glow { sprites.removeAll() }
        if next.view != settings.view || next.angle != settings.angle {
            tour = MotionClock(); shotIndex = 0; renderedShot = -1; outgoing = nil
        }
        settings = next; captionKey = ""
    }
    static func renderSize(_ size: CGSize, pixelSize: Double) -> CGSize {
        let scale = min(1 / pixelSize, 800 / max(1, size.width), 600 / max(1, size.height))
        return CGSize(width: max(1, ceil(size.width * scale)), height: max(1, ceil(size.height * scale)))
    }
    private func advance(_ time: Double) {
        if running {
            motion.step(now: time, speed: settings.speed, maximumStep: 0.1)
            tour.step(now: time, speed: 1, maximumStep: .infinity)
        }
        // Fixed subjects can still be explored from changing viewpoints.
        shotIndex = (settings.view == .tour || settings.angle == .roaming) ? Int(tour.elapsed / settings.secondsPerView) : 0
        activeView = settings.view == .tour ? CosmosView.itinerary[shotIndex % CosmosView.itinerary.count] : settings.view
        if renderedShot != shotIndex {
            outgoing = currentImage; transitionStart = time; renderedShot = shotIndex
            sprites.removeAll(keepingCapacity: true); captionKey = ""
        }
    }
    private var elevation: Double {
        switch settings.angle {
        case .classic: return 0.61548
        case .low: return 0.32
        case .high: return 0.95
        case .roaming: return [0.61548, 0.42, 0.78, 0.52][shotIndex % 4]
        }
    }
    private var yaw: Double { settings.angle == .roaming ? [0.78, 0.38, 1.08, 0.64][shotIndex % 4] : .pi / 4 }
    private func hash(_ x: Int, _ y: Int, _ z: Int = 0) -> Double {
        var n = UInt64(bitPattern: Int64(x &* 374761393 &+ y &* 668265263 &+ z &* 1442695041))
        n = (n ^ (n >> 13)) &* 1274126177; n ^= n >> 16
        return Double(n % 65536) / 65535
    }
    private func color(_ r: Double, _ g: Double, _ b: Double, _ a: Double = 1) -> CGColor {
        NSColor(srgbRed: min(1, max(0, r)), green: min(1, max(0, g)), blue: min(1, max(0, b)), alpha: a).cgColor
    }
    private func surface(_ planet: Int, _ x: Int, _ y: Int, _ z: Int) -> (Double, Double, Double) {
        let noise = hash(x, y, z), band = sin(Double(z) * 1.7 + sin(Double(x) * 0.45) * 0.8)
        switch planet {
        case -1: return noise > 0.76 ? (1, 0.93, 0.62) : (1, 0.57 + noise * 0.25, 0.22)
        case 0: return (0.48 + noise * 0.24, 0.44 + noise * 0.22, 0.51 + noise * 0.2)
        case 1: return (0.91, 0.63 + band * 0.12, 0.36 + band * 0.08)
        case 2:
            if abs(z) > 8 || noise > 0.90 { return (0.76, 0.94, 0.90) }
            let land = sin(Double(x) * 0.58 + sin(Double(z) * 0.8)) + cos(Double(y) * 0.63 + Double(z) * 0.35)
            return land > 0.48 ? (0.24, 0.64 + noise * 0.2, 0.47) : (0.10, 0.38 + noise * 0.13, 0.70 + noise * 0.13)
        case 3: return (0.77 + noise * 0.15, 0.30 + noise * 0.15, 0.24 + noise * 0.07)
        case 4:
            if x > 1 && x < 7 && z < 1 && z > -4 && y > 4 { return (0.78, 0.30, 0.24) }
            return band > 0.25 ? (0.87, 0.73, 0.55) : (0.65 + noise * 0.14, 0.41 + noise * 0.10, 0.31)
        case 5: return (0.90, 0.76 + band * 0.09, 0.47 + band * 0.10)
        case 6: return (0.36 + noise * 0.08, 0.79 + band * 0.05, 0.80 + noise * 0.08)
        case 7: return (0.23, 0.38 + band * 0.06, 0.83 + noise * 0.10)
        default: return (0.54 + noise * 0.18, 0.57 + noise * 0.15, 0.65 + noise * 0.15)
        }
    }
    private func sprite(_ planet: Int) -> CGImage {
        let key = String(planet)
        if let image = sprites[key] { return image }
        let c = bitmap(width: 240, height: 200)!
        c.setShouldAntialias(false)
        halo(c, at: CGPoint(x: 120, y: 100), radius: 31, rgb: surface(planet, 0, 4, 6), strength: planet == -1 ? 0.9 : 0.26)
        let unit = 3.0, a = yaw, e = elevation
        func project(_ x: Double, _ y: Double, _ z: Double) -> CGPoint {
            CGPoint(x: 120 + (x * cos(a) - y * sin(a)) * unit,
                    y: 100 + (z * cos(e) - (x * sin(a) + y * cos(a)) * sin(e)) * unit)
        }
        struct Voxel { let x: Int; let y: Int; let z: Int; let ring: Bool; let depth: Double }
        var voxels: [Voxel] = []
        func inside(_ x: Int, _ y: Int, _ z: Int) -> Bool { x*x + y*y + z*z <= 100 }
        for z in -10...10 { for y in -10...10 { for x in -10...10 {
            if inside(x,y,z) && (!inside(x+1,y,z) || !inside(x,y+1,z) || !inside(x,y,z+1)) {
                let depth = (Double(x) * sin(a) + Double(y) * cos(a)) * cos(e) + Double(z) * sin(e)
                voxels.append(Voxel(x: x, y: y, z: z, ring: false, depth: depth))
            }
        } } }
        if planet == 5 || planet == 6 {
            for y in -23...23 { for x in -23...23 {
                let r = hypot(Double(x), Double(y))
                if r > 14 && r < 23 && (r < 18.5 || r > 20) && hash(x, y) > 0.08 {
                    let z = planet == 6 ? x / 2 : 0
                    let depth = (Double(x) * sin(a) + Double(y) * cos(a)) * cos(e) + Double(z) * sin(e)
                    voxels.append(Voxel(x: x, y: y, z: z, ring: true, depth: depth))
                }
            } }
        }
        voxels.sort { $0.depth < $1.depth }
        for v in voxels {
            let x = Double(v.x), y = Double(v.y), z = Double(v.z)
            let rgb = v.ring ? (0.62 + hash(v.x,v.y) * 0.28, 0.56 + hash(v.x,v.y) * 0.25, 0.48 + hash(v.x,v.y) * 0.22) : surface(planet, v.x, v.y, v.z)
            let shade = planet == -1 ? 1 : 0.58 + 0.42 * max(0, (-x * 0.3 + y * 0.5 + z * 0.8) / 10)
            let h = v.ring ? 0.28 : 0.5
            func face(_ vertices: [(Double, Double, Double)], _ light: Double) {
                c.beginPath()
                for (i,p) in vertices.enumerated() {
                    let point = project(p.0,p.1,p.2)
                    if i == 0 { c.move(to: point) } else { c.addLine(to: point) }
                }
                c.closePath(); c.setFillColor(color(rgb.0 * shade * light, rgb.1 * shade * light, rgb.2 * shade * light)); c.fillPath()
            }
            face([(x+0.5,y-0.5,z-h),(x+0.5,y+0.5,z-h),(x+0.5,y+0.5,z+h),(x+0.5,y-0.5,z+h)], 0.66)
            face([(x-0.5,y+0.5,z-h),(x+0.5,y+0.5,z-h),(x+0.5,y+0.5,z+h),(x-0.5,y+0.5,z+h)], 0.82)
            face([(x-0.5,y-0.5,z+h),(x+0.5,y-0.5,z+h),(x+0.5,y+0.5,z+h),(x-0.5,y+0.5,z+h)], 1.15)
        }
        let image = c.makeImage()!; sprites[key] = image; return image
    }
    private func makeSky(_ size: CGSize) -> CGImage {
        let c = bitmap(width: Int(size.width), height: Int(size.height))!
        c.setFillColor(color(0.018, 0.024, 0.065)); c.fill(CGRect(origin: .zero, size: size))
        if settings.background == .void { c.setFillColor(NSColor.black.cgColor); c.fill(CGRect(origin: .zero, size: size)) }
        if settings.background == .nebula || settings.background == .aurora {
            // Spatially stable dithering: luminous dust without temporal noise.
            for y in stride(from: 0, to: Int(size.height), by: 2) { for x in stride(from: 0, to: Int(size.width), by: 2) {
                let u = Double(x) / size.width, v = Double(y) / size.height
                let wave = 0.52 + 0.18 * sin(u * 7) + 0.08 * sin(u * 19)
                let cloud = exp(-pow((v-wave) * 5, 2)) * (0.4 + 0.6 * hash(x/2,y/2))
                let strength = cloud * (settings.background == .aurora ? 0.19 : 0.13)
                c.setFillColor(settings.background == .aurora ? color(0.12,0.65,0.58,strength) : color(0.46,0.27,0.72,strength))
                c.fill(CGRect(x: x, y: y, width: 2, height: 2))
            } }
        }
        if settings.background != .void {
            let count = Int(size.width * size.height / 260 * settings.starDensity)
            for i in 0..<max(0,count) {
                let x = floor(hash(i,17) * size.width), y = floor(hash(i,39) * size.height), bright = hash(i,67)
                c.setFillColor(color(0.58 + bright * 0.35, 0.72 + bright * 0.25, 1, 0.18 + bright * 0.65))
                c.fill(CGRect(x: x, y: y, width: 1, height: 1))
                if bright > 0.983 {
                    c.setFillColor(color(0.58,0.77,1,0.25))
                    c.fill(CGRect(x: x-2, y: y, width: 5, height: 1)); c.fill(CGRect(x: x, y: y-2, width: 1, height: 5))
                }
            }
        }
        return c.makeImage()!
    }
    private func halo(_ c: CGContext, at p: CGPoint, radius: Double, rgb: (Double,Double,Double), strength: Double) {
        guard settings.glow > 0 else { return }
        let colors = [color(rgb.0,rgb.1,rgb.2,strength * settings.glow), color(rgb.0,rgb.1,rgb.2,0)]
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0,1])!
        c.drawRadialGradient(gradient, startCenter: p, startRadius: radius * 0.3, endCenter: p, endRadius: radius * 1.65, options: [])
    }
    private func body(_ c: CGContext, _ planet: Int, at p: CGPoint, radius: Double) {
        let scale = radius / 31
        c.draw(sprite(planet), in: CGRect(x: p.x - 120 * scale, y: p.y - 100 * scale, width: 240 * scale, height: 200 * scale))
    }
    private func render(size: CGSize, compact: Bool) -> CGImage? {
        if bufferSize != size || buffer == nil { buffer = bitmap(width: Int(size.width), height: Int(size.height)); bufferSize = size }
        guard let c = buffer else { return nil }
        if sky == nil || skySize != size { sky = makeSky(size); skySize = size }
        c.clear(CGRect(origin: .zero, size: size)); c.setShouldAntialias(false); c.interpolationQuality = .none
        if let sky { c.draw(sky, in: CGRect(origin: .zero, size: size)) }
        // Common design coordinates preserve compositions on portrait and ultrawide screens.
        let isSystem = [.solarSystem, .innerPlanets, .outerPlanets].contains(activeView)
        let designHeight = isSystem ? max(420, 2 * (280 * sin(elevation) + 45)) : 420
        let scale = min(size.width / 640, size.height / designHeight) * (compact && settings.labels ? 0.68 : 1)
        c.saveGState(); c.translateBy(x: size.width / 2, y: size.height * 0.54); c.scaleBy(x: scale, y: scale)
        let t = motion.elapsed
        let zoom = 1 + 0.025 * sin(t * 0.035)
        c.translateBy(x: sin(t * 0.025) * 7, y: cos(t * 0.031) * 4); c.scaleBy(x: zoom, y: zoom)
        if let planet = activeView.planet {
            let radius = planet == 5 || planet == 6 ? 69.0 : 91.0
            let a = t * 0.035 + 0.5
            let moon = CGPoint(x: -15 + cos(a) * 185, y: 8 + sin(a) * 78)
            let hasMoon = [2,4,5,7].contains(planet)
            if hasMoon && sin(a) > 0 { body(c, 8, at: moon, radius: planet == 2 ? 19 : 12) }
            body(c, planet, at: CGPoint(x: -15, y: 8), radius: radius)
            if hasMoon && sin(a) <= 0 { body(c, 8, at: moon, radius: planet == 2 ? 19 : 12) }
            if settings.asteroids && planet == 3 { drawDust(c, t: t, field: false) }
        } else if activeView == .deepSpace {
            halo(c, at: CGPoint(x: -160, y: 45), radius: 100, rgb: (0.33,0.35,1), strength: 0.75)
            body(c, 7, at: CGPoint(x: -85, y: 24), radius: 81)
            body(c, 8, at: CGPoint(x: 175, y: -56), radius: 20)
            if settings.asteroids { drawDust(c, t: t, field: true) }
            // A distant amber sun and a slow, stepped comet.
            body(c, -1, at: CGPoint(x: 215, y: 112), radius: 11)
            let x = 180 - (t * 1.5).truncatingRemainder(dividingBy: 400)
            for i in (0..<34).reversed() {
                c.setFillColor(color(0.37,0.84,0.9,Double(34-i)/80))
                c.fill(CGRect(x: x + Double(i)*2, y: 128 + Double(i), width: 2, height: 2))
            }
        } else if activeView == .asteroidBelt {
            body(c, -1, at: CGPoint(x: -205, y: 70), radius: 22)
            body(c, 4, at: CGPoint(x: 163, y: 50), radius: 48)
            if settings.asteroids { drawDust(c, t: t, field: true) }
            body(c, 8, at: CGPoint(x: -58 + sin(t*0.02)*12, y: -18), radius: 35)
        } else {
            let indices = activeView == .innerPlanets ? Array(0...3) : activeView == .outerPlanets ? Array(4...7) : Array(0...7)
            let radii = [8.0,12,13,10,27,23,18,17]
            let rotation = yaw - .pi / 4 + t * 0.006
            let squash = sin(elevation)
            struct Placed { let planet: Int; let p: CGPoint; let radius: Double }
            var placed = [Placed(planet: -1, p: .zero, radius: activeView == .solarSystem ? 27 : 34)]
            for (j,i) in indices.enumerated() {
                let r = indices.count == 8 ? 55 + Double(j) * 30 : 78 + Double(j) * 58
                if settings.orbits {
                    c.setStrokeColor(color(0.32,0.52,0.67,0.28)); c.setLineWidth(0.65)
                    c.strokeEllipse(in: CGRect(x: -r, y: -r*squash, width: r*2, height: r*squash*2))
                }
                let phase = [2.8, 5.0, 0.45, 3.9, 2.2, 5.7, 0.9, 3.5][i] + rotation + t * (0.015 / Double(i+1))
                placed.append(Placed(planet: i, p: CGPoint(x: cos(phase)*r, y: sin(phase)*r*squash), radius: radii[i] * (indices.count == 4 ? 1.25 : 1)))
            }
            if settings.asteroids { drawDust(c, t: t, field: false) }
            for p in placed.sorted(by: { $0.p.y > $1.p.y }) { body(c, p.planet, at: p.p, radius: p.radius) }
        }
        c.restoreGState()
        return c.makeImage()
    }
    private func drawDust(_ c: CGContext, t: Double, field: Bool) {
        for i in 0..<(field ? 140 : 110) {
            let a = hash(i, 5) * .pi * 2 + t * 0.008
            let r = (field ? 100.0 : 153.0) + hash(i, 6) * (field ? 260 : 18)
            let x = cos(a) * r, y = sin(a) * r * sin(elevation)
            let v = 0.3 + hash(i, 7) * 0.35
            c.setFillColor(color(v * 0.85,v * 0.9,v,0.8))
            let w = field ? 1 + floor(hash(i, 8) * 4) : 1
            c.fill(CGRect(x: floor(x), y: floor(y), width: w, height: w))
        }
    }
    func updateLayer(_ root: CALayer, size: CGSize, time: Double, date: Date) -> Bool {
        guard size.width > 0, size.height > 0 else { return true }
        advance(time)
        let pixels = Self.renderSize(size, pixelSize: settings.pixelSize)
        if let image = render(size: pixels, compact: size.width < 600 || size.height < 300) { currentImage = image; picture.contents = image }
        if picture.superlayer !== root { root.addSublayer(picture); root.addSublayer(dissolve); root.addSublayer(caption) }
        root.backgroundColor = NSColor.black.cgColor; root.masksToBounds = true
        for layer in [picture, dissolve] {
            layer.frame = CGRect(origin: .zero, size: size); layer.magnificationFilter = .nearest; layer.minificationFilter = .nearest
        }
        dissolve.contents = outgoing
        dissolve.opacity = Float(max(0, 1 - (time-transitionStart) / 2.4))
        if dissolve.opacity == 0 { outgoing = nil; dissolve.contents = nil }
        let key = "\(activeView.rawValue)-\(size)-\(settings.labels)-\(root.contentsScale)"
        if captionKey != key {
            captionKey = key; caption.contents = nil
            if settings.labels, size.width >= 250, size.height >= 160 {
                let resolution = Mercator.mapRenderSize(size, backingScale: root.contentsScale)
                if let c = bitmap(width: Int(ceil(resolution.width)), height: Int(ceil(resolution.height))) {
                    c.scaleBy(x: resolution.width / size.width, y: resolution.height / size.height)
                    let small = size.width < 600, margin: CGFloat = small ? 18 : 38
                    withAppKit(c) {
                        text("VOXEL COSMOS", at: CGPoint(x: margin, y: size.height-margin-12), size: small ? 8 : 10, color: NSColor(srgbRed: 0.51, green: 0.66, blue: 0.77, alpha: 1), tracking: small ? 2 : 3)
                        text(activeView.title.uppercased(), at: CGPoint(x: margin, y: margin+17), size: small ? 13 : 23, color: NSColor(srgbRed: 0.81, green: 0.89, blue: 0.91, alpha: 1), weight: .light, tracking: small ? 1.5 : 3)
                        text(activeView.planet != nil ? "A SMALL WORLD IN AN ENDLESS NIGHT" : "AN IMAGINED CELESTIAL MINIATURE", at: CGPoint(x: margin, y: margin), size: small ? 6 : 9, color: NSColor(srgbRed: 0.44, green: 0.57, blue: 0.69, alpha: 1), tracking: small ? 1 : 2)
                    }
                    caption.contents = c.makeImage()
                }
            }
            caption.frame = CGRect(origin: .zero, size: size)
        }
        caption.opacity = outgoing == nil ? 1 : Float(min(1, max(0, (time-transitionStart-0.9)/1.5)))
        return true
    }
    func draw(in context: CGContext, size: CGSize, time: Double, date: Date) {
        let root = CALayer(); root.bounds = CGRect(origin: .zero, size: size)
        CATransaction.begin(); CATransaction.setDisableActions(true)
        _ = updateLayer(root, size: size, time: time, date: date); root.render(in: context)
        CATransaction.commit()
    }
}
