import Foundation

struct ResearchRoom:Equatable {let center:WorldPoint;let width:Double;let height:Double;let kind:Int}
struct ResearchWorld:Equatable {
    let seed:UInt64
    let rooms:[ResearchRoom]
    let connections:[WorldEdge]
    let maze:ResearchMaze
    let rocks:[[WorldPoint]]
    let dust:[WorldPoint]
    let environment:ResearchEnvironment
    let phase:Double
    init(seed:UInt64,settings:ResearchSettings){
        self.seed=seed;var r=ArtRandom(state:seed);phase=r.next()*6.28
        environment=settings.environment == .random ? [.cave,.archive,.deepLab][Int(r.next()*3)]:settings.environment
        rooms=(0..<6).map {i in .init(center:.init(x:1120+Double(i%3)*780+r.next()*120,y:370+Double(i/3)*390+r.next()*80),width:420+r.next()*160,height:220+r.next()*130,kind:i%4)}
        connections=[.init(a:0,b:1),.init(a:1,b:2),.init(a:0,b:3),.init(a:3,b:4),.init(a:4,b:5),.init(a:2,b:5)]
        maze=ResearchMaze(seed:seed &+ 71)
        var facets:[[WorldPoint]]=[]
        for i in 0..<28 {
            let x=r.next()*4200,y=950+r.next()*950,w=200+r.next()*600,h=150+r.next()*500
            facets.append([.init(x:x-w,y:y+h),.init(x:x+w,y:y+h*0.5),.init(x:x+w*0.45,y:y-h),.init(x:x-w*0.60,y:y-h*0.3)])
            if i%2==0 {facets.append([.init(x:x,y:0),.init(x:x+w,y:0),.init(x:x+w*0.3,y:280+r.next()*190)])}
        }
        rocks=facets;dust=(0..<28).map{_ in .init(x:1350+r.next()*1550,y:400+r.next()*670)}
    }
    func camera(_ time:Double,_ settings:ResearchSettings,aspect:Double=1.6)->WorldCamera {
        let t=max(0,time)*settings.pace.rate
        let focus=aspect<1 ? 1875.0:2040.0
        let stops=[WorldCamera(x:focus,y:815,zoom:1.0),WorldCamera(x:1020,y:815,zoom:1.08),WorldCamera(x:3050,y:810,zoom:1.0)]
        let leg=420.0,phase=t/leg,index=Int(phase)%stops.count,next=(index+1)%stops.count
        let f=worldEase(((phase-floor(phase))*leg-210)/210),a=stops[index],b=stops[next]
        return .init(x:a.x+(b.x-a.x)*f+sin(t/270+self.phase)*28,y:a.y+(b.y-a.y)*f+sin(t/330+self.phase)*18,zoom:a.zoom+(b.zoom-a.zoom)*f+0.018*sin(t/410+self.phase))
    }
    func fragment(_ time:Double,_ settings:ResearchSettings)->(String,Double) {
        guard settings.lore != .pureArt else{return ("",0)}
        // Messages wait for a main-instrument visit instead of appearing off camera.
        let t=max(0,time)*settings.pace.rate,cycle=Int(t/1260),local=t.truncatingRemainder(dividingBy:1260)
        let second=settings.text != .minimal && local>155
        let window=second ? 164.0:64.0,age=local-window
        guard age>0 && age<19 && (settings.text != .minimal || cycle%2==0) else{return ("",0)}
        let opacity=worldEase(age/4)*(1-worldEase((age-14)/5))
        if settings.lore == .deepLore && settings.text == .lore && cycle%3==2 && !second {
            return (["PATIENCE BROS","THE CAVE RECOMMENDS WAITING","GOOD RESEARCH TAKES TIME"][(cycle/3)%3],opacity)
        }
        return (["REVIEW PENDING","MORE DATA REQUIRED","STATUS: STILL THINKING","REASSESS LATER","ANOTHER EVALUATION","WAIT"][(cycle+(second ? 1:0)+Int(seed%3))%6],opacity)
    }
    func experiment(_ time:Double)->String {
        let hours=Int(max(0,time)/3600)+Int(seed%240)+4320
        return String(format:"RUN %03d · ELAPSED %03dD %02dH",Int(seed%97)+1,hours/24,hours%24)
    }
    func readiness(_ time:Double)->Double {0.9965+sin(max(0,time)/1600+phase)*0.001}
}
