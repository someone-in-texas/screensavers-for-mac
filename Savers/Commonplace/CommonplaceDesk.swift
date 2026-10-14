import AppKit

/// A persistent tabletop, independent of the page being read. Rasterized only
/// on palette or viewport changes; camera movement simply transforms its layer.
enum CommonplaceDesk {
    static func camera(seconds: Double, size: CGSize) -> CGPoint {
        CGPoint(x:size.width*(0.025*sin(seconds*0.021)+0.009*sin(seconds*0.009)),
                y:size.height*(0.024*sin(seconds*0.016+0.4)+0.008*sin(seconds*0.033)))
    }
    static func image(size: CGSize, desk: NSColor, paper: NSColor, ink: NSColor, seed: UInt64) -> CGImage? {
        let density = min(2.0,2200/max(size.width,size.height))
        let w = max(1,Int(ceil(size.width*density))), h = max(1,Int(ceil(size.height*density)))
        let height = 1600*size.height/size.width
        guard let c = bitmap(width:w,height:h) else { return nil }
        c.scaleBy(x:Double(w)/1600,y:Double(h)/height)
        let bounds = CGRect(x:0,y:0,width:1600,height:height)
        c.setFillColor(desk.cgColor);c.fill(bounds)
        var random = ArtRandom(state:seed &+ 741)
        // Fine, interrupted tabletop fibers and broad rubbed tonal patches.
        for _ in 0..<6500 {
            let x = random.next()*1600,y = random.next()*height
            c.setStrokeColor(paper.withAlphaComponent(0.018+random.next()*0.025).cgColor);c.setLineWidth(0.35+random.next()*0.5)
            c.move(to:CGPoint(x:x,y:y));c.addQuadCurve(to:CGPoint(x:x+15+random.next()*80,y:y+0.5),control:CGPoint(x:x+30,y:y+random.next()*2));c.strokePath()
        }
        let glow = CGGradient(colorsSpace:nil,colors:[paper.withAlphaComponent(0.10).cgColor,NSColor.clear.cgColor] as CFArray,locations:[0,1])!
        c.drawRadialGradient(glow,startCenter:CGPoint(x:450,y:height*0.77),startRadius:10,endCenter:CGPoint(x:450,y:height*0.77),endRadius:1200,options:[])
        func scrap(_ rect: CGRect, angle: Double, shade: Double, ruled: Bool) {
            c.saveGState();c.translateBy(x:rect.midX,y:rect.midY);c.rotate(by:angle)
            let r = CGRect(x:-rect.width/2,y:-rect.height/2,width:rect.width,height:rect.height)
            c.setShadow(offset:CGSize(width:4,height:-6),blur:10,color:NSColor.black.withAlphaComponent(0.30).cgColor)
            c.setFillColor(paper.blended(withFraction:shade,of:desk)!.cgColor);c.fill(r);c.setShadow(offset:.zero,blur:0,color:nil)
            c.setStrokeColor(ink.withAlphaComponent(0.14).cgColor);c.setLineWidth(0.6)
            if ruled { for y in stride(from:r.minY+22,to:r.maxY-12,by:17) { c.move(to:CGPoint(x:r.minX+12,y:y));c.addLine(to:CGPoint(x:r.maxX-12,y:y));c.strokePath() } }
            else {
                c.move(to:CGPoint(x:r.minX,y:r.maxY));c.addLine(to:CGPoint(x:0,y:r.midY-14));c.addLine(to:CGPoint(x:r.maxX,y:r.maxY));c.strokePath()
            }
            if ruled {
                withAppKit(c) {
                    CommonplaceHandwriting.draw("measure twice\nkeep the offcuts",rect:CGRect(x:r.minX+18,y:r.maxY-85,width:r.width-36,height:70),size:18,color:ink.withAlphaComponent(0.42))
                }
                c.setStrokeColor(ink.withAlphaComponent(0.22).cgColor);c.setLineWidth(0.8)
                c.move(to:CGPoint(x:r.minX+20,y:r.maxY-100));c.addQuadCurve(to:CGPoint(x:r.minX+125,y:r.maxY-104),control:CGPoint(x:r.minX+74,y:r.maxY-98));c.strokePath()
            }
            c.restoreGState()
        }
        scrap(CGRect(x:45,y:height*0.60,width:320,height:350),angle:0.11,shade:0.16,ruled:true)
        scrap(CGRect(x:1215,y:height*0.09,width:300,height:220),angle:-0.12,shade:0.11,ruled:false)
        scrap(CGRect(x:1060,y:height*0.77,width:370,height:230),angle:0.09,shade:0.23,ruled:true)
        c.saveGState();c.translateBy(x:175,y:height*0.60+250);c.rotate(by:0.10)
        c.setStrokeColor(paper.blended(withFraction:0.48,of:ink)!.cgColor);c.setLineWidth(2.6);c.setLineCap(.round)
        c.move(to:CGPoint(x:11,y:2));c.addLine(to:CGPoint(x:11,y:52));c.addCurve(to:CGPoint(x:-11,y:52),control1:CGPoint(x:11,y:69),control2:CGPoint(x:-11,y:69));c.addLine(to:CGPoint(x:-11,y:0));c.addCurve(to:CGPoint(x:6,y:0),control1:CGPoint(x:-11,y:-13),control2:CGPoint(x:6,y:-13));c.addLine(to:CGPoint(x:6,y:47));c.strokePath();c.restoreGState()
        // A worn pencil with exposed wood and a graphite point.
        c.saveGState();c.translateBy(x:1410,y:height*0.53);c.rotate(by:-0.13)
        c.setShadow(offset:CGSize(width:4,height:-5),blur:5,color:NSColor.black.withAlphaComponent(0.3).cgColor)
        c.setFillColor(NSColor(srgbRed:0.58,green:0.39,blue:0.20,alpha:1).cgColor);c.fill(CGRect(x:-6,y:-190,width:12,height:330));c.setShadow(offset:.zero,blur:0,color:nil)
        c.setFillColor(paper.withAlphaComponent(0.5).cgColor);c.fill(CGRect(x:-4,y:-187,width:2,height:325))
        c.move(to:CGPoint(x:-6,y:-190));c.addLine(to:CGPoint(x:0,y:-220));c.addLine(to:CGPoint(x:6,y:-190));c.closePath();c.setFillColor(NSColor(srgbRed:0.72,green:0.58,blue:0.37,alpha:1).cgColor);c.fillPath()
        c.move(to:CGPoint(x:-1.6,y:-211));c.addLine(to:CGPoint(x:0,y:-220));c.addLine(to:CGPoint(x:1.6,y:-211));c.closePath();c.setFillColor(ink.cgColor);c.fillPath();c.restoreGState()
        // Partial cup ring is a quiet trace, not another prominent object.
        c.setStrokeColor(ink.withAlphaComponent(0.18).cgColor);c.setLineWidth(2.4)
        c.addArc(center:CGPoint(x:225,y:height*0.19),radius:83,startAngle:0.3,endAngle:5.6,clockwise:false);c.strokePath()
        c.setStrokeColor(paper.withAlphaComponent(0.08).cgColor);c.setLineWidth(1.0)
        c.strokeEllipse(in:CGRect(x:143,y:height*0.19-81,width:163,height:163))
        return c.makeImage()
    }
}
