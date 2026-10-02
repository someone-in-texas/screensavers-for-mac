import AppKit

enum FlourishGeometry {
    static func thickness(depth: Int, progress: Double, character: FlourishLine) -> Double {
        let base=character == .brushPen ? 3.2 : character == .etching ? 1.35 : 2.45
        return max(0.28,base*pow(0.63,Double(depth))*(1-0.65*min(1,max(0,progress))))
    }
    static func stem(_ branch: FlourishBranch, character: FlourishLine) -> CGPath {
        let path=CGMutablePath(),points=branch.points
        guard points.count>1 else{return path}
        var upper:[CGPoint]=[],lower:[CGPoint]=[]
        for i in points.indices {
            let a=points[max(0,i-1)],b=points[min(points.count-1,i+1)],d=hypot(b.x-a.x,b.y-a.y)
            let nx=d>0 ? -(b.y-a.y)/d : 0,ny=d>0 ? (b.x-a.x)/d : 1
            let tail=min(1,Double(points.count-1-i)/7+0.12)
            let w=thickness(depth:branch.depth,progress:Double(i)*2.5/branch.energy,character:character)*0.5*tail*(1+0.09*sin(Double(i)*0.17+branch.phase))
            upper.append(CGPoint(x:points[i].x+nx*w,y:points[i].y+ny*w));lower.append(CGPoint(x:points[i].x-nx*w,y:points[i].y-ny*w))
        }
        path.move(to:upper[0]);for p in upper.dropFirst(){path.addLine(to:p)};for p in lower.reversed(){path.addLine(to:p)};path.closeSubpath();return path
    }
    static func ornament(_ o: FlourishOrnament) -> (CGPath,CGPath) {
        let outline=CGMutablePath(),detail=CGMutablePath(),s=o.size*(o.kind==3 ? 1.3:1)
        if o.kind<4 {
            let width=o.kind==1 ? s*0.15 : o.kind==2 ? s*0.44 : s*0.30
            if o.kind==3 {
                // A feathered frond: small leaflets share one curved rachis.
                for j in 0..<4 {
                    let x=s*(0.14+Double(j)*0.20),l=s*(0.26-Double(j)*0.026)
                    for side in [-1.0,1.0] {
                        outline.move(to:CGPoint(x:x,y:0))
                        outline.addQuadCurve(to:CGPoint(x:x+l*0.7,y:side*l*0.55),control:CGPoint(x:x+l*0.15,y:side*l*0.65))
                        outline.addQuadCurve(to:CGPoint(x:x,y:0),control:CGPoint(x:x+l*0.55,y:side*l*0.06))
                    }
                }
            } else if o.kind==2 {
                // Heart base, tapered tip; asymmetrical lobes avoid stamp-like symmetry.
                outline.move(to:.zero)
                outline.addCurve(to:CGPoint(x:s,y:0),control1:CGPoint(x:-s*0.12,y:width*1.25),control2:CGPoint(x:s*0.48,y:width))
                outline.addCurve(to:.zero,control1:CGPoint(x:s*0.50,y:-width*0.9),control2:CGPoint(x:-s*0.10,y:-width))
                outline.closeSubpath()
            } else {
                outline.move(to:.zero)
                outline.addCurve(to:CGPoint(x:s,y:0),control1:CGPoint(x:s*0.18,y:width),control2:CGPoint(x:s*0.88,y:width*(0.7+o.variation*0.4)))
                outline.addCurve(to:.zero,control1:CGPoint(x:s*0.85,y:-width*0.9),control2:CGPoint(x:s*0.20,y:-width*0.75));outline.closeSubpath()
            }
            detail.move(to:.zero);detail.addQuadCurve(to:CGPoint(x:s*0.93,y:0),control:CGPoint(x:s*0.5,y:s*0.04))
            if s>24 && o.kind != 3 && o.kind != 1 {
                for side in [-1.0,1.0] {detail.move(to:CGPoint(x:s*0.38,y:0));detail.addQuadCurve(to:CGPoint(x:s*0.61,y:side*width*0.65),control:CGPoint(x:s*0.47,y:side*width*0.12))}
            }
        } else {
            if o.kind==4 {
                detail.move(to:.zero);detail.addQuadCurve(to:CGPoint(x:s*0.42,y:0),control:CGPoint(x:s*0.16,y:s*0.08))
                outline.move(to:CGPoint(x:s*0.34,y:0))
                outline.addCurve(to:CGPoint(x:s*1.05,y:s*0.35),control1:CGPoint(x:s*0.40,y:s*0.26),control2:CGPoint(x:s*0.84,y:s*0.20))
                outline.addQuadCurve(to:CGPoint(x:s*1.12,y:s*0.10),control:CGPoint(x:s*1.22,y:s*0.34))
                outline.addQuadCurve(to:CGPoint(x:s*1.10,y:-s*0.12),control:CGPoint(x:s*0.97,y:0))
                outline.addQuadCurve(to:CGPoint(x:s*1.03,y:-s*0.31),control:CGPoint(x:s*1.20,y:-s*0.31))
                outline.addCurve(to:CGPoint(x:s*0.34,y:0),control1:CGPoint(x:s*0.82,y:-s*0.20),control2:CGPoint(x:s*0.44,y:-s*0.24))
                detail.move(to:CGPoint(x:s*0.64,y:0));detail.addLine(to:CGPoint(x:s*1.15,y:0))
                return(outline,detail)
            }
            let petals=o.kind==5 ? 7 : o.kind==6 ? 5 : 6
            let center=CGPoint(x:s*1.15,y:0)
            detail.move(to:.zero);detail.addQuadCurve(to:center,control:CGPoint(x:s*0.5,y:s*0.18))
            for i in 0..<petals {
                let a=Double(i)/Double(petals) * .pi*2+o.variation
                let length=s*(0.68+0.13*sin(Double(i)*2.3+o.variation)),w=o.kind==6 ? 0.12 : 0.38
                func p(_ x:Double,_ y:Double)->CGPoint {CGPoint(x:center.x+cos(a)*x-sin(a)*y,y:center.y+sin(a)*x+cos(a)*y)}
                outline.move(to:p(s*0.1,0));outline.addCurve(to:p(length,0),control1:p(length*0.4,length*w),control2:p(length*0.95,length*w))
                outline.addCurve(to:p(s*0.1,0),control1:p(length*0.95,-length*w),control2:p(length*0.4,-length*w))
                if o.kind==7 {detail.move(to:p(s*0.19,0));detail.addQuadCurve(to:p(length*0.7,0),control:p(length*0.4,length*0.09))}
            }
            detail.addEllipse(in:CGRect(x:center.x-s*0.12,y:-s*0.12,width:s*0.24,height:s*0.24))
            if o.kind==5 {
                for i in 0...55 {let a=Double(i)*0.17,r=s*0.10*Double(i)/55,p=CGPoint(x:center.x+cos(a)*r,y:sin(a)*r);if i==0{detail.move(to:p)}else{detail.addLine(to:p)}}
            }
        }
        return (outline,detail)
    }
}
