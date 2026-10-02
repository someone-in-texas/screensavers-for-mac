import AppKit
import QuartzCore

/// A shallow, fixed composition. Cached pigment/paper; only stroke reveals and rare turns update.
final class FineArtScene: SaverScene {
    let research: Bool
    private var settings=SaverSettings()
    private let explicitSeed: UInt64?
    private var sessionSeed: UInt64
    private var clock=WorldClock(), running=false, dirty=true
    private let canvas=CALayer(), stage=CALayer(), paper=CALayer(), chair=CALayer()
    private var ink:[CAShapeLayer]=[], bodies:[CALayer]=[], marks:[CAShapeLayer]=[]
    private var signals:[CAShapeLayer]=[]
    private var strokes:[PrintStroke]=[]
    private var lastAngle=Double.infinity
    private(set) var seed:UInt64=0
    private(set) var chairAngle=0.0
    var segmentCount:Int {strokes.count}
    init(research:Bool,seed:UInt64?=nil){self.research=research;explicitSeed=seed;sessionSeed=seed ?? UInt64.random(in:0...UInt64.max)}
    func start(){running=true;clock.pause();if explicitSeed==nil {sessionSeed=UInt64.random(in:0...UInt64.max);dirty=true}}
    func stop(){running=false;clock.pause()}
    func apply(_ value:SaverSettings){if settings.research != value.research || settings.strawberry != value.strawberry {dirty=true};settings=value.sanitized()}
    private func build(_ date:Date){
        let rs=settings.research,ss=settings.strawberry
        seed=explicitSeed ?? (research ? rs.seedBehavior.resolve(fresh:sessionSeed,fixed:rs.seed,date:date):ss.seedBehavior.resolve(fresh:sessionSeed,fixed:ss.seed,date:date))
        stage.sublayers?.forEach{$0.removeFromSuperlayer()};ink=[];bodies=[];marks=[];signals=[];lastAngle = .infinity
        stage.bounds=CGRect(origin:.zero,size:FineArtArtwork.size);stage.anchorPoint = .zero
        let colors=research ? rs.fineArt.palette.colors : ss.fineArt.palette.colors
        paper.frame=stage.bounds;paper.contents=FineArtArtwork.paper(colors,texture:research ? .paper:ss.fineArt.texture,seed:seed);stage.addSublayer(paper)
        if research {
            let world=ResearchPrint(seed:seed,settings:rs.fineArt);strokes=world.strokes
            chair.frame=CGRect(x:world.anchor.x-120,y:world.anchor.y-47,width:240,height:260)
        } else {
            let world=StrawberryPrint(seed:seed,settings:ss.fineArt);strokes=world.strokes
            for (i,form) in world.forms.enumerated(){let l=CALayer();l.frame=CGRect(x:form.x-100,y:form.y-110,width:200,height:220);l.contents=FineArtArtwork.fruit(form,index:i,colors:colors,settings:ss.fineArt,seed:seed);bodies.append(l)}
        }
        for (i,stroke) in strokes.enumerated() {
            let l=CAShapeLayer();l.path=stroke.path;l.fillColor=nil;l.strokeColor=WorldInk.color(colors.ink);l.lineWidth=stroke.weight;l.opacity=Float(stroke.opacity);l.lineCap = .round;l.lineJoin = .round
            if research {switch rs.fineArt.line {case .technical:l.lineWidth *= 0.8;case .ink:l.lineWidth *= 1.25;case .graphite:l.opacity *= 0.83;case .etched:l.lineWidth *= 0.65}}
            if research && colors.ground.r<0.2 && stroke.opacity>0.6 {l.opacity *= 1.12}
            stage.addSublayer(l);ink.append(l)
            if !research && i%19==0 {
                let signal=CAShapeLayer();signal.path=stroke.path;signal.fillColor=nil;signal.strokeColor=WorldInk.color(colors.ink);signal.lineWidth=1.5;signal.lineCap = .round;signal.opacity=0;stage.addSublayer(signal);signals.append(signal)
            }
            if !research && i%7==2 && ss.fineArt.blend != .organic {
                let m=CAShapeLayer();m.path=CGPath(ellipseIn:CGRect(x:stroke.end.x-1.5,y:stroke.end.y-1.5,width:3,height:3),transform:nil);m.fillColor=nil;m.strokeColor=WorldInk.color(colors.ink,0.38);m.lineWidth=0.65;m.name=String(i);stage.addSublayer(m);marks.append(m)
            }
        }
        if research {stage.addSublayer(chair)} else {bodies.forEach{stage.addSublayer($0)}}
        clock.reset();dirty=false
    }
    func updateLayer(_ root:CALayer,size:CGSize,time:Double,date:Date)->Bool {
        guard size.width>0,size.height>0,size.width.isFinite,size.height.isFinite else {return true}
        CATransaction.begin();CATransaction.setDisableActions(true);defer{CATransaction.commit()}
        if canvas.superlayer !== root {canvas.removeFromSuperlayer();root.addSublayer(canvas);canvas.masksToBounds=true;canvas.addSublayer(stage)}
        canvas.frame=CGRect(origin:root.bounds.origin,size:size)
        if dirty {build(date)}
        let colors=research ? settings.research.fineArt.palette.colors:settings.strawberry.fineArt.palette.colors
        canvas.backgroundColor=WorldInk.color(colors.ground)
        let portrait=size.height>size.width
        let scale=portrait ? min(size.width/1250,size.height/1100) : min(size.width/1600,size.height/1000)
        stage.transform=CATransform3DMakeScale(scale,scale,1);stage.position=CGPoint(x:(size.width-1600*scale)/2,y:(size.height-1000*scale)/2)
        for (i,l) in ink.enumerated() {
            let weight=strokes[i].weight
            let multiplier=research ? (settings.research.fineArt.line == .technical ? 0.8 : settings.research.fineArt.line == .ink ? 1.25 : settings.research.fineArt.line == .etched ? 0.65 : 1.0) : 1.0
            l.lineWidth=max(weight*multiplier,min(0.65/scale,weight*1.6))
        }
        clock.tick(time,running:running);let t=clock.elapsed
        if research {
            let s=settings.research.fineArt;chairAngle=s.chair.angle(t)
            if abs(chairAngle-lastAngle)>0.002 {chair.contents=FineArtArtwork.chair(colors,angle:chairAngle);lastAngle=chairAngle}
            for (i,l) in ink.enumerated() {
                // Independent slow breaths prevent a global erase or loading-bar cycle.
                let phase=t*s.pace.rate/260+Double(i)*0.173
                l.strokeEnd=0.70+0.30*(0.5+0.5*sin(phase))
            }
        } else {
            let s=settings.strawberry.fineArt
            for (i,l) in ink.enumerated() {
                let phase=t/115+Double(i)*0.61
                l.strokeEnd=s.motion == .growth ? 0.86+0.14*(0.5+0.5*sin(phase)):1
                let amplitude=s.signal == .hidden || s.motion == .still ? 0 : s.signal == .subtle ? 0.035:0.08
                l.opacity=Float(min(1,strokes[i].opacity*(colors.ground.r<0.2 ? 1.09:1)+amplitude*pow(max(0,sin(phase)),12)))
            }
            for (i,l) in bodies.enumerated(){let scale=s.motion == .breathing ? 1+sin(t/83+Double(i))*0.004:1;l.transform=CATransform3DMakeScale(scale,scale,1)}
            for m in marks {
                let index=Int(m.name ?? "") ?? 0
                m.opacity=Float(worldEase((Double(ink[index].strokeEnd)-0.994)/0.006))
            }
            for (i,signal) in signals.enumerated() {
                let phase=(t/105+Double(i)*0.37).truncatingRemainder(dividingBy:1)
                let visible=Double(ink[i*19].strokeEnd)
                signal.strokeStart=phase*visible;signal.strokeEnd=min(visible,phase*visible+0.018)
                let active=s.motion != .still && s.signal != .hidden
                signal.opacity=active ? Float(sin(phase * .pi)*sin(phase * .pi)*(s.signal == .subtle ? 0.12:0.28)):0
            }
        }
        return true
    }
    func draw(in c:CGContext,size:CGSize,time:Double,date:Date){let root=CALayer();root.bounds=CGRect(origin:.zero,size:size);_ = updateLayer(root,size:size,time:time,date:date);root.render(in:c)}
}

