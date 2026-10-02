import AppKit

/// Fixed-size editions: seeded geometry is generated once, animation reveals existing ink.
struct PrintStroke {
    let path: CGPath
    let points: [CGPoint]
    let weight: Double
    let opacity: Double
    var end: CGPoint { points.last ?? .zero }
}
struct PrintForm: Equatable { let x: Double, y: Double, width: Double, height: Double, tilt: Double }
struct ResearchPrint {
    let anchor: CGPoint
    let strokes: [PrintStroke]
    init(seed: UInt64, settings: ResearchFineSettings) {
        var r = ArtRandom(state: seed)
        let ax = settings.composition == .asymmetric ? 610.0 : settings.composition == .gallery ? 560 : 770
        anchor = CGPoint(x: ax, y: 450)
        var ink: [PrintStroke] = []
        func route(_ points: [CGPoint], _ weight: Double, _ opacity: Double) {
            let p=CGMutablePath();p.addLines(between:points)
            ink.append(PrintStroke(path:p,points:points,weight:weight,opacity:opacity))
        }
        // Two foot routes enter a loose plan; chambers share edges instead of overprinting boxes.
        route([CGPoint(x:ax+20,y:459),CGPoint(x:ax+20,y:431),CGPoint(x:ax+113,y:431)],1.15,0.74)
        route([CGPoint(x:ax-25,y:454),CGPoint(x:ax-25,y:412),CGPoint(x:ax+76,y:412),CGPoint(x:ax+76,y:343)],0.7,0.36)
        let groups=settings.drawing == .sparse ? 2 : 4
        for i in 0..<groups {
            let column=i%2,row=i/2
            var x=ax+[94.0,301,119,330][i]
            let y=[463.0,450,326,284][i] + (r.next()-0.5)*12
            if settings.composition == .radial && column==0 {x=ax-245}
            if settings.composition == .centered {x -= 40}
            let w=[167.0,91,176,93][i]*(0.91+r.next()*0.18),h=[64.0,126,81,47][i]*(0.90+r.next()*0.20)
            if i==3 {
                route([CGPoint(x:x-19,y:y+14),CGPoint(x:x+w,y:y+14),CGPoint(x:x+w,y:y-h)],0.72,0.40)
                continue
            }
            if i==2 {
                route([CGPoint(x:x,y:y),CGPoint(x:x+70,y:y),CGPoint(x:x+70,y:y+24),CGPoint(x:x+w,y:y+24),CGPoint(x:x+w,y:y-h),CGPoint(x:x+41,y:y-h)],1.08,0.64)
            } else {
            route([CGPoint(x:x,y:y-27),CGPoint(x:x,y:y),CGPoint(x:x+w,y:y),CGPoint(x:x+w,y:y-h),CGPoint(x:x+28,y:y-h)],1.08,0.68)
            }
            if i != 1 {route([CGPoint(x:x+19,y:y-8),CGPoint(x:x+19,y:y-h+19),CGPoint(x:x+w-24,y:y-h+19),CGPoint(x:x+w-24,y:y-29),CGPoint(x:x+59,y:y-29)],0.72,0.48)}
            if settings.density != .open && settings.drawing != .sparse {
                route([CGPoint(x:x+w,y:y-h+21),CGPoint(x:x+w+24,y:y-h+21),CGPoint(x:x+w+24,y:y-h-23),CGPoint(x:x+w-32,y:y-h-23)],0.60,0.28)
                if i != 0 {route([CGPoint(x:x+42,y:y-h+19),CGPoint(x:x+42,y:y-46),CGPoint(x:x+67,y:y-46)],0.65,0.41)}
            }
            if row==0 && column==0 {route([CGPoint(x:x+51,y:y-h),CGPoint(x:x+51,y:326),CGPoint(x:x+83,y:326)],0.75,0.48)}
            if column==0 && row==0 {route([CGPoint(x:x+w,y:y-17),CGPoint(x:ax+301,y:y-17)],0.7,0.40)}
            if settings.drawing == .recursive || settings.density == .dense {
                route([CGPoint(x:x+33,y:y-17),CGPoint(x:x+w-13,y:y-17),CGPoint(x:x+w-13,y:y-h+9),CGPoint(x:x+9,y:y-h+9)],0.5,0.29)
            }
            if settings.drawing == .blueprint || settings.drawing == .orthographic {
                route([CGPoint(x:x-7,y:y+11),CGPoint(x:x+w+14,y:y+11)],0.45,0.21)
                if settings.drawing == .blueprint {
                    route([CGPoint(x:x-8,y:y+15),CGPoint(x:x-8,y:y-h-8)],0.45,0.21)
                    route([CGPoint(x:x-12,y:y+11),CGPoint(x:x-4,y:y+11)],0.55,0.33)
                }
            }
        }
        route([CGPoint(x:ax-43,y:461),CGPoint(x:ax-43,y:472),CGPoint(x:ax+55,y:472),CGPoint(x:ax+55,y:451)],0.45,0.20)
        strokes=ink
    }
}
struct StrawberryPrint {
    let forms: [PrintForm]
    let strokes: [PrintStroke]
    init(seed: UInt64, settings: StrawberryFineSettings) {
        var r = ArtRandom(state:seed)
        var f:[PrintForm]=[]
        let xs:[Double], ys:[Double], scales:[Double]
        switch settings.composition {
        case .suspended: xs=[574,795,988];ys=[642,672,630];scales=[1.08,0.92,0.78]
        case .anchored: xs=[570,785,995];ys=[563,576,558];scales=[1,0.86,1.02]
        case .triptych: xs=[510,800,1090];ys=[660,660,660];scales=[0.9,1,0.91]
        case .asymmetric: xs=[610,842,1000];ys=[656,615,677];scales=[1.2,0.78,0.66]
        case .clustered: xs=[665,810,936];ys=[670,642,690];scales=[1,0.83,0.74]
        }
        for i in 0..<3 { f.append(PrintForm(x:xs[i]+(r.next()-0.5)*20,y:ys[i]+(r.next()-0.5)*14,width:(i==0 ? 113 : i==1 ? 98 : 86)*scales[i],height:(i==0 ? 133 : i==1 ? 154 : 140)*scales[i],tilt:(r.next()-0.5)*0.19)) }
        forms=f
        var ink:[PrintStroke]=[]
        var attachments:[CGPoint]=[]
        for form in f {
            let x=0.04*form.width,y = -0.50*form.height
            attachments.append(CGPoint(x:form.x+x*cos(form.tilt)-y*sin(form.tilt),y:form.y+x*sin(form.tilt)+y*cos(form.tilt)))
        }
        for index in f.indices {
            let origin=attachments[index]
            for branch in 0..<6 {
                let spread=(Double(branch)-2.5)*35 + (r.next()-0.5)*34
                let depth=170+r.next()*185
                let threshold=min(0.92,max(0.15,settings.blend.threshold+(r.next()-0.5)*0.62))
                let p=CGMutablePath();p.move(to:origin)
                var points=[origin], previous=origin
                let organicSteps=Int(ceil(threshold*6))
                for j in 1...6 {
                    let t=Double(j)/6
                    let x=origin.x+spread*pow(t,0.8)+sin(t*4+Double(branch))*13*t
                    let y=origin.y-depth*t
                    let next=CGPoint(x:x,y:y)
                    if j>organicSteps && branch%3 != 1 {
                        // One long trace, at most two turns; some roots remain organic to the end.
                        let elbow=CGPoint(x:previous.x,y:y)
                        p.addLine(to:elbow);p.addLine(to:next);points += [elbow,next]
                        if j<6 {
                            let end=CGPoint(x:x,y:origin.y-depth)
                            if branch==0 && index != 1 {
                                let bend=CGPoint(x:x,y:end.y+31),offset=CGPoint(x:x+9,y:end.y+31),tip=CGPoint(x:x+9,y:end.y)
                                p.addLine(to:bend);p.addLine(to:offset);p.addLine(to:tip);points += [bend,offset,tip]
                            } else {p.addLine(to:end);points.append(end)}
                            previous=end;break
                        }
                    } else {
                        p.addCurve(to:next,control1:CGPoint(x:previous.x+sin(Double(branch))*8,y:previous.y-20),control2:CGPoint(x:x-7,y:y+20));points.append(next)
                    }
                    previous=next
                }
                ink.append(PrintStroke(path:p,points:points,weight:branch%3==0 ? 1.12:0.65,opacity:branch%3==0 ? 0.74:0.39+r.next()*0.15))
                let start=points[min(2+branch%2,points.count-1)]
                for twigIndex in 0..<2 {
                    let end=CGPoint(x:start.x+spread*0.5+Double(twigIndex)*22-11,y:start.y-52-r.next()*96)
                    let twig=CGMutablePath();twig.move(to:start);twig.addCurve(to:end,control1:CGPoint(x:start.x+spread*0.2,y:start.y-20),control2:CGPoint(x:end.x-10,y:end.y+32))
                    ink.append(PrintStroke(path:twig,points:[start,end],weight:twigIndex==0 ? 0.45:0.32,opacity:twigIndex==0 ? 0.30:0.20))
                }
            }
            // Long, shared root across the interval: not three isolated diagrams.
            if index<2 {
                let a=CGPoint(x:origin.x+24,y:origin.y-86),b=CGPoint(x:attachments[index+1].x-22,y:attachments[index+1].y-158)
                let p=CGMutablePath();p.move(to:origin);p.addCurve(to:a,control1:CGPoint(x:origin.x-5,y:origin.y-41),control2:CGPoint(x:a.x-13,y:a.y+22));p.addCurve(to:b,control1:CGPoint(x:a.x+58,y:a.y-78),control2:CGPoint(x:b.x-62,y:b.y+43));p.addLine(to:CGPoint(x:b.x,y:b.y-55))
                ink.append(PrintStroke(path:p,points:[origin,a,b,CGPoint(x:b.x,y:b.y-55)],weight:0.7,opacity:0.37))
            }
        }
        strokes=ink
    }
}

