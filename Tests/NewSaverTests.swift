import AppKit

func runNewSaverTests() {
    runBloomSeedSessionTests()
    runBloomIllustrationTests()
    runCommonplaceMotionTests()
    let date = Date(timeIntervalSince1970:1_800_000_000)
    for plant in BloomPlant.allCases.dropFirst() {
        for seed:UInt64 in [1,42,919] {
            let tree = BloomStructure(species:plant,seed:seed)
            expect(!tree.branches.isEmpty && tree.branches.count<1000 && tree.organs.count<4000,"bounded persistent geometry for \(plant)")
            for branch in tree.branches {
                expect([branch.start.x,branch.start.y,branch.control.x,branch.control.y,branch.end.x,branch.end.y,branch.width,branch.birth].allSatisfy(\.isFinite),"finite botanical structure")
                expect(branch.width>0 && branch.birth>=0,"positive branch dimensions and birth")
            }
            for organ in tree.organs { expect(tree.branches.indices.contains(organ.branch) && (0...1).contains(organ.along),"organs remain attached to valid branches") }
        }
    }
    for emphasis in BloomSeason.allCases {
        var settings = BloomSettings();settings.emphasis = emphasis
        var phases:[Double] = []
        for i in 0..<1000 {
            let calendar = BloomCalendar(years:Double(i)/1000,settings:settings)
            phases.append(calendar.phase)
            expect([calendar.foliage,calendar.bloom,calendar.autumn,calendar.winter,calendar.rain,calendar.wind].allSatisfy { $0.isFinite && (0...1).contains($0) },"bounded continuous phenology")
        }
        expect(zip(phases,phases.dropFirst()).allSatisfy { $0<=$1 },"season emphasis preserves calendar progression")
        expect(phases.contains { $0<0.25 } && phases.contains { $0>0.75 },"every emphasis still visits every season")
    }
    let size = CGSize(width:900,height:600)
    func layerTotal(_ layer:CALayer)->Int { 1+(layer.sublayers ?? []).reduce(0) { $0+layerTotal($1) } }
    func unpaintedVisibleOrgans(_ layer: CALayer, inheritedOpacity: Float = 1) -> Int {
        let opacity = inheritedOpacity*layer.opacity
        guard opacity>0.04 else { return 0 }
        let children = layer.sublayers ?? []
        if let shape = layer as? CAShapeLayer, let path = shape.path,
           path.boundingBoxOfPath.height<2, children.count == 3,
           children.last is CAShapeLayer, shape.fillColor == nil {
            let t = shape.affineTransform()
            if abs(t.a*t.d-t.b*t.c)>1 && children[0].contents == nil { return 1 }
        }
        return children.reduce(0) { $0+unpaintedVisibleOrgans($1,inheritedOpacity:opacity) }
    }
    for plant in [BloomPlant.oak,.sunflower,.pine] {
        let root = CALayer(), scene = YearsInBloomScene(seed:42);var settings = SaverSettings();settings.bloom.plant = plant;settings.bloom.layout = .specimen;settings.bloom.pace = .fast
        scene.apply(settings);scene.start();var largest = 0
        for frame in 0...920 { _ = scene.updateLayer(root,size:size,time:Double(frame)/4,date:date);largest = max(largest,layerTotal(root));expect(unpaintedVisibleOrgans(root) == 0,"paint is prepared before an organ becomes visibly large") }
        expect(scene.simulatedYears>5 && largest<6000,"full cohort renews with bounded retained layers")
        scene.stop();let paused = scene.simulatedYears
        _ = scene.updateLayer(root,size:size,time:9999,date:date);near(scene.simulatedYears,paused,"stopped bloom clock")
        scene.start();_ = scene.updateLayer(root,size:size,time:10000,date:date);near(scene.simulatedYears,paused,"wake does not jump a botanical year")
        scene.stop()
    }
    var selection = CommonplaceSelection(seed:42), layouts = Set<Int>(), entries = Set<String>()
    let days = CommonplaceLibrary.starter
    for _ in 0..<120 {
        let page = selection.next(days:days,density:.automatic)
        layouts.insert(page.layout);entries.formUnion(page.entries.map(\.id))
        expect(selection.recentLayouts.count<=8 && selection.recentEntries.count<=30,"bounded display history")
    }
    expect(layouts.count == 18 && entries.count>30,"long sequence visits all page grammars and most starter writing")
    let resources = URL(fileURLWithPath:"Assets/Commonplace")
    let library = CommonplaceLibrary(archive:nil,resources:resources)
    expect(library.artifacts.count>=10 && library.artifacts.allSatisfy { $0.0.reusable },"starter artifacts decode with verified provenance")
    for theme in CommonplaceTheme.allCases {
        let scene = CommonplaceScene(seed:42,archive:nil,resources:resources)
        var settings = SaverSettings();settings.commonplace.theme = theme;settings.commonplace.pace = .normal
        scene.apply(settings);scene.start()
        let layer = CALayer()
        for size in [CGSize(width:1200,height:800),CGSize(width:800,height:1200),CGSize(width:280,height:180),CGSize(width:2560,height:1080)] {
            _ = scene.updateLayer(layer,size:size,time:0,date:date)
            expect(layer.sublayers?.count == 3,"Commonplace fits a fixed three-layer presentation at every viewport")
        }
        for frame in 0...1100 { _ = scene.updateLayer(layer,size:CGSize(width:900,height:600),time:Double(frame)/4,date:date) }
        expect(scene.renderedPages>=6 && scene.currentLayout>=0 && scene.currentLayout<18,"offline chapters continue without model/network activity")
        scene.stop();let pages = scene.renderedPages
        _ = scene.updateLayer(layer,size:CGSize(width:900,height:600),time:1_000_000,date:date)
        expect(scene.renderedPages == pages,"stopped notebook cannot advance")
    }
    for theme in CommonplaceTheme.allCases.dropFirst() {
        for index in 0..<18 {
            for height in [632.0,937.5,1071,1575] {
                let layout = CommonplaceLayout(index:index,width:1500,height:height,theme:theme)
                expect(layout.note.maxY<layout.title.y-130,"writing excludes title/date band")
                expect(layout.note.width>0 && layout.note.height>0,"positive responsive writing area")
                if layout.picture.width>0 { expect(!layout.note.intersects(layout.picture),"image and reserved credits exclude prose") }
            }
        }
    }
    expect(CommonplaceSettings().sanitized() == CommonplaceSettings(),"default interests preserve settings round-trip order")
    let old = Data("{\"speed\":3,\"labels\":false}".utf8)
    if let settings = try? JSONDecoder().decode(SaverSettings.self,from:old) {
        expect(settings.bloom == BloomSettings() && settings.commonplace == CommonplaceSettings(),"new options default while older preferences decode")
        expect(settings.speed == 3 && !settings.labels,"existing preferences preserved")
    } else { expect(false,"older preference schema remains readable") }
}

