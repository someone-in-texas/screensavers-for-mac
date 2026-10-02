import AppKit
import QuartzCore

/// An asset-free, seeded sky. Curves and folded-paper faces stay vector sharp;
/// each tick commits the camera, colors and every moving layer together.
final class PaperSkyScene: SaverScene {
    struct Point3 {
        var x: Double; var y: Double; var z: Double
    }
    struct Camera {
        var yaw: Double; var pitch: Double; var perspective: Double
        static func preset(_ mode: PaperCamera) -> Self {
            switch mode {
            case .journey, .isometric: return Self(yaw: 0.72, pitch: 0.46, perspective: 0)
            case .chase: return Self(yaw: 0.04, pitch: 0.18, perspective: 1)
            case .side: return Self(yaw: 1.48, pitch: 0.08, perspective: 0)
            }
        }
        func blended(to other: Self, amount: Double) -> Self {
            Self(yaw: yaw + (other.yaw-yaw)*amount, pitch: pitch + (other.pitch-pitch)*amount,
                 perspective: perspective + (other.perspective-perspective)*amount)
        }
    }
    private let seed: UInt64
    private var settings = PaperSkySettings()
    private var motion = MotionClock(), journey = MotionClock()
    private var running = false
    private let canvas = CALayer(), sky = CAGradientLayer(), haze = CAGradientLayer()
    private let sun = CAGradientLayer(), sunMask = CAShapeLayer(), world = CALayer()
    private struct Cloud {
        let x: Double, z: Double, altitude: Double
        let width: Double, height: Double
        let silhouette: CGPath, crest: CGPath
    }
    private let sunlight = CAGradientLayer()
    private var clouds: [Cloud] = []
    private var cloudLayers: [CAGradientLayer] = []
    private var cloudRims: [CAShapeLayer] = []
    private var foldLayers: [CAShapeLayer] = []
    private var accentLayers: [CAShapeLayer] = []
    private var windLayers: [CAShapeLayer] = []
    private var planeLayers: [[CAShapeLayer]] = []
    private var trailLayers: [CAShapeLayer] = []
    private var trailMasks: [CAGradientLayer] = []
    private var lastSize = CGSize.zero
    private var solarCoordinate = 0.7
    private var configured = false
    private var cameraFrom = Camera.preset(.isometric)
    private var cameraTo = Camera.preset(.isometric)
    private var cameraChangedAt = 0.0
    private var lastShot = -1
    private(set) var activeCamera = PaperCamera.isometric
    private(set) var visibleCompanions = 0
    private(set) var currentCamera = Camera.preset(.isometric)
    private(set) var elapsed = 0.0