enum FineArtArtwork {
    static let size=CGSize(width:1600,height:1000)
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
    static func chair(_ colors:PrintColors,angle:Double)->CGImage {
        WorldInk.image(CGSize(width:240,height:260),2){ c in
            let blue=colors.pigment
            let dark=WorldInk.blend(blue,RGB(0.065,0.10,0.19),0.40)
            let edge=WorldInk.blend(blue,RGB(0.76,0.81,0.86),0.22)
            func p(_ x:Double,_ y:Double,_ z:Double)->CGPoint {
                let xx=x*cos(angle)-z*sin(angle),zz=x*sin(angle)+z*cos(angle)
                return CGPoint(x:120+xx*0.86+zz*0.47,y:47+y+zz*0.25-xx*0.10)
            }
            func tube(_ path:CGPath,_ width:Double=4.4) {
                c.addPath(path);c.setStrokeColor(WorldInk.color(dark));c.setLineWidth(width);c.setLineCap(.round);c.setLineJoin(.round);c.strokePath()
                c.addPath(path);c.setStrokeColor(WorldInk.color(blue));c.setLineWidth(width*0.63);c.strokePath()
            }
            func rail(_ points:[CGPoint],_ width:Double=4.4){let path=CGMutablePath();path.addLines(between:points);tube(path,width)}
            WorldInk.softShadow(c,CGPoint(x:129,y:47),144,23,colors.ink,0.12)
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
            c.addPath(back);c.setFillColor(WorldInk.color(blue));c.fillPath()
            let inset=CGMutablePath();inset.move(to:p(-35,135,29));inset.addLine(to:p(-35,144,31));inset.addCurve(to:p(-23,162,34),control1:p(-36,155,33),control2:p(-31,162,34));inset.addCurve(to:p(23,162,34),control1:p(-9,166,35),control2:p(14,166,35));inset.addCurve(to:p(35,144,31),control1:p(31,162,34),control2:p(36,155,33))
            c.addPath(inset);c.setStrokeColor(WorldInk.color(dark,0.45));c.setLineWidth(0.9);c.strokePath()
            // Small hinge plates and diagonal stays make the folding mechanism legible.
            for x in [-40.0,40.0] {
                rail([p(x,107,25),p(x,78,31),p(x,73,-13)],2.4)
                let hinge=p(x,88,23)
                WorldInk.oval(c,CGRect(x:hinge.x-2.7,y:hinge.y-2.7,width:5.4,height:5.4),dark)
                WorldInk.oval(c,CGRect(x:hinge.x-1,y:hinge.y-1,width:2,height:2),edge,0.75)
            }
            func seat(_ y:Double)->CGPath {
                let path=CGMutablePath();path.move(to:p(-37,y,-33));path.addLine(to:p(37,y,-33))
                path.addCurve(to:p(46,y,-25),control1:p(44,y,-33),control2:p(46,y,-31));path.addLine(to:p(44,y,23))
                path.addCurve(to:p(36,y,29),control1:p(44,y,28),control2:p(42,y,29));path.addLine(to:p(-36,y,29))
                path.addCurve(to:p(-44,y,23),control1:p(-42,y,29),control2:p(-44,y,28));path.addLine(to:p(-46,y,-25))
                path.addCurve(to:p(-37,y,-33),control1:p(-46,y,-31),control2:p(-44,y,-33));path.closeSubpath();return path
            }
            c.addPath(seat(73));c.setFillColor(WorldInk.color(dark));c.fillPath()
            c.addPath(seat(78));c.setFillColor(WorldInk.color(blue));c.fillPath()
            // Restrained turned rim, not a glossy upholstery cushion.
            WorldInk.path(c,[p(-38,78,-32),p(37,78,-32),p(45,78,-25)],edge,1.15,0.85)
            WorldInk.path(c,[p(-30,79,22),p(30,79,22)],dark,0.65,0.32)
            for x in [-47.0,47.0] {rail([p(x,0,-42),p(x,3,-39)],5.1)}
            for x in [-44.07,44.07] {rail([p(x,0,54),p(x,3,51)],4.5)}
        }
    }
    static func fruitPath(_ index:Int)->CGPath {
        let p=CGMutablePath()
        p.move(to:CGPoint(x:0.04,y:-0.50))
        if index==0 {
            p.addCurve(to:CGPoint(x:-0.48,y:0.07),control1:CGPoint(x:-0.18,y:-0.48),control2:CGPoint(x:-0.57,y:-0.24))
            p.addCurve(to:CGPoint(x:0.16,y:0.43),control1:CGPoint(x:-0.48,y:0.37),control2:CGPoint(x:-0.14,y:0.52))
            p.addCurve(to:CGPoint(x:0.49,y:-0.06),control1:CGPoint(x:0.36,y:0.34),control2:CGPoint(x:0.54,y:0.15))
            p.addCurve(to:CGPoint(x:0.04,y:-0.50),control1:CGPoint(x:0.44,y:-0.31),control2:CGPoint(x:0.24,y:-0.48))
        } else if index==1 {
            p.addCurve(to:CGPoint(x:-0.38,y:0.26),control1:CGPoint(x:-0.22,y:-0.35),control2:CGPoint(x:-0.35,y:0.04))
            p.addCurve(to:CGPoint(x:-0.19,y:0.49),control1:CGPoint(x:-0.40,y:0.40),control2:CGPoint(x:-0.30,y:0.53))
            p.addCurve(to:CGPoint(x:0.25,y:0.36),control1:CGPoint(x:-0.11,y:0.49),control2:CGPoint(x:0.16,y:0.40))
            p.addCurve(to:CGPoint(x:0.04,y:-0.50),control1:CGPoint(x:0.58,y:0.17),control2:CGPoint(x:0.31,y:-0.38))
        } else {
            p.addCurve(to:CGPoint(x:-0.43,y:0.02),control1:CGPoint(x:-0.27,y:-0.43),control2:CGPoint(x:-0.49,y:-0.20))
            p.addCurve(to:CGPoint(x:-0.05,y:0.37),control1:CGPoint(x:-0.40,y:0.24),control2:CGPoint(x:-0.24,y:0.44))
            p.addCurve(to:CGPoint(x:0.44,y:-0.06),control1:CGPoint(x:0.29,y:0.30),control2:CGPoint(x:0.53,y:0.18))
            p.addCurve(to:CGPoint(x:0.04,y:-0.50),control1:CGPoint(x:0.38,y:-0.28),control2:CGPoint(x:0.27,y:-0.44))
        }
        p.closeSubpath();return p
    }
    static func fruit(_ form:PrintForm,index:Int,colors:PrintColors,settings:StrawberryFineSettings,seed:UInt64)->CGImage {
        WorldInk.image(CGSize(width:200,height:220),2){c in
            c.translateBy(x:100,y:110);c.rotate(by:form.tilt);c.scaleBy(x:form.width,y:form.height)
            let path=fruitPath(index);c.addPath(path);c.setFillColor(WorldInk.color(WorldInk.blend(colors.pigment,colors.ink,Double(index)*0.06)));c.fillPath()
            c.saveGState();c.addPath(path);c.clip()
            var r=ArtRandom(state:seed &+ UInt64(index)*79)
            for _ in 0..<1300 {
                let x=r.next()-0.5,y=r.next()-0.55,rad=0.002+r.next()*0.016
                WorldInk.oval(c,CGRect(x:x,y:y,width:rad,height:rad*0.58),r.next()>0.5 ? colors.ground : colors.ink,0.02+r.next()*0.05)
            }
            // Irregular ink deposits and scumbled edges, no specular fruit highlights.
            for _ in 0..<35 {let x=r.next()-0.5,y=r.next()-0.5;WorldInk.oval(c,CGRect(x:x,y:y,width:0.22+r.next()*0.25,height:0.05+r.next()*0.08),colors.ink,0.017)}
            c.restoreGState()
            if settings.literalness != .abstract {
                for _ in 0..<(settings.literalness == .botanical ? 24 : 7) {
                    let x=(r.next()-0.5)*0.57,y=(r.next()-0.5)*0.66
                    WorldInk.path(c,[CGPoint(x:x,y:y),CGPoint(x:x+0.005,y:y+0.018)],colors.ground,0.006,0.20)
                }
            }
            if settings.literalness == .botanical {WorldInk.path(c,[CGPoint(x:0.02,y:0.41),CGPoint(x:-0.08,y:0.50),CGPoint(x:-0.06,y:0.57)],colors.ink,0.012,0.7)}
        }
    }
}