func runBloomIllustrationTests() {
    for layout in [BloomLayout.grouping,.meadow,.woodland] {
        let count = layout == .meadow ? 5:3
        let placements = BloomDrawing.placements(layout:layout,count:count,seed:42)
        expect(placements == BloomDrawing.placements(layout:layout,count:count,seed:42),"cluster placement remains stable across annual renewal")
        expect(placements != BloomDrawing.placements(layout:layout,count:count,seed:91),"cluster spacing varies with the garden seed")
        expect(placements.allSatisfy { abs($0.anchor.x)<170 && abs($0.anchor.y)<30 && (0.45...1.1).contains($0.scale) },"clusters preserve bounded fit and plausible relative scale")
        let sorted = placements.map { $0.anchor.x }.sorted()
        let gaps = zip(sorted,sorted.dropFirst()).map { $1-$0 }
        expect((gaps.max()! - gaps.min()!)>12,"cluster gaps avoid an evenly spaced specimen lineup")
    }
    let straight = BloomBranch(start:.zero,control:CGPoint(x:0,y:50),end:CGPoint(x:0,y:100),birth:0,width:8,order:0)
    let stroke = BloomDrawing.branch(straight,growth:1,width:8,tipRatio:0.25,dry:0)
    expect(stroke.body == BloomDrawing.branch(straight,growth:1,width:8,tipRatio:0.25,dry:0).body,"branch brush envelope is deterministic")
    expect(stroke.body.contains(CGPoint(x:3,y:2)) && !stroke.body.contains(CGPoint(x:3,y:98)),"brush envelope narrows toward its tip")
    let growing = BloomDrawing.branch(straight,growth:0.5,width:8,tipRatio:0.25,dry:0)
    near(growing.body.boundingBoxOfPath.maxY,50,"branch envelope follows the existing growth front")
    let empty = BloomDrawing.branch(straight,growth:0,width:8,tipRatio:0.25,dry:0)
    expect(empty.body.isEmpty,"unborn branches have no filled envelope")
    for size in [CGSize(width:1400,height:1000),CGSize(width:800,height:1200),CGSize(width:3440,height:1440)] {
        for seconds in [0.0,234,1000000] {
            let drop = BloomWeatherField.rain(seconds:seconds,size:size,origin:CGPoint(x:0.35,y:0.61),speed:0.18,wind:0.65,length:10)
            let next = BloomWeatherField.rain(seconds:seconds+0.001,size:size,origin:CGPoint(x:0.35,y:0.61),speed:0.18,wind:0.65,length:10)
            let stroke = CGPoint(x:drop.head.x-drop.tail.x,y:drop.head.y-drop.tail.y)
            expect(abs(stroke.x*drop.velocity.y-stroke.y*drop.velocity.x)<0.00001,"rain streak follows travel direction at every aspect ratio")
            var dx = next.head.x-drop.head.x, dy = next.head.y-drop.head.y
            if dx < -size.width/2 { dx += size.width+60 };if dy < -size.height/2 { dy += size.height+60 }
            if dx > size.width/2 { dx -= size.width+60 };if dy > size.height/2 { dy -= size.height+60 }
            expect(abs(dx/0.001-drop.velocity.x)<0.1 && abs(dy/0.001-drop.velocity.y)<0.1,"rain trajectory derivative agrees with streak velocity even after long uptime")
        }
    }
    let field = BloomWeatherField.mask(seed:42)!, fieldAgain = BloomWeatherField.mask(seed:42)!
    expect(field.dataProvider!.data! as Data == fieldAgain.dataProvider!.data! as Data,"cloud field remains deterministic between renders")
    expect(field.bytesPerRow*field.height<512*1024,"moving weather field uses a small shared mask")
    let atmosphere = BloomAtmosphere(), sky = CALayer(), skySize = CGSize(width:640,height:480)
    sky.bounds = CGRect(origin:.zero,size:skySize);sky.addSublayer(atmosphere.background);sky.addSublayer(atmosphere.foreground)
    func weatherFrame(_ year: Double, _ seconds: Double) -> Data {
        let options = BloomSettings(), paper = NSColor(srgbRed:0.94,green:0.93,blue:0.85,alpha:1)
        CATransaction.begin();CATransaction.setDisableActions(true)
        atmosphere.update(size:skySize,seconds:seconds,season:BloomCalendar(years:year,settings:options),settings:options,paper:paper,ink:.brown,seed:42)
        CATransaction.commit()
        let context = bitmap(width:640,height:480)!
        context.setFillColor(paper.cgColor);context.fill(sky.bounds);sky.render(in:context)
        return context.makeImage()!.dataProvider!.data! as Data
    }
    let winterSky = weatherFrame(3.86,250)
    expect(winterSky == weatherFrame(3.86,250),"atmospheric washes and particles are deterministic at paused active time")
    let summerSky = weatherFrame(3.35,218)
    let outer = (24*640+24)*4, center = (240*640+320)*4
    func pixelDifference(_ offset: Int) -> Int { (0..<3).reduce(0) { $0+abs(Int(winterSky[offset+$1])-Int(summerSky[offset+$1])) } }
    expect(pixelDifference(outer)>0,"seasonal cast reaches negative space near page corners")
    expect(pixelDifference(center)>pixelDifference(outer),"weather remains stronger around plants than in negative space")
    let legacy = Data("{\"plant\":\"willow\",\"layout\":\"woodland\",\"palette\":\"moonlit\",\"pace\":\"fast\",\"weather\":\"calm\",\"texture\":\"strong\",\"emphasis\":\"autumn\",\"seed\":91}".utf8)
    if let old = try? JSONDecoder().decode(BloomSettings.self,from:legacy) {
        expect(old.plant == .willow && old.layout == .woodland && old.palette == .moonlit && old.seed == 91,"watercolor migration retains saved botanical choices")
        expect(old.art == BloomArtSettings(),"existing settings select calibrated watercolor without rewriting preferences")
        var tuned = old;tuned.art.edgeIrregularity = 0.7;tuned.art.rendering = .organic
        let data = try! JSONEncoder().encode(tuned)
        expect(try! JSONDecoder().decode(BloomSettings.self,from:data) == tuned,"art controls persist with existing settings")
    } else { expect(false,"old botanical schema decodes") }
    let partial = try! JSONDecoder().decode(BloomArtSettings.self,from:Data("{\"rendering\":\"unknown\",\"paperGrain\":0.2}".utf8))
    expect(partial.rendering == .botanicalWatercolor && partial.paperGrain == 0.2 && partial.wetEdges == 0.25,"partial art settings retain independent defaults")
    var invalid = BloomArtSettings();invalid.edgeIrregularity = .nan;invalid.paperGrain = -1;invalid.wetEdges = 8
    expect(invalid.sanitized().edgeIrregularity == 0.35 && invalid.sanitized().paperGrain == 0 && invalid.sanitized().wetEdges == 1,"nonfinite and extreme artistic controls sanitize")
    let original = CGMutablePath();original.move(to:.zero)
    original.addCurve(to:CGPoint(x:0,y:1),control1:CGPoint(x:-0.3,y:0.2),control2:CGPoint(x:-0.2,y:0.8))
    original.addQuadCurve(to:.zero,control:CGPoint(x:0.4,y:0.6));original.closeSubpath()
    for species in BloomPlant.allCases.dropFirst() {
        let first = BloomIllustration.organicPath(original,species:species,flower:false,variation:0.42,amount:0.35)
        let same = BloomIllustration.organicPath(original,species:species,flower:false,variation:0.42,amount:0.35)
        let other = BloomIllustration.organicPath(original,species:species,flower:false,variation:0.91,amount:0.35)
        expect(first == same && first != other,"seeded \(species) contour is persistent and individual")
        expect(BloomIllustration.organicPath(original,species:species,flower:false,variation:0.42,amount:0) == original,"zero irregularity preserves exact path")
        first.applyWithBlock { e in if e.pointee.type == .moveToPoint { expect(e.pointee.points[0] == .zero,"petiole remains attached after contour deformation") } }
        expect(first.boundingBoxOfPath.width < 0.5 && first.boundingBoxOfPath.height < 1.05,"organic deformation preserves leaf proportions")
    }
    let organ = BloomOrgan(branch:0,along:0.5,angle:0,length:20,variation:0.42,flower:false)
    let path = BloomIllustration.organicPath(original,species:.oak,flower:false,variation:organ.variation,amount:0.35)
    func paint(_ art: BloomArtSettings = BloomArtSettings()) -> BloomIllustration.Painting {
        BloomIllustration.paint(path:path,species:.oak,organ:organ,color:.systemGreen,paper:.white,ink:.brown,art:art,resolution:96)!
    }
    let first = paint(), same = paint()
    expect(first.image.dataProvider!.data! as Data == same.image.dataProvider!.data! as Data,"pigment and fibers render byte-identically from persistent organ seed")
    var organic = BloomArtSettings();organic.rendering = .organic
    expect(first.image.dataProvider!.data! as Data != paint(organic).image.dataProvider!.data! as Data,"organic comparison omits watercolor substrate and bleeding")
    let cache = BloomPaintingCache(limit:first.bytes*2)
    func key(_ i: Double) -> BloomPaintingCache.Key { .init(species:"oak",variation:i,flower:false,autumn:false) }
    _ = cache.painting(key(1)) { first };_ = cache.painting(key(2)) { first }
    _ = cache.painting(key(1)) { expect(false,"cached image must not regenerate");return nil }
    _ = cache.painting(key(3)) { first }
    expect(cache.bytes<=cache.limit && cache.hits == 1 && cache.misses == 3,"bounded cache accounts image row bytes")
    _ = cache.painting(key(2)) { first }
    expect(cache.misses == 4,"least recently used artwork is evicted")
    cache.removeAll();expect(cache.bytes == 0,"palette or resolution invalidation releases cached artwork")
    let tiny = BloomPaintingCache(limit:1);_ = tiny.painting(key(0)) { first }
    expect(tiny.bytes == 0,"oversized painting cannot exceed cache budget")

    let scene = YearsInBloomScene(seed:42),root = CALayer(),date = Date(timeIntervalSince1970:1800000000)
    var settings = SaverSettings();settings.bloom.plant = .oak;settings.bloom.layout = .specimen
    scene.apply(settings);scene.start()
    let size = CGSize(width:900,height:600)
    for i in 0...500 { _ = scene.updateLayer(root,size:size,time:Double(i)/4,date:date) }
    expect(scene.pendingPaintingCount == 0 && scene.paintingCacheMisses>0,"bounded preparation queue completes before mature growth")
    let misses = scene.paintingCacheMisses
    for i in 501...600 { _ = scene.updateLayer(root,size:size,time:Double(i)/4,date:date) }
    expect(scene.paintingCacheMisses == misses,"perennial year boundary reuses artwork without rebuild")
    func snapshot() -> Data {
        let context = bitmap(width:900,height:600)!;root.render(in:context)
        return context.makeImage()!.dataProvider!.data! as Data
    }
    scene.stop();let before = snapshot()
    _ = scene.updateLayer(root,size:size,time:9999,date:date)
    expect(snapshot() == before,"paused watercolor pixels remain identical")
    scene.start();_ = scene.updateLayer(root,size:size,time:10000,date:date)
    expect(snapshot() == before,"resume preserves pigment, geometry and season")
    func paintedLayers(_ layer: CALayer) -> Int {
        (layer.contents == nil ? 0:1)+(layer.sublayers ?? []).reduce(0) { $0+paintedLayers($1) }
    }
    let populated = paintedLayers(root)
    root.contentsScale = 2
    _ = scene.updateLayer(root,size:size,time:10000,date:date)
    expect(paintedLayers(root) == populated,"resizing preserves every visible painting during replacement")
    expect(scene.paintingCacheMisses>misses && scene.paintingCacheBytes<=24*1024*1024,"backing-scale change invalidates bounded raster cache")
    scene.stop();let unfinished = scene.pendingPaintingCount, heldMisses = scene.paintingCacheMisses
    _ = scene.updateLayer(root,size:size,time:20000,date:date)
    expect(scene.pendingPaintingCount == unfinished && scene.paintingCacheMisses == heldMisses,"stop suspends unfinished painting jobs")
    scene.start()
    for _ in 0..<700 { _ = scene.updateLayer(root,size:CGSize(width:3840,height:2160),time:20000,date:date) }
    expect(scene.pendingPaintingCount == 0 && scene.activePaintingBytes<=24*1024*1024,"large Retina artwork finishes within its active raster budget")
    scene.stop()
}

