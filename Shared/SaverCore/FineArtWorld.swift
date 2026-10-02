import AppKit

/// A bounded edition of paths, with connected branches and staggered lifetimes.
struct PrintStroke {
    let path: CGPath
    let points: [CGPoint]
    let weight: Double
    let opacity: Double
    var family = 0
    var delay = 0.0
    var duration = 22.0
    var digital = false
    var end: CGPoint { points.last ?? .zero }
    func evolution(_ time: Double, research: Bool) -> (end: Double, opacity: Double) {
        let cycle=PrintCycle(family:family,research:research)
        let state=cycle.state(time)
        let tempo=research ? cycle.period/78:1
        return (worldEase((state.phase/tempo-delay)/duration),state.opacity)
    }
}
/// Start with blank ink, then renew a connected branch only while invisible.
/// Unequal periods avoid synchronized clears and long completed-drawing plateaus.
struct PrintCycle {
    let family:Int, research:Bool
    var period:Double {research ? 78+Double(family)*9 : 49+Double((family*7)%9)*2}
    var start:Double {research ? Double(family)*3 : Double(family%6)*2+Double(family/6)*0.9}
    func state(_ time:Double)->(generation:Int,phase:Double,opacity:Double) {
        let elapsed=max(0,(time.isFinite ? time:0)-start)
        let phase=elapsed.truncatingRemainder(dividingBy:period)
        return (Int(elapsed/period),phase,1-worldEase((phase-(period-7))/7))
    }
}

