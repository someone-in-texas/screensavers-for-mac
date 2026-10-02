import AppKit
import QuartzCore

final class DappleScene: SaverScene {
    private var settings = DappleSettings()
    private let launchSeed: UInt64
    private let explicitSeed: UInt64?
    private var chosenSeed: UInt64?
    private(set) var simulation: DappleSimulation?
    private var previous: Double?
    private var running = false
    private var rebuild = true
    private var appearanceDirty = true
    private var lastScale = 0.0
    private var lastAspect = 0.0
    private let canvas = CALayer(), field = CALayer(), light = CAGradientLayer()
    private var disks: [CALayer] = []
    init(seed: UInt64? = nil) { explicitSeed = seed; launchSeed = seed ?? UInt64.random(in: 0...UInt64.max) }
    func start() {
        running = true; previous = nil
        if explicitSeed == nil && settings.seedBehavior == .daily { chosenSeed = nil; rebuild = true }
    }
    func stop() { running = false; previous = nil }
    func apply(_ value: SaverSettings) {
        let next = value.dapple.sanitized()
        if next.motion != settings.motion || next.density != settings.density || next.size != settings.size || next.seedBehavior != settings.seedBehavior || next.seed != settings.seed { rebuild = true; chosenSeed = nil }
        if next.palette != settings.palette || next.material != settings.material || next.texture != settings.texture || next.backgroundTexture != settings.backgroundTexture { appearanceDirty = true }
        settings = next; simulation?.settings = next
    }
    func updateLayer(_ root: CALayer, size: CGSize, time: Double, date: Date) -> Bool {
        guard size.width > 0 && size.height > 0 else { return true }
        CATransaction.begin(); CATransaction.setDisableActions(true); defer { CATransaction.commit() }
        if canvas.superlayer !== root {
            canvas.removeFromSuperlayer(); root.addSublayer(canvas); canvas.masksToBounds = true
            if field.superlayer == nil {
                canvas.addSublayer(field); canvas.addSublayer(light)
                light.type = .radial; light.startPoint = CGPoint(x:0.15,y:0.9); light.endPoint = CGPoint(x:1,y:0)
                light.colors = [NSColor.white.withAlphaComponent(0.07).cgColor, NSColor.black.withAlphaComponent(0.035).cgColor]
            }
        }
        canvas.frame = CGRect(origin: root.bounds.origin, size: size); field.frame = canvas.bounds; light.frame = canvas.bounds
        let aspect = Double(size.width/size.height), units = Double(size.height)/900
        let pixelScale = units * Double(root.contentsScale)
        if abs(aspect-lastAspect) > 0.001 { rebuild = true; lastAspect = aspect }
        if chosenSeed == nil { chosenSeed = explicitSeed ?? settings.resolvedSeed(fresh: launchSeed, date: date) }
        if rebuild {
            simulation = DappleSimulation(seed: chosenSeed!, aspect: aspect, settings: settings)
            disks.forEach { $0.removeFromSuperlayer() }; disks.removeAll()
            for i in simulation!.dots.indices {
                let disk = CALayer(); disk.name = "dapple.dot.\(i)"; disk.contentsGravity = .resize
                let surface = CALayer(); disk.addSublayer(surface)
                let shading = CAGradientLayer(); shading.type = .radial
                shading.startPoint = CGPoint(x:0.28,y:0.78); shading.endPoint = CGPoint(x:1.0,y:0.0)
                shading.locations = [0,0.55,1]; shading.masksToBounds = true; disk.addSublayer(shading)
                field.addSublayer(disk); disks.append(disk)
            }
            previous = nil; appearanceDirty = true; rebuild = false
        }
        if abs(pixelScale-lastScale) > 0.02 { appearanceDirty = true; lastScale = pixelScale }
        if appearanceDirty {
            let bg = DappleTexture.background(settings.palette, textured: settings.backgroundTexture, seed: chosenSeed!)
            let backing = min(2, min(3072 / Double(size.width),3072 / Double(size.height)))
            let paper = bitmap(width:max(1,Int(size.width*backing)),height:max(1,Int(size.height*backing)))!
            paper.draw(bg,in:CGRect(x:0,y:0,width:512,height:512),byTiling:true)
            canvas.contents = paper.makeImage(); canvas.contentsGravity = .resize
            for (i,d) in simulation!.dots.enumerated() {
                let disk = disks[i]
                disk.sublayers![0].contents = DappleTexture.surface(radius:d.radius, color:settings.palette.colors[d.color], material:settings.material, intensity:settings.texture, seed:chosenSeed! &+ UInt64(i)*7919, scale:pixelScale)
                let shading = disk.sublayers![1] as! CAGradientLayer
                let strength = settings.material == .ink ? 0.035 : settings.material == .ceramic ? 0.22 : settings.material == .soft ? 0.13 : 0.09
                shading.colors = [NSColor.white.withAlphaComponent(strength).cgColor, NSColor.white.withAlphaComponent(0).cgColor,NSColor.black.withAlphaComponent(strength*(settings.material == .ceramic ? 0.36 : 0.45)).cgColor]
            }
            appearanceDirty = false
        }
        if running, let previous { simulation?.advance(max(0,time-previous)) }
        previous = running ? time : nil
        guard let sim = simulation else { return true }
        for (i,d) in sim.dots.enumerated() {
            let disk = disks[i], radius = d.radius * units
            if disk.bounds.width != radius*2 {
                disk.bounds = CGRect(x:0,y:0,width:radius*2,height:radius*2)
                let surface = disk.sublayers![0], shading = disk.sublayers![1] as! CAGradientLayer
                surface.bounds = disk.bounds; surface.position = CGPoint(x:radius,y:radius)
                shading.frame = disk.bounds.insetBy(dx:radius*0.025,dy:radius*0.025); shading.cornerRadius = radius*0.975
                disk.shadowPath = CGPath(ellipseIn:disk.bounds.insetBy(dx:radius*0.04,dy:radius*0.04),transform:nil)
            }
            disk.position = CGPoint(x:d.x*units,y:d.y*units)
            let stretch = min(0.018,max(0,d.vy)/4500)
            let squash = d.squash - stretch
            disk.transform = CATransform3DMakeScale(1+squash,1-squash,1)
            disk.sublayers![0].transform = CATransform3DMakeRotation(d.rotation,0,0,1)
            let altitude = max(0,d.y-d.radius-sim.ground(d))
            disk.shadowColor = NSColor(srgbRed:0.12,green:0.10,blue:0.08,alpha:1).cgColor
            disk.shadowOpacity = settings.shadows ? Float(0.13/(1+altitude/160)) : 0
            disk.shadowOffset = CGSize(width:radius*0.08,height:-radius*0.11)
            disk.shadowRadius = radius*(0.10+min(0.10,altitude/700))
        }
        return true
    }
    func draw(in context: CGContext, size: CGSize, time: Double, date: Date) {
        let root = CALayer(); root.bounds = CGRect(origin:.zero,size:size)
        _ = updateLayer(root,size:size,time:time,date:date); root.render(in:context)
    }
}
