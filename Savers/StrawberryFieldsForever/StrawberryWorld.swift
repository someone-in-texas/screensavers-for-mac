import Foundation

struct StrawberryPlant:Equatable {let position:WorldPoint;let scale:Double;let phase:Double;let fruit:Int;let variant:Int}
struct StrawberryWorld:Equatable {
    let seed:UInt64
    let plants:[StrawberryPlant]
    let nodes:[WorldPoint]
    let edges:[WorldEdge]
    let stars:[WorldPoint]
    let hills:[[WorldPoint]]
    let period:Double
    let phase:Double
    init(seed:UInt64,settings:StrawberrySettings){
        self.seed=seed;var r=ArtRandom(state:seed);phase=r.next()*6.28;period=880+r.next()*150
        var terrain:[[WorldPoint]]=[]
        for depth in 0..<5 {
            let offset=r.next()*6.28
            terrain.append((0...60).map {i in let x=Double(i)*70;return WorldPoint(x:x,y:1530-Double(depth)*62+sin(x/460+offset)*35+cos(x/231+offset)*12)})
        }
        hills=terrain
        var p:[StrawberryPlant]=[]
        for i in 0..<settings.density.count {
            let depth=pow(r.next(),0.68),x=180+r.next()*3740
            p.append(.init(position:.init(x:x,y:1080+depth*410),scale:0.24+(1-depth)*1.0,phase:r.next()*6.28,fruit:r.next()<0.7 ? 1+Int(r.next()*2):0,variant:i%8))
        }
        // Two hero plants anchor the foreground; the deliberate triad is lore-gated.
        p.append(.init(position:.init(x:1580,y:1100),scale:1.55,phase:1,fruit:settings.lore == .pureArt || seed%2==1 ? 2:3,variant:8))
        p.append(.init(position:.init(x:2720,y:1058),scale:2.1,phase:2,fruit:1,variant:6))
        p.append(.init(position:.init(x:2380,y:1150),scale:1.15,phase:3,fruit:2,variant:9))
        plants=p.sorted{$0.position.y>$1.position.y}
        // Connected cable trunk follows the rear floor, racks, and earth ceiling.
        var n:[WorldPoint]=[]
        for i in 0..<8 {n.append(.init(x:1370+Double(i)*175,y:285+sin(Double(i))*9))}
        n.append(.init(x:1350,y:740));n.append(.init(x:1510,y:905));n.append(.init(x:1910,y:942));n.append(.init(x:2320,y:929));n.append(.init(x:2670,y:803));n.append(.init(x:2740,y:291))
        nodes=n
        var e:[WorldEdge]=[]
        for i in 1..<8 {e.append(.init(a:i-1,b:i))}
        e += [.init(a:0,b:8),.init(a:8,b:9),.init(a:9,b:10),.init(a:10,b:11),.init(a:11,b:12),.init(a:12,b:13),.init(a:13,b:7)]
        edges=e
        stars=(0..<125).map {_ in .init(x:r.next()*4200,y:1440+r.next()*760)}
    }
    func underground(_ time:Double,_ settings:StrawberrySettings)->Double {
        let t=max(0,time)*settings.pace.rate,cycle=t/period,position=(cycle-floor(cycle))*period
        let hold=settings.balance == .mostlyField ? period*0.52:settings.balance == .balanced ? period*0.35:period*0.20
        let ramp=145.0,returnAt=period-160
        return worldEase((position-hold)/ramp)*(1-worldEase((position-returnAt)/145))
    }
    func camera(_ time:Double,_ settings:StrawberrySettings)->WorldCamera {
        let t=max(0,time)*settings.pace.rate,below=underground(time,settings)
        return .init(x:2080+sin(t/170+phase)*120+sin(t/393)*70,y:1545-945*below+sin(t/211)*18,zoom:1.04+sin(t/270+phase)*0.035)
    }
    func weather(_ time:Double,_ settings:StrawberrySettings)->Double {
        guard settings.weather != .off else{return 0}
        let interval=settings.weather == .rare ? 610.0:330.0
        let p=(max(0,time)+Double(seed%57)).truncatingRemainder(dividingBy:interval)
        // A slow acceleration front, then an equally soft deceleration.
        return sin(.pi*worldEase((p-interval+125)/55))*0.6-sin(.pi*worldEase((p-interval+62)/52))*0.35
    }
    func wind(_ time:Double,_ plant:StrawberryPlant,_ settings:StrawberrySettings)->Double {
        let energy=max(0.2,1+weather(time,settings))
        return settings.wind.amount*energy*(sin(time*0.23-plant.position.x/340+plant.phase)*0.012+sin(time*0.39+plant.phase)*0.004)
    }
    func signal(_ time:Double,_ index:Int)->WorldPoint {
        let edge=edges[index%edges.count],a=nodes[edge.a],b=nodes[edge.b]
        let phase=(max(0,time)/18+Double(index)*0.31).truncatingRemainder(dividingBy:1)
        return .init(x:a.x+(b.x-a.x)*phase,y:a.y+(b.y-a.y)*phase)
    }
    /// Local fiction, never a statement about an actual model, person, or release.
    func fragment(_ time:Double,_ settings:StrawberrySettings)->(String,Double) {
        guard settings.lore != .pureArt,settings.text != .none else{return ("",0)}
        let interval=settings.text == .rare ? 210.0:125.0,t=max(0,time),slot=Int(t/interval),local=t.truncatingRemainder(dividingBy:interval)
        guard local>50 && local<66 else{return ("",0)}
        let alpha=worldEase((local-50)/3)*(1-worldEase((local-62)/4))
        if settings.lore == .terminallyOnline && slot%11==7 {
            return (["THIS IS WHAT ILYA SAW","DON'T DIE","Q *","DISCARD AFTER REVIEW"][(slot/11)%4],alpha)
        }
        // READY / NOT READY deliberately revisit the same surface in successive slots.
        let fragments=[["REVIEW PENDING","AWAITING ANOTHER REVIEW"],["READY"],["NOT READY"],["DEPLOYMENT: NEXT WEEK","ONE MORE WEEK"],["FINAL CHECK","AFTER ONE FINAL CHECK"],["FINAL CHECK 2","ONE LAST CHECK, AGAIN"],["NOTHING IS ANNOUNCED","NO ANNOUNCEMENT TONIGHT"],["THURSDAY REMAINS INTERESTING","THE BENCHMARKS ARE STRANGE TONIGHT"],["TEMPORARY BRIEF","DISCARD AFTER REVIEW"],["THE FIELD IS READY","REASONING HAS MOVED UNDERGROUND"]]
        let group=fragments[(slot+Int(seed%3))%fragments.count]
        return (group[(slot/10+Int(seed%7))%group.count],alpha)
    }
}
