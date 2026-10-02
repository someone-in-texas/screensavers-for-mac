import AppKit

func runFlourishTests() {
    var s=FlourishSettings()
    var a=FlourishGrowth(seed:42,aspect:1.6,settings:s),b=a
    for frame in 0..<4000 {
        a.advance(0.1);b.advance(0.1)
        if frame%100==0 {
            expect(a.branches==b.branches && a.ornaments==b.ornaments,"Flourish decisions reproduce across long growth")
            expect(a.branches.count<=36 && a.ornaments.count<=450 && a.segmentCount<5300,"Flourish bounded density")
            expect(a.branches.flatMap(\.points).allSatisfy { $0.x.isFinite && $0.y.isFinite && $0.x > -46 && $0.x < a.width+46 && $0.y > -46 && $0.y < 951 },"Flourish finite world coordinates")
        }
    }
    expect(a.segmentCount>400 && a.ornaments.count>15,"Flourish develops stems and botanical details")
    expect(a.occupancy.contains {$0>0},"growth records spatial occupancy")
    expect(a.crowd(FlourishPoint(x:-1000,y:10))==0,"occupancy boundary access is safe")
    expect(a.branches.allSatisfy {!$0.alive},"mature stems stop presentation interpolation")
    for style in FlourishStyle.allCases {
        var dense=FlourishSettings();dense.style=style;dense.density=1;dense.leaves=1;dense.flowers=1
        var slow=FlourishGrowth(seed:91,aspect:0.55,settings:dense),fast=slow
        for _ in 0..<900 {slow.advance(1.0/30);fast.advance(1.0/60);fast.advance(1.0/60)}
        expect(slow.branches==fast.branches && slow.ornaments==fast.ornaments,"growth independent of presentation cadence")
        for _ in 0..<2400 {slow.advance(0.25)}
        expect(slow.branches.count<=36 && slow.ornaments.count<=450 && slow.segmentCount<5300,"dense portrait stays bounded across every growth style")
    }
    let different=FlourishGrowth(seed:99,aspect:1.6,settings:s)
    expect(different.branches != FlourishGrowth(seed:42,aspect:1.6,settings:s).branches,"seeds vary root composition")
    let base=FlourishGeometry.thickness(depth:0,progress:0,character:.finePen)
    expect(base>FlourishGeometry.thickness(depth:1,progress:0,character:.finePen),"branch hierarchy tapers by depth")
    expect(base>FlourishGeometry.thickness(depth:0,progress:1,character:.finePen),"stems taper toward the tip")
    // A bent stroke must hug its centerline, never close each side into a triangle.
    let branch=FlourishBranch(points:[.init(x:0,y:0),.init(x:20,y:20),.init(x:40,y:0)],angle:0,curvature:0,depth:0,family:0,phase:0,energy:100)
    let path=FlourishGeometry.stem(branch,character:.finePen)
    expect(!path.contains(CGPoint(x:20,y:5)) && path.contains(CGPoint(x:20,y:20)),"tapered polygon does not create diagonal fill artifacts")
    for kind in 0..<8 {
        let o=FlourishOrnament(position:.init(x:0,y:0),angle:0,size:30,kind:kind,family:0,born:0,variation:0.4)
        let geometry=FlourishGeometry.ornament(o)
        expect(!geometry.0.isEmpty && !geometry.1.isEmpty && geometry.0.boundingBox.width<100,"bounded procedural leaf/flower geometry")
    }
    for palette in FlourishPalette.allCases {expect(palette.background.valid && palette.inks.count==4 && palette.inks.allSatisfy(\.valid),"Flourish palette roles valid")}
    s.speed = .nan;s.density=9;s.flowers = -1
    expect(s.sanitized().speed==1 && s.sanitized().density==1 && s.sanitized().flowers==0,"Flourish setting bounds")
    var value=SaverSettings();value.flourish.palette = .midnight;value.flourish.seedBehavior = .fixed;value.flourish.seed=UInt64.max
    expect((try! JSONDecoder().decode(SaverSettings.self,from:JSONEncoder().encode(value)))==value,"Flourish settings round trip")
    expect((try! JSONDecoder().decode(SaverSettings.self,from:Data("{\"speed\":7}".utf8))).flourish==FlourishSettings(),"old preferences gain Flourish defaults")
    let scene=FlourishScene(seed:42),root=CALayer(),size=CGSize(width:600,height:400)
    scene.start();_ = scene.updateLayer(root,size:size,time:0,date:Date())
    for frame in 1...400 { _ = scene.updateLayer(root,size:size,time:Double(frame)/10,date:Date()) }
    let before=scene.growth!.branches
    scene.stop();_ = scene.updateLayer(root,size:size,time:2000,date:Date());scene.start();_ = scene.updateLayer(root,size:size,time:4000,date:Date())
    expect(scene.growth!.branches==before,"Flourish excludes suspended time")
    expect(root.sublayers?.count==1,"Flourish has one bounded canvas")
    scene.stop()
}