struct PrintForm: Equatable { let x: Double, y: Double, width: Double, height: Double, tilt: Double }
struct ResearchPrint {
    let anchor: CGPoint
    let strokes: [PrintStroke]
    init(seed: UInt64, settings: ResearchFineSettings, generations:[Int:Int]=[:]) {
        let ax = settings.composition == .asymmetric ? 665.0 : settings.composition == .gallery ? 620 : 790
        anchor = CGPoint(x: ax, y: 485)
        var ink: [PrintStroke] = []
        // Each family starts at a chair foot. Chambers grow from completed junctions,
        // then retire independently so the drawing never clears all at once.
        let families = settings.drawing == .sparse ? 2 : 3
        for family in 0..<families {
            var r=ArtRandom(state:seed ^ (UInt64(family+1) &* 0x9e3779b97f4a7c15) ^ (UInt64(generations[family] ?? 0) &* 0xd1b54a32d192ed03))
            let direction = family == 2 || (settings.composition == .radial && family == 1) ? -1.0 : 1.0
            let origin = CGPoint(x:ax + (family == 0 ? 20 : family == 1 ? -25 : -43),y:family == 2 ? 482 : 470)
            let w = 112+r.next()*48, h = 57+r.next()*30
            let baseY = family == 2 ? 395.0 : 433-Double(family)*76
            func pt(_ x:Double,_ y:Double)->CGPoint {CGPoint(x:origin.x+direction*x,y:y)}
            func route(_ points:[CGPoint],_ weight:Double,_ opacity:Double,_ delay:Double,_ duration:Double) {
                let p=CGMutablePath();p.addLines(between:points)
                ink.append(PrintStroke(path:p,points:points,weight:weight,opacity:opacity,family:family,delay:delay,duration:duration))
            }
            let junction=pt(52,baseY)
            route([origin,pt(0,baseY+27),pt(26,baseY+27),pt(26,baseY),junction],1.15,0.77,0,12)
            let corner=pt(52+w,baseY-h)
            let chamber = family == 1 ? [junction,pt(52+w*0.52,baseY),pt(52+w*0.52,baseY+18),pt(52+w,baseY+18),corner] : [junction,pt(52+w,baseY),corner]
            route(chamber,1.08,0.74,12,18)
            route([corner,pt(80,baseY-h),pt(80,baseY-22),pt(28+w,baseY-22)],0.72,0.48,30,22)
            if family == 0 && settings.drawing != .sparse {
                route([pt(28+w,baseY-22),pt(28+w,baseY)],0.72,0.48,52,10)
            }
            if settings.density != .open && settings.drawing != .sparse {
                let out=pt(100+w,baseY-h-57)
                route([corner,pt(100+w,baseY-h),out,pt(157+w,baseY-h-57),pt(157+w,baseY-16)],0.85,0.53,30,25)
                route([out,pt(100+w,baseY-h-92),pt(35+w,baseY-h-92)],0.55,0.32,55,15)
                // A contrary branch gives the plan an unfinished, asymmetric rhythm.
                route([junction,pt(52,baseY+19),pt(13,baseY+19)],0.58,0.36,15,34)
            }
            if settings.drawing == .recursive || settings.density == .dense {
                route([corner,pt(37+w,baseY-h),pt(37+w,baseY-35),pt(97,baseY-35),pt(97,baseY-h+15)],0.52,0.35,33,26)
            }
            if settings.drawing == .blueprint || settings.drawing == .orthographic {
                route([pt(42,baseY+10),pt(66+w,baseY+10)],0.45,0.23,18,18)
                if settings.drawing == .blueprint {route([pt(42,baseY+16),pt(42,baseY-h-10)],0.45,0.23,20,17)}
            }
        }
        strokes=ink
    }
}
struct StrawberryPrint {
    let forms: [PrintForm]
    let strokes: [PrintStroke]
    init(seed: UInt64, settings: StrawberryFineSettings, generations:[Int:Int]=[:]) {
        var r = ArtRandom(state:seed)
        var f:[PrintForm]=[]
        let xs:[Double], ys:[Double], scales:[Double]
        switch settings.composition {
        case .suspended: xs=[574,795,988];ys=[654,687,644];scales=[1.08,0.92,0.78]
        case .anchored: xs=[570,785,995];ys=[603,616,598];scales=[1,0.86,1.02]
        case .triptych: xs=[510,800,1090];ys=[670,670,670];scales=[0.9,1,0.91]
        case .asymmetric: xs=[610,842,1000];ys=[676,635,697];scales=[1.2,0.78,0.66]
        case .clustered: xs=[665,810,936];ys=[690,662,710];scales=[1,0.83,0.74]
        }
        for i in 0..<3 {
            let profile=(i+Int(seed%3))%3
            let widths=[142.0,162,121],heights=[148.0,119,151]
            f.append(PrintForm(x:xs[i]+(r.next()-0.5)*24,y:ys[i]+(r.next()-0.5)*18,
                               width:(widths[profile]+r.next()*20)*scales[i],height:(heights[profile]+r.next()*20)*scales[i],tilt:(r.next()-0.5)*0.56))
        }
        forms=f
        var ink:[PrintStroke]=[]
        for (index,form) in f.enumerated() {
            let x=0.04*form.width,y = -0.50*form.height
            let origin=CGPoint(x:form.x+x*cos(form.tilt)-y*sin(form.tilt),y:form.y+x*sin(form.tilt)+y*cos(form.tilt))
            for branch in 0..<6 {
                let family=index*6+branch
                var r=ArtRandom(state:seed ^ (UInt64(family+1) &* 0x9e3779b97f4a7c15) ^ (UInt64(generations[family] ?? 0) &* 0xd1b54a32d192ed03))
                let spread=(Double(branch)-2.5)*38 + (r.next()-0.5)*30
                let depth=min(origin.y-112,235+r.next()*210)
                let digital=settings.blend != .organic && (settings.blend == .synthetic || branch%3 != 1)
                let threshold=min(0.87,max(0.22,settings.blend.threshold+(r.next()-0.5)*0.30))
                let p=CGMutablePath();p.move(to:origin)
                var points=[origin], previous=origin
                for j in 1...8 {
                    let t=Double(j)/8
                    let next=CGPoint(x:origin.x+spread*pow(t,0.8)+sin(t*4+Double(branch))*12*t,y:origin.y-depth*t)
                    if digital && t>threshold {
                        let elbow=CGPoint(x:previous.x,y:next.y)
                        p.addLine(to:elbow);p.addLine(to:next);points += [elbow,next]
                    } else {
                        p.addCurve(to:next,control1:CGPoint(x:previous.x+sin(Double(branch))*9,y:previous.y-20),control2:CGPoint(x:next.x-7,y:next.y+20));points.append(next)
                    }
                    previous=next
                }
                let duration=22+r.next()*7
                ink.append(PrintStroke(path:p,points:points,weight:branch%3==0 ? 1.12:0.70,opacity:branch%3==0 ? 0.76:0.45,family:family,delay:0,duration:duration,digital:digital))
                for twigIndex in 0..<2 {
                    let start=points[min(3+twigIndex*2,points.count-1)]
                    let end=CGPoint(x:start.x+spread*0.48+Double(twigIndex)*25-12,y:max(104,start.y-90-r.next()*100))
                    let twig=CGMutablePath();twig.move(to:start)
                    let circuit=digital && twigIndex==1
                    if circuit {
                        twig.addLine(to:CGPoint(x:start.x,y:end.y+28));twig.addLine(to:CGPoint(x:end.x,y:end.y+28));twig.addLine(to:end)
                    } else {twig.addCurve(to:end,control1:CGPoint(x:start.x+spread*0.2,y:start.y-25),control2:CGPoint(x:end.x-10,y:end.y+32))}
                    ink.append(PrintStroke(path:twig,points:[start,end],weight:twigIndex==0 ? 0.48:0.40,opacity:twigIndex==0 ? 0.34:0.28,family:family,delay:duration*0.70,duration:PrintCycle(family:family,research:false).period-10-duration*0.70+Double(twigIndex),digital:circuit))
                }
            }
        }
        strokes=ink
    }
}