func runCommonplaceMotionTests() {
    let size = CGSize(width:1200,height:800), date = Date(timeIntervalSince1970:1800000000)
    CommonplaceHandwriting.register(resources:URL(fileURLWithPath:"Assets/Commonplace"))
    expect(NSFont(name:CommonplaceHandwriting.face,size:24) != nil,"bundled OFL handwriting font registers without installing it")
    let scene = CommonplaceScene(seed:42,archive:nil,resources:URL(fileURLWithPath:"Assets/Commonplace")), root = CALayer()
    root.bounds = CGRect(origin:.zero,size:size)
    var settings = SaverSettings();settings.commonplace.pace = .normal
    scene.apply(settings);scene.start()
    for frame in 0...160 { _ = scene.updateLayer(root,size:size,time:Double(frame)/4,date:date) }
    let layers = root.sublayers!, desk = layers[0], incoming = layers[2]
    let deskImage = desk.contents as! CGImage, pageImage = incoming.contents as! CGImage
    let cameraBefore = desk.position
    let raster = bitmap(width:pageImage.width,height:pageImage.height)!
    raster.draw(pageImage,in:CGRect(x:0,y:0,width:pageImage.width,height:pageImage.height))
    let blank = raster.makeImage()!.cropping(to:CGRect(x:0,y:0,width:4,height:4))!
    expect((blank.dataProvider!.data! as Data).allSatisfy { $0 == 0 },"page margins are transparent rather than baked desk rectangles")
    for frame in 161...188 { _ = scene.updateLayer(root,size:size,time:Double(frame)/4,date:date) }
    expect(desk.contents as! CGImage === deskImage,"page handoff reuses the same tabletop raster")
    expect(hypot(desk.position.x-cameraBefore.x,desk.position.y-cameraBefore.y)>0.5,"desk camera moves during quiet reading and page handoff")
    let offset = abs(incoming.position.x-desk.position.x)+abs(incoming.position.y-desk.position.y)
    expect(offset>30,"incoming page moves independently of the desk during transition")
    func pixels() -> Data { let c = bitmap(width:1200,height:800)!;root.render(in:c);return c.makeImage()!.dataProvider!.data! as Data }
    scene.stop();let paused = pixels()
    _ = scene.updateLayer(root,size:size,time:9000,date:date);expect(paused == pixels(),"desk pan and page transition pause exactly")
    scene.start();_ = scene.updateLayer(root,size:size,time:10000,date:date);expect(paused == pixels(),"resuming does not jump the camera or handwriting")
    scene.stop()
    for t in stride(from:0.0,to:1000,by:0.25) {
        let camera = CommonplaceDesk.camera(seconds:t,size:size)
        expect(abs(camera.x)<size.width*0.04 && abs(camera.y)<size.height*0.04,"camera stays within tabletop overscan")
    }
}


