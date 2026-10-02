import Foundation

struct DappleDot: Equatable {
    var x: Double; var y: Double; var vx: Double; var vy: Double
    let radius: Double; let phase: Double; let lane: Int; let color: Int
    var contourOffset: Double { 48 * sin(phase * 2.3) }
    var congestion = 0.0; var migration = 0.0
    var squash = 0.0; var rotation = 0.0; var nextHop: Double
}
struct DappleTerrain {
    let phase: Double
    func height(_ x: Double, lane: Int, time: Double) -> Double {
        145 + Double(lane) * 238 + 52 * sin(x / 280 + phase + Double(lane) * 1.7 + time * 0.012)
            + 21 * sin(x / 133 - phase + Double(lane) + time * 0.007)
    }
    func slope(_ x: Double, lane: Int, time: Double) -> Double {
        52 / 280 * cos(x / 280 + phase + Double(lane) * 1.7 + time * 0.012)
            + 21 / 133 * cos(x / 133 - phase + Double(lane) + time * 0.007)
    }
}
/// A 900-unit-high world, fixed 120 Hz integration, bounded soft contact response.
/// Visible edges are windows into the world; wrapping happens completely offscreen.
struct DappleSimulation {
    private(set) var dots: [DappleDot] = []
    private(set) var time = 0.0
    private(set) var collisions = 0
    let width: Double
    let terrain: DappleTerrain
    var settings: DappleSettings
    private var remainder = 0.0
    init(seed: UInt64, aspect: Double, settings: DappleSettings) {
        self.settings = settings.sanitized(); width = max(320, aspect * 900)
        var random = DappleRandom(state: seed)
        terrain = DappleTerrain(phase: random.next() * .pi * 2)
        let base = settings.density == .sparse ? 18.0 : settings.density == .full ? 36.0 : 25.0
        let count = max(10, min(48, Int(base * sqrt(width / 1440) * (settings.motion == .zen ? 0.65 : 1))))
        for i in 0..<count {
            let anchor = i % 9 == 0
            let radius = (anchor ? 51 + random.next() * 16 : 18 + pow(random.next(), 0.65) * 22) * (settings.size == .small ? 0.72 : settings.size == .large ? 1.25 : 1)
            let phase = random.next() * .pi * 2, lane = (i + i / 9) % 3
            var x = 0.0, y = 0.0
            for _ in 0..<120 {
                x = random.next() * width
                y = settings.motion == .float || settings.motion == .zen ? 90 + random.next() * 720 : terrain.height(x, lane: lane, time: 0) + radius + 48 * sin(phase * 2.3) + (settings.events ? 52 * sin(phase) : 0) + random.next() * 70
                if dots.allSatisfy({ hypot($0.x-x, $0.y-y) > $0.radius + radius + 20 }) { break }
            }
            var color = 0, best = Double.infinity
            for candidate in 0..<5 {
                let population = Double(dots.filter { $0.color == candidate }.count)
                let neighbors = Double(dots.filter { $0.color == candidate && hypot($0.x-x,$0.y-y) < $0.radius+radius+100 }.count)
                let score = population*0.65 + neighbors*2 + random.next()*1.3
                if score < best { best = score; color = candidate }
            }
            dots.append(DappleDot(x: x, y: y, vx: 12 + random.next() * 12, vy: 0, radius: radius, phase: phase, lane: lane, color: color, nextHop: 4 + random.next() * 20))
        }
    }
    func ground(_ d: DappleDot) -> Double {
        terrain.height(d.x, lane:d.lane, time:time) + d.contourOffset + d.migration
            + (settings.events ? 52 * sin(time * 0.042 + d.phase) : 0)
    }
    mutating func advance(_ delta: Double) {
        guard delta.isFinite && delta > 0 else { return }
        remainder += min(delta, 0.25) * settings.speed
        let step = 1.0 / 120
        while remainder + 1e-10 >= step { integrate(step); remainder -= step }
    }
    private mutating func integrate(_ dt: Double) {
        time += dt; collisions = 0
        let floating = settings.motion == .float || settings.motion == .zen
        let calm = settings.motion == .zen ? 0.32 : 1.0
        // A long, smooth lull once per two minutes; no hard event-state changes.
        let lull = settings.events ? 1 - 0.65 * pow(max(0, sin(time * .pi / 95 - 1.2)), 12) : 1
        for i in dots.indices {
            var d = dots[i]
            if floating {
                let flowX = 13 * sin(d.y / 240 + time * 0.045 + d.phase * 0.3)
                let flowY = 11 * cos(d.x / 330 - time * 0.036 + d.phase * 0.2)
                d.vx += (flowX * calm * lull - d.vx) * dt * 0.35
                d.vy += (flowY * calm * lull - d.vy) * dt * 0.35
                // Turn gently before the top/bottom; never bounce on viewport edges.
                d.vy += (max(0, 110-d.y) - max(0, d.y-790)) * dt * 0.08
            } else {
                let slope = terrain.slope(d.x, lane: d.lane, time: time)
                var drive = (settings.motion == .playground ? 23.0 : 16.0) * (0.85 + 0.18*sin(d.phase) + 0.52*sin(time*0.065+d.phase)) * lull
                // Look ahead softly. Neighbors can meet without becoming permanent queues.
                for other in dots where other.x > d.x && abs(other.y-d.y) < (other.radius+d.radius)*0.8 {
                    let gap = other.x-d.x-other.radius-d.radius
                    if gap < 65 && gap > -d.radius { drive *= max(0.25,min(1,gap/65)) }
                }
                d.vx += (drive - d.vx) * dt * 0.45 - slope * dt * 24
                d.vy -= 72 * dt
                let ground = self.ground(d) + d.radius
                if d.y <= ground && d.vy < 10 {
                    let impact = max(0, -d.vy)
                    d.y = ground
                    d.vy = impact > 13 ? impact * 0.40 : 0
                    d.squash = max(d.squash, min(0.065, impact / 1800))
                    if time >= d.nextHop {
                        let playful = settings.motion == .playground ? 1.35 : 1.0
                        d.vy = (33 + 17 * sin(d.phase + time * 0.13)) * sqrt(32 / d.radius) * playful * lull
                        if settings.events && sin(time * 0.041 + d.phase) > 0.94 { d.vy *= 1.4 }
                        d.nextHop = time + 9 + 8 * (1 + sin(d.phase + time * 0.06))
                    }
                }
            }
            var crowded = false
            for j in dots.indices where j != i {
                let other = dots[j], dx = other.x-d.x, dy = other.y-d.y
                let distance = hypot(dx,dy), contact = d.radius+other.radius
                let gap = min(d.radius,other.radius)*0.45
                if distance < contact+gap && distance > 0.01 {
                    let strength = min(35,(contact+gap-distance)/gap*24)
                    d.vx -= dx/distance*strength*dt
                    d.vy -= dy/distance*strength*dt*(floating ? 1 : 0.4)
                    crowded = true
                }
            }
            d.congestion = min(12,max(0,d.congestion + (crowded ? dt : -dt*0.65)))
            let escape = d.congestion > 4 ? 58 * sin(d.phase+1.1) : 0
            d.migration += (escape-d.migration)*dt*0.10
            d.vx = min(65, max(-65, d.vx)); d.vy = min(110, max(-110, d.vy))
            d.x += d.vx * dt; d.y += d.vy * dt
            d.rotation -= d.vx * dt / d.radius * (floating ? 0.08 : 0.45)
            d.squash *= exp(-dt * 9)
            if d.x > width + d.radius * 2 { d.x = -d.radius * 2 }
            if d.x < -d.radius * 2 - 1 { d.x = width + d.radius * 2 }
            if !floating { d.y = max(d.y, self.ground(d) + d.radius - 2) }
            dots[i] = d
        }
        // Two position passes settle piles without stiff high-energy impulses.
        for pass in 0..<2 {
            for i in dots.indices {
                for j in (i+1)..<dots.count {
                    if Self.resolve(&dots, i, j, impulse: pass == 0) { collisions += 1 }
                }
            }
        }
    }
    @discardableResult static func resolve(_ dots: inout [DappleDot], _ i: Int, _ j: Int, impulse: Bool) -> Bool {
        var a = dots[i], b = dots[j]
        let dx = b.x-a.x, dy = b.y-a.y, distance = hypot(dx,dy), target = a.radius+b.radius
        guard distance < target else { return false }
        let nx = distance > 0.0001 ? dx/distance : 1, ny = distance > 0.0001 ? dy/distance : 0
        let invA = 1 / (a.radius*a.radius), invB = 1 / (b.radius*b.radius), sum = invA+invB
        let correction = max(0, target-distance-0.25) * 0.85
        a.x -= nx*correction*invA/sum; a.y -= ny*correction*invA/sum
        b.x += nx*correction*invB/sum; b.y += ny*correction*invB/sum
        let relative = (b.vx-a.vx)*nx + (b.vy-a.vy)*ny
        if impulse && relative < 0 {
            let push = -1.25 * relative / sum
            a.vx -= push*nx*invA; a.vy -= push*ny*invA
            b.vx += push*nx*invB; b.vy += push*ny*invB
            let squash = min(0.05, -relative/1200)
            a.squash = max(a.squash,squash); b.squash = max(b.squash,squash)
        }
        dots[i] = a; dots[j] = b; return true
    }
}
