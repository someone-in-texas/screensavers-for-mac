import AppKit

/// Filled brush envelopes follow the original branch centerline, keeping every
/// leaf attachment intact. Inspired by Flourish's pressure/taper approach.
enum BloomDrawing {
    struct Placement: Equatable { let anchor: CGPoint; let scale: Double }
    static func placements(layout: BloomLayout, count: Int, seed: UInt64) -> [Placement] {
        guard count > 1 else { return [.init(anchor:.zero,scale:1)] }
        var random = ArtRandom(state:seed &+ 9311)
        let positions: [CGPoint]
        let scales: [Double]
        switch layout {
        case .meadow:
            positions = [CGPoint(x:-132,y:4),CGPoint(x:-84,y:13),CGPoint(x:7,y:-8),CGPoint(x:48,y:-3),CGPoint(x:116,y:8)]
            scales = [0.72,0.89,0.70,0.86,0.60]
        case .woodland:
            positions = [CGPoint(x:16,y:2),CGPoint(x:-93,y:19),CGPoint(x:66,y:-13)]
            scales = [0.95,0.69,0.59]
        default:
            positions = [CGPoint(x:-17,y:7),CGPoint(x:-92,y:-9),CGPoint(x:76,y:-3)]
            scales = [0.96,0.56,0.66]
        }
        return (0..<count).map { i in
            let point = positions[i%positions.count]
            return .init(anchor:CGPoint(x:point.x+(random.next()-0.5)*24,y:point.y+(random.next()-0.5)*9),scale:scales[i%scales.count]*(0.90+random.next()*0.20))
        }
    }
    struct Stroke { let body: CGPath; let light: CGPath; let pencil: CGPath }
    static func branch(_ branch: BloomBranch, growth: Double, width: Double, tipRatio: Double, dry: Double, startDirection: CGPoint? = nil, endDirection: CGPoint? = nil) -> Stroke {
        let body = CGMutablePath(), light = CGMutablePath(), pencil = CGMutablePath()
        guard growth > 0, width > 0 else { return Stroke(body:body,light:light,pencil:pencil) }
        let steps = 24, phase = branch.birth*17+branch.end.x*0.07
        var left: [CGPoint] = [], right: [CGPoint] = []
        for i in 0...steps {
            let u = Double(i)/Double(steps), t = u*growth, q = 1-t
            let control = CGPoint(x:branch.control.x+dry*4,y:branch.control.y)
            let end = CGPoint(x:branch.end.x+dry*9,y:branch.end.y-dry*14)
            var at = CGPoint(x:q*q*branch.start.x+2*q*t*control.x+t*t*end.x,y:q*q*branch.start.y+2*q*t*control.y+t*t*end.y)
            var dx = 2*q*(control.x-branch.start.x)+2*t*(end.x-control.x)
            var dy = 2*q*(control.y-branch.start.y)+2*t*(end.y-control.y)
            if i == 0, let direction = startDirection { dx = direction.x;dy = direction.y }
            if i == steps && growth == 1, let direction = endDirection { dx = direction.x;dy = direction.y }
            let length = max(0.001,hypot(dx,dy)), nx = -dy/length, ny = dx/length
            if i == 0 && startDirection != nil {
                // Adjacent antialiased layer edges otherwise expose a paper hairline.
                at.x -= dx/length*0.22;at.y -= dy/length*0.22
            }
            // Endpoint modulation is zero: sequential trunk sections meet at the
            // same width. Newly extending tips stay soft and narrow.
            let pressure = 1+0.075*sin(t*13+phase)*sin(t*Double.pi)
            let growingTip = 1-(1-growth)*pow(u,8)*0.86
            let radius = width*0.5*(1-(1-tipRatio)*t)*pressure*growingTip
            left.append(CGPoint(x:at.x+nx*radius,y:at.y+ny*radius))
            right.append(CGPoint(x:at.x-nx*radius,y:at.y-ny*radius))
            let a = CGPoint(x:at.x+nx*radius*(0.32+sin(t*18+phase)*0.10),y:at.y+ny*radius*0.32)
            let b = CGPoint(x:at.x-nx*radius*0.64,y:at.y-ny*radius*0.64)
            if i == 0 || sin(t*29+phase) < -0.3 { light.move(to:a) } else { light.addLine(to:a) }
            if i == 0 || sin(t*21+phase) < -0.45 { pencil.move(to:b) } else { pencil.addLine(to:b) }
        }
        body.move(to:left[0]);for point in left.dropFirst() { body.addLine(to:point) }
        for point in right.reversed() { body.addLine(to:point) };body.closeSubpath()
        return Stroke(body:body,light:light,pencil:pencil)
    }
}
