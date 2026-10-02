import Foundation

struct LatticeCell:Equatable {
    var state:UInt8=0 // 0 dormant, 1...12 living excitation, 13...36 refractory decay
    var age:UInt16=0
    var energy:Float=0
}
struct LatticeEvent:Equatable {
    enum Kind:Int {case seed,lantern,void,beacon}
    let kind:Kind
    var x:Double;var y:Double
    let born:Int;let duration:Int
    let phase:Double
}
/// Excitable fronts, resource-limited colonies, advection and conductive pulses.
/// Contiguous double buffers and reusable environmental fields bound allocations.
struct LatticeWorld {
    let width:Int,height:Int
    private(set) var cells:[LatticeCell]
    private var next:[LatticeCell]
    private(set) var substrate:[Float]
    private var neighbors:[Int]
    private var random:ArtRandom
    private(set) var generation=0
    private(set) var liveFraction=0.0,changeFraction=0.0
    private(set) var events:[LatticeEvent]=[]
    var settings:LatticeSettings
    private var quiet=0
    init(seed:UInt64,width:Int,height:Int,settings:LatticeSettings) {
        self.width=max(12,min(256,width));self.height=max(12,min(192,height));self.settings=settings.sanitized()
        let count=self.width*self.height
        cells=Array(repeating:LatticeCell(),count:count);next=cells;substrate=Array(repeating:0,count:count);neighbors=Array(repeating:0,count:count*8)
        random=ArtRandom(state:seed)
        let phase=random.next()*6.28,phase2=random.next()*6.28
        for y in 0..<self.height {for x in 0..<self.width {
            let i=y*self.width+x,xx=Double(x),yy=Double(y)
            let field=0.5+0.23*sin(xx*0.065+sin(yy*0.051+phase)*1.9+phase2)+0.20*cos(yy*0.095+sin(xx*0.043+phase2)*2.2+phase)
            substrate[i]=Float(field)
            var n=0
            for dy in -1...1 {for dx in -1...1 where dx != 0 || dy != 0 {neighbors[i*8+n]=((y+dy+self.height)%self.height)*self.width+(x+dx+self.width)%self.width;n+=1}}
            cells[i].energy=Float(max(0,field))
        }}
        for _ in 0..<Int(5+settings.activity*7) {seedColony()}
    }
    mutating func clear(){for i in cells.indices {cells[i]=LatticeCell(state:0,age:0,energy:substrate[i])};quiet=0}
    private mutating func seedColony(at position:(Int,Int)?=nil) {
        let x=position?.0 ?? Int(random.next()*Double(width)),y=position?.1 ?? Int(random.next()*Double(height))
        for dy in -1...1 {for dx in -1...1 where abs(dx)+abs(dy)<2 || random.next()>0.6 {
            let i=((y+dy+height)%height)*width+(x+dx+width)%width
            cells[i].state=1;cells[i].age=0;cells[i].energy=0.95
        }}
    }
    static func birth(mode:LatticeMode,excited:Int,living:Int,energy:Float,substrate:Float,directionActive:Bool)->Bool {
        switch mode {
        case .bloom:return excited>=1 && excited<=3 && living<=5 && energy>0.43
        case .drift:return directionActive && living<=4 && energy>0.34
        case .reef:return living>=2 && living<=5 && energy>0.58 && substrate>0.38
        case .signal:return excited>=1 && excited<=2 && substrate>0.47 && energy>0.37
        }
    }
    mutating func step() {
        generation+=1
        let mode=settings.mode,weather=Float(0.05*sin(Double(generation)*0.0017))
        var live=0,changed=0
        let denseBrake:Float=liveFraction>0.30 ? 0.004:0
        for i in cells.indices {
            let c=cells[i];var result=c,excited=0,living=0
            for k in 0..<8 {let state=cells[neighbors[i*8+k]].state;if state>0 && state<=12 {living+=1};if state>0 && state<=3 {excited+=1}}
            let fertile=substrate[i]+weather
            result.energy=min(1,max(0,c.energy+Float(0.0015+settings.activity*0.003)*(fertile+0.1)-denseBrake))
            if c.state==0 {
                let heading=sin(Double(i%width)*0.053+Double(generation)*0.0015)+cos(Double(i/width)*0.071-Double(generation)*0.0009)
                let direction=Int(floor((heading+2)*1.5))%4
                let turn=sin(Double(i/width)*0.13+Double(generation)*0.002)+cos(Double(i%width)*0.09)
                let k=turn>1.2 ? [0,2,7,5][direction]:[3,1,4,6][direction]
                let state=cells[neighbors[i*8+k]].state
                let directional=(state>0 && state<9) || (excited==2 && fertile>0.68 && i%5==0)
                if Self.birth(mode:mode,excited:excited,living:living,energy:c.energy,substrate:fertile,directionActive:directional) {
                    // Seeded choice, only at eligible fronts, creates branching rather than noise.
                    let chance=mode == .reef ? 0.10+settings.activity*0.13 : mode == .signal ? 0.86 : 0.60+settings.activity*0.25
                    if random.next()<chance {result.state=1;result.age=0;result.energy=max(0,c.energy-0.23)}
                }
            } else if c.state<=12 {
                result.age=min(65000,c.age+1)
                if mode == .reef && c.age<UInt16(70+substrate[i]*140) && living>=1 && living<=5 && c.energy>0.15 {
                    result.state=UInt8(min(12,2+Int(c.age)/18));result.energy=max(0,c.energy-0.003-Float(i%7)*0.0005)
                } else {result.state=c.state + (mode == .drift && generation%2==0 ? 0:1);result.energy=max(0,c.energy-(mode == .drift ? 0.009:0.012))}
            } else {
                result.state=c.state>=UInt8(18+Int(settings.persistence*12)+i%7) ? 0:c.state + (mode == .drift && generation%2==0 ? 0:1)
                result.age=0
            }
            if result.state>0 && result.state<=12 {live+=1};if result.state != c.state {changed+=1}
            next[i]=result
        }
        swap(&cells,&next)
        liveFraction=Double(live)/Double(cells.count);changeFraction=Double(changed)/Double(cells.count)
        quiet=liveFraction<0.004 || changeFraction<0.0004 ? quiet+1:0
        // Local recovery is a seed, never a full-grid reset. Recovery survives Events=Minimal.
        if quiet>35 || generation%Int(150-settings.activity*65)==0 {seedColony();quiet=0}
        if mode == .drift && liveFraction<0.016 && generation%20==0 {seedColony();seedColony()}
        events.removeAll {generation-$0.born>$0.duration}
        if generation%Int(220-settings.events*140)==0 && settings.events>0 && events.count<3 {
            let kind=LatticeEvent.Kind(rawValue:Int(random.next()*4))!
            events.append(LatticeEvent(kind:kind,x:random.next()*Double(width),y:random.next()*Double(height),born:generation,duration:100+Int(random.next()*120),phase:random.next()*6.28))
        }
        for e in events.indices {
            var event=events[e],age=generation-event.born
            if event.kind == .lantern {event.x=(event.x+0.18+Double(width)).truncatingRemainder(dividingBy:Double(width));event.y=(event.y+sin(event.phase+Double(age)*0.03)*0.11+Double(height)).truncatingRemainder(dividingBy:Double(height));events[e]=event}
            let x=Int(event.x),y=Int(event.y)
            switch event.kind {
            case .seed:if age==0{seedColony(at:(x,y))}
            case .lantern:if age%5==0{seedColony(at:(x,y))}
            case .beacon:if age%45==0{seedColony(at:(x,y))}
            case .void:
                let radius=3+Int(3*sin(min(1,Double(age)/Double(event.duration)) * .pi))
                for dy in -radius...radius {for dx in -radius...radius where dx*dx+dy*dy<=radius*radius {let i=((y+dy+height)%height)*width+(x+dx+width)%width;cells[i].state=max(cells[i].state,20);cells[i].energy=0.05}}
            }
        }
    }
}
