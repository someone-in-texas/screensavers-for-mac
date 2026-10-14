import AppKit

/// A small continuous cloud-density mask. The layers move this immutable field
/// over the paper; there is no frame noise and no full-resolution simulation.
enum BloomWeatherField {
    static func mask(seed: UInt64) -> CGImage? {
        let w = 384,h = 256
        guard let c = bitmap(width:w,height:h) else { return nil }
        var random = ArtRandom(state:seed &+ 3981)
        let clouds = (0..<8).map { _ in (random.next()*1.4-0.2,random.next()*1.4-0.2,0.13+random.next()*0.24,0.11+random.next()*0.21,0.35+random.next()*0.5,random.next()*6.28) }
        // One-pixel fills honor the shared bitmap's native byte order.
        for y in 0..<h { for x in 0..<w {
            let px = Double(x)/Double(w), py = Double(y)/Double(h)
            var field = 0.0
            for (cx,cy,rx,ry,amount,angle) in clouds {
                let dx = px-cx,dy = py-cy
                let u = dx*cos(angle)+dy*sin(angle),v = -dx*sin(angle)+dy*cos(angle)
                field += exp(-pow(u/rx,2)-pow(v/ry,2))*amount
            }
            let alpha = min(0.82,field*0.56)
            c.setFillColor(NSColor.white.withAlphaComponent(alpha).cgColor)
            c.fill(CGRect(x:x,y:y,width:1,height:1))
        } }
        return c.makeImage()
    }
    struct RainSample { let head: CGPoint; let tail: CGPoint; let velocity: CGPoint }
    static func rain(seconds: Double, size: CGSize, origin: CGPoint, speed: Double, wind: Double, length: Double) -> RainSample {
        func wrap(_ v: Double) -> Double { v-floor(v) }
        let drift = seconds*0.045+wind*0.035*sin(seconds*0.21)
        let vx = (0.045+wind*0.035*0.21*cos(seconds*0.21))*(size.width+60)
        let vy = -speed*(size.height+60)
        let head = CGPoint(x:wrap(origin.x+drift)*(size.width+60)-30,y:wrap(origin.y-seconds*speed)*(size.height+60)-30)
        let magnitude = hypot(vx,vy)
        return RainSample(head:head,tail:CGPoint(x:head.x-vx/magnitude*length,y:head.y-vy/magnitude*length),velocity:CGPoint(x:vx,y:vy))
    }
}
