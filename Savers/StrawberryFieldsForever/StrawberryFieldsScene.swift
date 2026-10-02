import AppKit
import QuartzCore

final class StrawberryLoreScene:SaverScene {
    private var settings=StrawberrySettings()
    private let explicitSeed:UInt64?
    private var sessionSeed:UInt64
    private var dirty=true,running=false
    private var clock=WorldClock()
    private(set) var world:StrawberryWorld?
    private let canvas=CALayer(),stage=CALayer(),message=CALayer()
    private var plants:[CALayer]=[],signals:[CALayer]=[]
    private var lastText=""
    init(seed:UInt64?=nil){explicitSeed=seed;sessionSeed=seed ?? UInt64.random(in:0...UInt64.max)}
    func start(){running=true;clock.pause();if explicitSeed==nil {sessionSeed=UInt64.random(in:0...UInt64.max);dirty=true}}
    func stop(){running=false;clock.pause()}
    func apply(_ value:SaverSettings){if settings != value.strawberry {dirty=true};settings=value.strawberry.sanitized()}
    private func build(_ date:Date){
        let seed=explicitSeed ?? settings.seedBehavior.resolve(fresh:sessionSeed,fixed:settings.seed,date:date)
        let world=StrawberryWorld(seed:seed,settings:settings);self.world=world;clock.reset()
        stage.sublayers?.forEach{$0.removeFromSuperlayer()};plants=[];signals=[];lastText=""
        stage.bounds=CGRect(origin:.zero,size:StrawberryArtwork.size);stage.anchorPoint = .zero
        stage.contents=StrawberryArtwork.backdrop(world,settings)
        let p=settings.palette.colors
        var images:[String:CGImage]=[:]
        for plant in world.plants {
            let key="\(plant.variant)-\(plant.fruit)"
            if images[key]==nil {images[key]=StrawberryArtwork.plant(plant.variant,fruit:plant.fruit,p:p)}
            let l=CALayer();l.contents=images[key];l.bounds=CGRect(x:0,y:0,width:190,height:200);l.anchorPoint=CGPoint(x:0.5,y:0);l.position=plant.position.point
            l.opacity=Float(0.96-max(0,plant.position.y-1140)/410*0.50)
            stage.addSublayer(l);plants.append(l)
        }
        if settings.network != .hidden {for i in 0..<8 {let l=WorldInk.dot(p.signal,1.5);stage.addSublayer(l);signals.append(l);l.position=world.nodes[i].point}}
        message.bounds=CGRect(x:0,y:0,width:260,height:30);message.position=CGPoint(x:1952.4,y:678.8);message.transform=CATransform3DMakeScale(0.8,0.8,1);stage.addSublayer(message)
        dirty=false
    }
    func updateLayer(_ root:CALayer,size:CGSize,time:Double,date:Date)->Bool {
        guard size.width>0 && size.height>0 else{return true}
        CATransaction.begin();CATransaction.setDisableActions(true);defer{CATransaction.commit()}
        if canvas.superlayer !== root {canvas.removeFromSuperlayer();root.addSublayer(canvas);canvas.masksToBounds=true;canvas.addSublayer(stage)}
        canvas.frame=CGRect(origin:root.bounds.origin,size:size);canvas.backgroundColor=settings.palette.colors.sky.color.cgColor
        if dirty {build(date)}
        clock.tick(time,running:running)
        guard let world else{return true};let t=clock.elapsed,camera=world.camera(t,settings)
        let scale=max(Double(size.height)/900*camera.zoom,Double(size.width)/4000)
        let half=Double(size.width)/scale/2,cameraX=min(4000-half,max(half,camera.x))
        stage.position=CGPoint(x:Double(size.width)/2-cameraX*scale,y:Double(size.height)/2-camera.y*scale);stage.transform=CATransform3DMakeScale(scale,scale,1)
        for (i,plant) in world.plants.enumerated(){var tr=CATransform3DMakeScale(plant.scale,plant.scale,1);tr=CATransform3DRotate(tr,world.wind(t,plant,settings),0,0,1);plants[i].transform=tr}
        for (i,l) in signals.enumerated(){l.position=world.signal(t,i).point;let phase=(t/18+Double(i)*0.31).truncatingRemainder(dividingBy:1);l.opacity=Float((settings.network == .visible ? 0.45:0.20)*pow(sin(phase * .pi),2)*(1+world.weather(t,settings)*0.2))}
        let (fragment,alpha)=world.fragment(t,settings)
        if fragment != lastText {lastText=fragment;message.contents=fragment.isEmpty ? nil:WorldInk.image(CGSize(width:260,height:30),2){c in WorldInk.label(c,fragment,CGPoint(x:6,y:8),10,settings.palette.colors.signal)}}
        message.opacity=Float(alpha)
        return true
    }
    func draw(in c:CGContext,size:CGSize,time:Double,date:Date){let root=CALayer();root.bounds=CGRect(origin:.zero,size:size);_ = updateLayer(root,size:size,time:time,date:date);root.render(in:c)}
}
