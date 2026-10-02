import AppKit

/// Small, immutable surface resources, generated once per appearance/scale change.
/// Grain stays attached to the material rather than flickering between frames.
enum DappleTexture {
    static func surface(radius: Double, color: RGB, material: DappleMaterial, intensity: Double, seed: UInt64, scale: Double) -> CGImage {
        let pixels = min(768, max(96, Int(ceil(radius * 2 * scale))))
        let c = bitmap(width: pixels, height: pixels)!
        c.scaleBy(x: Double(pixels)/256, y: Double(pixels)/256)
        var random = DappleRandom(state: seed)
        let path = CGMutablePath()
        let phase = random.next() * .pi * 2
        for i in 0...360 {
            let a = Double(i) / 360 * .pi * 2
            let r = 125 + (material == .ceramic ? 0.15 : 0.30) * (sin(a*7+phase) + 0.45*sin(a*13-phase))
            let p = CGPoint(x: 128 + r*cos(a), y: 128 + r*sin(a))
            if i == 0 { path.move(to:p) } else { path.addLine(to:p) }
        }
        path.closeSubpath(); c.addPath(path); c.clip()
        c.setFillColor(color.color.cgColor); c.fill(CGRect(x: 0,y: 0,width:256,height:256))
        // Broad pigment variation under fine fibers. Low alpha avoids a noise-filter look.
        for _ in 0..<110 {
            let x = random.next()*256, y = random.next()*256, r = 3 + random.next()*14
            c.setFillColor((random.next() > 0.5 ? NSColor.white : NSColor.black).withAlphaComponent(intensity * 0.012).cgColor)
            c.fillEllipse(in: CGRect(x:x,y:y,width:r,height:r*0.7))
        }
        let count = material == .soft ? 2500 : 4600
        for _ in 0..<count {
            let x = random.next()*256, y = random.next()*256, length = 0.25 + random.next() * (material == .paper ? 1.3 : 0.55)
            let alpha = intensity * (material == .ink ? 0.19 : material == .ceramic ? 0.06 : material == .paper ? 0.09 : 0.12) * (0.3+random.next())
            c.setFillColor((random.next() > 0.55 ? NSColor.white : NSColor.black).withAlphaComponent(alpha).cgColor)
            c.fillEllipse(in: CGRect(x:x,y:y,width:length,height:0.22+random.next()*0.45))
        }
        if material == .paper {
            for _ in 0..<100 {
                let x = random.next()*256, y = random.next()*256, length = 2+random.next()*4
                c.setStrokeColor((random.next()>0.45 ? NSColor.white : NSColor.black).withAlphaComponent(intensity*0.04).cgColor)
                c.setLineWidth(0.20); c.move(to:CGPoint(x:x,y:y))
                c.addQuadCurve(to:CGPoint(x:x+length,y:y+0.8),control:CGPoint(x:x+length*0.5,y:y+random.next()*1.8)); c.strokePath()
            }
        }
        // A very faint, broken printed rim rather than a glossy bevel.
        c.addPath(path); c.setStrokeColor(NSColor.white.withAlphaComponent(material == .ceramic ? 0.22 : 0.07).cgColor); c.setLineWidth(1.3); c.strokePath()
        return c.makeImage()!
    }
    static func background(_ palette: DapplePalette, textured: Bool, seed: UInt64) -> CGImage {
        let c = bitmap(width: 512, height: 512)!
        c.setFillColor(palette.background.color.cgColor); c.fill(CGRect(x:0,y:0,width:512,height:512))
        if textured {
            var random = DappleRandom(state: seed)
            for _ in 0..<24000 {
                let x = random.next()*512, y = random.next()*512
                c.setFillColor((random.next()>0.5 ? NSColor.white : NSColor.black).withAlphaComponent((0.023+random.next()*0.025) * (palette == .nightGarden || palette == .dusk ? 0.65 : 1)).cgColor)
                c.fillEllipse(in:CGRect(x:x,y:y,width:0.3+random.next()*1.4,height:0.3+random.next()*0.5))
            }
        }
        return c.makeImage()!
    }
}
