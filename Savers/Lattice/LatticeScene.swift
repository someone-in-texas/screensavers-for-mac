import AppKit
import QuartzCore

final class LatticeScene:SaverScene {
    private var settings=LatticeSettings()
    private let explicitSeed:UInt64?
    private var sessionSeed:UInt64
    private var previous:Double?,accumulator=0.0
    private var running=false,dirty=true
    private(set) var world:LatticeWorld?
    private let canvas=CALayer(),picture=CALayer()
    private var buffer:CGContext?
    private var light:[Float]=[],blur:[Float]=[]
    private var colors:[CGColor]=[]
    private var lastGeneration = -1
    init(seed:UInt64?=nil){explicitSeed=seed;sessionSeed=seed ?? UInt64.random(in:0...UInt64.max)}
    func start(){running=true;previous=nil;if explicitSeed==nil {sessionSeed=UInt64.random(in:0...UInt64.max);dirty=true}}
    func stop(){running=false;previous=nil}
    func apply(_ value:SaverSettings){let next=value.lattice.sanitized();if next.mode != settings.mode || next.pixels != settings.pixels || next.seed != settings.seed || next.seedBehavior != settings.seedBehavior {dirty=true};if next != settings {lastGeneration = -1;colors=[]};settings=next;world?.settings=next}
    static func dimensions(_ size:CGSize,scale:Double,pixels:LatticePixel)->(Int,Int) {
        let target=pixels == .fine ? 135.0:pixels == .bold ? 72.0:100.0
        let integer=max(1,ceil(max(Double(size.height)*scale/(target*3),Double(size.width)*scale/(256*3))))
        let cellSize=3*integer/max(1,scale)
        return (max(12,Int(ceil(size.width/cellSize))),max(12,Int(ceil(size.height/cellSize))))
    }
    func updateLayer(_ root:CALayer,size:CGSize,time:Double,date:Date)->Bool {
        guard size.width>0 && size.height>0 else{return true}
        CATransaction.begin();CATransaction.setDisableActions(true);defer{CATransaction.commit()}
        if canvas.superlayer !== root {canvas.removeFromSuperlayer();root.addSublayer(canvas);canvas.masksToBounds=true;if picture.superlayer==nil{canvas.addSublayer(picture);picture.magnificationFilter = .nearest;picture.minificationFilter = .nearest}}
        canvas.frame=CGRect(origin:root.bounds.origin,size:size);canvas.backgroundColor=settings.palette.background.color.cgColor
        let scale=Double(root.contentsScale),d=Self.dimensions(size,scale:scale,pixels:settings.pixels)
        if dirty || world?.width != d.0 || world?.height != d.1 {
            let seed=explicitSeed ?? settings.seedBehavior.resolve(fresh:sessionSeed,fixed:settings.seed,date:date)
            world=LatticeWorld(seed:seed,width:d.0,height:d.1,settings:settings)
            buffer=bitmap(width:d.0*3,height:d.1*3);light=Array(repeating:0,count:d.0*d.1);blur=light
            previous=nil;accumulator=0;lastGeneration = -1;dirty=false
            // A short, deterministic opening establishes a living world without a blank wait.
            for _ in 0..<45 {world?.step()}
        }
        if running,let previous {accumulator += min(0.25,max(0,time-previous))*settings.speed
            while accumulator>=1 {world?.step();accumulator-=1}
        };previous=running ? time:nil
        if let world,world.generation != lastGeneration {render(world);lastGeneration=world.generation;picture.contents=buffer?.makeImage()}
        let integer=max(1,ceil(max(size.width*scale/Double(d.0*3),size.height*scale/Double(d.1*3))))
        let w=Double(d.0*3)*integer/scale,h=Double(d.1*3)*integer/scale
        picture.frame=CGRect(x:floor((Double(size.width)-w)*scale/2)/scale,y:floor((Double(size.height)-h)*scale/2)/scale,width:w,height:h)
        return true
    }
    private func render(_ world:LatticeWorld) {
        guard let c=buffer else{return}
        let bg=settings.palette.background,inks=settings.palette.colors
        if colors.isEmpty {
            for role in 0..<4 {for level in 0..<32 {
                let t=Double(level)/31,ink=inks[role]
                colors.append(RGB(bg.r+(ink.r-bg.r)*t,bg.g+(ink.g-bg.g)*t,bg.b+(ink.b-bg.b)*t).color.cgColor)
            }}
        }
        c.setFillColor(bg.color.cgColor);c.fill(CGRect(x:0,y:0,width:world.width*3,height:world.height*3))
        let w=world.width,h=world.height
        for i in light.indices {
            let s=world.cells[i].state
            light[i]=s==0 ? 0:s<=3 ? 1:s<=12 ? 0.14:Float(max(0,1-Double(s-12)/24))*0.22
        }
        if settings.glow>0 && settings.palette != .paper {
            for _ in 0..<3 {
                for y in 0..<h {for x in 0..<w {let i=y*w+x
                    blur[i]=(light[i]*2+light[y*w+(x+w-1)%w]+light[y*w+(x+1)%w]+light[((y+h-1)%h)*w+x]+light[((y+1)%h)*w+x])/6
                }}
                swap(&light,&blur)
            }
            for i in light.indices where light[i]>0.012 {
                let level=min(22,Int(Double(light[i])*settings.glow*45))
                c.setFillColor(colors[32+level]);c.fill(CGRect(x:(i%w)*3,y:(i/w)*3,width:3,height:3))
            }
        }
        for i in world.cells.indices {
            let cell=world.cells[i],s=Int(cell.state)
            guard s>0 else{continue}
            let role=s<=2 ? 3:s<=8 ? 2:s<=12 ? 1:0
            let brightness=s<=12 ? max(9,30-Int(cell.age)/8)+Int(cell.energy*2):max(1,Int((1-Double(s-12)/25)*22))
            c.setFillColor(colors[role*32+min(31,brightness)])
            let x=(i%w)*3,y=(i/w)*3
            if s<=3 && (i*17+Int(cell.age))%13==0 {c.fill(CGRect(x:x,y:y+1,width:3,height:1));c.fill(CGRect(x:x+1,y:y,width:1,height:3))}
            else if s<=12 {c.fill(CGRect(x:x,y:y,width:settings.grid == .subtle ? 2:3,height:settings.grid == .crt ? 2:3))}
            else {c.fill(CGRect(x:x+1,y:y+1,width:1,height:1))}
        }
    }
    func draw(in c:CGContext,size:CGSize,time:Double,date:Date){let root=CALayer();root.bounds=CGRect(origin:.zero,size:size);_ = updateLayer(root,size:size,time:time,date:date);root.render(in:c)}
}
