import AppKit

func runDappleTests() {
    var settings = DappleSettings()
    let a = DappleSimulation(seed:42, aspect:16.0/9, settings:settings)
    let b = DappleSimulation(seed:42, aspect:16.0/9, settings:settings)
    expect(a.dots == b.dots, "Dapple seed reproduces initial population")
    expect(a.dots != DappleSimulation(seed:43, aspect:16.0/9, settings:settings).dots, "Dapple seeds vary composition")
    expect((20...45).contains(a.dots.count), "balanced population leaves breathing room")
    expect(a.dots.allSatisfy { (18...67).contains($0.radius) && (0..<5).contains($0.color) }, "sizes and color roles are bounded")
    for palette in DapplePalette.allCases {
        expect(palette.background.valid && palette.colors.count >= 5 && palette.colors.allSatisfy(\.valid), "valid curated palette \(palette)")
    }
    settings.speed = .nan; settings.texture = 99
    expect(settings.sanitized().speed == 1 && settings.sanitized().texture == 1, "Dapple settings clamp invalid numbers")
    settings.speed = -1; expect(settings.sanitized().speed == 0.35, "slowest motion still moves")
    settings = DappleSettings(); settings.seedBehavior = .daily
    expect(settings.resolvedSeed(fresh:1,date:Date(timeIntervalSince1970:100000)) == settings.resolvedSeed(fresh:2,date:Date(timeIntervalSince1970:100100)), "daily seed ignores launch randomness")
    settings.seedBehavior = .fixed; settings.seed = UInt64.max
    expect(settings.resolvedSeed(fresh:1,date:Date()) == UInt64.max, "full-range fixed seed")
    var saved = SaverSettings(); saved.dapple = settings
    expect((try! JSONDecoder().decode(SaverSettings.self,from:JSONEncoder().encode(saved))) == saved, "Dapple settings round-trip")
    expect((try! JSONDecoder().decode(SaverSettings.self,from:Data("{\"speed\":7}".utf8))).dapple == DappleSettings(), "older records gain Dapple defaults")
    settings = DappleSettings()
    var thirty = DappleSimulation(seed:7,aspect:16.0/9,settings:settings), sixty = thirty
    for _ in 0..<300 { thirty.advance(1.0/30); sixty.advance(1.0/60); sixty.advance(1.0/60) }
    expect(thirty.dots == sixty.dots, "simulation is independent of 30 vs 60 Hz presentation")
    for motion in DappleMotion.allCases {
        settings.motion = motion; settings.density = .full; settings.size = .large; settings.speed = 1.7
        var sim = DappleSimulation(seed:42,aspect:0.65,settings:settings)
        var same = sim
        for frame in 0..<18000 {
            sim.advance(1.0/30); same.advance(1.0/30)
            if frame % 300 == 0 {
                expect(sim.dots == same.dots, "fixed-step simulation remains deterministic")
                expect(sim.dots.allSatisfy { [$0.x,$0.y,$0.vx,$0.vy,$0.rotation,$0.squash].allSatisfy(\.isFinite) && abs($0.vx)<150 && abs($0.vy)<180 && $0.x > -250 && $0.x < sim.width+250 && $0.y > -100 && $0.y < 1100 }, "ten-minute dense portrait simulation remains bounded: \(motion)")
            }
        }
    }
    let terrain = DappleTerrain(phase:1.3)
    for lane in 0..<3 {
        for x in stride(from:-200.0,to:2200,by:9) {
            let y = terrain.height(x,lane:lane,time:0)
            expect(abs(terrain.height(x+0.01,lane:lane,time:0)-y)<0.004, "continuous terrain")
            expect(abs(y-(145+Double(lane)*238))<=73, "terrain range")
            near((terrain.height(x+0.001,lane:lane,time:0)-terrain.height(x-0.001,lane:lane,time:0))/0.002,terrain.slope(x,lane:lane,time:0),"terrain derivative",tolerance:0.00001)
        }
    }
    for radius in [18.0,40,80] {
        var dots = [DappleDot(x:0,y:0,vx:30,vy:0,radius:radius,phase:0,lane:0,color:0,nextHop:10),DappleDot(x:radius+15,y:0,vx:-20,vy:0,radius:30,phase:0,lane:0,color:1,nextHop:10)]
        let energy = dots.reduce(0) { $0 + $1.radius*$1.radius*($1.vx*$1.vx+$1.vy*$1.vy) }
        for _ in 0..<5 { DappleSimulation.resolve(&dots,0,1,impulse:true) }
        expect(hypot(dots[0].x-dots[1].x,dots[0].y-dots[1].y)>radius+29.5, "contacts separate unequal sizes")
        expect(dots.reduce(0) { $0 + $1.radius*$1.radius*($1.vx*$1.vx+$1.vy*$1.vy) } <= energy, "contacts cannot add energy")
    }
    func pixels(_ material: DappleMaterial, seed: UInt64 = 42) -> Data {
        let scene = DappleScene(seed:seed), c = bitmap(width:600,height:400)!
        var s = SaverSettings(); s.dapple.material = material
        scene.apply(s); scene.start(); scene.draw(in:c,size:CGSize(width:600,height:400),time:0,date:Date(timeIntervalSince1970:0)); scene.stop()
        return c.makeImage()!.dataProvider!.data! as Data
    }
    let paper = pixels(.paper)
    expect(paper == pixels(.paper), "Dapple pixels reproduce for fixed seed and viewport")
    expect(paper != pixels(.paper,seed:99), "Dapple different seeds produce different artwork")
    expect(Set(DappleMaterial.allCases.map { pixels($0) }).count == 4, "all four materials visibly differ at the same pose")
    // Rendering uses a bounded layer tree and immutable textures between frames.
    let scene = DappleScene(seed:42), root = CALayer(), size = CGSize(width:1200,height:800)
    scene.start(); _ = scene.updateLayer(root,size:size,time:0,date:Date())
    let field = root.sublayers![0].sublayers![0], first = field.sublayers![0].sublayers![0].contents as! CGImage
    let count = field.sublayers!.count
    for frame in 1...180 { _ = scene.updateLayer(root,size:size,time:Double(frame)/30,date:Date()) }
    expect(field.sublayers!.count == count && (field.sublayers![0].sublayers![0].contents as! CGImage) === first, "textures and layer population stay cached during motion")
    let before = scene.simulation!.dots
    scene.stop(); _ = scene.updateLayer(root,size:size,time:1000,date:Date()); scene.start(); _ = scene.updateLayer(root,size:size,time:2000,date:Date())
    expect(scene.simulation!.dots == before,"stopped scene excludes suspended time")
    expect(field.sublayers!.allSatisfy { $0.animationKeys()?.isEmpty ?? true }, "Dapple frame publication adds no implicit animations")
    var textureOff = SaverSettings(); textureOff.dapple.texture = 0; textureOff.dapple.shadows = false; textureOff.dapple.backgroundTexture = false
    scene.apply(textureOff); _ = scene.updateLayer(root,size:size,time:2001,date:Date())
    expect(field.sublayers!.allSatisfy { $0.shadowOpacity == 0 }, "shadows toggle updates every dot")
    scene.stop()
    let daily = DappleScene(), dailyRoot = CALayer()
    var dailySettings = SaverSettings(); dailySettings.dapple.seedBehavior = .daily
    daily.apply(dailySettings); daily.start()
    _ = daily.updateLayer(dailyRoot,size:size,time:0,date:Date(timeIntervalSince1970:172800))
    let dayOne = daily.simulation!.dots
    daily.stop(); daily.start()
    _ = daily.updateLayer(dailyRoot,size:size,time:100,date:Date(timeIntervalSince1970:173800))
    expect(daily.simulation!.dots == dayOne,"daily scene repeats on same-day restart")
    daily.stop(); daily.start()
    _ = daily.updateLayer(dailyRoot,size:size,time:200,date:Date(timeIntervalSince1970:259200))
    expect(daily.simulation!.dots != dayOne,"daily scene refreshes on next-day restart")
    daily.stop()
}
