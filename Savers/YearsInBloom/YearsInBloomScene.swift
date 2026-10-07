import AppKit
import QuartzCore

final class YearsInBloomScene: SaverScene {
    private var settings = BloomSettings()
    private var clock = MotionClock()
    private var running = false
    private let seed: UInt64
    private let paper = CALayer(), atmosphere = CAGradientLayer(), weather = CAShapeLayer(), distantRain = CAShapeLayer()
    private let seasonalWash = CAGradientLayer(), lightning = CALayer()
    private let garden = CALayer(), ground = CALayer(), successor = CAShapeLayer()
    private var annualYear = -1
    private var gardenBounds = CGRect(x:-150,y:0,width:300,height:300)
    private var size = CGSize.zero
    private var cohort = -1
    private var plants: [PlantLayers] = []
        private var rebuild = true
    private(set) var simulatedYears = 0.0
    private(set) var layerCount = 0
    init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) { self.seed = seed }
    func configuration(store: SettingsStore, changed: @escaping (SaverSettings) -> Void) -> SaverConfiguration? { BloomConfiguration(store:store,changed:changed) }
    func start() { guard !running else { return }; running = true; clock.pause() }
    func stop() { running = false; clock.pause() }
    func apply(_ value: SaverSettings) {
        let next = value.bloom
        if next != settings { rebuild = true }
        settings = next
    }
    private final class PlantLayers {
        let structure: BloomStructure
        let layer = CALayer(), snow = CAShapeLayer(), roots = CAShapeLayer(), seedHeads = CAShapeLayer()
        var branches: [CAShapeLayer] = []
        var leaves: [CAShapeLayer] = []
        var details: [CAShapeLayer] = []
        let anchor: CGPoint
        let scale: Double
        init(_ structure: BloomStructure, anchor: CGPoint, scale: Double) { self.structure = structure; self.anchor = anchor; self.scale = scale }
    }
    private var pigments: (paper: NSColor, ink: NSColor, leaf: NSColor, bloom: NSColor) {
        switch settings.palette {
        case .botanical:return (.init(srgbRed:0.94,green:0.93,blue:0.85,alpha:1),.init(srgbRed:0.28,green:0.24,blue:0.18,alpha:1),.init(srgbRed:0.28,green:0.42,blue:0.24,alpha:1),.init(srgbRed:0.63,green:0.38,blue:0.38,alpha:1))
        case .vintage:return (.init(srgbRed:0.88,green:0.84,blue:0.72,alpha:1),.init(srgbRed:0.31,green:0.25,blue:0.19,alpha:1),.init(srgbRed:0.39,green:0.43,blue:0.27,alpha:1),.init(srgbRed:0.61,green:0.43,blue:0.35,alpha:1))
        case .moonlit:return (.init(srgbRed:0.11,green:0.16,blue:0.21,alpha:1),.init(srgbRed:0.52,green:0.61,blue:0.65,alpha:1),.init(srgbRed:0.44,green:0.62,blue:0.58,alpha:1),.init(srgbRed:0.74,green:0.69,blue:0.74,alpha:1))
        case .golden:return (.init(srgbRed:0.94,green:0.86,blue:0.68,alpha:1),.init(srgbRed:0.38,green:0.29,blue:0.17,alpha:1),.init(srgbRed:0.49,green:0.49,blue:0.22,alpha:1),.init(srgbRed:0.76,green:0.49,blue:0.22,alpha:1))
        case .pastel:return (.init(srgbRed:0.95,green:0.93,blue:0.90,alpha:1),.init(srgbRed:0.44,green:0.40,blue:0.39,alpha:1),.init(srgbRed:0.48,green:0.64,blue:0.49,alpha:1),.init(srgbRed:0.79,green:0.54,blue:0.59,alpha:1))
        case .ink:return (.init(srgbRed:0.92,green:0.91,blue:0.85,alpha:1),.init(srgbRed:0.22,green:0.25,blue:0.26,alpha:1),.init(srgbRed:0.35,green:0.40,blue:0.39,alpha:1),.init(srgbRed:0.30,green:0.33,blue:0.34,alpha:1))
        case .vesper:return (.init(srgbRed:0.85,green:0.84,blue:0.86,alpha:1),.init(srgbRed:0.31,green:0.28,blue:0.39,alpha:1),.init(srgbRed:0.32,green:0.48,blue:0.47,alpha:1),.init(srgbRed:0.62,green:0.40,blue:0.52,alpha:1))
        }
    }
    private func paperImage(_ size: CGSize) -> CGImage? {
        let w = min(1800,Int(max(1,size.width))), h = min(1400,Int(max(1,size.height)))
        guard let c = bitmap(width:w,height:h) else { return nil }
        c.setFillColor(pigments.paper.cgColor); c.fill(CGRect(x:0,y:0,width:w,height:h))
        var random = ArtRandom(state:seed)
        let strength = settings.texture == .subtle ? 0.025 : settings.texture == .medium ? 0.045 : 0.075
        for _ in 0..<(w*h/20) {
            let x = random.next()*Double(w), y = random.next()*Double(h)
            c.setStrokeColor(pigments.ink.withAlphaComponent(strength*random.next()).cgColor)
            c.setLineWidth(0.45);c.move(to:CGPoint(x:x,y:y));c.addLine(to:CGPoint(x:x+1+random.next()*3,y:y+random.next()));c.strokePath()
        }
        return c.makeImage()
    }
    private func leafPath(_ species: BloomPlant, flower: Bool, variation: Double) -> CGPath {
        let path = CGMutablePath()
        if flower {
            if species == .lavender || species == .sage || species == .grass {
                for tier in 0..<(5+Int(variation*3)) { for side in [-1.0,1.0] {
                    path.addEllipse(in:CGRect(x:side*(0.08+variation*0.035)-0.11,y:Double(tier)*0.16+side*variation*0.055,width:0.22*(1-Double(tier)*0.075),height:0.17+variation*0.05))
                } }
            } else if species == .coneflower {
                // Rays share the cone's base, then arc down under their own weight.
                for ray in 0..<11 {
                    let angle = Double(ray)/11*Double.pi*2
                    let x = cos(angle)*(0.82+variation*0.10)
                    let y = -0.43+sin(angle)*0.19
                    path.move(to:CGPoint(x:-0.07,y:-0.06))
                    path.addCurve(to:CGPoint(x:x,y:y),control1:CGPoint(x:x*0.48,y:0.03),control2:CGPoint(x:x*0.96,y:y+0.18))
                    path.addCurve(to:CGPoint(x:0.07,y:-0.06),control1:CGPoint(x:x*0.84,y:y-0.15),control2:CGPoint(x:x*0.34,y:-0.08))
                    path.closeSubpath()
                }
            } else {
                let petals = species == .dogwood ? 4 : species == .sunflower ? 17 : species == .rose ? 13 : 9
                for p in 0..<petals {
                    let a = Double(p)/Double(petals)*Double.pi*2+sin(Double(p)*3.7+variation)*0.06
                    let reach = 0.90+sin(Double(p)*5.1+variation)*0.09
                    var transform = CGAffineTransform(rotationAngle:a)
                    let petal = CGMutablePath()
                    petal.move(to:CGPoint(x:-0.08,y:0.10))
                    if species == .dogwood {
                        petal.addCurve(to:CGPoint(x:-0.05,y:0.92),control1:CGPoint(x:-0.49,y:0.30),control2:CGPoint(x:-0.46,y:1.03))
                        petal.addQuadCurve(to:CGPoint(x:0.05,y:0.92),control:CGPoint(x:0,y:0.77))
                        petal.addCurve(to:CGPoint(x:0.08,y:0.10),control1:CGPoint(x:0.45,y:1.03),control2:CGPoint(x:0.48,y:0.29))
                    } else {
                        let width = species == .sunflower ? 0.20:0.30
                        petal.addCurve(to:CGPoint(x:0.04,y:reach),control1:CGPoint(x:-width,y:0.42),control2:CGPoint(x:-width*0.7,y:reach*0.9))
                        petal.addCurve(to:CGPoint(x:0.08,y:0.10),control1:CGPoint(x:width,y:reach*0.79),control2:CGPoint(x:width,y:0.41))
                    }
                    petal.closeSubpath();if let shape = petal.copy(using:&transform) { path.addPath(shape) }
                }
            }
        } else if species == .cedar {
            for tier in 0..<5 {
                let y = Double(tier)*0.19, width = 0.24*(1-Double(tier)*0.12)
                path.move(to:CGPoint(x:0,y:y-0.08));path.addQuadCurve(to:CGPoint(x:-width,y:y+0.21),control:CGPoint(x:-width*1.3,y:y+0.02));path.addLine(to:CGPoint(x:0,y:y+0.08))
                path.addQuadCurve(to:CGPoint(x:width,y:y+0.24),control:CGPoint(x:width*0.3,y:y+0.05));path.addQuadCurve(to:CGPoint(x:0,y:y+0.36),control:CGPoint(x:width*0.5,y:y+0.32))
            }
        } else if species.evergreen {
            for i in 0..<7 {
                let y = Double(i)/7, width = (1-y)*0.45
                path.move(to:CGPoint(x:0,y:y-0.18));path.addLine(to:CGPoint(x:-width,y:y+0.25))
                path.move(to:CGPoint(x:0,y:y-0.12));path.addLine(to:CGPoint(x:width,y:y+0.3))
            }
        } else if species == .oak {
            path.move(to:.zero)
            for side in [-1.0,1.0] {
                let ascending = side<0
                for step in 0..<5 {
                    let i = ascending ? step:4-step
                    let y = Double(i)*0.18+0.06, width = sin((y+0.05)*Double.pi)*0.33
                    let end = CGPoint(x:side*width*0.62,y:ascending ? y+0.16:y)
                    path.addCurve(to:end,control1:CGPoint(x:side*width*1.30,y:ascending ? y:y+0.16),control2:CGPoint(x:side*width*1.38,y:ascending ? y+0.15:y+0.02))
                }
                if ascending { path.addQuadCurve(to:CGPoint(x:0.08,y:0.92),control:CGPoint(x:0,y:1.08)) }
            };path.closeSubpath()
        } else if [.maple,.japaneseMaple].contains(species) {
            let points:[CGPoint] = [CGPoint(x:0,y:0),CGPoint(x:-0.18,y:0.22),CGPoint(x:-0.47,y:0.27),CGPoint(x:-0.30,y:0.42),CGPoint(x:-0.61,y:0.67),CGPoint(x:-0.28,y:0.63),CGPoint(x:-0.30,y:0.92),CGPoint(x:-0.10,y:0.79),CGPoint(x:0,y:1.15),CGPoint(x:0.12,y:0.79),CGPoint(x:0.32,y:0.96),CGPoint(x:0.29,y:0.61),CGPoint(x:0.56,y:0.70),CGPoint(x:0.32,y:0.40),CGPoint(x:0.47,y:0.28),CGPoint(x:0.17,y:0.20)]
            path.addLines(between:points);path.closeSubpath()
        } else {
            let width = species == .willow || species == .lavender ? 0.16 : species == .fern ? 0.18 : species == .birch ? 0.31 : 0.36
            path.move(to:.zero)
            path.addCurve(to:CGPoint(x:0,y:1),control1:CGPoint(x:-width,y:0.18),control2:CGPoint(x:-width*(0.6+variation*0.3),y:0.8))
            path.addCurve(to:.zero,control1:CGPoint(x:width,y:0.75),control2:CGPoint(x:width*0.9,y:0.21));path.closeSubpath()
        }
        return path
    }
    private func populate(_ root: CALayer, cohort: Int) {
        garden.sublayers?.forEach { $0.removeFromSuperlayer() }; plants.removeAll()
        var random = ArtRandom(state: seed &+ UInt64(cohort) &* 7919)
        let layout = settings.layout == .automatic ? [BloomLayout.specimen,.grouping,.meadow,.woodland][Int(random.next()*4)] : settings.layout
        let choices = Array(BloomPlant.allCases.dropFirst())
        let primary = settings.plant == .automatic ? choices[Int(random.next()*Double(choices.count))] : settings.plant
        let species: [BloomPlant]
        switch layout {
        case .meadow: species = [.grass,.coneflower,.lavender,.wildflowers,.grass]
        case .woodland: species = [primary.woody ? primary:.oak,.birch,.fern]
        case .grouping: species = [primary,.grass,.wildflowers]
        default: species = [primary]
        }
        let anchors = species.count == 1 ? [CGPoint(x:0,y:0)] : species.count == 5 ? [CGPoint(x:-145,y:0),CGPoint(x:-70,y:4),CGPoint(x:5,y:-5),CGPoint(x:75,y:3),CGPoint(x:145,y:-2)] : [CGPoint(x:0,y:0),CGPoint(x:-125,y:-8),CGPoint(x:122,y:0)]
        for (index, plant) in species.enumerated() {
            let structure = BloomStructure(species:plant,seed:seed &+ UInt64(cohort*101+index*17) &+ (plant.annual ? UInt64(max(0,annualYear))*104729:0))
            let item = PlantLayers(structure,anchor:anchors[index],scale:species.count == 1 ? 1 : index == 0 ? 0.95 : layout == .woodland ? 0.75 : 0.62)
            garden.addSublayer(item.layer)
            let rootPath = CGMutablePath()
            for side in [-1.0,1.0] { for i in 0..<4 { rootPath.move(to:CGPoint(x:0,y:4));rootPath.addQuadCurve(to:CGPoint(x:side*Double(8+i*8),y:-4-Double(i%2)*3),control:CGPoint(x:side*Double(4+i*3),y:-3)) } }
            item.roots.path = rootPath;item.roots.fillColor = nil;item.roots.strokeColor = pigments.ink.withAlphaComponent(0.16).cgColor;item.roots.lineWidth = 0.6;item.layer.addSublayer(item.roots)
            for branch in structure.branches {
                let shape = CAShapeLayer(), path = CGMutablePath()
                path.move(to:branch.start);path.addQuadCurve(to:branch.end,control:branch.control)
                shape.path = path;shape.fillColor = nil;shape.lineCap = .round;shape.lineJoin = .round
                item.layer.addSublayer(shape);item.branches.append(shape)
            }
            for organ in structure.organs {
                let shape = CAShapeLayer();shape.path = leafPath(plant,flower:organ.flower,variation:organ.variation)
                shape.lineWidth = plant.evergreen ? 0.045 : 0.016
                shape.fillColor = plant.evergreen ? nil : pigments.leaf.cgColor
                shape.lineCap = .round;shape.lineJoin = .round
                let detail = CAShapeLayer(), veins = CGMutablePath()
                if organ.flower {
                    let r = plant == .sunflower ? 0.37:plant == .coneflower ? 0.28:0.13
                    if plant == .coneflower {
                        veins.move(to:CGPoint(x:-r,y:-0.08))
                        veins.addCurve(to:CGPoint(x:r,y:-0.08),control1:CGPoint(x:-r*0.80,y:0.32),control2:CGPoint(x:r*0.65,y:0.34))
                        veins.addQuadCurve(to:CGPoint(x:-r,y:-0.08),control:CGPoint(x:0,y:-0.16));veins.closeSubpath()
                    } else { veins.addEllipse(in:CGRect(x:-r,y:-r,width:r*2,height:r*2)) }
                    detail.fillColor = pigments.ink.cgColor
                    if plant == .sunflower {
                        let seeds = CAShapeLayer(), dots = CGMutablePath()
                        for n in 0..<55 { let angle = Double(n)*2.39996, radius = sqrt(Double(n)/55)*0.33;dots.addEllipse(in:CGRect(x:cos(angle)*radius,y:sin(angle)*radius,width:0.025,height:0.025)) }
                        seeds.path = dots;seeds.fillColor = pigments.paper.withAlphaComponent(0.30).cgColor;detail.addSublayer(seeds)
                    }
                } else if !plant.evergreen {
                    veins.move(to:.zero);veins.addQuadCurve(to:CGPoint(x:0,y:0.94),control:CGPoint(x:0.03,y:0.46))
                    for n in 1...4 { for side in [-1.0,1.0] { let y = Double(n)*0.16;veins.move(to:CGPoint(x:0,y:y));veins.addLine(to:CGPoint(x:side*0.20,y:y+0.15)) } }
                    detail.fillColor = nil
                }
                if !plant.evergreen {
                    let pigment = CAShapeLayer(), freckles = CGMutablePath()
                    for n in 0..<5 { let x = sin(Double(n)*7.1+organ.variation)*0.08,y = 0.30+Double(n)*0.08;freckles.addEllipse(in:CGRect(x:x,y:y,width:0.08+organ.variation*0.06,height:0.13)) }
                    pigment.path = freckles;pigment.fillColor = pigments.paper.withAlphaComponent(0.13).cgColor;shape.addSublayer(pigment)
                }
                detail.path = veins;detail.lineWidth = 0.013;detail.strokeColor = pigments.ink.withAlphaComponent(0.32).cgColor;shape.addSublayer(detail)
                item.layer.addSublayer(shape);item.leaves.append(shape);item.details.append(detail)
            }
            item.snow.fillColor = nil;item.snow.lineCap = .round;item.layer.addSublayer(item.snow);item.layer.addSublayer(item.seedHeads)
            plants.append(item)
        }
        var bounds = CGRect.null
        for item in plants {
            for branch in item.structure.branches {
                for at in [branch.start,branch.control,branch.end] {
                    let point = CGPoint(x:at.x*item.scale+item.anchor.x,y:at.y*item.scale+item.anchor.y)
                    bounds = bounds.union(CGRect(x:point.x-22,y:point.y-15,width:44,height:44))
                }
            }
        }
        gardenBounds = bounds
        layerCount = plants.reduce(5) { $0+$1.branches.count+$1.leaves.count*2+1 }
    }
    func updateLayer(_ root: CALayer, size: CGSize, time: Double, date: Date) -> Bool {
        guard size.width > 0 && size.height > 0 && size.width.isFinite && size.height.isFinite else { return true }
        CATransaction.begin();CATransaction.setDisableActions(true);defer { CATransaction.commit() }
        if running { clock.step(now:time,speed:1/settings.pace.secondsPerYear,maximumStep:0.25) }
        simulatedYears = clock.elapsed
        let nextCohort = Int(simulatedYears/5), age = simulatedYears.truncatingRemainder(dividingBy:5)
        if paper.superlayer !== root { root.addSublayer(paper);root.addSublayer(atmosphere);root.addSublayer(seasonalWash);root.addSublayer(distantRain);root.addSublayer(ground);root.addSublayer(garden);root.addSublayer(successor);root.addSublayer(weather);root.addSublayer(lightning);root.masksToBounds = true }
        if size != self.size || rebuild {
            self.size = size;paper.frame = CGRect(origin:.zero,size:size);paper.contents = paperImage(size)
            atmosphere.frame = paper.frame;atmosphere.type = .radial
            seasonalWash.frame = paper.frame;seasonalWash.type = .radial
            seasonalWash.startPoint = CGPoint(x:0.52,y:0.43);seasonalWash.endPoint = CGPoint(x:0.96,y:0.95)
            lightning.frame = paper.frame;lightning.backgroundColor = NSColor.white.cgColor
            if let c = bitmap(width:600,height:120) {
                let gradient = CGGradient(colorsSpace:nil,colors:[pigments.leaf.withAlphaComponent(0.085).cgColor,NSColor.clear.cgColor] as CFArray,locations:[0,1])!
                c.saveGState();c.scaleBy(x:1,y:0.18)
                for (x,y,r) in [(220.0,320.0,180.0),(340.0,295.0,210.0),(410.0,350.0,125.0)] {
                    c.drawRadialGradient(gradient,startCenter:CGPoint(x:x,y:y),startRadius:2,endCenter:CGPoint(x:x+8,y:y),endRadius:r,options:[])
                };c.restoreGState()
                ground.contents = c.makeImage()
            }
            atmosphere.startPoint = CGPoint(x:0.4,y:0.7);atmosphere.endPoint = CGPoint(x:1,y:0)
        }
        let year = Int(simulatedYears)
        if cohort != nextCohort || annualYear != year || rebuild {
            annualYear = year;populate(root,cohort:nextCohort);cohort = nextCohort;rebuild = false
        }
        let season = BloomCalendar(years:simulatedYears,settings:settings), p = pigments
        let spring = max(0,1-abs(season.phase-0.15)*5), summer = max(0,1-abs(season.phase-0.38)*5)
        let washColor = season.phase<0.27 ? NSColor(srgbRed:0.49,green:0.65,blue:0.59,alpha:0.12*spring+season.rain*0.09) : season.phase<0.53 ? NSColor(srgbRed:0.92,green:0.68,blue:0.31,alpha:0.15*summer) : season.phase<0.77 ? NSColor(srgbRed:0.74,green:0.46,blue:0.24,alpha:0.16*season.autumn) : NSColor(srgbRed:0.36,green:0.50,blue:0.63,alpha:0.23*season.winter)
        atmosphere.colors = [washColor.cgColor,NSColor.clear.cgColor]
        atmosphere.startPoint = CGPoint(x:0.43+sin(simulatedYears*2.1)*0.1,y:0.7)
        seasonalWash.colors = [washColor.withAlphaComponent(season.winter*0.14+season.autumn*(1-season.winter)*0.05).cgColor,NSColor.clear.cgColor]
        // A rare distant glow, never a hard white flash.
        let stormGlow = settings.weather == .dramatic && season.rain>0.55 ? pow(max(0,sin(simulatedYears*89.1)),22)*0.035:0
        lightning.opacity = Float(stormGlow)
        let scale = min(size.width*0.58/max(1,gardenBounds.width),size.height*0.64/max(1,gardenBounds.height))
        garden.position = CGPoint(x:size.width*0.5+sin(simulatedYears*0.4)*size.width*0.008,y:size.height*0.22)
        ground.frame = CGRect(x:size.width*0.24,y:garden.position.y-30*scale,width:size.width*0.52,height:65*scale)
        garden.setAffineTransform(CGAffineTransform(scaleX:scale,y:scale))
        let renewal = min(1,age/0.035)*min(1,(5-age)/0.15)
        garden.opacity = Float(renewal)
        let seedling = CGMutablePath()
        seedling.move(to:.zero);seedling.addQuadCurve(to:CGPoint(x:1,y:18),control:CGPoint(x:-3,y:9))
        seedling.move(to:CGPoint(x:0,y:10));seedling.addQuadCurve(to:CGPoint(x:-10,y:15),control:CGPoint(x:-10,y:23));seedling.addQuadCurve(to:CGPoint(x:0,y:10),control:CGPoint(x:-6,y:10))
        seedling.move(to:CGPoint(x:1,y:15));seedling.addQuadCurve(to:CGPoint(x:10,y:21),control:CGPoint(x:4,y:26));seedling.addQuadCurve(to:CGPoint(x:1,y:15),control:CGPoint(x:8,y:14))
        successor.path = seedling;successor.fillColor = p.leaf.withAlphaComponent(0.65).cgColor;successor.strokeColor = p.ink.withAlphaComponent(0.40).cgColor;successor.lineWidth = 0.6
        successor.position = garden.position;successor.setAffineTransform(CGAffineTransform(scaleX:scale,y:scale))
        successor.opacity = Float(age>4.75 ? min(1,(age-4.75)/0.1):age<0.25 ? max(0,1-age/0.25):0)
        for (plantIndex,item) in plants.enumerated() {
            let plant = item.structure.species
            let growingAge = plant.annual ? max(0,season.phase-0.035)*0.90 : plant.woody ? floor(age)+min(1,max(0,(season.phase-0.03)/0.50)) : season.phase*2.2
            let alive = plant.woody || plant.evergreen ? 1.0 : plant.annual ? max(0.08,1-max(0,(season.phase-0.84)/0.15)):max(0.10,season.foliage)
            item.layer.position = item.anchor
            let activeSeconds = simulatedYears*settings.pace.secondsPerYear
            let bodySway = (sin(activeSeconds*0.19+Double(plantIndex)*2.4)+sin(activeSeconds*0.073+Double(plantIndex)))*0.006*(0.2+season.wind)*(plant.woody ? 0.5:1)
            item.layer.setAffineTransform(CGAffineTransform(rotationAngle:bodySway).scaledBy(x:item.scale,y:item.scale));item.layer.opacity = Float(alive)
            item.roots.opacity = Float(min(1,age*2))
            let caps = CGMutablePath()
            for (i,branch) in item.structure.branches.enumerated() {
                let growth = min(1,max(0,(growingAge-branch.birth)/0.24))
                let shape = item.branches[i]
                shape.strokeEnd = growth*(plant.annual ? 1-max(0,(season.phase-0.80)/0.2)*0.88:1)
                if plant.annual {
                    let dry = max(0,(season.phase-0.56)/0.35)
                    let path = CGMutablePath();path.move(to:branch.start);path.addQuadCurve(to:CGPoint(x:branch.end.x+dry*9,y:branch.end.y-dry*14),control:CGPoint(x:branch.control.x+dry*4,y:branch.control.y))
                    shape.path = path;shape.opacity = Float(1-dry*0.55)
                }
                shape.lineWidth = branch.width*(0.45+min(age,4)*0.16)
                shape.strokeColor = (plant == .birch && branch.order == 0 ? NSColor(srgbRed:0.70,green:0.68,blue:0.59,alpha:1) : p.ink.blended(withFraction:branch.order == 0 ? 0.18:0.37,of:p.paper)!).cgColor
                if season.winter>0, growth>0.5, branch.order>0 {
                    let start = branch.point(0.18), end = branch.point(min(0.9,growth))
                    caps.move(to:CGPoint(x:start.x,y:start.y+branch.width/2+0.8));caps.addQuadCurve(to:CGPoint(x:end.x,y:end.y+1),control:CGPoint(x:branch.control.x,y:branch.control.y+1.5))
                }
            }
            item.snow.path = caps;item.snow.strokeColor = NSColor(srgbRed:0.98,green:0.98,blue:0.93,alpha:0.78*season.winter).cgColor;item.snow.lineWidth = 1.5+season.winter*1.2
            for (i,organ) in item.structure.organs.enumerated() {
                let branch = item.structure.branches[organ.branch]
                let growth = min(1,max(0,(growingAge-branch.birth-0.24*organ.along)/0.16))
                let springLeaf = min(1,max(0,(season.phase-0.025-organ.variation*0.045)/0.13))
                let shedAt = 0.59+organ.variation*0.18
                let fall = min(1,max(0,(season.phase-shedAt)/0.055))
                let leafSeason = plant.evergreen ? 0.94 : springLeaf*(1-max(0,(season.phase-0.83)/0.14))
                let blossom = season.bloom*min(1,max(0,(season.phase-0.15-organ.variation*0.09)/0.10))
                let visibility = growth*(organ.flower ? blossom : leafSeason)
                let shape = item.leaves[i]
                let point = branch.point(organ.along)
                let t = simulatedYears*settings.pace.secondsPerYear
                let sway = (sin(t*0.41+Double(i)*2.39)+sin(t*0.23+Double(plantIndex)*1.7))*0.025*(0.3+season.wind)
                let dropping = !plant.evergreen && !organ.flower && fall>0
                let groundY = -5+sin(organ.variation*33)*9+cos(organ.variation*73)*4
                shape.position = dropping ? CGPoint(x:point.x+sin(organ.variation*43+fall*5)*fall*28+season.wind*fall*20,y:point.y*(1-fall)+groundY*fall):point
                let leafScale = organ.length*max(0.001,growth*(organ.flower ? blossom:plant.evergreen ? 1:springLeaf))
                shape.setAffineTransform(CGAffineTransform(rotationAngle:organ.angle+sway+(dropping ? fall*(1.2+organ.variation*4.8):0)+(organ.flower && plant == .sunflower ? sin(organ.variation*9)*0.18:0)).scaledBy(x:leafScale,y:leafScale))
                shape.opacity = Float(min(0.97,visibility*(0.76+organ.variation*0.20)*(dropping ? 0.80-organ.variation*0.25:1)))
                let rust = NSColor(srgbRed:0.68,green:0.37+organ.variation*0.16,blue:0.17,alpha:1)
                let green = plant.evergreen ? p.leaf.blended(withFraction:season.winter*0.18,of:NSColor(srgbRed:0.25,green:0.38,blue:0.35,alpha:1))! : p.leaf.blended(withFraction:season.autumn*(0.65+organ.variation*0.3),of:rust) ?? p.leaf
                var color = organ.flower ? p.bloom : (green.blended(withFraction:organ.variation*0.20,of:p.paper) ?? green)
                if plant == .sunflower && organ.flower { color = .init(srgbRed:0.83,green:0.63,blue:0.20,alpha:1) }
                if plant == .lavender && organ.flower { color = .init(srgbRed:0.51,green:0.44,blue:0.64,alpha:1) }
                item.details[i].fillColor = organ.flower ? p.ink.withAlphaComponent(0.78).cgColor:nil
                if plant == .japaneseMaple && !organ.flower { color = p.bloom.blended(withFraction:season.autumn*0.3,of:rust)! }
                if plant == .grass && organ.flower { color = p.ink.blended(withFraction:0.45,of:p.paper)! }
                shape.fillColor = plant.evergreen && plant != .cedar ? nil : color.cgColor;shape.strokeColor = (plant.evergreen ? green.withAlphaComponent(0.88):p.ink.withAlphaComponent(0.36)).cgColor
            }
            let heads = CGMutablePath()
            if plant.annual || plant == .fruitTree {
                for organ in item.structure.organs where organ.flower {
                    let branch = item.structure.branches[organ.branch]
                    let dry = plant.annual ? max(0,(season.phase-0.56)/0.35):0
                    let t = Double(item.branches[organ.branch].strokeEnd),q = 1-t
                    let control = CGPoint(x:branch.control.x+dry*4,y:branch.control.y)
                    let tip = CGPoint(x:branch.end.x+dry*9,y:branch.end.y-dry*14)
                    let at = CGPoint(x:q*q*branch.start.x+2*q*t*control.x+t*t*tip.x,y:q*q*branch.start.y+2*q*t*control.y+t*t*tip.y)
                    let r = plant == .sunflower ? 8.0:plant == .fruitTree ? 4.5:3.0
                    heads.addEllipse(in:CGRect(x:at.x-r,y:at.y-r,width:r*2,height:r*1.6))
                }
            }
            item.seedHeads.path = heads;item.seedHeads.fillColor = (plant == .fruitTree ? NSColor(srgbRed:0.62,green:0.28,blue:0.19,alpha:0.82):p.ink.withAlphaComponent(0.78)).cgColor
            item.seedHeads.opacity = Float(min(1,max(0,(season.phase-0.51)/0.08))*max(0,1-(season.phase-0.86)/0.1))
        }
        let precipitation = CGMutablePath(), seconds = simulatedYears*settings.pace.secondsPerYear
        var random = ArtRandom(state:seed &+ 800)
        let snow = season.winter, amount = max(season.rain,snow*0.48)
        for _ in 0..<80 {
            let x = (random.next()+seconds*(0.008+season.wind*0.01)).truncatingRemainder(dividingBy:1)
            let y = (random.next()-seconds*(snow>0.3 ? 0.019:0.19)).truncatingRemainder(dividingBy:1)
            let at = CGPoint(x:size.width*(0.13+x*0.74),y:size.height*(y<0 ? y+1:y))
            if snow>0.3 { precipitation.addEllipse(in:CGRect(x:at.x,y:at.y,width:1.3+random.next()*1.8,height:2)) }
            else { precipitation.move(to:at);precipitation.addLine(to:CGPoint(x:at.x+season.wind*5,y:at.y-9)) }
        }
        weather.path = precipitation;weather.fillColor = snow>0.3 ? NSColor(srgbRed:0.98,green:0.98,blue:0.95,alpha:amount*0.95).cgColor:nil
        distantRain.path = precipitation;distantRain.setAffineTransform(CGAffineTransform(translationX:size.width*0.025,y:18));distantRain.lineWidth = 0.4
        distantRain.strokeColor = snow>0.3 ? nil:p.ink.withAlphaComponent(amount*0.09).cgColor;distantRain.fillColor = nil
        weather.strokeColor = snow>0.3 ? nil:p.ink.withAlphaComponent(amount*0.29).cgColor;weather.lineWidth = 0.6
        return true
    }
    func draw(in context: CGContext, size: CGSize, time: Double, date: Date) {
        let root = CALayer();root.bounds = CGRect(origin:.zero,size:size)
        _ = updateLayer(root,size:size,time:time,date:date);root.render(in:context)
    }
}
