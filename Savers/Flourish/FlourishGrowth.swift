import Foundation

struct FlourishPoint: Equatable { var x: Double; var y: Double }
struct FlourishBranch: Equatable {
    var points: [FlourishPoint]
    var angle: Double
    var curvature: Double
    var curl = 0.0
    var curlLeft = 0
    var length = 0.0
    var nextLeaf = 18.0
    var nextBranch = 100.0
    let depth: Int
    let family: Int
    let phase: Double
    let energy: Double
    var alive = true
    var waitUntil = 0.0
    var lastGrowth = -1.0
}
struct FlourishOrnament: Equatable {
    let position: FlourishPoint
    let angle: Double
    let size: Double
    let kind: Int // leaves 0...3, flowers 4...7
    let family: Int
    let born: Double
    let variation: Double
}
/// A bounded occupancy field guides progressive tips; no prebuilt drawing is revealed.
struct FlourishGrowth {
    let width: Double
    let settings: FlourishSettings
    private(set) var branches: [FlourishBranch] = []
    private(set) var ornaments: [FlourishOrnament] = []
    private(set) var age = 0.0
    private(set) var segmentCount = 0
    private(set) var occupancy: [UInt16]
    let columns: Int
    private var random: ArtRandom
    private var remainder = 0.0
    var presentationAge:Double {age+remainder}
    var tipFraction:Double {min(1,max(0,remainder*6))}
    private var nextRoot = 15.0
    private let composition: Int
    let openCenter: FlourishPoint
    init(seed: UInt64, aspect: Double, settings: FlourishSettings) {
        width=max(450,aspect*900);self.settings=settings.sanitized()
        columns=Int(ceil(width/32));occupancy=Array(repeating:0,count:columns*29)
        random=ArtRandom(state:seed);composition=Int(random.next()*4)
        openCenter=FlourishPoint(x:width*(0.35+random.next()*0.3),y:440+random.next()*100)
        addRoot();if settings.style != .sparse { addRoot() }
    }
    mutating func addRoot() {
        let side=branches.count%2, f=0.12+random.next()*0.22
        let p: FlourishPoint, angle: Double
        switch composition {
        case 0:p=FlourishPoint(x:width*(side==0 ? f : 1-f),y:-15);angle=side==0 ? 0.72 : 2.25
        case 1:p=FlourishPoint(x:side==0 ? -10 : width+10,y:100+random.next()*330);angle=side==0 ? 0.65 : 2.55
        case 2:p=FlourishPoint(x:width*(side==0 ? f : 1-f),y:side==0 ? -10 : 910);angle=side==0 ? 0.80 : -2.4
        default:p=FlourishPoint(x:side==0 ? -10 : width+10,y:150+random.next()*470);angle=side==0 ? 0.4 : 2.8
        }
        branches.append(FlourishBranch(points:[p],angle:angle,curvature:0,depth:0,family:branches.count%3,phase:random.next()*6.28,energy:700+random.next()*380))
    }
    private mutating func placeOrnament(_ candidate:FlourishOrnament) {
        func footprint(_ o:FlourishOrnament)->(Double,Double,Double) {
            let offset=o.size*(o.kind<4 ? 0.50:o.kind==4 ? 0.82:1.15)
            return (o.position.x+cos(o.angle)*offset,o.position.y+sin(o.angle)*offset,o.size*(o.kind<4 ? 0.29:0.63))
        }
        let a=footprint(candidate)
        // Keep crossing stems, but give botanical silhouettes their own small space.
        guard !ornaments.contains(where: {let b=footprint($0);return hypot(a.0-b.0,a.1-b.1)<(a.2+b.2)*0.78}) else{return}
        ornaments.append(candidate)
    }
    func cell(_ p: FlourishPoint) -> Int? {
        let x=Int(floor(p.x/32)), y=Int(floor(p.y/32))
        guard x>=0 && x<columns && y>=0 && y<29 else{return nil};return y*columns+x
    }
    func crowd(_ p: FlourishPoint) -> Double { cell(p).map { Double(occupancy[$0]) } ?? 0 }
    mutating func advance(_ delta: Double) {
        guard delta.isFinite && delta>0 else{return}
        remainder += min(delta,0.25)*settings.speed
        while remainder+1e-10 >= 1.0/6 { step();remainder-=1.0/6 }
    }
    private mutating func step() {
        age += 1.0/6
        let limit=Int(1900+settings.density*3200), branchLimit=settings.style == .sparse ? 12 : Int(18+settings.density*18)
        guard segmentCount<limit && age<240 else{for i in branches.indices {branches[i].alive=false};return}
        if age>nextRoot && branches.count<branchLimit/2 {
            addRoot();nextRoot=age+38+random.next()*26
        }
        let count=branches.count
        for i in 0..<count {
            guard branches[i].alive && age>=branches[i].waitUntil else{continue}
            var b=branches[i];let p=b.points.last!
            if b.length>b.energy || b.points.count>520 {
                if random.next()<settings.flowers && ornaments.count<450 {placeOrnament(FlourishOrnament(position:p,angle:b.angle,size:20+random.next()*20,kind:4+Int(random.next()*4),family:b.family,born:age,variation:random.next()))}
                branches[i].alive=false;continue
            }
            let stepLength=(b.depth==0 ? 2.8 : 2.15)*(0.86+0.14*sin(age*0.2+b.phase))
            let tangent=b.angle
            var turn=0.005*sin(b.length/95+b.phase)+0.003*cos(b.length/43-b.phase)
            let curlChance=settings.style == .spiral ? 0.012 : settings.style == .ornamental ? 0.007 : 0.003
            if b.curlLeft==0 && b.length>80 && random.next()<curlChance {
                b.curl=(random.next()>0.5 ? 1.0 : -1.0)*(0.027+random.next()*0.025)
                b.curlLeft=Int((b.depth>0 ? 115:70)+random.next()*60)
            }
            if b.curlLeft>0 {
                if b.depth>0 && (settings.style == .spiral || settings.style == .ornamental) {b.curl *= 1.009;turn+=max(-0.075,min(0.075,b.curl))} else {turn+=b.curl}
                b.curlLeft-=1
            }
            // Look ahead on both sides. Occupancy only nudges curves, never jitters them.
            func ahead(_ a: Double)->FlourishPoint { FlourishPoint(x:p.x+cos(a)*52,y:p.y+sin(a)*52) }
            let left=crowd(ahead(tangent+0.45)),right=crowd(ahead(tangent-0.45))
            turn += max(-0.018,min(0.018,(right-left)*0.0009))
            if b.length>150 && crowd(p)>48 {branches[i].alive=false;continue}
            var desiredX=0.0,desiredY=0.0
            if p.x<85 {desiredX+=(85-p.x)/85};if p.x>width-85 {desiredX-=(p.x-width+85)/85}
            if p.y<55 {desiredY+=(55-p.y)/55};if p.y>820 {desiredY-=(p.y-820)/80}
            let dx=p.x-openCenter.x,dy=p.y-openCenter.y,dist=hypot(dx,dy)
            if dist<170 && dist>1 {desiredX+=dx/dist*(170-dist)/250;desiredY+=dy/dist*(170-dist)/250}
            turn += (cos(tangent)*desiredY-sin(tangent)*desiredX)*0.055
            b.curvature=b.curvature*0.88+turn*0.12;b.angle+=max(-0.065,min(0.065,b.curvature))
            let q=FlourishPoint(x:p.x+cos(b.angle)*stepLength,y:p.y+sin(b.angle)*stepLength)
            guard q.x > -45 && q.x < width+45 && q.y > -45 && q.y < 950 else{branches[i].alive=false;continue}
            b.points.append(q);b.length+=stepLength;b.lastGrowth=age;segmentCount+=1
            if let k=cell(q) {occupancy[k]=min(600,occupancy[k]+1)}
            if b.length>b.nextLeaf && ornaments.count<450 {
                if random.next()<settings.leaves && crowd(q)<35 && !ornaments.contains(where: {$0.kind>=4 && hypot($0.position.x-q.x,$0.position.y-q.y)<45}) {
                    let side=random.next()>0.5 ? 1.0 : -1.0
                    placeOrnament(FlourishOrnament(position:q,angle:b.angle+side*(0.65+random.next()*0.55),size:(18+random.next()*19)*pow(0.86,Double(b.depth)),kind:(b.family==0 ? (random.next()<0.12 ? 3:0):b.family),family:b.family,born:age,variation:random.next()))
                }
                b.nextLeaf=b.length+24+random.next()*30
            }
            if b.length>b.nextBranch && branches.count<branchLimit && b.depth<2 && crowd(q)<32 {
                let side=random.next()>0.5 ? 1.0 : -1.0
                if random.next() < (settings.style == .wild ? 0.8 : 0.48) {
                    var child=FlourishBranch(points:[q],angle:b.angle+side*0.68,curvature:side*0.006,depth:b.depth+1,family:b.family,phase:random.next()*6.28,energy:210+random.next()*280)
                    child.waitUntil=age+5+random.next()*15;branches.append(child)
                } else if ornaments.count<450 && random.next()<settings.flowers && !ornaments.contains(where: {$0.kind<4 && hypot($0.position.x-q.x,$0.position.y-q.y)<25}) {
                    placeOrnament(FlourishOrnament(position:q,angle:b.angle+side*0.65,size:18+random.next()*14,kind:4+Int(random.next()*4),family:b.family,born:age,variation:random.next()))
                }
                b.nextBranch=b.length+100+random.next()*120
            }
            branches[i]=b
        }
    }
}