    init(seed: UInt64 = UInt64.random(in: 0...UInt64.max)) { self.seed = seed }
    func start() { guard !running else { return }; running = true; motion.pause(); journey.pause() }
    func stop() { running = false; motion.pause(); journey.pause() }
    func apply(_ value: SaverSettings) {
        let next = value.paperSky.sanitized()
        if settings.camera != next.camera || settings.secondsPerView != next.secondsPerView { lastShot = -1 }
        settings = next
    }
    private func random(_ i: Int, _ channel: Int) -> Double {
        var n = seed &+ UInt64(truncatingIfNeeded: i) &* 0x9E3779B97F4A7C15 &+ UInt64(channel) &* 0xBF58476D1CE4E5B9
        n = (n ^ (n >> 30)) &* 0xBF58476D1CE4E5B9
        n = (n ^ (n >> 27)) &* 0x94D049BB133111EB
        return Double((n ^ (n >> 31)) & 0xFFFFFF) / Double(0xFFFFFF)
    }
    private func smooth(_ value: Double) -> Double { let x = min(1, max(0, value)); return x*x*(3-2*x) }
    private func cg(_ rgb: RGB, alpha: Double = 1) -> CGColor {
        NSColor(srgbRed: rgb.r, green: rgb.g, blue: rgb.b, alpha: alpha).cgColor
    }
    private func mix(_ a: RGB, _ b: RGB, _ t: Double) -> RGB { RGB(a.r+(b.r-a.r)*t, a.g+(b.g-a.g)*t, a.b+(b.b-a.b)*t) }
    private func colors() -> [RGB] {
        // Zenith, middle sky, horizon, near clouds, far clouds, paper shadow.
        let palettes: [[RGB]] = [
            [RGB(0.12,0.07,0.30), RGB(0.60,0.21,0.49), RGB(1,0.65,0.40), RGB(0.20,0.12,0.36), RGB(0.77,0.39,0.59), RGB(0.52,0.40,0.71)],
            [RGB(0.20,0.15,0.42), RGB(0.88,0.38,0.51), RGB(1,0.79,0.55), RGB(0.38,0.23,0.48), RGB(0.93,0.57,0.62), RGB(0.69,0.46,0.61)],
            [RGB(0.06,0.08,0.25), RGB(0.34,0.22,0.59), RGB(0.93,0.43,0.64), RGB(0.12,0.12,0.31), RGB(0.55,0.39,0.72), RGB(0.42,0.42,0.72)],
            [RGB(0.04,0.18,0.29), RGB(0.21,0.48,0.57), RGB(1,0.72,0.57), RGB(0.10,0.28,0.37), RGB(0.41,0.65,0.66), RGB(0.34,0.58,0.63)]
        ]
        if settings.palette != .evolving { return palettes[PaperPalette.allCases.firstIndex(of: settings.palette)!-1] }
        let phase = elapsed / 65 + random(1, 2)*4
        let index = Int(phase) % palettes.count, blend = smooth(phase-floor(phase))
        return zip(palettes[index], palettes[(index+1)%palettes.count]).map { mix($0.0, $0.1, blend) }
    }
    private func configure() {
        guard !configured else { return }; configured = true
        canvas.masksToBounds = true
        canvas.name = "paper.canvas"; sun.name = "paper.sun"; world.name = "paper.world"
        canvas.addSublayer(sky); canvas.addSublayer(sunlight); canvas.addSublayer(sun); canvas.addSublayer(world); canvas.addSublayer(haze)
        sunlight.type = .radial; sunlight.startPoint = CGPoint(x: 0.5, y: 0.5); sunlight.endPoint = CGPoint(x: 1, y: 1)
        sunlight.locations = [0, 0.22, 0.56, 1]
        sky.startPoint = CGPoint(x: 0.5, y: 1); sky.endPoint = CGPoint(x: 0.5, y: 0)
        sky.locations = [0, 0.48, 0.82, 1]
        sun.cornerRadius = 1; sun.masksToBounds = false; sun.mask = sunMask
        sun.startPoint = CGPoint(x: 0.5, y: 1); sun.endPoint = CGPoint(x: 0.5, y: 0)
        haze.startPoint = CGPoint(x: 0.5, y: 0); haze.endPoint = CGPoint(x: 0.5, y: 1)
        haze.locations = [0, 0.32, 0.55, 1]
        for i in 0..<48 {
            clouds.append(makeCloud(i))
            let layer = CAGradientLayer(); layer.name = "paper.cloud.\(i)"
            layer.bounds = CGRect(x: 0, y: 0, width: 320, height: 100)
            layer.anchorPoint = CGPoint(x: 0.5, y: 0.28)
            layer.startPoint = CGPoint(x: 0.5, y: 1); layer.endPoint = CGPoint(x: 0.5, y: 0)
            layer.locations = [0, 0.42, 0.76, 1]
            let mask = CAShapeLayer(); mask.path = clouds[i].silhouette; layer.mask = mask
            world.addSublayer(layer); cloudLayers.append(layer)
            let rim = CAShapeLayer(); rim.fillColor = nil; rim.lineWidth = 0.7; rim.lineCap = .round
            rim.bounds = layer.bounds; rim.anchorPoint = layer.anchorPoint; rim.path = clouds[i].crest
            world.addSublayer(rim); cloudRims.append(rim)
        }
        for _ in 0..<5 {
            let wind = CAShapeLayer(); wind.fillColor = nil; wind.lineWidth = 0.55; wind.lineCap = .round
            world.addSublayer(wind); windLayers.append(wind)
        }
        for _ in 0..<6 {
            let trail = CAShapeLayer(); trail.name = "paper.trail.\(planeLayers.count)"; trail.fillColor = nil; trail.lineWidth = 0.8; trail.lineCap = .round
            let fade = CAGradientLayer(); fade.colors = [NSColor.white.cgColor, NSColor.clear.cgColor]
            trail.mask = fade; trailMasks.append(fade)
            world.addSublayer(trail); trailLayers.append(trail)
            var faces: [CAShapeLayer] = []
            for _ in 0..<4 {
                let face = CAShapeLayer(); face.name = "paper.plane.\(planeLayers.count).\(faces.count)"; face.lineWidth = 0.65; face.lineJoin = .round
                world.addSublayer(face); faces.append(face)
            }
            planeLayers.append(faces)
            let folds = CAShapeLayer(); folds.name = "paper.fold.\(foldLayers.count)"; folds.fillColor = nil; folds.lineWidth = 0.65; folds.lineCap = .round
            world.addSublayer(folds); foldLayers.append(folds)
            let accent = CAShapeLayer(); accent.fillColor = nil; accent.lineWidth = 1.25; accent.lineCap = .round
            world.addSublayer(accent); accentLayers.append(accent)
        }
    }
    private func makeCloud(_ index: Int) -> Cloud {
        let cell = index * 17 % 48 // Every density samples the whole field, not its front rows.
        let x = (Double(cell % 8)-3.5)*9 + (random(index,10)-0.5)*5
        let z = (Double(cell / 8)-2.5)*14 + (random(index,11)-0.5)*7
        let width = 3.4+random(index,12)*3.5
        let height = 0.7+random(index,13)*0.6
        // A cloud is a soft volume billboard at a persistent 3D location. Its
        // silhouette never morphs into another camera layout during an orbit.
        let xs = [0.0,25,55,83,114,147,183,220,263,295,320]
        let crestCount = 1+Int(random(index,110)*3.99)
        let shoulder = 0.28+random(index,111)*0.42
        let shoulderWidth = 0.20+random(index,112)*0.12
        var crest: [CGPoint] = []
        for j in xs.indices {
            let fixed = j == 0 || j == xs.count-1
            let u = xs[j]/320
            var height = 23+10*sin(u*Double.pi)+26*exp(-pow((u-shoulder)/shoulderWidth,2))
            for k in 1..<crestCount {
                let peak = 0.18+random(index,k+115)*0.64
                let breadth = 0.065+random(index,k+120)*0.07
                height += (8+random(index,k+125)*9)*exp(-pow((u-peak)/breadth,2))
            }
            crest.append(CGPoint(x: xs[j] + (fixed ? 0 : (random(index,j+70)-0.5)*13),
                                 y: fixed ? 23 : height))
        }
        let silhouette = CGMutablePath(); silhouette.move(to: crest[0])
        for j in 1..<crest.count {
            let previous = crest[j-1], point = crest[j]
            silhouette.addQuadCurve(to: CGPoint(x: (previous.x+point.x)/2, y: (previous.y+point.y)/2), control: previous)
        }
        silhouette.addQuadCurve(to: crest.last!, control: crest.last!)
        silhouette.addCurve(to: crest[0], control1: CGPoint(x: 250,y: -12), control2: CGPoint(x: 65,y: -5))
        silhouette.closeSubpath()
        let rim = CGMutablePath(); rim.move(to: CGPoint(x: (crest[3].x+crest[4].x)/2, y: (crest[3].y+crest[4].y)/2))
        for j in 4...6 { rim.addQuadCurve(to: CGPoint(x: (crest[j].x+crest[j+1].x)/2, y: (crest[j].y+crest[j+1].y)/2), control: crest[j]) }
        return Cloud(x: x, z: z, altitude: -5.2-random(index,15)*2.4, width: width, height: height, silhouette: silhouette, crest: rim)
    }
    private func curvedPath(_ points: [CGPoint], closed: Bool = true) -> CGPath {
        let path = CGMutablePath()
        guard points.count > 2 else { return path }
        if closed {
            func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint { CGPoint(x: (a.x+b.x)/2, y: (a.y+b.y)/2) }
            path.move(to: midpoint(points.last!, points[0]))
            for i in points.indices { path.addQuadCurve(to: midpoint(points[i], points[(i+1)%points.count]), control: points[i]) }
            path.closeSubpath()
        } else {
            path.move(to: points[0]); for point in points.dropFirst() { path.addLine(to: point) }
        }
        return path
    }
    private func cloudCenter(_ index: Int) -> Point3 {
        let cloud = clouds[index]
        let travel = (cloud.z-elapsed*0.7+42).truncatingRemainder(dividingBy: 84)
        return Point3(x: cloud.x, y: cloud.altitude, z: (travel < 0 ? travel+84 : travel)-42)
    }
    private func drawClouds(size: CGSize, palette: [RGB], backingScale: CGFloat) {
        let count = Int(settings.clouds*48)
        for i in 0..<48 {
            let center = cloudCenter(i), projected = project(center, size: size)
            let depth = projected.depth
            let horizon = 1-smooth((Double(projected.point.y)/Double(size.height)-0.48)/0.18)
            let opacity = i < count ? smooth((depth-5)/9)*(1-smooth((depth-24)/27))*smooth((42-abs(center.z))/7)*horizon : 0
            let distance = smooth((depth-8)/38)
            let atmospheric = mix(palette[4], palette[2], 0.22)
            let color = mix(palette[3], atmospheric, 0.32+distance*0.62)
            let solar = exp(-pow((Double(projected.point.x)/Double(size.width)-solarCoordinate)*2.8, 2))
            let width = clouds[i].width*projected.scale*2
            let height = max(12, clouds[i].height*projected.scale*2)
            let layer = cloudLayers[i]
            layer.position = projected.point; layer.setAffineTransform(CGAffineTransform(scaleX: width/320, y: height/100))
            layer.opacity = Float(opacity); layer.isHidden = i >= count
            layer.contentsScale = backingScale; layer.mask?.contentsScale = backingScale
            layer.zPosition = CGFloat(-depth)
            let crestColor = mix(color, palette[2], 0.08+solar*0.12)
            layer.colors = [cg(crestColor, alpha: 0.75), cg(color, alpha: 0.78), cg(color, alpha: 0.3), cg(color, alpha: 0)]
            let rim = cloudRims[i]
            rim.position = layer.position; rim.setAffineTransform(layer.affineTransform()); rim.contentsScale = backingScale
            rim.lineWidth = CGFloat(0.65*320/max(1,width))
            rim.strokeColor = cg(palette[2], alpha: (0.10+settings.glow*0.16)*solar*(1-distance))
            rim.opacity = Float(opacity); rim.zPosition = CGFloat(-depth+0.05)
        }
        for (i, layer) in windLayers.enumerated() {
            let phase = (elapsed*0.011+random(i,60)).truncatingRemainder(dividingBy: 1)
            let opacity = smooth(phase/0.15)*smooth((1-phase)/0.15)
            let points = (0..<28).map { j -> CGPoint in
                let z = 18-phase*36+Double(j)*0.42
                return project(Point3(x: (Double(i)-2)*5+sin(z*0.15+Double(i))*0.6, y: -2.6, z: z), size: size).point
            }
            layer.path = curvedPath(points, closed: false); layer.strokeColor = cg(palette[2], alpha: 0.07)
            layer.opacity = settings.trails ? Float(opacity) : 0; layer.zPosition = -90; layer.contentsScale = backingScale
        }
    }
    private func project(_ p: Point3, size: CGSize) -> (point: CGPoint, scale: Double, depth: Double) {
        let a = currentCamera.yaw, e = currentCamera.pitch
        let horizontal = p.x*cos(a) + p.z*sin(a)
        let along = -p.x*sin(a) + p.z*cos(a)
        let vertical = p.y*cos(e) + along*sin(e)
        let depth = 16 + along*cos(e) - p.y*sin(e)
        let perspective = 16 / max(3, depth)
        let factor = (1-currentCamera.perspective) + currentCamera.perspective*perspective
        let unit = Double(min(size.width / 24, size.height / 15))
        return (CGPoint(x: Double(size.width)*0.45 + horizontal*unit*factor,
                        y: Double(size.height)*0.51 + vertical*unit*factor), unit*factor, depth)
    }
    private func updateCamera() {
        let shot = settings.camera == .journey ? Int(journey.elapsed / settings.secondsPerView) : 0
        if shot != lastShot {
            let order: [PaperCamera] = [.isometric, .chase, .side, .chase]
            activeCamera = settings.camera == .journey ? order[shot % order.count] : settings.camera
            cameraFrom = currentCamera; cameraTo = Camera.preset(activeCamera)
            cameraChangedAt = journey.elapsed
            if lastShot == -1 && elapsed == 0 { cameraFrom = cameraTo }
            lastShot = shot
        }
        currentCamera = cameraFrom.blended(to: cameraTo, amount: smooth((journey.elapsed-cameraChangedAt)/7))
    }
    func updateLayer(_ root: CALayer, size: CGSize, time: Double, date: Date) -> Bool {
        guard size.width > 0, size.height > 0 else { return true }
        CATransaction.begin(); CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }
        configure()
        if canvas.superlayer !== root { root.addSublayer(canvas) }
        if running {
            motion.step(now: time, speed: settings.speed, maximumStep: 0.1)
            journey.step(now: time, speed: 1, maximumStep: .infinity)
        }
        elapsed = motion.elapsed; updateCamera()
        canvas.frame = CGRect(origin: root.bounds.origin, size: size)
        for layer in [sky as CALayer, world, haze] { layer.frame = CGRect(origin: .zero, size: size) }
        let palette = colors()
        sky.colors = [cg(palette[0]), cg(palette[1]), cg(palette[2]), cg(palette[4])]
        haze.colors = [cg(palette[3], alpha: 0.92), cg(palette[3], alpha: 0.35), cg(palette[3], alpha: 0), cg(palette[3], alpha: 0)]
        let diameter = min(size.width*0.21, size.height*0.315)
        let solarPhase = elapsed*0.009 + random(0,61)*Double.pi*2
        let solarX = 0.70 - (currentCamera.yaw-0.72)*0.12 + sin(solarPhase)*0.025
        solarCoordinate = solarX
        let solarY = 0.69 + cos(solarPhase)*0.022 + (currentCamera.pitch-0.46)*0.04
        let sunCenter = CGPoint(x: Double(size.width)*solarX, y: Double(size.height)*solarY)
        sun.frame = CGRect(x: sunCenter.x-diameter/2, y: sunCenter.y-diameter/2, width: diameter, height: diameter)
        sun.isHidden = !settings.sun; sunlight.isHidden = !settings.sun
        sunlight.frame = CGRect(x: sunCenter.x-diameter*1.8, y: sunCenter.y-diameter*1.8, width: diameter*3.6, height: diameter*3.6)
        sunlight.colors = [cg(palette[2], alpha: settings.glow*0.70), cg(palette[2], alpha: settings.glow*0.45), cg(palette[2], alpha: 0.08*settings.glow), cg(palette[2], alpha: 0)]
        sun.colors = [cg(mix(RGB(1,0.93,0.76), palette[2], 0.12+0.08*sin(solarPhase))), cg(palette[2])]
        if size != lastSize {
            let path = CGMutablePath(), r = diameter/2
            // Exact circular arcs keep the sun smooth at every display scale.
            for (low, high) in [(0.02,0.065), (0.10,0.16), (0.20,0.27), (0.31,0.39), (0.43,1.0)] {
                let a = asin(CGFloat(low)*2-1), b = asin(CGFloat(high)*2-1)
                path.move(to: CGPoint(x: r+r*cos(a), y: r+r*sin(a)))
                path.addArc(center: CGPoint(x: r,y: r), radius: r, startAngle: a, endAngle: b, clockwise: false)
                path.addLine(to: CGPoint(x: r-r*cos(b), y: r+r*sin(b)))
                path.addArc(center: CGPoint(x: r,y: r), radius: r, startAngle: .pi-b, endAngle: .pi-a, clockwise: false)
                path.closeSubpath()
            }
            sunMask.path = path; lastSize = size
        }
        drawClouds(size: size, palette: palette, backingScale: root.contentsScale)
        sunMask.contentsScale = root.contentsScale
        visibleCompanions = 0
        for faces in planeLayers { for face in faces { face.contentsScale = root.contentsScale } }
        for i in 0..<6 {
            var opacity = 1.0
            var center = Point3(x: sin(elapsed*0.14)*0.6, y: sin(elapsed*0.21)*0.2, z: 0)
            if i > 0 {
                let period = 70+random(i,54)*35
                let phase = (elapsed+random(i,40)*period).truncatingRemainder(dividingBy: period)/period
                let joining = smooth((phase-0.10)/0.18)*smooth((0.90-phase)/0.18)
                opacity = settings.companions ? smooth((phase-0.03)/0.07)*smooth((0.97-phase)/0.07) : 0
                center = Point3(x: (i % 2 == 0 ? -1 : 1)*(3.4+random(i,41)*5+(1-joining)*14) + sin(elapsed*0.12+Double(i))*0.5,
                                y: 0.4+random(i,42)*2+sin(elapsed*0.18+Double(i))*0.25,
                                z: -12+phase*35+random(i,43)*4)
                if opacity > 0.05 { visibleCompanions += 1 }
            }
            drawPlane(i, center: center, opacity: opacity, size: size, palette: palette)
        }
        return true
    }
    private func drawPlane(_ index: Int, center: Point3, opacity: Double, size: CGSize, palette: [RGB]) {
        let bank = sin(elapsed*(0.15+random(index,45)*0.11)+Double(index)*1.4)*(index == 0 ? 0.11 : 0.09+random(index,46)*0.18)
        let pitch = sin(elapsed*(0.12+random(index,47)*0.06)+Double(index))*0.055
        let heading = index == 0 ? sin(elapsed*0.07)*0.035 : sin(elapsed*0.09+Double(index))*0.12
        let scale = index == 0 ? 1.0 : 0.57+random(index,44)*0.22
        let wing = index == 0 ? 2.3 : 1.55+random(index,48)*1.25
        let noseLength = index == 0 ? 2.8 : 2.4+random(index,49)*1.3
        let tail = index == 0 ? -1.6 : -1.25-random(index,50)*0.6
        let keelDepth = index == 0 ? -0.72 : -0.42-random(index,51)*0.4
        func point(_ x: Double, _ y: Double, _ z: Double) -> Point3 {
            let bx = x*cos(bank)-y*sin(bank), by = x*sin(bank)+y*cos(bank)
            let py = by*cos(pitch)-z*sin(pitch), pz = by*sin(pitch)+z*cos(pitch)
            return Point3(x: center.x+(bx*cos(heading)+pz*sin(heading))*scale, y: center.y+py*scale,
                          z: center.z+(-bx*sin(heading)+pz*cos(heading))*scale)
        }
        let nose = point(0,0,noseLength), left = point(-wing,0.18,tail), right = point(wing,0.18,tail)
        let innerL = point(-0.18,-0.24,tail+0.1), innerR = point(0.18,-0.24,tail+0.1), keel = point(0,keelDepth,tail+0.6)
        let faces = [[nose,left,innerL], [nose,innerL,keel], [nose,keel,innerR], [nose,innerR,right]]
        let paper = index == 0 ? RGB(1,0.95,0.84) : mix(RGB(0.97,0.91,0.85), palette[5], 0.14+random(index,52)*0.28)
        let depth = project(center, size: size).depth
        let distance = index == 0 ? 0 : smooth((depth-15)/30)*0.40
        func subtract(_ a: Point3, _ b: Point3) -> Point3 { Point3(x: a.x-b.x, y: a.y-b.y, z: a.z-b.z) }
        func normal(_ vertices: [Point3]) -> Point3 {
            let u = subtract(vertices[1],vertices[0]), v = subtract(vertices[2],vertices[0])
            var n = Point3(x: u.y*v.z-u.z*v.y, y: u.z*v.x-u.x*v.z, z: u.x*v.y-u.y*v.x)
            let length = max(0.001, sqrt(n.x*n.x+n.y*n.y+n.z*n.z)) * (n.y < 0 ? -1 : 1)
            n.x /= length; n.y /= length; n.z /= length; return n
        }
        for (j, vertices) in faces.enumerated() {
            let projected = vertices.map { project($0, size: size) }
            let path = CGMutablePath(); path.move(to: projected[0].point)
            path.addLine(to: projected[1].point); path.addLine(to: projected[2].point); path.closeSubpath()
            let layer = planeLayers[index][j]
            let n = normal(vertices)
            let light = max(0, n.x*0.38+n.y*0.82+n.z*0.43)
            let view = Point3(x: sin(currentCamera.yaw)*cos(currentCamera.pitch), y: sin(currentCamera.pitch), z: -cos(currentCamera.yaw)*cos(currentCamera.pitch))
            let grazing = pow(1-abs(n.x*view.x+n.y*view.y+n.z*view.z), 3)
            var shade = mix(palette[5], paper, 0.28+0.72*light)
            shade = mix(shade, palette[2], (0.025+0.065*grazing)*settings.glow)
            shade = mix(shade, palette[1], distance)
            layer.path = path; layer.fillColor = cg(shade); layer.strokeColor = cg(shade)
            layer.lineWidth = 0.35
            layer.opacity = Float(opacity)
            layer.zPosition = CGFloat(-projected.map(\.depth).reduce(0,+)/3)
            layer.shadowOpacity = 0
        }
        // Selected folds catch light; the whole silhouette never gets a neon outline.
        let folds = CGMutablePath()
        for (a,b) in [(nose,innerL), (nose,right)] {
            folds.move(to: project(a,size: size).point); folds.addLine(to: project(b,size: size).point)
        }
        let fold = foldLayers[index]; fold.path = folds; fold.zPosition = CGFloat(-depth+0.35)
        fold.strokeColor = cg(RGB(1,0.92,0.75), alpha: (0.20+settings.glow*0.5)*(1-distance))
        fold.opacity = Float(opacity); fold.contentsScale = planeLayers[index][0].contentsScale
        let accent = accentLayers[index], accentPath = CGMutablePath()
        // A faint inset wing stripe follows the fold geometry rather than floating on it.
        let seamSide = index % 2 == 0 ? 1.0 : -1.0
        for j in 0..<2 {
            let wingPoint = seamSide < 0 ? left : right, inner = seamSide < 0 ? innerL : innerR
            let weight = j == 0 ? 0.15 : 0.80, front = 0.90-weight
            let p = Point3(x: nose.x*front+wingPoint.x*weight+inner.x*0.1,
                           y: nose.y*front+wingPoint.y*weight+inner.y*0.1,
                           z: nose.z*front+wingPoint.z*weight+inner.z*0.1)
            if j == 0 { accentPath.move(to: project(p,size: size).point) } else { accentPath.addLine(to: project(p,size: size).point) }
        }
        accent.path = accentPath; accent.zPosition = CGFloat(-depth+0.36)
        accent.strokeColor = cg(mix(palette[2], palette[5], random(index,53)), alpha: 0.24)
        accent.opacity = Float(opacity); accent.contentsScale = fold.contentsScale
        let trail = trailLayers[index], path = CGMutablePath()
        for j in 0..<24 {
            let distance = Double(j)*0.35
            let tailPoint = point(0,-0.24,tail)
            let p = project(Point3(x: tailPoint.x+sin(elapsed*0.22-distance*0.13)*distance*0.06,
                                   y: tailPoint.y-distance*0.025, z: tailPoint.z-distance), size: size).point
            if j == 0 {
                path.move(to: p); trailMasks[index].startPoint = CGPoint(x: p.x/size.width, y: p.y/size.height)
            } else { path.addLine(to: p) }
            if j == 23 { trailMasks[index].endPoint = CGPoint(x: p.x/size.width, y: p.y/size.height) }
        }
        trail.frame = CGRect(origin: .zero, size: size)
        trailMasks[index].frame = trail.bounds
        trail.path = path; trail.strokeColor = cg(palette[2], alpha: 0.28)
        trail.opacity = settings.trails ? Float(opacity) : 0
        trail.zPosition = -1000
    }
    func draw(in context: CGContext, size: CGSize, time: Double, date: Date) {
        let root = CALayer(); root.bounds = CGRect(origin: .zero, size: size)
        _ = updateLayer(root, size: size, time: time, date: date)
        root.render(in: context)
    }
}