func runBloomSeedSessionTests() {
    let size = CGSize(width:480,height:320), date = Date(timeIntervalSince1970:1_800_000_000)
    func pixels(_ scene:YearsInBloomScene, _ root:CALayer, time:Double = 0) -> Data {
        root.bounds = CGRect(origin:.zero,size:size)
        _ = scene.updateLayer(root,size:size,time:time,date:date)
        let context = bitmap(width:480,height:320)!
        root.render(in:context)
        return context.makeImage()!.dataProvider!.data! as Data
    }
    let legacyData = try! JSONEncoder().encode(BloomSettings())
    let legacyJSON = try! JSONSerialization.jsonObject(with:legacyData) as! [String:Any]
    expect(legacyJSON["fixedSeedEnabled"] == nil,"default Bloom encoding preserves legacy absence of fixed seed opt-in")
    let legacy = try! JSONDecoder().decode(BloomSettings.self,from:legacyData)
    expect(legacy.fixedSeedEnabled == nil,"legacy Bloom settings decode without fixed seed opt-in")
    for rendering in [BloomRendering.classic, .botanicalWatercolor] {
        var settings = SaverSettings();settings.bloom.art.rendering = rendering
        settings.bloom.fixedSeedEnabled = true;settings.bloom.seed = 731
        let first = YearsInBloomScene(seed:11), second = YearsInBloomScene(seed:22)
        let a = CALayer(), b = CALayer()
        first.apply(settings);second.apply(settings)
        let opening = pixels(first,a)
        expect(opening == pixels(second,b),"fixed composition ignores launch seed in \(rendering)")
        first.start()
        for frame in 0...80 { _ = first.updateLayer(a,size:size,time:Double(frame)/4,date:date) }
        expect(first.simulatedYears>0,"seeded scene advances before reseeding")
        settings.bloom.seed = UInt64.max;first.apply(settings)
        expect(first.simulatedYears == 0 && first.pendingPaintingCount == 0 && first.paintingCacheBytes == 0,"reseed resets time and discards pending paintings and cache")
        first.stop()
        let changed = pixels(first,a,time:1000)
        expect(changed != opening,"new seed changes actual rendered composition")
        let fresh = YearsInBloomScene(seed:99), freshRoot = CALayer();fresh.apply(settings)
        expect(changed == pixels(fresh,freshRoot),"reseeded paper, plants and weather match a fresh fixed-seed scene")
        settings.bloom.seed = 731;first.apply(settings)
        expect(pixels(first,a) == opening,"restoring a fixed seed restores its starting rendering")
        first.start();_ = first.updateLayer(a,size:size,time:9000,date:date)
        expect(first.simulatedYears == 0,"seed reset does not accumulate inactive wall time")
        first.stop()
        settings.bloom.fixedSeedEnabled = nil;settings.bloom.seed = 111
        let defaultScene = YearsInBloomScene(seed:11), defaultRoot = CALayer();defaultScene.apply(settings)
        let defaultPixels = pixels(defaultScene,defaultRoot)
        settings.bloom.seed = 222;first.apply(settings)
        expect(pixels(first,a) == defaultPixels,"disabling repeat returns to original launch seed and ignores stored seed")
        let otherLaunch = YearsInBloomScene(seed:22), otherRoot = CALayer();otherLaunch.apply(settings)
        expect(pixels(otherLaunch,otherRoot) != defaultPixels,"default composition still varies with launch seed")
    }
}
