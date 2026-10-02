import AppKit
import QuartzCore

/// Cached print surfaces, resolution-aware subjects, and independently growing ink families.
final class FineArtScene: SaverScene {
    let research: Bool
    private var settings=SaverSettings()
    private let explicitSeed: UInt64?
    private var sessionSeed: UInt64
    private var clock=WorldClock(), running=false, dirty=true
    private let canvas=CALayer(), stage=CALayer(), paper=CALayer(), chair=CALayer()
    private var ink:[CAShapeLayer]=[], bodies:[CALayer]=[], marks:[CAShapeLayer]=[]
    private var signals:[CAShapeLayer]=[], strokes:[PrintStroke]=[], forms:[PrintForm]=[]
    private var lastAngle=Double.infinity, rasterScale=0.0
    private var generations:[Int:Int]=[:], chairInk:[CAShapeLayer]=[]
    private(set) var artworkCenter=CGPoint(x:800,y:500)
    private(set) var artworkBounds=CGRect.zero
    private(set) var renewalCount=0
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
        stage.sublayers?.forEach{$0.removeFromSuperlayer()};ink=[];bodies=[];marks=[];signals=[];forms=[];lastAngle = .infinity;rasterScale=0;generations=[:];renewalCount=0;chairInk=[];chair.sublayers?.forEach{$0.removeFromSuperlayer()};chair.contents=nil
        let colors=research ? rs.fineArt.palette.colors : ss.fineArt.palette.colors
        paper.contents=FineArtArtwork.paper(colors,texture:research ? .paper:ss.fineArt.texture,seed:seed)
        if research {
            let world=ResearchPrint(seed:seed,settings:rs.fineArt);strokes=world.strokes
            chair.bounds=CGRect(x:0,y:0,width:240,height:260);chair.position=CGPoint(x:world.anchor.x,y:world.anchor.y+83)
            artworkBounds=strokes.reduce(CGRect(x:world.anchor.x-82,y:world.anchor.y-18,width:164,height:200)){$0.union($1.path.boundingBoxOfPath)}
            artworkCenter=CGPoint(x:artworkBounds.midX,y:artworkBounds.midY)
        } else {
            let world=StrawberryPrint(seed:seed,settings:ss.fineArt);strokes=world.strokes;forms=world.forms
            artworkCenter=CGPoint(x:800,y:500)
            for form in forms {let l=CALayer();l.bounds=CGRect(origin:.zero,size:FineArtArtwork.fruitSize);l.position=CGPoint(x:form.x,y:form.y);bodies.append(l)}
        }
        for (i,stroke) in strokes.enumerated() {
            let l=CAShapeLayer();l.path=stroke.path;l.fillColor=nil;l.strokeColor=WorldInk.color(colors.ink);l.lineWidth=stroke.weight;l.lineCap = .round;l.lineJoin = .round
            stage.addSublayer(l);ink.append(l)
            if research || (stroke.digital && i%3==0) {
                let signal=CAShapeLayer();signal.path=stroke.path;signal.fillColor=nil;signal.strokeColor=WorldInk.color(colors.ink);signal.lineWidth=stroke.weight*1.3;signal.lineCap = .round;signal.opacity=0;signal.name=String(i);stage.addSublayer(signal);signals.append(signal)
            }
            if !research && stroke.digital && i%3 != 1 {
                let m=CAShapeLayer();m.path=terminal(stroke.end,index:i);m.fillColor=nil;m.strokeColor=WorldInk.color(colors.ink);m.lineWidth=0.7;m.name=String(i);stage.addSublayer(m);marks.append(m)
            }
        }
        if research {stage.addSublayer(chair)} else {bodies.forEach{stage.addSublayer($0)}}
        clock.reset();dirty=false
    }
    private func terminal(_ end:CGPoint,index:Int)->CGPath {
        let p=CGMutablePath()
        if index%2==0 {p.addEllipse(in:CGRect(x:end.x-2.3,y:end.y-2.3,width:4.6,height:4.6))}
        else {
            p.addRect(CGRect(x:end.x-2,y:end.y-2,width:4,height:4))
            for pin in 0..<3 {p.move(to:CGPoint(x:end.x+2,y:end.y+Double(pin)*4));p.addLine(to:CGPoint(x:end.x+8,y:end.y+Double(pin)*4))}
        }
        return p
    }
    private func renew(_ time:Double) {
        guard research || settings.strawberry.fineArt.motion == .growth else{return}
        var changed=Set<Int>()
        for family in Set(strokes.map(\.family)) {
            let generation=PrintCycle(family:family,research:research).state(time).generation
            if generation != (generations[family] ?? 0) {generations[family]=generation;changed.insert(family)}
        }
        guard !changed.isEmpty else{return}
        let next=research ? ResearchPrint(seed:seed,settings:settings.research.fineArt,generations:generations).strokes : StrawberryPrint(seed:seed,settings:settings.strawberry.fineArt,generations:generations).strokes
        for i in strokes.indices where changed.contains(strokes[i].family) {strokes[i]=next[i];ink[i].path=next[i].path}
        for signal in signals {let i=Int(signal.name!)!;if changed.contains(strokes[i].family){signal.path=strokes[i].path}}
        for mark in marks {let i=Int(mark.name!)!;if changed.contains(strokes[i].family){mark.path=terminal(strokes[i].end,index:i)}}
        renewalCount += changed.count
    }
    private func updateChair(_ colors:PrintColors,angle:Double,scale:Double) {
        let shapes=FineArtArtwork.chairPaths(colors,angle:angle)
        if chairInk.isEmpty {
            for _ in shapes {let layer=CAShapeLayer();layer.lineCap = .round;layer.lineJoin = .round;chair.addSublayer(layer);chairInk.append(layer)}
        }
        for (layer,shape) in zip(chairInk,shapes) {
            layer.path=shape.path;layer.fillColor=shape.fill;layer.strokeColor=shape.stroke;layer.lineWidth=shape.width;layer.contentsScale=scale
        }
    }
    func updateLayer(_ root:CALayer,size:CGSize,time:Double,date:Date)->Bool {
        guard size.width>0,size.height>0,size.width.isFinite,size.height.isFinite else {return true}
        CATransaction.begin();CATransaction.setDisableActions(true);defer{CATransaction.commit()}
        if canvas.superlayer !== root {canvas.removeFromSuperlayer();root.addSublayer(canvas)}
        if paper.superlayer !== canvas {canvas.addSublayer(paper)}
        if stage.superlayer !== canvas {canvas.addSublayer(stage)}
        // The host can start with a tiny preview, an offset bounds origin, or reused
        // layer geometry. Establish local coordinates before fitting the artwork.
        canvas.anchorPoint=CGPoint(x:0.5,y:0.5);canvas.transform=CATransform3DIdentity
        canvas.bounds=CGRect(origin:.zero,size:size)
        canvas.position=CGPoint(x:root.bounds.origin.x+size.width/2,y:root.bounds.origin.y+size.height/2)
        canvas.masksToBounds=true
        paper.frame=canvas.bounds
        if dirty {build(date)}
        stage.bounds=CGRect(x:artworkCenter.x-800,y:artworkCenter.y-500,width:1600,height:1000)
        stage.anchorPoint=CGPoint(x:0.5,y:0.5)
        clock.tick(time,running:running);let t=clock.elapsed
        let colors=research ? settings.research.fineArt.palette.colors:settings.strawberry.fineArt.palette.colors
        canvas.backgroundColor=WorldInk.color(colors.ground)
        let portrait=size.height>size.width
        let scale=0.92*(portrait ? min(size.width/1250,size.height/1100) : min(size.width/1600,size.height/1000))
        let moving=research || settings.strawberry.fineArt.motion != .still
        let driftX=moving ? 70*sin(t/61)+24*sin(t/139):0
        let driftY=moving ? 42*sin(t/79)+20*sin(t/157):0
        stage.transform=CATransform3DMakeScale(scale,scale,1)
        stage.position=CGPoint(x:size.width/2+driftX*scale,y:size.height/2+driftY*scale)
        // Shape-layer rasterization and cached subjects must follow both display
        // backing scale and fitted artwork scale, including a move between displays.
        let effective=max(1,scale*max(1,root.contentsScale)),resolution=max(2,ceil(effective))
        let resolutionChanged=resolution != rasterScale
        if resolutionChanged {
            rasterScale=resolution
            for (i,l) in bodies.enumerated(){l.contents=FineArtArtwork.fruit(forms[i],index:i,colors:colors,settings:settings.strawberry.fineArt,seed:seed,resolution:resolution);l.contentsScale=resolution}
        }
        let pace=research ? settings.research.fineArt.pace.rate:1
        renew(t*pace)
        for (i,l) in ink.enumerated() {
            let stroke=strokes[i]
            let multiplier=research ? (settings.research.fineArt.line == .technical ? 0.8 : settings.research.fineArt.line == .ink ? 1.25 : settings.research.fineArt.line == .etched ? 0.65 : 1.0):1
            l.contentsScale=effective;l.lineWidth=max(stroke.weight*multiplier,min(0.70/scale,stroke.weight*1.6))
            let evolves=research || settings.strawberry.fineArt.motion == .growth
            let state=stroke.evolution(t*pace,research:research)
            l.strokeEnd=evolves ? state.end:1
            let pulse = !research && settings.strawberry.fineArt.motion == .pulse ? 0.86+0.14*sin(t/9+Double(stroke.family)):1
            l.opacity=Float(stroke.opacity*(evolves ? state.opacity:1)*pulse*(research && settings.research.fineArt.line == .graphite ? 0.88:1))
        }
        if !research {
            for (i,body) in bodies.enumerated() {
                body.opacity=settings.strawberry.fineArt.motion == .breathing ? Float(0.96+0.04*sin(t/11+Double(i)*1.7)):1
            }
        }
        if research {
            chairAngle=settings.research.fineArt.chair.angle(t*pace)
            if abs(chairAngle-lastAngle)>0.0002 || resolutionChanged {updateChair(colors,angle:chairAngle,scale:effective);lastAngle=chairAngle}
            // Native vectors retain display resolution at every fitted scale.
            for layer in chairInk {layer.contentsScale=effective}
        }
        for m in marks {
            let index=Int(m.name ?? "") ?? 0
            m.contentsScale=effective;m.opacity=ink[index].opacity*Float(worldEase((Double(ink[index].strokeEnd)-0.96)/0.04))*0.85
        }
        for signal in signals {
            let index=Int(signal.name ?? "") ?? 0,visible=Double(ink[index].strokeEnd)
            signal.contentsScale=effective
            if research {
                signal.strokeStart=max(0,visible-0.035);signal.strokeEnd=visible
                signal.opacity=visible>0 && visible<0.995 ? ink[index].opacity*0.35:0
            } else {
                let phase=(t/19+Double(index)*0.137).truncatingRemainder(dividingBy:1)
                signal.strokeStart=phase*visible;signal.strokeEnd=min(visible,phase*visible+0.027)
                let active=settings.strawberry.fineArt.motion != .still && settings.strawberry.fineArt.signal != .hidden
                signal.opacity=active ? ink[index].opacity*Float(pow(sin(phase * .pi),2)*(settings.strawberry.fineArt.signal == .subtle ? 0.20:0.42)):0
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