/// Keep the entire original renderer intact and make the new print the default.
class ContemplativeScene: SaverScene {
    private let fine:FineArtScene, legacy:SaverScene
    private let research:Bool
    private var lore=false,running=false
    init(research:Bool,seed:UInt64?){self.research=research;fine=FineArtScene(research:research,seed:seed);legacy=research ? ResearchLoreScene(seed:seed):StrawberryLoreScene(seed:seed)}
    private var current:SaverScene {lore ? legacy:fine}
    func start(){running=true;current.start()}
    func stop(){running=false;current.stop()}
    private weak var root:CALayer?
    func apply(_ value:SaverSettings){
        let next=research ? value.research.loreMode:value.strawberry.loreMode
        if next != lore {current.stop();root?.sublayers?.forEach{$0.removeFromSuperlayer()};lore=next;if running {current.start()}}
        fine.apply(value);legacy.apply(value)
    }
    func updateLayer(_ root:CALayer,size:CGSize,time:Double,date:Date)->Bool {self.root=root;return current.updateLayer(root,size:size,time:time,date:date)}
    func draw(in c:CGContext,size:CGSize,time:Double,date:Date){current.draw(in:c,size:size,time:time,date:date)}
}
final class GoodResearchScene:ContemplativeScene {init(seed:UInt64?=nil){super.init(research:true,seed:seed)}}
final class StrawberryFieldsScene:ContemplativeScene {init(seed:UInt64?=nil){super.init(research:false,seed:seed)}}
