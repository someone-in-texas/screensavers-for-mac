import AppKit
import QuartzCore

final class ResearchLoreScene:SaverScene {
    private var settings=ResearchSettings()
    private let explicitSeed:UInt64?
    private var sessionSeed:UInt64
    private var dirty=true,running=false
    private var clock=WorldClock()
    private(set) var world:ResearchWorld?
    private let canvas=CALayer(),stage=CALayer(),instrument=CALayer(),message=CALayer(),agent=CALayer(),hand=CAShapeLayer(),progress=CALayer()
    private var dust:[CALayer]=[],streaks:[CALayer]=[]
    private var lastText="",lastInstrument=""
    init(seed:UInt64?=nil){explicitSeed=seed;sessionSeed=seed ?? UInt64.random(in:0...UInt64.max)}
    func start(){running=true;clock.pause();if explicitSeed==nil {sessionSeed=UInt64.random(in:0...UInt64.max);dirty=true}}
    func stop(){running=false;clock.pause()}
    func apply(_ value:SaverSettings){if settings != value.research {dirty=true};settings=value.research.sanitized()}
    private func build(_ date:Date){
        let seed=explicitSeed ?? settings.seedBehavior.resolve(fresh:sessionSeed,fixed:settings.seed,date:date)
        let world=ResearchWorld(seed:seed,settings:settings);self.world=world;clock.reset();lastText="";lastInstrument=""
        stage.sublayers?.forEach{$0.removeFromSuperlayer()};dust=[];streaks=[]
        stage.bounds=CGRect(origin:.zero,size:ResearchArtwork.size);stage.anchorPoint = .zero;stage.contents=ResearchArtwork.backdrop(world,settings)
        let p=settings.palette.colors
        if settings.mazes != .rare || world.seed%3==0 {agent.bounds=CGRect(x:0,y:0,width:4,height:4);agent.cornerRadius=2;agent.backgroundColor=WorldInk.color(p.lamp);agent.shadowColor=WorldInk.color(p.lamp);agent.shadowOpacity=0.4;agent.shadowRadius=4;agent.shadowOffset = .zero;stage.addSublayer(agent)}
        for (i,d) in world.dust.enumerated(){let l=WorldInk.dot(p.paper,i%3==0 ? 0.8:0.5);l.opacity=0.10;l.position=d.point;stage.addSublayer(l);dust.append(l)}
        for i in 0..<4 {let l=CALayer();l.bounds=CGRect(x:0,y:0,width:14+Double(i)*4,height:0.65);l.backgroundColor=WorldInk.color(p.screen,0.14);stage.addSublayer(l);streaks.append(l)}
        let path=CGMutablePath();path.move(to:.zero);path.addLine(to:CGPoint(x:0,y:19));hand.path=path;hand.strokeColor=WorldInk.color(p.dark);hand.lineWidth=1.2;hand.position=CGPoint(x:1972,y:971);stage.addSublayer(hand)
        message.bounds=CGRect(x:0,y:0,width:285,height:30);message.position=CGPoint(x:2370,y:927);stage.addSublayer(message)
        instrument.bounds=CGRect(x:0,y:0,width:285,height:25);instrument.position=CGPoint(x:2370,y:970);stage.addSublayer(instrument)
        progress.bounds=CGRect(x:0,y:0,width:240,height:1);progress.anchorPoint = .zero;progress.position=CGPoint(x:2230,y:902);progress.backgroundColor=WorldInk.color(p.screen,0.18);stage.addSublayer(progress)
        dirty=false
    }
    func updateLayer(_ root:CALayer,size:CGSize,time:Double,date:Date)->Bool {
        guard size.width>0 && size.height>0 else{return true}
        CATransaction.begin();CATransaction.setDisableActions(true);defer{CATransaction.commit()}
        if canvas.superlayer !== root {canvas.removeFromSuperlayer();root.addSublayer(canvas);canvas.masksToBounds=true;canvas.addSublayer(stage)}
        canvas.frame=CGRect(origin:root.bounds.origin,size:size);canvas.backgroundColor=WorldInk.color(settings.palette.colors.dark)
        if dirty {build(date)}
        clock.tick(time,running:running);guard let world else{return true}
        let t=clock.elapsed,camera=world.camera(t,settings,aspect:Double(size.width/size.height)),scale=max(Double(size.height)/900*camera.zoom,Double(size.width)/4000)
        let half=Double(size.width)/scale/2,cameraX=min(4000-half,max(half,camera.x))
        stage.position=CGPoint(x:Double(size.width)/2-cameraX*scale,y:Double(size.height)/2-camera.y*scale);stage.transform=CATransform3DMakeScale(scale,scale,1)
        let a=world.maze.agent(t);agent.position=ResearchArtwork.project(-80+a.x*21,149,143+a.y*21)
        for (i,l) in dust.enumerated(){let d=world.dust[i];l.position=CGPoint(x:d.x+sin(t/43+Double(i))*8,y:d.y+sin(t/59+Double(i))*11);let distance=abs(d.x-(2680-(1330-d.y)*0.58));l.opacity=Float(max(0,1-distance/120)*0.17)}
        for (i,l) in streaks.enumerated(){let f=(t*0.038+Double(i)*0.25).truncatingRemainder(dividingBy:1);l.position=CGPoint(x:2700+f*60,y:1120+Double(i)*40);l.opacity=Float(sin(f * .pi)*0.45)}
        hand.transform=CATransform3DMakeRotation(-t/60*Double.pi*2,0,0,1)
        progress.transform=CATransform3DMakeScale(world.readiness(t),1,1)
        let metadata=world.experiment(t)
        if metadata != lastInstrument {lastInstrument=metadata;instrument.contents=WorldInk.image(CGSize(width:285,height:25),2){c in WorldInk.label(c,metadata,CGPoint(x:0,y:7),9,settings.palette.colors.paper,0.36)}}
        let (fragment,alpha)=world.fragment(t,settings)
        if fragment != lastText {lastText=fragment;message.contents=fragment.isEmpty ? nil:WorldInk.image(CGSize(width:285,height:30),2){c in WorldInk.label(c,fragment,CGPoint(x:0,y:8),10.5,settings.palette.colors.screen)}}
        message.opacity=Float(alpha)
        return true
    }
    func draw(in c:CGContext,size:CGSize,time:Double,date:Date){let root=CALayer();root.bounds=CGRect(origin:.zero,size:size);_ = updateLayer(root,size:size,time:time,date:date);root.render(in:c)}
}
