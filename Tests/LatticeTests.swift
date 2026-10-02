import AppKit

func runLatticeTests() {
    var settings=LatticeSettings()
    for mode in LatticeMode.allCases {
        settings.mode=mode
        var a=LatticeWorld(seed:42,width:48,height:30,settings:settings),b=a
        var activeSamples=0,changes=0,eventKinds=Set<Int>(),maximum=0.0
        for generation in 0..<3000 {
            a.step();b.step()
            if generation%50==0 {
                expect(a.cells==b.cells && a.events==b.events,"Lattice deterministic updates: \(mode)")
                expect(a.cells.allSatisfy {$0.state<=36 && $0.energy.isFinite && (0...1).contains($0.energy)},"Lattice valid states/resources")
                expect(a.cells.count==48*30 && a.events.count<=3,"Lattice bounded storage/events")
                if a.liveFraction>0 {activeSamples+=1};if a.changeFraction>0 {changes+=1};maximum=max(maximum,a.liveFraction)
            }
            for e in a.events {eventKinds.insert(e.kind.rawValue);expect(a.generation-e.born<=e.duration,"event expiry")}
        }
        expect(activeSamples>30 && changes>30 && maximum<0.90,"long-run world remains active without saturation: \(mode)")
        expect(eventKinds.count>=3,"long runs produce several local event types")
        a.clear();var recovered=false
        for _ in 0..<100 {a.step();recovered = recovered || a.cells.contains {$0.state>0 && $0.state<=12}}
        expect(recovered,"dead worlds recover locally without reset")
    }
    var driftSettings=LatticeSettings();driftSettings.mode = .drift;driftSettings.events=0
    var drift=LatticeWorld(seed:91,width:160,height:100,settings:driftSettings),driftSamples=0,driftLive=0.0
    for generation in 0..<6000 {
        drift.step()
        if generation>1000 && generation%50==0 {driftSamples+=1;driftLive+=drift.liveFraction}
    }
    expect(driftLive/Double(driftSamples)>0.003,"Drift maintains distributed life at gallery resolution without optional events")
    expect(LatticeWorld.birth(mode:.bloom,excited:1,living:2,energy:0.8,substrate:0.6,directionActive:false),"Bloom front propagates with resources")
    expect(!LatticeWorld.birth(mode:.bloom,excited:1,living:2,energy:0.1,substrate:0.6,directionActive:false),"exhausted habitat suppresses births")
    expect(!LatticeWorld.birth(mode:.drift,excited:2,living:2,energy:0.8,substrate:0.6,directionActive:false),"Drift requires upstream excitation")
    expect(!LatticeWorld.birth(mode:.signal,excited:1,living:1,energy:0.8,substrate:0.1,directionActive:true),"Signal respects nonconductive substrate")
    var tiny=LatticeWorld(seed:UInt64.max,width:0,height:0,settings:settings)
    for _ in 0..<500 {tiny.step()};expect(tiny.cells.count==144,"small dimensions clamp and wrapped boundaries stay safe")
    for p in LatticePalette.allCases {expect(p.background.valid && p.colors.count==4 && p.colors.allSatisfy(\.valid),"Lattice palette roles valid")}
    settings.speed = .infinity;settings.glow=20;settings.activity = -1
    expect(settings.sanitized().speed==10 && settings.sanitized().glow==1 && settings.sanitized().activity==0,"Lattice numeric bounds")
    var value=SaverSettings();value.lattice.palette = .amber;value.lattice.mode = .signal;value.lattice.seed=UInt64.max
    expect((try! JSONDecoder().decode(SaverSettings.self,from:JSONEncoder().encode(value)))==value,"Lattice settings round trip")
    expect((try! JSONDecoder().decode(SaverSettings.self,from:Data("{\"speed\":7}".utf8))).lattice==LatticeSettings(),"older settings retain defaults")
    let scene=LatticeScene(seed:42),root=CALayer(),size=CGSize(width:600,height:400)
    scene.start();_ = scene.updateLayer(root,size:size,time:0,date:Date())
    for frame in 1...200 {_ = scene.updateLayer(root,size:size,time:Double(frame)/30,date:Date())}
    let before=scene.world!.generation
    scene.stop();_ = scene.updateLayer(root,size:size,time:1000,date:Date());scene.start();_ = scene.updateLayer(root,size:size,time:2000,date:Date())
    expect(scene.world!.generation==before,"Lattice stop/restart excludes suspended time")
    let canvas=root.sublayers![0],picture=canvas.sublayers![0]
    expect(picture.magnificationFilter == .nearest && canvas.sublayers!.count==1,"pixel presentation uses one crisp image, no per-cell layers")
    let image=picture.contents as! CGImage
    expect((picture.bounds.width/Double(image.width)).rounded()==picture.bounds.width/Double(image.width),"integer pixel scaling")
    expect(picture.frame.minX<=0 && picture.frame.minY<=0 && picture.frame.maxX>=size.width && picture.frame.maxY>=size.height,"integer lattice fills the viewport without an inset matte")
    scene.stop()
}