struct PrintShape {
    let path:CGPath
    var fill:CGColor? = nil
    var stroke:CGColor? = nil
    var width:Double = 1
}

enum FineArtArtwork {
    static let size=CGSize(width:1600,height:1000)
    static let fruitSize=CGSize(width:300,height:340)
    static func paper(_ colors:PrintColors,texture:PrintTexture,seed:UInt64)->CGImage {
        WorldInk.image(size){ c in
            WorldInk.rect(c,CGRect(origin:.zero,size:size),colors.ground)
            guard texture != .smooth else {return}
            var r=ArtRandom(state:seed ^ 0x9c08)
            let count=texture == .vellum ? 19000 : 33000
            for i in 0..<count {
                let x=r.next()*1600,y=r.next()*1000,a=0.012+r.next()*0.032
                if texture == .canvas {WorldInk.path(c,[CGPoint(x:x,y:y),CGPoint(x:x+4,y:y)],colors.ink,0.35,a)}
                else {WorldInk.oval(c,CGRect(x:x,y:y,width:0.35+r.next()*1.3,height:0.3+r.next()*0.9),i%3==0 ? RGB(1,1,1):colors.ink,a)}
            }
        }
    }
    static func chairPaths(_ colors:PrintColors,angle:Double)->[PrintShape] {
            var shapes:[PrintShape]=[]
            func fill(_ path:CGPath,_ color:RGB,_ alpha:Double=1){shapes.append(PrintShape(path:path,fill:WorldInk.color(color,alpha)))}
            func stroke(_ path:CGPath,_ color:RGB,_ width:Double,_ alpha:Double=1){shapes.append(PrintShape(path:path,stroke:WorldInk.color(color,alpha),width:width))}
            func line(_ points:[CGPoint],_ color:RGB,_ width:Double,_ alpha:Double=1){let p=CGMutablePath();p.addLines(between:points);stroke(p,color,width,alpha)}
            func oval(_ rect:CGRect,_ color:RGB,_ alpha:Double=1){fill(CGPath(ellipseIn:rect,transform:nil),color,alpha)}
            let blue=colors.pigment
            let dark=WorldInk.blend(blue,RGB(0.065,0.10,0.19),0.40)
            let edge=WorldInk.blend(blue,RGB(0.76,0.81,0.86),0.22)
            func p(_ x:Double,_ y:Double,_ z:Double)->CGPoint {
                let xx=x*cos(angle)-z*sin(angle),zz=x*sin(angle)+z*cos(angle)
                return CGPoint(x:120+xx*0.86+zz*0.47,y:47+y+zz*0.25-xx*0.10)
            }
            func tube(_ path:CGPath,_ width:Double=4.4) {
                stroke(path,dark,width)
                stroke(path,blue,width*0.63)
            }
            func rail(_ points:[CGPoint],_ width:Double=4.4){let path=CGMutablePath();path.addLines(between:points);tube(path,width)}
            for i in 0..<10 {
                let w=144-Double(i)*10,h=23-Double(i)*1.6
                oval(CGRect(x:129-w/2,y:47-h/2,width:w,height:h),colors.ink,0.009)
            }
            // Rear folding support: a second splayed U-frame pivots beneath the seat.
            for x in [-39.0,39.0] {
                rail([p(x*1.13,0,54),p(x,67,-14),p(x,81,-22)],4.3)
            }
            rail([p(-41,28,27),p(41,28,27)],3.5)
            rail([p(-40,58,-5),p(40,58,-5)],3.1)
            // One continuous rolled steel frame: front legs, bent shoulders, rounded top.
            let frame=CGMutablePath();frame.move(to:p(-47,0,-42));frame.addLine(to:p(-41,77,20));frame.addLine(to:p(-43,143,32))
            frame.addCurve(to:p(-29,170,37),control1:p(-45,157,35),control2:p(-40,169,37))
            frame.addCurve(to:p(29,170,37),control1:p(-12,174,38),control2:p(17,174,38))
            frame.addCurve(to:p(43,143,32),control1:p(41,169,37),control2:p(45,157,35))
            frame.addLine(to:p(41,77,20));frame.addLine(to:p(47,0,-42));tube(frame,5.0)
            // Pressed metal back, with bowed lower lip and an inset rolled perimeter.
            let back=CGMutablePath();back.move(to:p(-39,124,28));back.addLine(to:p(-39,143,31))
            back.addCurve(to:p(-26,166,35),control1:p(-40,156,34),control2:p(-36,165,35))
            back.addCurve(to:p(26,166,35),control1:p(-10,170,36),control2:p(16,170,36))
            back.addCurve(to:p(39,143,31),control1:p(36,165,35),control2:p(40,156,34))
            back.addLine(to:p(39,124,28));back.addCurve(to:p(-39,124,28),control1:p(18,130,20),control2:p(-18,130,20));back.closeSubpath()
            fill(back,blue)
            let inset=CGMutablePath();inset.move(to:p(-35,135,29));inset.addLine(to:p(-35,144,31));inset.addCurve(to:p(-23,162,34),control1:p(-36,155,33),control2:p(-31,162,34));inset.addCurve(to:p(23,162,34),control1:p(-9,166,35),control2:p(14,166,35));inset.addCurve(to:p(35,144,31),control1:p(31,162,34),control2:p(36,155,33))
            stroke(inset,dark,0.9,0.45)
            // Small hinge plates and diagonal stays make the folding mechanism legible.
            for x in [-40.0,40.0] {
                rail([p(x,107,25),p(x,78,31),p(x,73,-13)],2.4)
                let hinge=p(x,88,23)
                oval(CGRect(x:hinge.x-2.7,y:hinge.y-2.7,width:5.4,height:5.4),dark)
                oval(CGRect(x:hinge.x-1,y:hinge.y-1,width:2,height:2),edge,0.75)
            }
            func seat(_ y:Double)->CGPath {
                let path=CGMutablePath();path.move(to:p(-37,y,-33));path.addLine(to:p(37,y,-33))
                path.addCurve(to:p(46,y,-25),control1:p(44,y,-33),control2:p(46,y,-31));path.addLine(to:p(44,y,23))
                path.addCurve(to:p(36,y,29),control1:p(44,y,28),control2:p(42,y,29));path.addLine(to:p(-36,y,29))
                path.addCurve(to:p(-44,y,23),control1:p(-42,y,29),control2:p(-44,y,28));path.addLine(to:p(-46,y,-25))
                path.addCurve(to:p(-37,y,-33),control1:p(-46,y,-31),control2:p(-44,y,-33));path.closeSubpath();return path
            }
            fill(seat(73),dark)
            fill(seat(78),blue)
            // Restrained turned rim, not a glossy upholstery cushion.
            line([p(-38,78,-32),p(37,78,-32),p(45,78,-25)],edge,1.15,0.85)
            line([p(-30,79,22),p(30,79,22)],dark,0.65,0.32)
            for x in [-47.0,47.0] {rail([p(x,0,-42),p(x,3,-39)],5.1)}
            for x in [-44.07,44.07] {rail([p(x,0,54),p(x,3,51)],4.5)}
            return shapes
    }
    static func fruitCrown(_ index:Int,seed:UInt64)->CGPoint {
        var r=ArtRandom(state:(seed ^ 0xF137) &+ UInt64(index)*7919)
        return CGPoint(x:(r.next()-0.5)*0.30,y:0.32+r.next()*0.14)
    }
    /// Seeded shoulders and cheek curves keep a recognizable fruit without a repeated stamp.
    static func fruitPath(_ index:Int,seed:UInt64=42)->CGPath {
        var r=ArtRandom(state:seed &+ UInt64(index)*7919)
        let left = -0.36-r.next()*0.18, right=0.35+r.next()*0.19
        let shoulderL=0.17+r.next()*0.24, shoulderR=0.18+r.next()*0.24
        let crown=fruitCrown(index,seed:seed), cheek=(r.next()-0.5)*0.22
        let leftBelly = -0.08+r.next()*0.25, rightBelly = -0.07+r.next()*0.25
        let p=CGMutablePath();p.move(to:CGPoint(x:0.04,y:-0.50))
        p.addCurve(to:CGPoint(x:left,y:leftBelly),control1:CGPoint(x:-0.12+cheek,y:-0.48),control2:CGPoint(x:left-0.04,y:-0.12))
        p.addCurve(to:crown,control1:CGPoint(x:left-0.03,y:shoulderL+0.17),control2:CGPoint(x:-0.16,y:shoulderL+0.09))
        p.addCurve(to:CGPoint(x:right,y:rightBelly),control1:CGPoint(x:0.20,y:shoulderR+0.13),control2:CGPoint(x:right+0.06,y:shoulderR+0.08))
        p.addCurve(to:CGPoint(x:0.04,y:-0.50),control1:CGPoint(x:right+0.01,y:-0.12),control2:CGPoint(x:0.19+cheek,y:-0.47))
        p.closeSubpath();return p
    }
    static func fruit(_ form:PrintForm,index:Int,colors:PrintColors,settings:StrawberryFineSettings,seed:UInt64,resolution:Double=2)->CGImage {
        WorldInk.image(fruitSize,resolution){c in
            c.translateBy(x:fruitSize.width/2,y:fruitSize.height/2);c.rotate(by:form.tilt);c.scaleBy(x:form.width,y:form.height)
            let path=fruitPath(index,seed:seed)
            let pigment=WorldInk.blend(colors.pigment,RGB(0.88,0.18,0.13),settings.literalness == .abstract ? 0:0.40-Double(index)*0.06)
            c.addPath(path);c.setFillColor(WorldInk.color(pigment));c.fillPath()
            c.saveGState();c.addPath(path);c.clip()
            var r=ArtRandom(state:seed &+ UInt64(index)*79)
            for _ in 0..<1300 {
                let x=r.next()-0.5,y=r.next()-0.55,rad=0.002+r.next()*0.012
                WorldInk.oval(c,CGRect(x:x,y:y,width:rad,height:rad*0.58),r.next()>0.5 ? colors.ground : colors.ink,0.02+r.next()*0.04)
            }
            if settings.literalness != .abstract {
                let seedColor=WorldInk.blend(RGB(0.12,0.19,0.10),colors.ink,0.25)
                // Jittered rows read as hand-cut seeds, with clear spacing and varied tilt.
                for row in 0..<5 {for col in 0..<5 {
                    guard r.next()>0.18 else {continue}
                    let x=(Double(col)-2)*0.16+(r.next()-0.5)*0.11
                    let y = -0.35+Double(row)*0.135+(r.next()-0.5)*0.055
                    guard path.contains(CGPoint(x:x*1.18,y:y)) else {continue}
                    c.saveGState();c.translateBy(x:x,y:y);c.rotate(by:(r.next()-0.5)*1.7)
                    let seedScale=0.75+r.next()*0.55;c.scaleBy(x:seedScale,y:seedScale)
                    let seed=CGMutablePath();seed.move(to:CGPoint(x:0,y:0.017))
                    seed.addCurve(to:CGPoint(x:0,y:-0.019),control1:CGPoint(x:-0.026,y:-0.013),control2:CGPoint(x:-0.005,y:-0.024))
                    seed.addCurve(to:CGPoint(x:0,y:0.017),control1:CGPoint(x:0.016,y:-0.019),control2:CGPoint(x:0.011,y:0.005))
                    c.addPath(seed);c.setFillColor(WorldInk.color(seedColor,0.88));c.fillPath();c.restoreGState()
                }}
            }
            c.restoreGState()
            if settings.literalness != .abstract {
                let leaf=WorldInk.blend(RGB(0.23,0.36,0.19),colors.ink,0.16)
                let center=fruitCrown(index,seed:seed)
                for i in 0..<5 {
                    let angle=Double(i)*1.22+0.22+(r.next()-0.5)*0.30
                    let length=0.21+r.next()*0.13
                    let tip=CGPoint(x:center.x+cos(angle)*length,y:center.y+sin(angle)*length*0.70)
                    let leafPath=CGMutablePath();leafPath.move(to:center)
                    leafPath.addQuadCurve(to:tip,control:CGPoint(x:(center.x+tip.x)/2-sin(angle)*0.05,y:(center.y+tip.y)/2+cos(angle)*0.055))
                    leafPath.addQuadCurve(to:center,control:CGPoint(x:(center.x+tip.x)/2+sin(angle)*0.035,y:(center.y+tip.y)/2-cos(angle)*0.045))
                    c.addPath(leafPath);c.setFillColor(WorldInk.color(leaf));c.fillPath()
                }
                let lean=(r.next()-0.5)*0.26,stemHeight=0.12+r.next()*0.06
                WorldInk.path(c,[center,CGPoint(x:center.x+lean*0.4,y:center.y+stemHeight*0.65),CGPoint(x:center.x+lean,y:center.y+stemHeight)],leaf,0.022+r.next()*0.009)
            }
        }
    }
}
