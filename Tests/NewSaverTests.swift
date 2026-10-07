import AppKit

func runNewSaverTests() {
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
    for plant in [BloomPlant.oak,.sunflower,.pine] {
        let root = CALayer(), scene = YearsInBloomScene(seed:42);var settings = SaverSettings();settings.bloom.plant = plant;settings.bloom.layout = .specimen;settings.bloom.pace = .fast
        scene.apply(settings);scene.start();var largest = 0
        for frame in 0...920 { _ = scene.updateLayer(root,size:size,time:Double(frame)/4,date:date);largest = max(largest,layerTotal(root)) }
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
