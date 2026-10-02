import AppKit
import QuartzCore

final class FlourishScene: SaverScene {
    private var settings=FlourishSettings()
    private let explicitSeed:UInt64?
    private var sessionSeed:UInt64
    private var resolved:UInt64=0
    private(set) var growth:FlourishGrowth?
    private var previous:Double?
    private var running=false,dirty=true
    private var aspect=0.0,cycle=0
    private let canvas=CALayer(),art=CALayer(),old=CALayer()
    private var stems:[CAShapeLayer]=[],ornaments:[CALayer]=[],counts:[Int]=[]
    init(seed:UInt64?=nil){explicitSeed=seed;sessionSeed=seed ?? UInt64.random(in:0...UInt64.max)}
    func start(){running=true;previous=nil;if explicitSeed==nil {sessionSeed=UInt64.random(in:0...UInt64.max);dirty=true}}
    func stop(){running=false;previous=nil}
    func apply(_ value:SaverSettings){let next=value.flourish.sanitized();if next != settings {dirty=true};settings=next}
    private func reset(aspect:Double,date:Date) {
        resolved=explicitSeed ?? settings.seedBehavior.resolve(fresh:sessionSeed,fixed:settings.seed,date:date)
        growth=FlourishGrowth(seed:resolved &+ UInt64(cycle)&*7919,aspect:aspect,settings:settings)
        stems.forEach{$0.removeFromSuperlayer()};ornaments.forEach{$0.removeFromSuperlayer()};stems=[];ornaments=[];counts=[]
    }
    func updateLayer(_ root:CALayer,size:CGSize,time:Double,date:Date)->Bool {
        guard size.width>0 && size.height>0 else{return true}
        CATransaction.begin();CATransaction.setDisableActions(true);defer{CATransaction.commit()}
        if canvas.superlayer !== root {canvas.removeFromSuperlayer();root.addSublayer(canvas);canvas.masksToBounds=true;if art.superlayer==nil{canvas.addSublayer(old);canvas.addSublayer(art)}}
        canvas.frame=CGRect(origin:root.bounds.origin,size:size)
        let a=Double(size.width/size.height),scale=Double(size.height)/900
        if dirty || abs(a-aspect)>0.001 {
            aspect=a;cycle=0;reset(aspect:a,date:date);previous=nil;old.contents=nil;dirty=false
            canvas.backgroundColor=settings.palette.background.color.cgColor
            if settings.background != .clean {
                let c=bitmap(width:512,height:512)!;c.setFillColor(settings.palette.background.color.cgColor);c.fill(CGRect(x:0,y:0,width:512,height:512))
                var r=ArtRandom(state:resolved)
                for _ in 0..<17000 {c.setFillColor(NSColor.black.withAlphaComponent(settings.background == .vellum ? 0.013 : 0.028).cgColor);c.fillEllipse(in:CGRect(x:r.next()*512,y:r.next()*512,width:0.3+r.next()*0.7,height:0.3+r.next()*0.3))}
                let backing=min(2,3072/max(Double(size.width),Double(size.height))),b=bitmap(width:max(1,Int(size.width*backing)),height:max(1,Int(size.height*backing)))!
                b.draw(c.makeImage()!,in:CGRect(x:0,y:0,width:512,height:512),byTiling:true);canvas.contents=b.makeImage()
            } else {canvas.contents=nil}
        }
        art.bounds=CGRect(x:0,y:0,width:growth!.width,height:900);art.anchorPoint = .zero;art.position = .zero;art.transform=CATransform3DMakeScale(scale,scale,1)
        old.frame=canvas.bounds
        if running,let previous {growth?.advance(max(0,time-previous))};previous=running ? time : nil
        if growth!.age>280 {
            let snapshotScale=min(1600/Double(size.width),1600/Double(size.height))
            let c=bitmap(width:max(1,Int(size.width*snapshotScale)),height:max(1,Int(size.height*snapshotScale)))
            if let c {c.scaleBy(x:snapshotScale*scale,y:snapshotScale*scale);art.render(in:c);old.contents=c.makeImage();old.opacity=1}
            cycle+=1;reset(aspect:a,date:date)
        }
        guard let g=growth else{return true}
        old.opacity=Float(max(0,1-g.presentationAge/14))
        if settings.breeze {art.transform=CATransform3DTranslate(CATransform3DMakeScale(scale,scale,1),sin(g.presentationAge*0.05)*1.1,cos(g.presentationAge*0.043)*0.7,0)}
        for (i,b) in g.branches.enumerated() {
            if i>=stems.count {let layer=CAShapeLayer();layer.fillColor=settings.palette.inks[b.family].color.cgColor;art.insertSublayer(layer,at:UInt32(stems.count));stems.append(layer);counts.append(0)}
            if counts[i] != b.points.count || b.alive {
                var visible=b
                if b.alive && b.points.count>1 && abs(b.lastGrowth-g.age)<0.0001 {let n=b.points.count-1,a=b.points[n-1],z=b.points[n];visible.points[n]=FlourishPoint(x:a.x+(z.x-a.x)*g.tipFraction,y:a.y+(z.y-a.y)*g.tipFraction)}
                stems[i].path=FlourishGeometry.stem(visible,character:settings.line);counts[i]=b.alive ? -b.points.count:b.points.count
            }
        }
        for (i,o) in g.ornaments.enumerated() {
            if i>=ornaments.count {
                let holder=CALayer(),paths=FlourishGeometry.ornament(o)
                holder.position=CGPoint(x:o.position.x,y:o.position.y);holder.transform=CATransform3DMakeRotation(o.angle,0,0,1)
                for (index,path) in [paths.0,paths.1].enumerated(){let l=CAShapeLayer();l.path=path;l.fillColor=nil;l.strokeColor=settings.palette.inks[o.kind>=4 ? 3:o.family].color.cgColor;l.lineWidth=index==0 ? (settings.line == .brushPen ? 1.25:0.9):0.46;l.lineCap = .round;l.lineJoin = .round;holder.addSublayer(l)}
                let wash=CAShapeLayer();wash.path=paths.0;wash.fillColor=settings.palette.inks[o.kind>=4 ? 3:o.family].color.withAlphaComponent(0.055).cgColor;holder.insertSublayer(wash,at:0)
                art.addSublayer(holder);ornaments.append(holder)
            }
            let age=g.presentationAge-o.born,outline=ornaments[i].sublayers![1] as! CAShapeLayer,veins=ornaments[i].sublayers![2] as! CAShapeLayer
            outline.strokeEnd=CGFloat(min(1,max(0,age/(o.kind>=4 ? 5:2.6))));veins.strokeEnd=CGFloat(min(1,max(0,(age-1.7)/2)))
            ornaments[i].sublayers![0].opacity=settings.wash ? Float(min(1,max(0,(age-2)/3))):0
        }
        return true
    }
    func draw(in c:CGContext,size:CGSize,time:Double,date:Date){let root=CALayer();root.bounds=CGRect(origin:.zero,size:size);_ = updateLayer(root,size:size,time:time,date:date);root.render(in:c)}
}
